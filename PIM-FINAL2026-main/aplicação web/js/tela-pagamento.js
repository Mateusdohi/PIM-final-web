// ===========================
// TELA 5: PAGAMENTO
// [PIM-WEB Cartão 8] Compra pela API: intent (servidor calcula o preço) e confirm-web (senha + token do cartão).
// Número e CVV do cartão nunca saem do navegador.
// ===========================

// [PIM-WEB Cartão 8] Guarda a intent em memória. Motivo: o nonce só vale para esta compra e não vai para localStorage.
let intentAtual = null;

function selecionarMetodoCompra(metodo, btn) {
  estado.metodoPagamentoCompra = metodo;
  atualizarBotoesMetodo('metodos-compra', btn);
  alternarCamposPagamento('campos-cartao-compra', 'pix-compra', metodo);
  // [PIM-WEB Cartão 8] Removido preencherCartaoSalvo. Motivo: o site não guarda mais cartão do usuário.
  garantirCampoSenha();
}

// [PIM-WEB Cartão 8] Cria o campo de senha por JS (o confirm-web exige reautenticação).
// Motivo: evita mexer no index.html e mantém a senha fora de qualquer armazenamento.
function garantirCampoSenha() {
  if (document.getElementById('pag-senha')) return;
  const botao = document.querySelector('#screen-pagamento .btn-primary');
  const input = document.createElement('input');
  input.type = 'password';
  input.id = 'pag-senha';
  input.className = 'input-field';
  input.placeholder = 'SUA SENHA (CONFIRMAÇÃO)';
  input.autocomplete = 'current-password';
  botao.parentNode.insertBefore(input, botao);
}

async function confirmarCompra() {
  // [PIM-WEB Cartão 8] Sem token, volta ao login. Motivo: a API exige autenticação.
  if (!temToken()) {
    mostrarToast('Sua sessão expirou. Entre de novo.', 'warning');
    irPara('screen-login', false);
    return;
  }

  const metodoUi = estado.metodoPagamentoCompra;
  const metodo = { credito: 'Credit', debito: 'Debit', pix: 'Pix' }[metodoUi];
  const partida = estado.partidaSelecionada;
  const setor = estado.setorSelecionado;
  const senha = document.getElementById('pag-senha')?.value || '';

  // [PIM-WEB Cartão 8] Código de sócio vai ao servidor, que valida. Motivo: validar só no navegador não protege o desconto.
  let memberCode = null;
  if (estado.usuarioLogado?.plano > 0) {
    memberCode = document.getElementById('input-codigo-socio')?.value.trim().toUpperCase();
    if (!memberCode) { mostrarToast('Informe seu código de sócio para aplicar o desconto.', 'warning'); return; }
  }

  if (!senha) { mostrarToast('Digite sua senha para confirmar a compra.', 'warning'); return; }

  // [PIM-WEB Cartão 8] Token do cartão (gateway simulado). Pix não usa token.
  let cardToken = null;
  if (metodo !== 'Pix') {
    const numero = document.querySelector('#campos-cartao-compra .input-field')?.value;
    try { cardToken = gerarTokenCartao(numero || ''); }
    catch (e) { mostrarToast(e.message, 'warning'); return; }
  }

  try {
    // 1) Cria a intent. O servidor calcula o preço e reserva por 10 minutos.
    const intent = await apiFetch('/api/payments/intents', {
      metodo: 'POST',
           // [PIM-WEB Cartão 9] Envia o assento escolhido. Motivo: o servidor trava o assento contra venda dupla.
      corpo: { matchId: partida.id, sector: setor, method: metodo, memberCode,
               seatRow: estado.assentoSelecionado?.row ?? null,
               seatNumber: estado.assentoSelecionado?.number ?? null },
    });
    intentAtual = intent;

    // 2) Confirma com senha, nonce e token. O servidor cobra e emite o ingresso.
    const resp = await apiFetch(`/api/payments/intents/${intent.intentId}/confirm-web`, {
      metodo: 'POST',
      corpo: { nonce: intent.nonce, password: senha, cardToken },
    });

    // [PIM-WEB Cartão 8] Limpa dados sensíveis dos campos e da memória.
    document.getElementById('pag-senha').value = '';
    document.querySelectorAll('#campos-cartao-compra input').forEach(i => i.value = '');
    const inputCodigo = document.getElementById('input-codigo-socio');
    if (inputCodigo) inputCodigo.value = '';
    intentAtual = null;

    mostrarTelaConfirmacao();
  } catch (e) {
    // [PIM-WEB Cartão 8] Erros da API (seat_taken, queue_required, payment_declined, 401) aparecem como toast.
       // [PIM-WEB Cartão 9] Assento tomado por outra pessoa: avisa e volta à grade já atualizada.
    // Motivo: o mapa que o usuário viu pode estar desatualizado.
    if (e instanceof ApiErro && e.code === 'seat_taken') {
      mostrarToast('Esse assento acabou de ser reservado. Escolha outro.', 'warning');
      abrirAssentos(estado.setorSelecionado);
      return;
    }
    mostrarToast(e instanceof ApiErro ? e.message : 'Erro inesperado.', 'error');
  }
}