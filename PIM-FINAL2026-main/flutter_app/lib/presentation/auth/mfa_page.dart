import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/di/injection.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/mfa.dart';
import '../../domain/repositories/repositories.dart';
import '../common/widgets.dart';
import 'bloc/auth_bloc.dart';

/// Autenticador (MFA): ativação com QR Code + chave em texto, códigos de recuperação,
/// gerar novos códigos e desativar (os dois pedem a senha atual). A compra exige o código de 6 dígitos.
class MfaPage extends StatefulWidget {
  const MfaPage({super.key});

  @override
  State<MfaPage> createState() => _MfaPageState();
}

class _MfaPageState extends State<MfaPage> {
  final _repo = sl<AuthRepository>();
  final _code = TextEditingController();
  final _password = TextEditingController();

  MfaStatus? _status;
  MfaSetup? _setup; // preenchido só durante a ativação
  List<String>? _recovery; // códigos recém-gerados (aparecem uma vez)
  bool _busy = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    final r = await _repo.mfaStatus();
    if (!mounted) return;
    setState(() {
      _status = r.valueOrNull;
      _loadError = r.failureOrNull?.message;
    });
  }

  /// Atualiza o usuário no app (para o aviso "ative o autenticador" sumir/aparecer e a compra liberar/bloquear).
  Future<void> _syncUser() async {
    final r = await _repo.refreshUser();
    final u = r.valueOrNull;
    if (u != null && mounted) context.read<AuthBloc>().add(UserUpdated(u));
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _start() => _run(() async {
        final r = await _repo.mfaSetup();
        if (!mounted) return;
        r.fold((f) => showAppSnack(context, f.message, error: true), (s) {
          setState(() {
            _setup = s;
            _recovery = null;
            _code.clear();
          });
        });
      });

  Future<void> _confirm() => _run(() async {
        if (_code.text.trim().isEmpty) {
          showAppSnack(context, 'Digite o código de 6 dígitos do aplicativo.', error: true);
          return;
        }
        final r = await _repo.mfaEnable(_code.text.trim());
        if (!mounted) return;
        await r.fold((f) async => showAppSnack(context, f.message, error: true), (codes) async {
          setState(() {
            _setup = null;
            _recovery = codes;
            _code.clear();
            _status = MfaStatus(enabled: true, recoveryCodesLeft: codes.length);
          });
          showAppSnack(context, 'Autenticador ativado. Guarde os códigos de recuperação.');
          await _syncUser();
        });
      });

  Future<void> _newCodes() => _run(() async {
        final pwd = _password.text;
        if (pwd.isEmpty) {
          showAppSnack(context, 'Digite sua senha atual.', error: true);
          return;
        }
        final r = await _repo.mfaNewRecoveryCodes(pwd);
        if (!mounted) return;
        r.fold((f) => showAppSnack(context, f.message, error: true), (codes) {
          setState(() {
            _recovery = codes;
            _password.clear();
            _status = MfaStatus(enabled: true, recoveryCodesLeft: codes.length);
          });
          showAppSnack(context, 'Novos códigos gerados. Os anteriores deixaram de valer.');
        });
      });

  Future<void> _disable() async {
    final pwd = _password.text;
    if (pwd.isEmpty) {
      showAppSnack(context, 'Digite sua senha atual.', error: true);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Desativar o autenticador?'),
        content: const Text('Sem ele você não poderá comprar ingressos até ativar de novo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCELAR')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('DESATIVAR')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(() async {
      final r = await _repo.mfaDisable(pwd);
      if (!mounted) return;
      await r.fold((f) async => showAppSnack(context, f.message, error: true), (_) async {
        setState(() {
          _status = const MfaStatus(enabled: false, recoveryCodesLeft: 0);
          _recovery = null;
          _password.clear();
        });
        showAppSnack(context, 'Autenticador desativado.');
        await _syncUser();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    return Scaffold(
      appBar: AppBar(title: const Text('AUTENTICADOR (MFA)')),
      body: SafeArea(
        child: status == null
            ? Center(
                child: _loadError == null
                    ? const CircularProgressIndicator()
                    : Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(_loadError!, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          OutlinedButton(onPressed: _loadStatus, child: const Text('TENTAR DE NOVO')),
                        ]),
                      ),
              )
            : ListView(padding: const EdgeInsets.all(20), children: [
                AppCard(
                  borderColor: status.enabled ? AppColors.brand : AppColors.warning,
                  child: Row(children: [
                    Icon(status.enabled ? Icons.verified_user : Icons.shield_outlined, color: status.enabled ? AppColors.brand : AppColors.warning),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        status.enabled
                            ? 'Autenticador ATIVADO. A compra de ingressos pede o código de 6 dígitos do seu aplicativo.'
                            : 'Autenticador DESATIVADO. Para comprar ingressos é preciso ativar: a compra é confirmada com um código de 6 dígitos do seu aplicativo (Microsoft Authenticator, Google Authenticator, Authy...).',
                        style: const TextStyle(fontSize: 13, height: 1.4),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
                if (!status.enabled) ..._disabledSection(),
                if (status.enabled) ..._enabledSection(status),
                if (_recovery != null) ..._recoverySection(_recovery!),
              ]),
      ),
    );
  }

  List<Widget> _disabledSection() {
    final s = _setup;
    if (s == null) {
      return [BusyButton(label: 'ATIVAR AUTENTICADOR', icon: Icons.qr_code_2, busy: _busy, onPressed: _start)];
    }
    return [
      const Text('1. Abra o Microsoft Authenticator, o Google Authenticator ou outro aplicativo e escaneie o QR Code. '
          'Se preferir, digite a chave abaixo no aplicativo (conta baseada em tempo).',
          style: TextStyle(height: 1.4)),
      const SizedBox(height: 12),
      Center(
        child: Semantics(
          label: 'QR Code para o aplicativo autenticador. A mesma chave está escrita abaixo.',
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.borderSoft)),
            child: QrImageView(data: s.otpAuthUri, size: 200, backgroundColor: Colors.white),
          ),
        ),
      ),
      const SizedBox(height: 12),
      const Center(child: Text('CHAVE (mesmo valor do QR Code)', style: TextStyle(color: AppColors.muted, fontSize: 11, letterSpacing: 1.5))),
      const SizedBox(height: 4),
      Center(child: SelectableText(s.secret, style: const TextStyle(fontFamily: 'monospace', fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: 1.5))),
      Center(
        child: TextButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: s.secret.replaceAll(' ', '')));
            showAppSnack(context, 'Chave copiada');
          },
          icon: const Icon(Icons.copy, size: 16),
          label: const Text('COPIAR CHAVE'),
        ),
      ),
      const SizedBox(height: 8),
      const Text('2. Digite o código de 6 dígitos que o aplicativo está mostrando agora.', style: TextStyle(height: 1.4)),
      const SizedBox(height: 8),
      TextField(
        controller: _code,
        keyboardType: TextInputType.number,
        maxLength: 7,
        textAlign: TextAlign.center,
        autofillHints: const [AutofillHints.oneTimeCode],
        style: const TextStyle(fontSize: 22, letterSpacing: 6, fontWeight: FontWeight.w800),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]'))],
        decoration: const InputDecoration(hintText: '000000', counterText: ''),
      ),
      const SizedBox(height: 8),
      BusyButton(label: 'CONFIRMAR E ATIVAR', busy: _busy, onPressed: _confirm),
    ];
  }

  List<Widget> _enabledSection(MfaStatus status) => [
        Text('Códigos de recuperação restantes: ${status.recoveryCodesLeft}', style: const TextStyle(color: AppColors.muted)),
        const SizedBox(height: 12),
        const SectionLabel('SENHA ATUAL'),
        const Text('Necessária para gerar novos códigos ou desativar.', style: TextStyle(color: AppColors.muted, fontSize: 12)),
        const SizedBox(height: 8),
        TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'SENHA ATUAL')),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: _busy ? null : _newCodes, child: const Text('GERAR NOVOS CÓDIGOS')),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _busy ? null : _disable,
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger)),
          child: const Text('DESATIVAR AUTENTICADOR'),
        ),
      ];

  List<Widget> _recoverySection(List<String> codes) => [
        const SizedBox(height: 20),
        AppCard(
          borderColor: AppColors.warning,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Códigos de recuperação', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('Guarde em local seguro: aparecem só agora e cada um vale uma vez (servem se você perder o celular).',
                style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.4)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final c in codes)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.borderSoft)),
                  child: SelectableText(c, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                ),
            ]),
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: codes.join('\n')));
                showAppSnack(context, 'Códigos copiados');
              },
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('COPIAR TODOS'),
            ),
          ]),
        ),
      ];
}
