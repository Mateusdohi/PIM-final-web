import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/injection.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/validators.dart';
import '../../domain/repositories/repositories.dart';
import '../accessibility/accessibility_sheet.dart';
import '../common/widgets.dart';
import 'bloc/auth_bloc.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _enableBiometric = false;
  bool _deviceHasBiometric = false;
  bool _autoPrompted = false;

  @override
  void initState() {
    super.initState();
    sl<BiometricAuthenticator>().isAvailable.then((v) {
      if (mounted) setState(() => _deviceHasBiometric = v);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bloc = context.read<AuthBloc>();
      final s = bloc.state;
      if (s.failure != null) showAppSnack(context, s.failure!.message, error: true);
      // Acesso rápido ativado: já abre o prompt de biometria ao entrar no app
      if (s.promptBiometric && !_autoPrompted) {
        _autoPrompted = true;
        bloc.add(const BiometricLoginRequested());
      }
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    context.read<AuthBloc>().add(LoginSubmitted(_email.text, _password.text, enableBiometric: _enableBiometric));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: BlocConsumer<AuthBloc, AuthState>(
          listenWhen: (p, c) => p.errorSeq != c.errorSeq && c.failure != null,
          listener: (context, s) => showAppSnack(context, s.failure!.message, error: true),
          builder: (context, state) {
            return SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                // Apresentação (mesmo bloco azul-marinho do login web)
                Container(
                  color: AppColors.navy,
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Align(alignment: Alignment.centerRight, child: AccessibilityButton()),
                    Row(children: [
                      Semantics(label: 'Logotipo Champions Card', child: Image.asset('assets/images/champions_card.png', height: 52)),
                      const SizedBox(width: 12),
                      const Text('CHAMPIONS\nCARD',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 1, height: 1.15)),
                    ]),
                    const SizedBox(height: 24),
                    const Text('Viva os melhores',
                        style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, height: 1.1)),
                    const Text('momentos',
                        style: TextStyle(color: AppColors.brandLight, fontSize: 30, fontWeight: FontWeight.w800, height: 1.1)),
                    const SizedBox(height: 12),
                    const Text(
                      'Compre ingressos dos jogos do seu time, escolha seu assento e ganhe desconto como sócio.',
                      style: TextStyle(color: Color(0xFFD6DEEA), height: 1.5),
                    ),
                  ]),
                ),
                // Formulário
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _form,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      const Text('Fazer login',
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.text)),
                      const SizedBox(height: 4),
                      const Text('Acesse sua conta para continuar', style: TextStyle(color: AppColors.muted)),
                      const SizedBox(height: 20),
                      const _FieldLabel('E-mail'),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(hintText: 'seu@email.com'),
                        validator: Validators.email,
                      ),
                      const SizedBox(height: 14),
                      const _FieldLabel('Senha'),
                      TextFormField(
                        controller: _password,
                        obscureText: _obscure,
                        autofillHints: const [AutofillHints.password],
                        decoration: InputDecoration(
                          hintText: 'Sua senha',
                          suffixIcon: IconButton(
                            tooltip: _obscure ? 'Mostrar senha' : 'Ocultar senha',
                            icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) => Validators.required(v, 'Informe a senha'),
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      if (_deviceHasBiometric)
                        CheckboxListTile(
                          value: _enableBiometric,
                          onChanged: (v) => setState(() => _enableBiometric = v ?? false),
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: const Text('Ativar acesso rápido com biometria / Face ID', style: TextStyle(fontSize: 13)),
                        ),
                      const SizedBox(height: 18),
                      BusyButton(label: 'FAZER LOGIN', busy: state.busy, onPressed: _submit),
                      if (state.biometricReady && _deviceHasBiometric) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: state.busy ? null : () => context.read<AuthBloc>().add(const BiometricLoginRequested()),
                          icon: const Icon(Icons.fingerprint),
                          label: const Text('ENTRAR COM BIOMETRIA'),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Text('Não tenho login: ', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                        GestureDetector(
                          onTap: state.busy ? null : () => context.push('/register'),
                          child: const Text('FAZER CADASTRO',
                              style: TextStyle(color: AppColors.brand, fontSize: 13, fontWeight: FontWeight.w800, decoration: TextDecoration.underline)),
                        ),
                      ]),
                    ]),
                  ),
                ),
              ]),
            );
          },
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
      );
}
