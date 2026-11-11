// ===========================
// TELA 5: PAGAMENTO
// [PIM-WEB Cartão 8] Compra pela API: intent (servidor calcula o preço) e confirm (código MFA + token do cartão).
// Número e CVV do cartão nunca saem do navegador.
// ===========================

// [PIM-WEB Cartão 8] Guarda a intent em memória. Motivo: o nonce só vale para esta compra e não vai para localStorage.
let intentAtual = null;

function selecionarMetodoCompra(metodo, btn) {
  estado.metodoPagamentoCompra = metodo;
  atualizarBotoesMetodo('metodos-compra', btn);
  alternarCamposPagamento('campos-cartao-compra', 'pix-compra', metodo);
  // [PIM-WEB Cartão 8] Removido preencherCartaoSalvo. Motivo: o site não guarda mais cartão do usuário.
  garantirCampoCodigo();
}

// Cria o campo do código MFA por JS (a compra é confirmada com o código de 6 dígitos do autenticador).
// Motivo: evita mexer no index.html e mantém o código fora de qualquer armazenamento.
function garantirCampoCodigo() {
  if (document.getElementById('pag-codigo')) return;
  const botao = document.querySelector('#screen-pagamento .btn-primary');
  const input = document.createElement('input');
  input.type = 'text';
  input.id = 'pag-codigo';
  input.className = 'input-field';
  input.placeholder = 'CÓDIGO DE 6 DÍGITOS DO AUTENTICADOR';
  input.setAttribute('inputmode', 'numeric');
  input.autocomplete = 'one-time-code';
  input.maxLength = 14;
  botao.parentNode.insertBefore(input, botao);
}

// Sem autenticador ativado não há compra: leva a pessoa ao perfil para ativar.
function exigirMfaAtivo() {
  if (estado.usuarioLogado?.mfaAtivo) return true;
  mostrarToast('Para comprar, ative o autenticador (MFA) no seu perfil.', 'warning');
  abrirPerfil();
  return false;
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
  const codigo = document.getElementById('pag-codigo')?.value || '';

  // [PIM-WEB Cartão 8] Código de sócio vai ao servidor, que valida. Motivo: validar só no navegador não protege o desconto.
  let memberCode = null;
  if (estado.usuarioLogado?.plano > 0) {
    memberCode = document.getElementById('input-codigo-socio')?.value.trim().toUpperCase();
    if (!memberCode) { mostrarToast('Informe seu código de sócio para aplicar o desconto.', 'warning'); return; }
  }

  if (!exigirMfaAtivo()) return;
  if (!codigo.trim()) { mostrarToast('Digite o código de 6 dígitos do seu autenticador para confirmar a compra.', 'warning'); return; }

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

    // 2) Confirma com o código do autenticador, o nonce e o token. O servidor confere o código, cobra e emite o ingresso.
    const resp = await apiFetch(`/api/payments/intents/${intent.intentId}/confirm`, {
      metodo: 'POST',
      corpo: { nonce: intent.nonce, code: codigo, cardToken },
    });

    // [PIM-WEB Cartão 8] Limpa dados sensíveis dos campos e da memória.
    document.getElementById('pag-codigo').value = '';
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
    if (e instanceof ApiErro && e.code === 'mfa_required') { exigirMfaAtivo(); return; }
    mostrarToast(e instanceof ApiErro ? e.message : 'Erro inesperado.', 'error');
  }
}