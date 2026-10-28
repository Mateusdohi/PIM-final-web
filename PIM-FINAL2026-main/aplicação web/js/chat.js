// ===========================
// CHAT DE DÚVIDAS
// [PIM-WEB Cartão 10] Conversa com POST /api/chat. A resposta vem do servidor; nenhuma chave existe no navegador.
// [PIM-WEB Chat] A resposta pode trazer botões de dúvidas (suggestions). Clicar manda a pergunta.
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
    adicionarMensagemChat('Olá! Posso ajudar com ingressos, assentos, planos de sócio, pagamento, carrinho e fila. Digite uma palavra ou escolha um assunto.', 'bot');
    mostrarSugestoesChat(['Ingressos', 'Assentos', 'Planos de sócio', 'Pagamento', 'Carrinho', 'Fila virtual', 'Conta e senha']);
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

// [PIM-WEB Chat] Mostra botões de dúvidas. Cada botão envia o próprio texto como pergunta. Só existe um grupo por vez.
function mostrarSugestoesChat(lista) {
  const caixa = document.getElementById('chat-msgs');
  removerSugestoesChat();
  if (!Array.isArray(lista) || lista.length === 0) return;
  const grupo = document.createElement('div');
  grupo.className = 'chat-sugestoes';
  lista.forEach(texto => {
    const b = document.createElement('button');
    b.type = 'button';
    b.className = 'chat-sugestao';
    b.textContent = texto;
    b.addEventListener('click', () => enviarChat(texto));
    grupo.appendChild(b);
  });
  caixa.appendChild(grupo);
  caixa.scrollTop = caixa.scrollHeight;
}

function removerSugestoesChat() {
  document.querySelectorAll('#chat-msgs .chat-sugestoes').forEach(g => g.remove());
}

// [PIM-WEB Chat] Aceita um texto vindo de um botão. Sem argumento, lê o campo de digitação.
async function enviarChat(textoBotao) {
  const input = document.getElementById('chat-input');
  const texto = (typeof textoBotao === 'string' ? textoBotao : input.value).trim();
  if (!texto) return;
  if (!temToken()) { mostrarToast('Sua sessão expirou. Entre de novo.', 'warning'); return; }

  removerSugestoesChat();
  adicionarMensagemChat(texto, 'eu');
  if (typeof textoBotao !== 'string') input.value = '';
  try {
    const r = await apiFetch('/api/chat', { metodo: 'POST', corpo: { message: texto } });
    adicionarMensagemChat(r.reply, 'bot');
    mostrarSugestoesChat(r.suggestions);
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