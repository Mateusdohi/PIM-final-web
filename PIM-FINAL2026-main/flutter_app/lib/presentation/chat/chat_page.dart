import 'package:flutter/material.dart';

import '../../core/di/injection.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/repositories/repositories.dart';

/// Assistente de dúvidas (igual ao chat do web): POST /api/chat, resposta com botões de assuntos.
class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _Msg {
  const _Msg(this.text, {required this.mine});
  final String text;
  final bool mine;
}

class _ChatPageState extends State<ChatPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <_Msg>[
    const _Msg('Olá! Posso ajudar com ingressos, assentos, planos de sócio, pagamento, carrinho e fila. Digite uma palavra ou escolha um assunto.', mine: false),
  ];
  List<String> _suggestions = const ['Ingressos', 'Assentos', 'Planos de sócio', 'Pagamento', 'Carrinho', 'Fila virtual', 'Conta e senha'];
  bool _sending = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _toEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      });

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _messages.add(_Msg(text, mine: true));
      _suggestions = const [];
      _sending = true;
      if (preset == null) _input.clear();
    });
    _toEnd();

    final r = await sl<ChatRepository>().send(text);
    if (!mounted) return;
    setState(() {
      _sending = false;
      r.fold(
        (f) => _messages.add(_Msg(f.message, mine: false)),
        (reply) {
          _messages.add(_Msg(reply.reply, mine: false));
          _suggestions = reply.suggestions;
        },
      );
    });
    _toEnd();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ASSISTENTE TICKETFUT')),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.all(16),
              children: [
                for (final m in _messages) _Bubble(m),
                if (_sending) const _Bubble(_Msg('...', mine: false)),
                if (_suggestions.isNotEmpty)
                  Wrap(spacing: 8, runSpacing: 4, children: [
                    for (final s in _suggestions) ActionChip(label: Text(s), onPressed: () => _send(s)),
                  ]),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppColors.borderSoft))),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  maxLength: 500,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: const InputDecoration(hintText: 'Digite sua dúvida...', counterText: ''),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(tooltip: 'Enviar', onPressed: _sending ? null : _send, icon: const Icon(Icons.send)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble(this.msg);
  final _Msg msg;

  @override
  Widget build(BuildContext context) => Align(
        alignment: msg.mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
          decoration: BoxDecoration(
            color: msg.mine ? AppColors.brand : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: msg.mine ? null : Border.all(color: AppColors.borderSoft),
          ),
          child: Text(msg.text, style: TextStyle(color: msg.mine ? Colors.white : AppColors.text, height: 1.35)),
        ),
      );
}
