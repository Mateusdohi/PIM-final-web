// ===========================
// TELA DE ASSENTOS
// [PIM-WEB Cartão 9] Mapa interativo. Lê GET /api/matches/{id}/seats?sector=... e desenha a grade no formato do setor.
// [PIM-WEB Visual] O servidor manda o tamanho de cada fileira (rowSizes). O site desenha exatamente essas cadeiras.
// ===========================

// [PIM-WEB Visual] Medidas de uma cadeira: 22px de largura + 4px de espaço = 26px. Altura 24px + 4px = 28px.
const ASSENTO_PASSO_X = 26;
const ASSENTO_PASSO_Y = 28;

// [PIM-WEB Cartão 9] Abre a tela e carrega a grade. Motivo: o setor escolhido agora leva a um assento.
function abrirAssentos(setor) {
  estado.setorSelecionado = setor;
  estado.assentoSelecionado = null;
  irPara('screen-assentos');
  carregarAssentos();
}

// [PIM-WEB Cartão 9] Busca os assentos ocupados no servidor.
// Motivo: linhas/colunas e ocupação vêm da API; o navegador não decide o que está livre.
async function carregarAssentos() {
  const grade = document.getElementById('assentos-grade');
  const info  = document.getElementById('assentos-info');
  const partida = estado.partidaSelecionada;
  const setor   = estado.setorSelecionado;
  grade.textContent = 'CARREGANDO...';
  info.textContent = `${partida.nome} · SETOR ${setor.toUpperCase()}`;

  let mapa;
  try {
    mapa = await apiFetch(`/api/matches/${partida.id}/seats?sector=${encodeURIComponent(setor)}`);
  } catch (e) {
    grade.textContent = '';
    mostrarToast(e instanceof ApiErro ? e.message : 'Erro inesperado.', 'error');
    return;
  }

  // [PIM-WEB Cartão 9] Setor indisponível: mostra o motivo que o servidor devolveu.
  if (!mapa.available) {
    grade.textContent = mapa.reason || 'Setor indisponível.';
    return;
  }

  // [PIM-WEB Cartão 9] Mapa de ocupados por "fileira-cadeira". Motivo: consulta rápida ao desenhar.
  const ocupados = new Map(mapa.taken.map(t => [`${t.row}-${t.number}`, t.status]));

  // [PIM-WEB Cartão 9] Cria um botão de assento. Motivo: o mesmo código serve para qualquer orientação.
  const criarAssento = (r, n) => {
    const b = document.createElement('button');
    b.type = 'button';
    b.className = 'assento';
    b.dataset.row = r;
    b.dataset.number = n;
    const status = ocupados.get(`${r}-${n}`);
    if (status) {
      b.classList.add('ocupado');
      b.disabled = true;
      b.title = `Fileira ${r}, cadeira ${n} (${status})`;
    } else {
      b.title = `Fileira ${r}, cadeira ${n}`;
      b.addEventListener('click', () => selecionarAssento(r, n, b));
    }
    b.setAttribute('aria-label', b.title); // [PIM-WEB Visual] Leitor de tela lê fileira e cadeira.
    return b;
  };

  // [PIM-WEB Visual] Tamanho de cada fileira vindo do servidor. Sem rowSizes (API antiga), todas ficam cheias.
  const tamanhos = Array.isArray(mapa.rowSizes) && mapa.rowSizes.length === mapa.rows
    ? mapa.rowSizes
    : Array(mapa.rows).fill(mapa.seatsPerRow);
  // Cadeiras visíveis da fileira r: de margem+1 até seatsPerRow-margem (a mesma regra do servidor).
  const faixaDaFileira = (r) => {
    const margem = Math.floor((mapa.seatsPerRow - tamanhos[r - 1]) / 2);
    return { de: margem + 1, ate: mapa.seatsPerRow - margem };
  };

  // [PIM-WEB Cartão 9] Rótulo do gramado. Motivo: orienta o torcedor (fileira 1 é a mais próxima do campo).
  const campo = document.createElement('div');
  campo.className = 'assentos-campo';
  campo.textContent = 'GRAMADO';

  const ordem = [];
  for (let r = 1; r <= mapa.rows; r++) ordem.push(r);

  grade.textContent = '';
  const lateral = (setor === 'Oeste' || setor === 'Leste');

  if (!lateral) {
    // [PIM-WEB Cartão 9] Norte e Sul: fileiras horizontais. Norte: fileira 1 embaixo. Sul: fileira 1 em cima.
    if (setor === 'Norte') ordem.reverse();
    if (setor === 'Sul') grade.appendChild(campo);
    // [PIM-WEB Visual] Largura fixa para todas as fileiras. Motivo: o rótulo fica alinhado à esquerda e as cadeiras centralizadas.
    const larguraFileira = (mapa.seatsPerRow * ASSENTO_PASSO_X + 60) + 'px';
    ordem.forEach(r => {
      const linha = document.createElement('div');
      linha.className = 'assentos-fileira';
      linha.style.width = larguraFileira;
      const rotulo = document.createElement('span');
      rotulo.className = 'assentos-rotulo';
      rotulo.textContent = r;
      linha.appendChild(rotulo);
      const f = faixaDaFileira(r);
      for (let n = f.de; n <= f.ate; n++) linha.appendChild(criarAssento(r, n));
      grade.appendChild(linha);
    });
    if (setor === 'Norte') grade.appendChild(campo);
  } else {
    // [PIM-WEB Cartão 9] Oeste e Leste: cada fileira vira uma coluna. Oeste: fileira 1 à direita. Leste: à esquerda.
    if (setor === 'Oeste') ordem.reverse();
    const faixa = document.createElement('div');
    faixa.className = 'assentos-lado';
    ordem.forEach(r => {
      const coluna = document.createElement('div');
      coluna.className = 'assentos-coluna';
      // [PIM-WEB Visual] Altura fixa com as cadeiras centralizadas. Motivo: forma o "D" do desenho e alinha os rótulos embaixo.
      const pecas = document.createElement('div');
      pecas.className = 'assentos-pecas';
      pecas.style.minHeight = (mapa.seatsPerRow * ASSENTO_PASSO_Y) + 'px';
      const f = faixaDaFileira(r);
      for (let n = f.de; n <= f.ate; n++) pecas.appendChild(criarAssento(r, n));
      coluna.appendChild(pecas);
      const rotulo = document.createElement('span');
      rotulo.className = 'assentos-rotulo';
      rotulo.style.textAlign = 'center';
      rotulo.style.margin = '0';
      rotulo.textContent = r;
      coluna.appendChild(rotulo);
      faixa.appendChild(coluna);
    });
    // [PIM-WEB Visual] Gramado ao lado, como no mapa: à direita no Oeste, à esquerda no Leste.
    campo.classList.add('assentos-campo-v');
    const caixa = document.createElement('div');
    caixa.className = 'assentos-lateral';
    if (setor === 'Leste') { caixa.appendChild(campo); caixa.appendChild(faixa); }
    else                   { caixa.appendChild(faixa); caixa.appendChild(campo); }
    grade.appendChild(caixa);
  }
}

// [PIM-WEB Cartão 9] Marca um único assento. Motivo: a compra é de um ingresso por vez.
function selecionarAssento(row, number, btn) {
  document.querySelectorAll('.assento.selecionado').forEach(a => a.classList.remove('selecionado'));
  btn.classList.add('selecionado');
  estado.assentoSelecionado = { row, number };
}

// [PIM-WEB Cartão 9] Segue para o pagamento só com assento escolhido.
function confirmarAssento() {
  if (!estado.assentoSelecionado) {
    mostrarToast('Escolha um assento.', 'warning');
    return;
  }
  prepararPagamento(estado.setorSelecionado);
}