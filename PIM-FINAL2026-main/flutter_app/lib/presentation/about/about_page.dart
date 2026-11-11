import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../common/widgets.dart';

/// "Quem somos": mesma página institucional do web.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  static const _teams = ['Palmeiras', 'Corinthians', 'Flamengo', 'São Paulo', 'Santos'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QUEM SOMOS')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const _Section(
              label: 'SOBRE A CHAMPIONS CARD',
              title: 'QUEM SOMOS',
              paragraphs: [
                'A Champions Card é uma plataforma de venda de ingressos de futebol. Ela reúne as partidas disponíveis em um só lugar, para o torcedor consultar e comprar com facilidade.',
                'Nossa proposta é simplificar o caminho do torcedor até o estádio: encontrar o jogo, escolher onde sentar e pagar com segurança.',
              ],
            ),
            const _Section(
              label: 'NOSSA PLATAFORMA',
              title: 'O QUE FAZEMOS',
              items: [
                'Mostramos as partidas com data, horário e preço.',
                'Você escolhe o setor no mapa do estádio e a cadeira que prefere.',
                'Sócios recebem desconto nos ingressos, de 5% a 20%.',
                'Você compra até 5 ingressos de uma vez, pelo carrinho.',
                'O chat responde dúvidas frequentes sobre ingressos, assentos e pagamento.',
              ],
            ),
            const _Section(
              label: 'O QUE NOS DIFERENCIA',
              title: 'NOSSOS DIFERENCIAIS',
              items: [
                'Mapa do estádio com setores e cadeiras livres e ocupadas.',
                'Escolha da cadeira exata, com fileira e número.',
                'Código de sócio conferido a cada compra.',
                'Compra confirmada com o código do aplicativo autenticador (MFA).',
                'O número do cartão não é enviado ao servidor: só um código gerado a partir dele.',
                'Carrinho com até 5 ingressos por compra.',
              ],
            ),
            const SectionLabel('COMO FUNCIONA'),
            const _Step('1', 'Escolha a partida', 'Veja data, horário e preço de cada jogo.'),
            const _Step('2', 'Escolha o setor', 'Use o mapa do estádio. O Leste é da torcida visitante.'),
            const _Step('3', 'Escolha a cadeira', 'Veja as cadeiras livres e ocupadas e toque na sua.'),
            const _Step('4', 'Confirme o pagamento', 'Pague com crédito, débito ou Pix e confirme com o código de 6 dígitos do seu autenticador.'),
            const SizedBox(height: 12),
            const SectionLabel('PLANOS DE SÓCIO'),
            const Text('Informe o código de sócio na hora da compra para ganhar desconto.', style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 10),
            const Row(children: [
              Expanded(child: _Plan('Bronze', '5%')),
              SizedBox(width: 8),
              Expanded(child: _Plan('Prata', '10%')),
              SizedBox(width: 8),
              Expanded(child: _Plan('Ouro', '20%')),
            ]),
            const SizedBox(height: 20),
            const SectionLabel('TIMES'),
            const Text('Escolha seu time ao se cadastrar. A lista de partidas mostra os jogos dele.', style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [for (final t in _teams) Chip(label: Text(t.toUpperCase()))]),
            const SizedBox(height: 24),
            FilledButton(onPressed: () => context.go('/matches'), child: const Text('VER PARTIDAS DISPONÍVEIS')),
            const SizedBox(height: 10),
            const Text('Versão de demonstração: o pagamento é simulado.',
                textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.title, this.paragraphs = const [], this.items = const []});
  final String label;
  final String title;
  final List<String> paragraphs;
  final List<String> items;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: AppColors.brand, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            for (final p in paragraphs) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(p, style: const TextStyle(height: 1.4))),
            for (final i in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Padding(padding: EdgeInsets.only(top: 2, right: 8), child: Icon(Icons.check_circle, size: 16, color: AppColors.brand)),
                  Expanded(child: Text(i, style: const TextStyle(height: 1.35))),
                ]),
              ),
          ]),
        ),
      );
}

class _Step extends StatelessWidget {
  const _Step(this.n, this.title, this.text);
  final String n;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(radius: 14, backgroundColor: AppColors.navy, child: Text(n, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(text, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
            ]),
          ),
        ]),
      );
}

class _Plan extends StatelessWidget {
  const _Plan(this.name, this.percent);
  final String name;
  final String percent;

  @override
  Widget build(BuildContext context) => AppCard(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
          Text(percent, style: const TextStyle(color: AppColors.brand, fontSize: 22, fontWeight: FontWeight.w900)),
          const Text('de desconto', style: TextStyle(color: AppColors.muted, fontSize: 11)),
        ]),
      );
}
