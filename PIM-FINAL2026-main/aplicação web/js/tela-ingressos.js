// ===========================
// MEUS INGRESSOS
// [PIM-WEB Meus Ingressos] Lista os ingressos do usuário logado (GET /api/tickets).
// Motivo: sem esta tela, depois da compra o torcedor não via o código nem o assento.
// Todo texto vai por textContent (sem innerHTML), por causa de XSS.
// ===========================

function miEl(tag, classe, texto) {
  const el = document.createElement(tag);
  if (classe) el.className = classe;
  if (texto !== undefined) el.textContent = texto;
  return el;
}

function miDinheiro(v) {
  return 'R$ ' + Number(v).toFixed(2).replace('.', ',');
}

function miData(iso) {
  const d = new Date(iso);
  return isNaN(d) ? '-' : d.toLocaleString('pt-BR', { dateStyle: 'short', timeStyle: 'short' });
}

// [PIM-WEB Meus Ingressos] Monta o cartão de um ingresso.
function miCartao(t) {
  const card = miEl('article', 'mi-card');
  card.appendChild(miEl('h3', 'mi-partida', t.matchName));

  const linhas = [
    ['Jogo', miData(t.kickoffAt)],
    ['Setor', t.sector],
    ['Assento', t.seatRow != null ? `Fileira ${t.seatRow} · Cadeira ${t.seatNumber}` : 'Sem assento marcado'],
    ['Valor pago', miDinheiro(t.amount)],
    ['Emitido em', miData(t.issuedAt)],
  ];
  const dl = miEl('dl', 'mi-dados');
  linhas.forEach(([rotulo, valor]) => {
    const linha = miEl('div', 'mi-linha');
    linha.appendChild(miEl('dt', '', rotulo));
    linha.appendChild(miEl('dd', '', valor));
    dl.appendChild(linha);
  });
  card.appendChild(dl);

  const cod = miEl('div', 'mi-codigo-box');
  cod.appendChild(miEl('span', 'mi-codigo-rotulo', 'CÓDIGO DO INGRESSO'));
  cod.appendChild(miEl('strong', 'mi-codigo', t.code));
  card.appendChild(cod);
  return card;
}

// [PIM-WEB Meus Ingressos] Abre a tela e busca os ingressos na API.
async function abrirMeusIngressos() {
  if (!temToken()) {
    mostrarToast('Sua sessão expirou. Entre de novo.', 'warning');
    irPara('screen-login', false);
    return;
  }
  const lista = document.getElementById('mi-lista');
  const vazio = document.getElementById('mi-vazio');
  const resumo = document.getElementById('mi-resumo');
  lista.textContent = '';
  vazio.style.display = 'none';
  resumo.textContent = 'Carregando...';
  irPara('screen-ingressos');
  try {
    const dados = await Api.meusIngressos();
    // mais recentes primeiro
    dados.sort((a, b) => new Date(b.issuedAt) - new Date(a.issuedAt));
    dados.forEach(t => lista.appendChild(miCartao(t)));
    if (dados.length === 0) {
      resumo.textContent = '';
      vazio.style.display = 'block';
    } else {
      const total = dados.reduce((soma, t) => soma + Number(t.amount), 0);
      resumo.textContent = `${dados.length} ingresso(s) · Total: ${miDinheiro(total)}`;
    }
  } catch (e) {
    resumo.textContent = '';
    if (e instanceof ApiErro && e.status === 401) {
      mostrarToast('Sua sessão expirou. Entre de novo.', 'warning');
      irPara('screen-login', false);
      return;
    }
    mostrarToast(e instanceof ApiErro ? e.message : 'Erro inesperado.', 'error');
  }
}
