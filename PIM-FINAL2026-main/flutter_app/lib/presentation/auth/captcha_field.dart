import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/di/injection.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/mfa.dart';
import '../../domain/repositories/repositories.dart';

/// Guarda o captcha atual (imagem + id) e o que a pessoa digitou. Cada captcha vale uma única tentativa:
/// depois de qualquer tentativa de login chame [load] para trocar a imagem.
class CaptchaController extends ChangeNotifier {
  final answer = TextEditingController();
  Captcha? captcha;
  bool loading = false;
  String? error;

  Future<void> load() async {
    loading = true;
    error = null;
    answer.clear();
    notifyListeners();
    final r = await sl<AuthRepository>().captcha();
    r.fold(
      (f) {
        captcha = null;
        error = f.message;
      },
      (c) => captcha = c,
    );
    loading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    answer.dispose();
    super.dispose();
  }
}

/// Campo "Verificação de segurança": imagem do captcha, botão para trocar a imagem e campo de texto.
class CaptchaField extends StatelessWidget {
  const CaptchaField({super.key, required this.controller, this.enabled = true});
  final CaptchaController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final c = controller.captcha;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text('Verificação de segurança',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
          ),
          Row(children: [
            Semantics(
              label: 'Imagem do captcha. Digite os caracteres que aparecem nela.',
              image: true,
              child: Container(
                width: 190,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.borderSoft),
                ),
                child: controller.loading
                    ? const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)))
                    : c == null
                        ? Center(child: Text(controller.error ?? 'Sem imagem', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: AppColors.muted)))
                        : ClipRRect(borderRadius: BorderRadius.circular(8), child: SvgPicture.memory(c.svg, width: 190, height: 64, fit: BoxFit.fill)),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Trocar imagem do captcha',
              onPressed: enabled && !controller.loading ? controller.load : null,
              icon: const Icon(Icons.refresh),
            ),
          ]),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller.answer,
            enabled: enabled,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            enableSuggestions: false,
            maxLength: 8,
            decoration: const InputDecoration(hintText: 'Digite os caracteres da imagem', counterText: ''),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Digite os caracteres da imagem'
                : (controller.captcha == null ? 'Toque em atualizar para carregar a imagem' : null),
          ),
        ]);
      },
    );
  }
}
