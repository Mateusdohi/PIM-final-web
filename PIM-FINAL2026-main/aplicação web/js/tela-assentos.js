// ===========================
// TELA DE ASSENTOS
// [PIM-WEB Cartão 9] Mapa interativo. Lê GET /api/matches/{id}/seats?sector=... e desenha a grade no formato do setor.
// ===========================

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
    return b;
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
    ordem.forEach(r => {
      const linha = document.createElement('div');
      linha.className = 'assentos-fileira';
              // [PIM-WEB Cartão 9] Trapézio por quantidade de cadeiras. Motivo: assentos ficam do mesmo tamanho.
      // Fileira 1 (perto do campo) mostra todas; a mais longe perde 8 (4 de cada ponta), sempre centralizada.
      const distancia = (r - 1) / (mapa.rows - 1);
      const visiveis = mapa.seatsPerRow - 2 * Math.round(4 * distancia);
      const inicio = (mapa.seatsPerRow - visiveis) / 2 + 1;
      const rotulo = document.createElement('span');
      rotulo.className = 'assentos-rotulo';
      rotulo.textContent = r;
      linha.appendChild(rotulo);
             for (let n = inicio; n < inicio + visiveis; n++) linha.appendChild(criarAssento(r, n));
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
      for (let n = 1; n <= mapa.seatsPerRow; n++) coluna.appendChild(criarAssento(r, n));
      const rotulo = document.createElement('span');
      rotulo.className = 'assentos-rotulo';
      rotulo.style.textAlign = 'center';
      rotulo.style.margin = '0';
      rotulo.textContent = r;
      coluna.appendChild(rotulo);
      faixa.appendChild(coluna);
    });
    if (setor === 'Leste') grade.appendChild(campo);
    grade.appendChild(faixa);
    if (setor === 'Oeste') grade.appendChild(campo);
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