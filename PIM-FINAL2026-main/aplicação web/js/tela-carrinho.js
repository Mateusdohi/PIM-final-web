// ===========================
// CARRINHO DE COMPRAS
// [PIM-WEB Carrinho] Só em memória (sem localStorage). Cada item é um assento; cada item vira uma compra na API.
// ===========================

// [PIM-WEB Carrinho] Limite de 5 itens. Motivo: a confirmação pela web aceita 10 por minuto por usuário.
const CARRINHO_MAX = 5;
let carrinho = [];
let metodoCarrinho = 'credito';
let finalizandoCarrinho = false;

// [PIM-WEB Carrinho] Confere se o assento já está no carrinho. Motivo: impede item duplicado.
function itemNoCarrinho(matchId, setor, row, number) {
  return carrinho.some(i => i.matchId === matchId && i.setor === setor && i.row === row && i.number === number);
}

// [PIM-WEB Carrinho] Atualiza o número mostrado no menu e na tela de assentos.
function atualizarContadorCarrinho() {
  document.querySelectorAll('.car-contador').forEach(el => { el.textContent = String(carrinho.length); });
}

// [PIM-WEB Carrinho] Botão da tela de assentos: guarda o assento escolhido.
function adicionarAoCarrinhoAtual() {
  const partida = estado.partidaSelecionada;
  const setor = estado.setorSelecionado;
  const a = estado.assentoSelecionado;
  if (!a) { mostrarToast('Escolha um assento.', 'warning'); return; }
  if (carrinho.length >= CARRINHO_MAX) {
    mostrarToast(`O carrinho aceita até ${CARRINHO_MAX} ingressos.`, 'warning');
    return;
  }
  if (itemNoCarrinho(partida.id, setor, a.row, a.number)) {
    mostrarToast('Esse assento já está no carrinho.', 'warning');
    return;
  }
  carrinho.push({
    matchId: partida.id, nome: partida.nome, data: partida.data, hora: partida.hora,
    preco: partida.preco, setor, row: a.row, number: a.number, erro: null,
  });
  estado.assentoSelecionado = null;
  atualizarContadorCarrinho();
  mostrarToast('Adicionado ao carrinho.', 'success');
  carregarAssentos(); // redesenha a grade: o assento do carrinho fica marcado
}

function removerDoCarrinho(i) {
  if (finalizandoCarrinho) return;
  carrinho.splice(i, 1);
  atualizarContadorCarrinho();
  renderizarCarrinho();
}

// [PIM-WEB Carrinho] Esvazia tudo. Chamado no "sair" para a lista não passar ao próximo usuário.
function limparCarrinho() {
  carrinho = [];
  metodoCarrinho = 'credito';
  ['car-senha', 'car-codigo-socio', 'car-cartao-numero', 'car-validade', 'car-cvv'].forEach(id => {
    const el = document.getElementById(id);
    if (el) el.value = '';
  });
  atualizarContadorCarrinho();
}

function abrirCarrinho() {
  if (!temToken()) {
    mostrarToast('Sua sessão expirou. Entre de novo.', 'warning');
    irPara('screen-login', false);
    return;
  }
  renderizarCarrinho();
  irPara('screen-carrinho');
}

// [PIM-WEB Carrinho] Desenha a lista. Usa textContent (sem innerHTML) porque os nomes vêm da API.
function renderizarCarrinho() {
  const lista = document.getElementById('car-lista');
  lista.textContent = '';
  let total = 0;

  carrinho.forEach((item, i) => {
    const preco = calcularPreco(item.preco); // só exibição: o servidor recalcula
    total += preco;

    const linha = document.createElement('div');
    linha.className = 'car-item';

    const info = document.createElement('div');
    const nome = document.createElement('div');
    nome.className = 'car-item-nome';
    nome.textContent = item.nome;
    const det = document.createElement('div');
    det.className = 'car-item-det';
    det.textContent = `${item.setor.toUpperCase()} · Fileira ${item.row}, cadeira ${item.number} · ${item.data} ${item.hora}`;
    info.append(nome, det);

    const valor = document.createElement('div');
    valor.className = 'car-item-preco';
    valor.textContent = 'R$ ' + preco.toFixed(2).replace('.', ',');

    const rem = document.createElement('button');
    rem.type = 'button';
    rem.className = 'car-remover';
    rem.textContent = 'Remover';
    rem.addEventListener('click', () => removerDoCarrinho(i));

    linha.append(info, valor, rem);
    if (item.erro) {
      const er = document.createElement('div');
      er.className = 'car-item-erro';
      er.textContent = item.erro;
      linha.appendChild(er);
    }
    lista.appendChild(linha);
  });

  const vazio = carrinho.length === 0;
  document.getElementById('car-vazio').style.display = vazio ? 'block' : 'none';
  document.getElementById('car-pagamento').style.display = vazio ? 'none' : 'flex';
  document.getElementById('car-total').textContent = vazio
    ? '' : `TOTAL: R$ ${total.toFixed(2).replace('.', ',')}`;

  const blocoSocio = document.getElementById('car-bloco-socio');
  if (blocoSocio) blocoSocio.style.display = (estado.usuarioLogado?.plano > 0) ? 'block' : 'none';
  alternarCamposPagamento('car-campos-cartao', 'car-pix', metodoCarrinho);
}

function selecionarMetodoCarrinho(metodo, btn) {
  metodoCarrinho = metodo;
  atualizarBotoesMetodo('car-metodos', btn);
  alternarCamposPagamento('car-campos-cartao', 'car-pix', metodo);
}

// [PIM-WEB Carrinho] Finaliza item por item. Para tudo se a sessão expirou, o cartão foi recusado ou houve erro geral.
// Continua se um assento foi tomado (seat_taken) ou a fila exige outra partida (queue_required).
async function finalizarCarrinho() {
  if (finalizandoCarrinho) return;
  if (!temToken()) {
    mostrarToast('Sua sessão expirou. Entre de novo.', 'warning');
    irPara('screen-login', false);
    return;
  }
  if (carrinho.length === 0) { mostrarToast('O carrinho está vazio.', 'warning'); return; }

  const metodo = { credito: 'Credit', debito: 'Debit', pix: 'Pix' }[metodoCarrinho];
  const senha = document.getElementById('car-senha').value;

  let memberCode = null;
  if (estado.usuarioLogado?.plano > 0) {
    memberCode = (document.getElementById('car-codigo-socio').value || '').trim().toUpperCase();
    if (!memberCode) { mostrarToast('Informe seu código de sócio para aplicar o desconto.', 'warning'); return; }
  }
  if (!senha) { mostrarToast('Digite sua senha para confirmar a compra.', 'warning'); return; }

  // Número do cartão só é lido aqui, no navegador. Só o token vai à API.
  const numero = document.getElementById('car-cartao-numero').value;
  if (metodo !== 'Pix') {
    try { gerarTokenCartao(numero); }
    catch (e) { mostrarToast(e.message, 'warning'); return; }
  }

  finalizandoCarrinho = true;
  const botao = document.getElementById('car-finalizar');
  botao.disabled = true;
  botao.textContent = 'PROCESSANDO...';

  const restantes = [];
  let comprados = 0;
  let totalCobrado = 0;
  let parar = false;
  let sessaoExpirou = false;

  for (const item of carrinho) {
    if (parar) { restantes.push(item); continue; }
    item.erro = null;
    try {
      const cardToken = metodo === 'Pix' ? null : gerarTokenCartao(numero); // um token por compra
      const intent = await apiFetch('/api/payments/intents', {
        metodo: 'POST',
        corpo: { matchId: item.matchId, sector: item.setor, method: metodo, memberCode,
                 seatRow: item.row, seatNumber: item.number },
      });
      await apiFetch(`/api/payments/intents/${intent.intentId}/confirm-web`, {
        metodo: 'POST',
        corpo: { nonce: intent.nonce, password: senha, cardToken },
      });
      comprados++;
      totalCobrado += intent.amount;
    } catch (e) {
      item.erro = e instanceof ApiErro ? e.message : 'Erro inesperado.';
      restantes.push(item);
      if (e instanceof ApiErro && e.status === 401) sessaoExpirou = true;
      const segue = e instanceof ApiErro && (e.code === 'seat_taken' || e.code === 'queue_required');
      if (!segue) parar = true;
    }
  }

  carrinho = restantes;
  finalizandoCarrinho = false;
  botao.disabled = false;
  botao.textContent = 'FINALIZAR COMPRA';
  document.getElementById('car-senha').value = '';
  atualizarContadorCarrinho();

  if (sessaoExpirou) {
    mostrarToast('Sua sessão expirou. Entre de novo.', 'warning');
    irPara('screen-login', false);
    return;
  }

  if (carrinho.length === 0) {
    // Tudo comprado: limpa os dados sensíveis e mostra a confirmação.
    ['car-codigo-socio', 'car-cartao-numero', 'car-validade', 'car-cvv'].forEach(id => {
      const el = document.getElementById(id);
      if (el) el.value = '';
    });
    mostrarToast(`${comprados} ingresso(s) comprado(s).\nTotal cobrado: R$ ${totalCobrado.toFixed(2).replace('.', ',')}`, 'success');
    mostrarTelaConfirmacao();
    return;
  }

  renderizarCarrinho();
  if (comprados === 0) {
    mostrarToast(restantes.find(i => i.erro)?.erro || 'Não foi possível finalizar.', 'error');
  } else {
    mostrarToast(`${comprados} ingresso(s) comprado(s).\n${carrinho.length} ficou no carrinho. Veja o motivo em cada item.`, 'warning');
  }
}

// [PIM-WEB Carrinho] Máscaras do cartão no carrinho (mesmo formato do cadastro).
(function mascarasCarrinho() {
  const num = document.getElementById('car-cartao-numero');
  const val = document.getElementById('car-validade');
  const cvv = document.getElementById('car-cvv');
  if (num) num.addEventListener('input', function () {
    this.value = this.value.replace(/\D/g, '').slice(0, 16).replace(/(.{4})/g, '$1 ').trim();
  });
  if (val) val.addEventListener('input', function () {
    let v = this.value.replace(/\D/g, '').slice(0, 4);
    if (v.length > 2) v = v.slice(0, 2) + '/' + v.slice(2);
    this.value = v;
  });
  if (cvv) cvv.addEventListener('input', function () {
    this.value = this.value.replace(/\D/g, '').slice(0, 4);
  });
})();