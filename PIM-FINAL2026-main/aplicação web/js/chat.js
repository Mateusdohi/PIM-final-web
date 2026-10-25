// ===========================
// CHAT DE DÚVIDAS
// [PIM-WEB Cartão 10] Conversa com POST /api/chat. A resposta vem do servidor; nenhuma chave existe no navegador.
// ===========================

// [PIM-WEB Cartão 10] Abre/fecha o painel. Motivo: sem login a API recusa, então avisa antes.
function alternarChat() {
  const painel = document.getElementById('chat-painel');
  if (!painel.classList.contains('aberto') && !temToken()) {
    mostrarToast('Entre na sua conta para usar o chat.', 'warning');
    return;
  }
  painel.classList.toggle('aberto');
  if (painel.classList.contains('aberto') && !document.getElementById('chat-msgs').children.length) {
    adicionarMensagemChat('Olá! Posso ajudar com ingressos, assentos, planos de sócio, pagamento e fila.', 'bot');
  }
}

// [PIM-WEB Cartão 10] Usa textContent, nunca innerHTML. Motivo: o texto digitado ou recebido não pode virar HTML (XSS).
function adicionarMensagemChat(texto, quem) {
  const caixa = document.getElementById('chat-msgs');
  const div = document.createElement('div');
  div.className = 'chat-msg ' + quem;
  div.textContent = texto;
  caixa.appendChild(div);
  caixa.scrollTop = caixa.scrollHeight;
}

async function enviarChat() {
  const input = document.getElementById('chat-input');
  const texto = input.value.trim();
  if (!texto) return;
  if (!temToken()) { mostrarToast('Sua sessão expirou. Entre de novo.', 'warning'); return; }

  adicionarMensagemChat(texto, 'eu');
  input.value = '';
  try {
    const r = await apiFetch('/api/chat', { metodo: 'POST', corpo: { message: texto } });
    adicionarMensagemChat(r.reply, 'bot');
  } catch (e) {
    adicionarMensagemChat(e instanceof ApiErro ? e.message : 'Erro inesperado.', 'bot');
  }
}

// [PIM-WEB Cartão 10] Ao sair, fecha e limpa o chat. Motivo: a conversa não pode ficar visível para o próximo usuário.
function limparChat() {
  const painel = document.getElementById('chat-painel');
  if (painel) painel.classList.remove('aberto');
  const caixa = document.getElementById('chat-msgs');
  if (caixa) caixa.textContent = '';
}