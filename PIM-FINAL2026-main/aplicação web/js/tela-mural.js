// ===========================
// MURAL DO TIME
// [PIM-WEB Mural] Carrossel de avisos ao lado das partidas. Cards reais vêm do sistema (próximo jogo e plano).
// Avisos reais do clube entram em MURAL_AVISOS. Os cards de exemplo são só modelo e aparecem marcados.
// ===========================

// [PIM-WEB Mural] EDITE AQUI: avisos reais de cada time. Formato: { tag: 'Clube', titulo: 'Título', texto: 'Texto' }.
const MURAL_AVISOS = {
  'palmeiras': [],
  'corinthians': [],
  'flamengo': [],
  'sao paulo': [],
  'santos': [],
  'default': [],
};

const MU_NOME = { 'palmeiras': 'Palmeiras', 'corinthians': 'Corinthians', 'flamengo': 'Flamengo', 'sao paulo': 'São Paulo', 'santos': 'Santos' };
const MU_COR  = { 'palmeiras': '#16803f', 'corinthians': '#111111', 'flamengo': '#c62828', 'sao paulo': '#d32f2f', 'santos': '#333333', 'default': '#16803f' };

let muItens = [];
let muIdx = 0;
let muTimer = null;
let muPausado = false;

// [PIM-WEB Mural] Estádio do time em casa, se ele joga em casa numa das partidas futuras.
function muEstadioDoTime(time) {
  const jogo = (typeof ctJogos !== 'undefined' ? ctJogos : []).find(j => j.times[0] === time && j.estadio);
  return jogo ? jogo.estadio.nome : '';
}

// [PIM-WEB Mural] Junta os cards: reais primeiro, depois os avisos do time, depois os exemplos.
function muMontarItens() {
  const time = estado.timeDoUsuario;
  const nome = MU_NOME[time] || 'seu time';
  const itens = [];
  const p = (typeof ctJogos !== 'undefined' ? ctJogos : [])[0];

  if (p) {
    const onde = p.estadio ? ` · ${p.estadio.nome}, ${p.estadio.cidade}` : '';
    itens.push({ tag: 'Próximo jogo', titulo: p.nome, texto: `${p.data} às ${p.hora}${onde}.` });
  }
  const plano = estado.usuarioLogado?.plano || 0;
  if (plano > 0) {
    itens.push({ tag: 'Seu plano', titulo: `Desconto de ${plano}%`, texto: 'Informe o seu código de sócio na hora de pagar para aplicar o desconto.' });
  } else {
    itens.push({ tag: 'Sócio', titulo: 'Desconto de 5% a 20%', texto: 'Assine em QUERO SER SÓCIO, na tela de login, e pague menos nos ingressos.' });
  }

  (MURAL_AVISOS[time] || MURAL_AVISOS['default'] || []).forEach(a => itens.push(a));

  const est = muEstadioDoTime(time);
  itens.push({ tag: 'Dia de jogo', titulo: `Vá de camisa do ${nome}`, texto: `Chegue com antecedência${est ? ' ao ' + est : ' ao estádio'} e confira o setor do seu ingresso.`, exemplo: true });
  itens.push({ tag: 'Torcida', titulo: 'Vá com a turma', texto: 'O carrinho aceita até 5 ingressos por compra. Escolha cadeiras próximas.', exemplo: true });
  itens.push({ tag: 'Mural', titulo: `Espaço para avisos do ${nome}`, texto: 'Troque este texto por avisos reais do clube, editando MURAL_AVISOS em js/tela-mural.js.', exemplo: true });
  return itens;
}

function pararMural() {
  if (muTimer) { clearInterval(muTimer); muTimer = null; }
}

function limparMural() {
  pararMural();
  muItens = [];
  const raiz = document.getElementById('mural-time');
  if (raiz) raiz.textContent = '';
}
function desenharMural() {
  const raiz = document.getElementById('mural-time');
  if (!raiz) return;
  pararMural();
  raiz.textContent = '';
  muItens = muMontarItens();
  muIdx = 0;

  raiz.appendChild(ctEl('h3', 'mu-titulo', 'Mural do time'));

  const card = ctEl('article', 'mu-card');
  const tag = ctEl('span', 'mu-tag');
  const tit = ctEl('h4', 'mu-card-titulo');
  const txt = ctEl('p', 'mu-texto');
  const ex = ctEl('small', 'mu-exemplo', 'Texto de exemplo');
  card.append(tag, tit, txt, ex);
  raiz.appendChild(card);

  const nav = ctEl('div', 'mu-nav');
  const ant = ctEl('button', 'mu-seta', '‹');
  ant.type = 'button'; ant.setAttribute('aria-label', 'Aviso anterior');
  const prox = ctEl('button', 'mu-seta', '›');
  prox.type = 'button'; prox.setAttribute('aria-label', 'Próximo aviso');
  const pontos = ctEl('div', 'mu-pontos');
  muItens.forEach((_, i) => {
    const b = ctEl('button', 'mu-ponto');
    b.type = 'button'; b.setAttribute('aria-label', `Aviso ${i + 1}`);
    b.addEventListener('click', () => mostrar(i));
    pontos.appendChild(b);
  });
  nav.append(ant, pontos, prox);
  raiz.appendChild(nav);

  const cor = MU_COR[estado.timeDoUsuario] || MU_COR['default'];
  card.style.setProperty('--mu-cor', cor);

  function mostrar(i) {
    muIdx = (i + muItens.length) % muItens.length;
    const it = muItens[muIdx];
    tag.textContent = it.tag;
    tit.textContent = it.titulo;
    txt.textContent = it.texto;
    ex.style.display = it.exemplo ? 'block' : 'none';
    pontos.querySelectorAll('.mu-ponto').forEach((b, k) => b.classList.toggle('mu-ponto-ativo', k === muIdx));
    card.classList.remove('mu-troca'); void card.offsetWidth; card.classList.add('mu-troca');
  }
  ant.addEventListener('click', () => mostrar(muIdx - 1));
  prox.addEventListener('click', () => mostrar(muIdx + 1));
  raiz.addEventListener('mouseenter', () => { muPausado = true; });
  raiz.addEventListener('mouseleave', () => { muPausado = false; });
  raiz.addEventListener('focusin', () => { muPausado = true; });
  raiz.addEventListener('focusout', () => { muPausado = false; });

  mostrar(0);
  // Troca automática a cada 7 s. Não roda se o usuário pediu menos movimento.
  if (!window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
    muTimer = setInterval(() => {
      if (!document.getElementById('mural-time')?.isConnected) { pararMural(); return; }
      if (!muPausado) mostrar(muIdx + 1);
    }, 7000);
  }
}
// [PIM-WEB Mural] Liga o mural à Central sem editar outros arquivos: roda junto com ela.
(function ligarMural() {
  const atualizarOrig = atualizarCentralTorcedor;
  const limparOrig = limparCentralTorcedor;
  atualizarCentralTorcedor = function (partidas) { atualizarOrig(partidas); desenharMural(); };
  limparCentralTorcedor = function () { limparOrig(); limparMural(); };
})();