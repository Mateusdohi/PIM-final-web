// ===========================
// PÁGINA "QUEM SOMOS"
// [PIM-WEB Quem Somos] Só navegação e apresentação: não altera dados, rotas nem permissões.
// ===========================

const QS_SECOES = ['qs-quem', 'qs-fazemos', 'qs-diferenciais', 'qs-como', 'qs-planos', 'qs-times'];
const QS_TIMES = [['palmeiras', 'Palmeiras'], ['corinthians', 'Corinthians'], ['flamengo', 'Flamengo'], ['sao paulo', 'São Paulo'], ['santos', 'Santos']];

// [PIM-WEB Quem Somos] Abre a página. Copia a visibilidade do botão admin do menu principal (o servidor continua conferindo o papel).
function abrirQuemSomos() {
  const orig = document.getElementById('btn-area-admin');
  const copia = document.getElementById('qs-btn-admin');
  if (orig && copia) copia.style.display = orig.style.display;
  desenharTimesQuemSomos();
  irPara('screen-quem-somos');
  atualizarSecaoAtiva();
}

// [PIM-WEB Quem Somos] Escudos dos times do cadastro. Usa os logos locais de dados.js (sem entrada do usuário).
function desenharTimesQuemSomos() {
  const caixa = document.getElementById('qs-times-lista');
  if (!caixa || caixa.children.length) return;
  QS_TIMES.forEach(([slug, nome]) => {
    const fig = document.createElement('figure');
    fig.className = 'qs-time';
    const escudo = document.createElement('div');
    escudo.className = 'qs-escudo';
    escudo.innerHTML = logoHtml(slug, 64);
    const legenda = document.createElement('figcaption');
    legenda.textContent = nome;
    fig.append(escudo, legenda);
    caixa.appendChild(fig);
  });
}

// [PIM-WEB Quem Somos] Rola até a seção escolhida no menu.
function irParaSecaoQuemSomos(id) {
  const el = document.getElementById(id);
  if (el) el.scrollIntoView({ behavior: 'smooth', block: 'start' });
}

// [PIM-WEB Quem Somos] Destaca no menu a seção que está no topo da tela.
function atualizarSecaoAtiva() {
  const tela = document.getElementById('screen-quem-somos');
  if (!tela || !tela.classList.contains('active')) return;
  let ativa = QS_SECOES[0];
  QS_SECOES.forEach(id => {
    const el = document.getElementById(id);
    if (el && el.getBoundingClientRect().top <= 170) ativa = id;
  });
  // No fim da página, a última seção fica ativa mesmo que não chegue ao topo.
  if (window.innerHeight + window.scrollY >= document.documentElement.scrollHeight - 4) {
    ativa = QS_SECOES[QS_SECOES.length - 1];
  }
  document.querySelectorAll('.qs-subitem').forEach(b => {
    b.classList.toggle('qs-ativo', b.dataset.alvo === ativa);
  });
}

document.querySelectorAll('.qs-subitem').forEach(b => {
  b.addEventListener('click', () => irParaSecaoQuemSomos(b.dataset.alvo));
});
window.addEventListener('scroll', atualizarSecaoAtiva, { passive: true });
window.addEventListener('resize', atualizarSecaoAtiva);
// ===========================
// [PIM-WEB Visual] Limpa o fundo dos escudos.
// Motivo: os PNGs trazem um fundo claro embutido (o quadrado cinza). Só o fundo ligado à borda vira transparente.
// ===========================
function limparFundoEscudo(src) {
  return new Promise(resolve => {
    const img = new Image();
    img.onload = () => {
      try {
        const w = img.naturalWidth, h = img.naturalHeight;
        const c = document.createElement('canvas');
        c.width = w; c.height = h;
        const ctx = c.getContext('2d', { willReadFrequently: true });
        ctx.drawImage(img, 0, 0);
        const dados = ctx.getImageData(0, 0, w, h);
        const px = dados.data;
        // Pixel de fundo: semitransparente, ou claro e sem cor (cinza/branco).
        const ehFundo = (i) => {
          if (px[i + 3] < 250) return true;
          const r = px[i], g = px[i + 1], b = px[i + 2];
          return Math.min(r, g, b) >= 150 && (Math.max(r, g, b) - Math.min(r, g, b)) <= 40;
        };
        const visto = new Uint8Array(w * h);
        const pilha = [];
        const empilha = (x, y) => {
          if (x < 0 || y < 0 || x >= w || y >= h) return;
          const p = y * w + x;
          if (visto[p] || !ehFundo(p * 4)) return;
          visto[p] = 1;
          pilha.push(p);
        };
        // Começa pelas bordas e avança só por pixels de fundo.
        for (let x = 0; x < w; x++) { empilha(x, 0); empilha(x, h - 1); }
        for (let y = 0; y < h; y++) { empilha(0, y); empilha(w - 1, y); }
        while (pilha.length) {
          const p = pilha.pop();
          const x = p % w, y = (p - x) / w;
          empilha(x + 1, y); empilha(x - 1, y); empilha(x, y + 1); empilha(x, y - 1);
        }
        for (let p = 0; p < w * h; p++) if (visto[p]) px[p * 4 + 3] = 0;
        ctx.putImageData(dados, 0, 0);
        resolve(c.toDataURL('image/png'));
      } catch (e) { resolve(src); }
    };
    img.onerror = () => resolve(src);
    img.src = src;
  });
}

(async function limparEscudos() {
  for (const chave of Object.keys(LOGOS_BASE64)) {
    LOGOS_BASE64[chave] = await limparFundoEscudo(LOGOS_BASE64[chave]);
  }
  // Esvazia os escudos do Quem Somos: eles são redesenhados com a imagem limpa na próxima abertura.
  const caixa = document.getElementById('qs-times-lista');
  if (caixa) caixa.textContent = '';
})();