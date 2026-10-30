// ===========================
// CENTRAL DO TORCEDOR
// [PIM-WEB Central] Painel interativo ao lado das partidas. Só usa dados reais: partidas da API, plano do usuário e assentos do servidor.
// ===========================

let ctJogos = [];     // partidas futuras do time do usuário, da mais próxima para a mais distante
let ctAba = 'jogo';
let ctTimer = null;
let ctSimulado = 0;   // desconto escolhido no simulador do plano (0 = nenhum)

const CT_SETORES = ['Norte', 'Sul', 'Oeste', 'Leste'];
const CT_ABAS = [['jogo', 'Jogo'], ['plano', 'Plano'], ['lugares', 'Lugares'], ['dicas', 'Dicas']];
// [PIM-WEB Central] Dicas: as mesmas regras que o chat já informa.
const CT_DICAS = [
  ['Quanto tempo o assento fica reservado?', 'A reserva dura 10 minutos, a partir do início do pagamento.'],
  ['Posso comprar mais de um ingresso?', 'Sim. O carrinho aceita até 5 ingressos por compra.'],
  ['Como o desconto de sócio é aplicado?', 'Informe seu código de sócio na hora de pagar. O servidor confere o código antes de aplicar o desconto.'],
  ['O que é o setor Leste?', 'É o setor da torcida visitante. Os outros setores são da torcida mandante.'],
  ['Como é a numeração das fileiras?', 'A fileira 1 é a mais próxima do gramado.'],
];

function ctReais(v) { return 'R$ ' + Number(v).toFixed(2).replace('.', ','); }

// [PIM-WEB Central] Cria um elemento com texto. Usa textContent: nada vindo da API vira HTML.
function ctEl(tag, classe, texto) {
  const e = document.createElement(tag);
  if (classe) e.className = classe;
  if (texto !== undefined) e.textContent = texto;
  return e;
}

function pararContagem() {
  if (ctTimer) { clearInterval(ctTimer); ctTimer = null; }
}

// [PIM-WEB Central] Esvazia o painel. Chamado ao recarregar as partidas, para não mostrar dados de outro usuário.
function limparCentralTorcedor() {
  pararContagem();
  ctJogos = [];
  const raiz = document.getElementById('central-torcedor');
  if (raiz) raiz.textContent = '';
}

// [PIM-WEB Central] Recebe as partidas da API e monta o painel com as do time do usuário.
function atualizarCentralTorcedor(partidas) {
  const time = estado.timeDoUsuario;
  const doTime = (time === 'default') ? partidas : partidas.filter(p => p.times.includes(time));
  ctJogos = doTime
    .filter(p => p.status !== 'finished')
    .sort((a, b) => new Date(a.inicio) - new Date(b.inicio));
  ctAba = 'jogo';
  ctSimulado = 0;
  desenharCentral();
}

function desenharCentral() {
  const raiz = document.getElementById('central-torcedor');
  if (!raiz) return;
  pararContagem();
  raiz.textContent = '';

  const abas = ctEl('div', 'ct-abas');
  abas.setAttribute('role', 'tablist');
  CT_ABAS.forEach(([id, rotulo]) => {
    const b = ctEl('button', 'ct-aba' + (id === ctAba ? ' ct-aba-ativa' : ''), rotulo);
    b.type = 'button';
    b.setAttribute('role', 'tab');
    b.setAttribute('aria-selected', id === ctAba ? 'true' : 'false');
    b.addEventListener('click', () => { ctAba = id; desenharCentral(); });
    abas.appendChild(b);
  });
  raiz.appendChild(abas);

  const painel = ctEl('div', 'ct-painel');
  painel.setAttribute('role', 'tabpanel');
  raiz.appendChild(painel);

  if (ctAba === 'jogo') painelJogo(painel);
  else if (ctAba === 'plano') painelPlano(painel);
  else if (ctAba === 'lugares') painelLugares(painel);
  else painelDicas(painel);
}

// ---------- Aba JOGO ----------
function painelJogo(painel) {
  const p = ctJogos[0];
  if (!p) { painel.appendChild(ctEl('p', 'ct-vazio', 'Nenhuma partida futura para o seu time.')); return; }

  const [t1, t2] = p.times;
  const times = ctEl('div', 'ct-times');
  // Os escudos vêm de constantes do projeto (dados.js); os nomes entram por textContent.
  times.innerHTML = logoHtml(t1, 36) + '<b></b><i>vs</i>' + logoHtml(t2, 36) + '<b></b>';
  const nomes = times.querySelectorAll('b');
  nomes[0].textContent = t1.toUpperCase();
  nomes[1].textContent = t2.toUpperCase();
  painel.appendChild(times);

  painel.appendChild(ctEl('p', 'ct-quando', `${p.data} · ${p.hora}`));

  if (p.estadio) {
    const est = ctEl('p', 'ct-estadio', `${p.estadio.nome} · ${p.estadio.cidade} `);
    const link = linkDoEstadio(p.estadio);
    if (link) est.appendChild(link);
    painel.appendChild(est);
  }

  if (Number.isFinite(new Date(p.inicio).getTime())) {
    const cont = ctEl('div', 'ct-contagem');
    cont.id = 'ct-contagem';
    [['dias', 'DIAS'], ['horas', 'HORAS'], ['min', 'MIN'], ['seg', 'SEG']].forEach(([un, rot]) => {
      const cx = ctEl('div', 'ct-cx');
      const n = ctEl('b', '', '--');
      n.dataset.un = un;
      cx.append(n, ctEl('small', '', rot));
      cont.appendChild(cx);
    });
    painel.appendChild(cont);
    iniciarContagem(p);
  }

  const preco = calcularPreco(p.preco);
  painel.appendChild(ctEl('p', 'ct-preco', ctReais(preco)));
  if ((estado.usuarioLogado?.plano || 0) > 0) {
    painel.appendChild(ctEl('p', 'ct-econ', `Você economiza ${ctReais(p.preco - preco)} como sócio.`));
  }
  const btn = ctEl('button', 'rd-btn-ingresso ct-btn', 'Ver ingressos →');
  btn.type = 'button';
  btn.addEventListener('click', () => selecionarPartida(p));
  painel.appendChild(btn);
}

// [PIM-WEB Central] Contagem regressiva. Para sozinha se o painel sair da tela ou o usuário sair.
function iniciarContagem(p) {
  const alvo = new Date(p.inicio).getTime();
  const tick = () => {
    const box = document.getElementById('ct-contagem');
    if (!box || !estado.usuarioLogado) { pararContagem(); return; }
    let resto = Math.max(0, alvo - Date.now());
    const d = Math.floor(resto / 86400000); resto -= d * 86400000;
    const h = Math.floor(resto / 3600000);  resto -= h * 3600000;
    const m = Math.floor(resto / 60000);    resto -= m * 60000;
    const s = Math.floor(resto / 1000);
    const v = { dias: d, horas: h, min: m, seg: s };
    box.querySelectorAll('b').forEach(n => { n.textContent = String(v[n.dataset.un]).padStart(2, '0'); });
  };
  tick();
  ctTimer = setInterval(tick, 1000);
}

// ---------- Aba PLANO ----------
function painelPlano(painel) {
  const u = estado.usuarioLogado;
  const plano = u?.plano || 0;
  const p = ctJogos[0];

  if (plano > 0) {
    painel.appendChild(ctEl('p', 'ct-destaque', `Plano ${u.nomePlano || 'de sócio'}`));
    painel.appendChild(ctEl('p', 'ct-texto', `Você tem ${plano}% de desconto nos ingressos.`));
    if (p) painel.appendChild(ctEl('p', 'ct-texto', `No próximo jogo, você economiza ${ctReais(p.preco - calcularPreco(p.preco))}.`));
    painel.appendChild(ctEl('p', 'ct-nota', 'Na hora de pagar, informe o seu código de sócio para aplicar o desconto.'));
    return;
  }

  painel.appendChild(ctEl('p', 'ct-destaque', 'Você ainda não é sócio'));
  if (!p) {
    painel.appendChild(ctEl('p', 'ct-vazio', 'Sem partida futura para simular.'));
  } else {
    painel.appendChild(ctEl('p', 'ct-texto', 'Veja quanto você pagaria no próximo jogo:'));
    const botoes = ctEl('div', 'ct-planos');
    [['Bronze', 5], ['Prata', 10], ['Ouro', 20]].forEach(([nome, d]) => {
      const b = ctEl('button', 'ct-plano' + (ctSimulado === d ? ' ct-plano-ativo' : ''), `${nome} ${d}%`);
      b.type = 'button';
      b.addEventListener('click', () => { ctSimulado = (ctSimulado === d ? 0 : d); desenharCentral(); });
      botoes.appendChild(b);
    });
    painel.appendChild(botoes);
    if (ctSimulado) {
      const novo = p.preco * (1 - ctSimulado / 100);
      painel.appendChild(ctEl('p', 'ct-resultado', `${ctReais(p.preco)} → ${ctReais(novo)}`));
      painel.appendChild(ctEl('p', 'ct-econ', `Economia de ${ctReais(p.preco - novo)} (valor aproximado).`));
    }
  }
  painel.appendChild(ctEl('p', 'ct-nota', 'Para assinar, use QUERO SER SÓCIO na tela de login.'));
}

// ---------- Aba LUGARES ----------
async function painelLugares(painel) {
  const p = ctJogos[0];
  if (!p) { painel.appendChild(ctEl('p', 'ct-vazio', 'Nenhuma partida futura para o seu time.')); return; }

  painel.appendChild(ctEl('p', 'ct-texto', `${p.nome} · ${p.data}`));
  const lista = ctEl('div', 'ct-setores');
  painel.appendChild(lista);
  lista.appendChild(ctEl('p', 'ct-vazio', 'Consultando lugares...'));

  try {
    // Quatro consultas ao servidor: uma por setor. Os ocupados incluem os reservados.
    const mapas = await Promise.all(CT_SETORES.map(s =>
      apiFetch(`/api/matches/${p.id}/seats?sector=${encodeURIComponent(s)}`)));
    if (ctAba !== 'lugares' || !lista.isConnected) return;   // o usuário trocou de aba
    lista.textContent = '';
    mapas.forEach((m, i) => {
      const linha = ctEl('div', 'ct-setor');
      linha.appendChild(ctEl('b', '', CT_SETORES[i]));
      const barra = ctEl('div', 'ct-barra');
      const preench = document.createElement('span');
      preench.style.width = '0%';
      barra.appendChild(preench);
      linha.appendChild(barra);
      const info = ctEl('small');
      if (!m.available) {
        info.textContent = 'Indisponível para o seu time';
      } else {
        const total = Array.isArray(m.rowSizes) ? m.rowSizes.reduce((a, b) => a + b, 0) : m.rows * m.seatsPerRow;
        const livres = Math.max(0, total - m.taken.length);
        info.textContent = `${livres} livres de ${total}`;
        const pct = total ? Math.round(100 * livres / total) : 0;
        requestAnimationFrame(() => { preench.style.width = pct + '%'; });
      }
      linha.appendChild(info);
      lista.appendChild(linha);
    });
    const btn = ctEl('button', 'rd-btn-ingresso ct-btn', 'Escolher meu lugar →');
    btn.type = 'button';
    btn.addEventListener('click', () => selecionarPartida(p));
    painel.appendChild(btn);
  } catch (e) {
    if (!lista.isConnected) return;
    lista.textContent = '';
    lista.appendChild(ctEl('p', 'ct-vazio', e instanceof ApiErro ? e.message : 'Não foi possível consultar os lugares.'));
  }
}

// ---------- Aba DICAS ----------
function painelDicas(painel) {
  CT_DICAS.forEach(([pergunta, resposta]) => {
    const d = document.createElement('details');
    d.className = 'ct-dica';
    d.appendChild(ctEl('summary', '', pergunta));
    d.appendChild(ctEl('p', '', resposta));
    painel.appendChild(d);
  });
}