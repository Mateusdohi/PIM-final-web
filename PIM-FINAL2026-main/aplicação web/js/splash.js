// ===========================
// TELA DE CARREGAMENTO DO TIME (#4)
// [PIM-WEB Visual] Visual claro, sem brilho. Frases e subtítulos por time continuam os mesmos.
// ===========================
const SPLASH_TIMES = {
  "palmeiras": {
    cor1: "#00c853", cor2: "#ffffff",
    bg: "linear-gradient(135deg, #0a1a0a 0%, #0d2a0d 50%, #0a1a0a 100%)",
    frases: ["O MAIOR CAMPEÃO DO BRASIL", "SOCIEDADE ESPORTIVA PALMEIRAS", "VERDÃO IMORTAL"],
    subtitulo: "BEM-VINDO, PALMEIRENSE!"
  },
  "flamengo": {
    cor1: "#e53935", cor2: "#000000",
    bg: "linear-gradient(135deg, #1a0808 0%, #2a0a0a 50%, #1a0808 100%)",
    frases: ["MENGÃO, O CLUBE DO POVO", "UMA VEZ FLAMENGO, SEMPRE FLAMENGO", "NAÇÃO RUBRO-NEGRA"],
    subtitulo: "BEM-VINDO, FLAMENGUISTA!"
  },
  "corinthians": {
    cor1: "#ffffff", cor2: "#888888",
    bg: "linear-gradient(135deg, #101010 0%, #1a1a1a 50%, #101010 100%)",
    frases: ["FIEL ATÉ O FIM", "SPORT CLUB CORINTHIANS PAULISTA", "O TIME DO POVO"],
    subtitulo: "BEM-VINDO, FIEL!"
  },
  "sao paulo": {
    cor1: "#e53935", cor2: "#ffffff",
    bg: "linear-gradient(135deg, #1a0808 0%, #0d0d1a 50%, #1a0808 100%)",
    frases: ["TRICOLOR CAMPEÃO MUNDIAL", "SÃO PAULO FUTEBOL CLUBE", "SOBERANO DO BRASIL"],
    subtitulo: "BEM-VINDO, SÃO-PAULINO!"
  },
  "santos": {
    cor1: "#f5f5f5", cor2: "#aaaaaa",
    bg: "linear-gradient(135deg, #0a0a12 0%, #12121a 50%, #0a0a12 100%)",
    frases: ["O REI DO FUTEBOL VEIO DAQUI", "SANTOS FUTEBOL CLUBE", "A VILA BELMIRO TE AGUARDA"],
    subtitulo: "BEM-VINDO, SANTISTA!"
  },
  "default": {
    cor1: "#00ff6a", cor2: "#00e5ff",
    bg: "linear-gradient(135deg, #0a0a0a 0%, #111418 50%, #0a0a0a 100%)",
    frases: ["BEM-VINDO AO CHAMPIONS CARD", "SEU INGRESSO COM DESCONTO", "FUTEBOL É PAIXÃO"],
    subtitulo: "BEM-VINDO!"
  }
};

function mostrarSplashTime(time, callback) {
  const cfg = SPLASH_TIMES[time] || SPLASH_TIMES["default"];

  const antigo = document.getElementById('splash-time');
  if (antigo) antigo.remove();

  const splash = document.createElement('div');
  splash.id = 'splash-time';
  splash.className = 'rd-splash';

  // [PIM-WEB Visual] Escudo do time (se houver). O estilo fica em redesign.css.
  const logo = LOGOS_BASE64[time] ? logoHtmlBig(time, 84) : '';

  splash.innerHTML = `
    <div class="rd-splash-marca">
      <img src="./CHAMPIONS_CARD.png" alt="" class="rd-splash-marca-img">
      <span>CHAMPIONS<br>CARD</span>
    </div>
    <div class="rd-splash-centro">
      ${logo ? `<div class="rd-splash-escudo">${logo}</div>` : ''}
      <p class="rd-splash-ola"></p>
      <p class="rd-splash-sub"></p>
      <div id="splash-frase-container" class="rd-splash-frase"></div>
    </div>
    <div class="rd-splash-barra"><span></span></div>
  `;

  // [PIM-WEB Visual] Nome e subtítulo via textContent (sem innerHTML).
  const nome = (estado.usuarioLogado?.nome || '').split(' ')[0];
  splash.querySelector('.rd-splash-ola').textContent = nome ? `Olá, ${nome}` : '';
  splash.querySelector('.rd-splash-sub').textContent = cfg.subtitulo;

  document.body.appendChild(splash);
  requestAnimationFrame(() => { splash.classList.add('rd-splash-visivel'); });

  const fraseContainer = splash.querySelector('#splash-frase-container');
  let idx = 0;
  function mostrarFrase() {
    const p = document.createElement('p');
    p.textContent = cfg.frases[idx];
    fraseContainer.textContent = '';
    fraseContainer.appendChild(p);
    idx = (idx + 1) % cfg.frases.length;
  }
  mostrarFrase();
  const intervalo = setInterval(mostrarFrase, 1000);

  setTimeout(() => {
    clearInterval(intervalo);
    splash.classList.remove('rd-splash-visivel');
    setTimeout(() => {
      splash.remove();
      if (callback) callback();
    }, 500);
  }, 3000);
}

// ===========================
// TELA DE CONFIRMAÇÃO DE COMPRA (#5)
// ===========================
function mostrarTelaConfirmacao() {
  const time = estado.timeDoUsuario;
  const cfg  = SPLASH_TIMES[time] || SPLASH_TIMES["default"];

  const tela = document.getElementById('screen-confirmacao');
  if (!tela) return;

  const logoHtmlConfirm = LOGOS_BASE64[time] ? logoHtmlBig(time, 50) : '';

  tela.querySelector('#confirm-titulo').style.color = cfg.cor1;
  tela.querySelector('#confirm-titulo').style.textShadow = `0 0 20px ${cfg.cor1}66`;
  tela.querySelector('#confirm-subtitulo').style.color = '#ffffff';
  tela.querySelector('#confirm-logo-time').innerHTML = logoHtmlConfirm;

  irPara('screen-confirmacao');
}