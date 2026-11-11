import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injection.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/validators.dart';
import '../../domain/entities/team.dart';
import '../../domain/repositories/repositories.dart';
import 'package:go_router/go_router.dart';

import '../auth/bloc/auth_bloc.dart';
import '../common/widgets.dart';

/// Perfil: editar nome e time (PUT /api/auth/me) e trocar a senha (POST /api/auth/change-password).
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _profileForm = GlobalKey<FormState>();
  final _passForm = GlobalKey<FormState>();
  late final TextEditingController _name;
  late String _team;
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _savingProfile = false;
  bool _savingPass = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthBloc>().state.user;
    _name = TextEditingController(text: user?.name ?? '');
    _team = TeamInfo.of(user?.team ?? '') != null ? user!.team : TeamInfo.all.first.slug;
  }

  @override
  void dispose() {
    _name.dispose();
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_profileForm.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _savingProfile = true);
    final result = await sl<AuthRepository>().updateProfile(name: _name.text.trim(), team: _team);
    if (!mounted) return;
    setState(() => _savingProfile = false);
    result.fold(
      (f) => showAppSnack(context, f.message, error: true),
      (user) {
        context.read<AuthBloc>().add(UserUpdated(user));
        showAppSnack(context, 'Perfil atualizado.');
      },
    );
  }

  Future<void> _changePassword() async {
    if (!_passForm.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _savingPass = true);
    final result = await sl<AuthRepository>().changePassword(current: _current.text, next: _new.text);
    if (!mounted) return;
    setState(() => _savingPass = false);
    result.fold(
      (f) => showAppSnack(context, f.message, error: true),
      (_) {
        _current.clear();
        _new.clear();
        _confirm.clear();
        showAppSnack(context, 'Senha alterada com sucesso.');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthBloc b) => b.state.user);
    return Scaffold(
      appBar: AppBar(title: const Text('PERFIL')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        AppCard(
          child: Row(children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: AppColors.navy,
              child: Text((user?.name.isNotEmpty ?? false) ? user!.name.substring(0, 1).toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(user?.email ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  (user?.isMember ?? false)
                      ? '${user!.planName} • ${user.planPercent}% de desconto'
                      : 'Você ainda não é sócio',
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                if (user?.memberCode != null)
                  Text('Código de sócio: ${user!.memberCode}', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                Text(user?.mfaEnabled == true ? 'Autenticador (MFA) ativado' : 'Autenticador (MFA) desativado',
                    style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                TextButton(
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32), alignment: Alignment.centerLeft),
                  onPressed: () => context.push('/mfa'),
                  child: Text(user?.mfaEnabled == true ? 'GERENCIAR AUTENTICADOR' : 'ATIVAR AUTENTICADOR'),
                ),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 20),
        const SectionLabel('Dados pessoais'),
        Form(
          key: _profileForm,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const _Label('Nome'),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              validator: Validators.name,
            ),
            const SizedBox(height: 14),
            const _Label('Time do coração'),
            DropdownButtonFormField<String>(
              initialValue: _team,
              items: [
                for (final t in TeamInfo.all)
                  DropdownMenuItem(
                    value: t.slug,
                    child: Row(children: [TeamLogo(t.slug, size: 22), const SizedBox(width: 10), Text(t.name)]),
                  ),
              ],
              onChanged: (v) => setState(() => _team = v ?? _team),
            ),
            const SizedBox(height: 18),
            BusyButton(label: 'SALVAR ALTERAÇÕES', busy: _savingProfile, onPressed: _saveProfile),
          ]),
        ),
        const SizedBox(height: 28),
        const SectionLabel('Trocar senha'),
        Form(
          key: _passForm,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const _Label('Senha atual'),
            TextFormField(
              controller: _current,
              obscureText: _obscure,
              validator: (v) => Validators.required(v, 'Informe a senha atual'),
              decoration: InputDecoration(
                suffixIcon: IconButton(
                  tooltip: _obscure ? 'Mostrar senhas' : 'Ocultar senhas',
                  icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const _Label('Nova senha'),
            TextFormField(controller: _new, obscureText: _obscure, validator: Validators.password),
            const SizedBox(height: 14),
            const _Label('Confirmar nova senha'),
            TextFormField(
              controller: _confirm,
              obscureText: _obscure,
              validator: (v) => v == _new.text ? null : 'As senhas não conferem',
            ),
            const SizedBox(height: 18),
            BusyButton(label: 'ALTERAR SENHA', busy: _savingPass, onPressed: _changePassword),
          ]),
        ),
        const SizedBox(height: 24),
      ]),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
      );
}
