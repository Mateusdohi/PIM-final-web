// ===========================
// TELA 4: MAPA DA ARENA
// [PIM-WEB Cartão 8] Mapa continua por setor.
// [PIM-WEB Cartão 9] Setor abre a escolha de assento (tela-assentos.js); o pagamento recebe o assento.
// [PIM-WEB Estádio] O desenho muda conforme o time da casa (mandante).
// ===========================

// [PIM-WEB Estádio] Geometria de cada estádio no SVG (viewBox 640x440). Cada setor tem: d (forma), div (divisórias), x e y (rótulo).
// Motivo: o mapa imita o estádio do mandante e acompanha o formato da grade de assentos.
const ESTADIOS_MAPA = {
  // Allianz Parque: desenho original (trapézio com cantos arredondados).
  'palmeiras': {
    pista: { x: 185, y: 135, w: 270, h: 170, rx: 16 }, campo: '',
    Norte: { d: 'M170 48 L470 48 Q505 48 522 82 L462 120 L178 120 L118 82 Q135 48 170 48 Z', div: 'M230 48V120M320 48V120M410 48V120', x: 320, y: 88 },
    Sul:   { d: 'M170 392 L470 392 Q505 392 522 358 L462 320 L178 320 L118 358 Q135 392 170 392 Z', div: 'M230 392V320M320 392V320M410 392V320', x: 320, y: 361 },
    Oeste: { d: 'M104 102 L164 140 L164 300 L104 338 Q62 300 62 220 Q62 140 104 102 Z', div: 'M70 170H164M64 220H164M70 270H164', x: 113, y: 225 },
    Leste: { d: 'M536 102 L476 140 L476 300 L536 338 Q578 300 578 220 Q578 140 536 102 Z', div: 'M570 170H476M576 220H476M570 270H476', x: 527, y: 225 },
  },
  // Morumbis: oval. Norte e Sul em arco; laterais abrem em leque.
  'sao paulo': {
    pista: { x: 178, y: 126, w: 284, h: 188, rx: 44 }, campo: '',
    Norte: { d: 'M100 84 Q320 -4 540 84 L462 120 L178 120 Z', div: 'M240 46V120M400 46V120', x: 320, y: 84 },
    Sul:   { d: 'M100 356 Q320 444 540 356 L462 320 L178 320 Z', div: 'M240 394V320M400 394V320', x: 320, y: 364 },
    Oeste: { d: 'M86 104 L164 140 V300 L86 336 Q22 290 22 220 Q22 150 86 104 Z', div: 'M30 175H164M30 265H164', x: 93, y: 225 },
    Leste: { d: 'M554 104 L476 140 V300 L554 336 Q618 290 618 220 Q618 150 554 104 Z', div: 'M610 175H476M610 265H476', x: 547, y: 225 },
  },
  // Maracanã: círculo. Quatro setores iguais, em arco, ao redor do campo.
  'flamengo': {
    pista: { x: 187, y: 87, w: 266, h: 266, rx: 133 }, campo: 'translate(320 220) scale(0.9) translate(-320 -220)',
    Norte: { d: 'M457.2 67.7 A205 205 0 0 0 182.8 67.7 L226.3 116 A140 140 0 0 1 413.7 116 Z', div: 'M353.9 84.2L369.6 21.1M286.1 84.2L270.4 21.1', x: 320, y: 52 },
    Sul:   { d: 'M457.2 372.3 A205 205 0 0 1 182.8 372.3 L226.3 324 A140 140 0 0 0 413.7 324 Z', div: 'M353.9 355.8L369.6 418.9M286.1 355.8L270.4 418.9', x: 320, y: 397 },
    Oeste: { d: 'M167.7 82.8 A205 205 0 0 0 167.7 357.2 L216 313.7 A140 140 0 0 1 216 126.3 Z', div: 'M184.2 186.1L121.1 170.4M184.2 253.9L121.1 269.6', x: 148, y: 225 },
    Leste: { d: 'M472.3 82.8 A205 205 0 0 1 472.3 357.2 L424 313.7 A140 140 0 0 0 424 126.3 Z', div: 'M455.8 186.1L518.9 170.4M455.8 253.9L518.9 269.6', x: 492, y: 225 },
  },
  // Neo Química Arena: retângulo com os cantos cortados.
  'corinthians': {
    pista: { x: 185, y: 135, w: 270, h: 170, rx: 4 }, campo: '',
    Norte: { d: 'M136 63 H504 L514 73 V94 L482 120 H158 L126 94 V73 Z', div: 'M259 63V120M381 63V120', x: 320, y: 96 },
    Sul:   { d: 'M136 377 H504 L514 367 V346 L482 320 H158 L126 346 V367 Z', div: 'M259 377V320M381 377V320', x: 320, y: 353 },
    Oeste: { d: 'M52 144 L62 134 H152 L162 144 V296 L152 306 H62 L52 296 Z', div: 'M52 190H162M52 250H162', x: 107, y: 225 },
    Leste: { d: 'M588 144 L578 134 H488 L478 144 V296 L488 306 H578 L588 296 Z', div: 'M588 190H478M588 250H478', x: 533, y: 225 },
  },
  // Vila Belmiro: retângulo compacto, sem diagonais.
  'santos': {
    pista: { x: 185, y: 135, w: 270, h: 170, rx: 2 }, campo: '',
    Norte: { d: 'M185 80 H455 V122 H185 Z', div: 'M275 80V122M365 80V122', x: 320, y: 105 },
    Sul:   { d: 'M185 318 H455 V360 H185 Z', div: 'M275 318V360M365 318V360', x: 320, y: 343 },
    Oeste: { d: 'M108 135 H168 V305 H108 Z', div: 'M108 190H168M108 250H168', x: 138, y: 225 },
    Leste: { d: 'M472 135 H532 V305 H472 Z', div: 'M472 190H532M472 250H532', x: 502, y: 225 },
  },
};

// [PIM-WEB Estádio] Aplica a geometria do estádio no SVG. Estádio desconhecido usa o desenho do Palmeiras.
function desenharEstadio(time) {
  const g = ESTADIOS_MAPA[time] || ESTADIOS_MAPA['palmeiras'];

  const pista = document.getElementById('mapa-pista');
  if (pista) {
    pista.setAttribute('x', g.pista.x);
    pista.setAttribute('y', g.pista.y);
    pista.setAttribute('width', g.pista.w);
    pista.setAttribute('height', g.pista.h);
    pista.setAttribute('rx', g.pista.rx);
  }
  const gramado = document.getElementById('mapa-gramado');
  if (gramado) {
    if (g.campo) gramado.setAttribute('transform', g.campo);
    else gramado.removeAttribute('transform');
  }

  ['Norte', 'Sul', 'Oeste', 'Leste'].forEach(nome => {
    const el = document.getElementById('mapa-' + nome.toLowerCase());
    const s = g[nome];
    if (!el || !s) return;
    el.querySelector('.mp-forma').setAttribute('d', s.d);
    el.querySelector('.mp-div').setAttribute('d', s.div);
    const rotulo = el.querySelector('.mp-rotulo');
    rotulo.setAttribute('x', s.x);
    rotulo.setAttribute('y', s.y);
  });
}

// [PIM-WEB Estádio] Linha com nome, cidade e link do estádio. Usa textContent (o nome vem da API).
function atualizarEstadioMapa(partida) {
  const el = document.getElementById('mp-estadio');
  if (!el) return;
  el.textContent = '';
  const e = partida && partida.estadio;
  if (!e) return;
  el.appendChild(document.createTextNode(`${e.nome} · ${e.cidade}`));
  const link = linkDoEstadio(e);
  if (link) el.appendChild(link);
}

// [PIM-WEB Visual] Mapa em SVG: cada setor é um <g id="mapa-..."> e a regra de bloqueio é a mesma de antes.
// Motivo: só mudou o desenho; quem pode ou não escolher cada setor continua sendo decidido aqui.
function atualizarMapaArena() {
  const partida = estado.partidaSelecionada;
  desenharEstadio(partida?.times?.[0]);   // [PIM-WEB Estádio] mandante = times[0]
  atualizarEstadioMapa(partida);

  const ehVisitante = estado.ehVisitante;
  ['Norte', 'Sul', 'Oeste', 'Leste'].forEach(nome => {
    const el = document.getElementById('mapa-' + nome.toLowerCase());
    if (!el) return;
    const bloqueado = ehVisitante ? nome !== 'Leste' : nome === 'Leste';
    let acao;
    if (bloqueado) {
      el.classList.add('mp-bloqueado');
      el.setAttribute('aria-disabled', 'true');
      acao = ehVisitante
        ? () => mostrarToast('Seu time é o visitante nesta partida.\nApenas o setor LESTE está disponível para torcedores visitantes.', 'warning')
        : () => mostrarToast('O setor LESTE é exclusivo para a torcida visitante.', 'warning');
    } else {
      el.classList.remove('mp-bloqueado');
      el.removeAttribute('aria-disabled');
      acao = () => escolherSetor(nome);
    }
    el.onclick = acao;
    // [PIM-WEB Visual] Teclado: Enter ou espaço fazem o mesmo que o clique.
    el.onkeydown = (e) => {
      if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); acao(); }
    };

    // [PIM-WEB Visual] Legenda com o estado real do setor (textContent: sem innerHTML).
    const li = document.getElementById('mp-leg-' + nome.toLowerCase());
    if (li) {
      li.classList.toggle('mp-leg-bloqueado', bloqueado);
      const small = li.querySelector('small');
      if (small) {
        small.textContent = !bloqueado
          ? 'Disponível'
          : (nome === 'Leste' ? 'Exclusivo torcida visitante' : 'Indisponível para o seu time');
      }
    }
  });

  const aviso = document.getElementById('aviso-visitante');
  const avisoMandante = document.getElementById('aviso-mandante');
  if (aviso) aviso.style.display = ehVisitante ? 'block' : 'none';
  if (avisoMandante) avisoMandante.style.display = !ehVisitante ? 'block' : 'none';
}

// [PIM-WEB Cartão 9] Setor agora abre a escolha de assento. O corpo antigo virou prepararPagamento.
function escolherSetor(setor) {
  // [PIM-WEB Cartão 8] Sem token, não segue. Motivo: o pagamento exige login na API.
  if (!temToken()) {
    mostrarToast('Sua sessão expirou. Entre de novo.', 'warning');
    irPara('screen-login', false);
    return;
  }
  abrirAssentos(setor);
}

// [PIM-WEB Cartão 9] Corpo antigo de escolherSetor, chamado depois de escolher o assento.
function prepararPagamento(setor) {
  estado.setorSelecionado = setor;
  const partida    = estado.partidaSelecionada;
  // [PIM-WEB Cartão 8] Valor só para exibição. O servidor recalcula o preço no pagamento.
  const precoFinal = calcularPreco(partida.preco);

  // [PIM-WEB Cartão 9] Resumo com fileira e cadeira. Motivo: o usuário confere o assento antes de pagar.
  // O comentário fica fora da crase: dentro do template literal ele viraria texto.
  const a = estado.assentoSelecionado;
  document.getElementById('resumo-partida').innerHTML =
    `${partida.nome} (${setor.toUpperCase()} · FILEIRA ${a.row}, CADEIRA ${a.number})<br><small style="color:#888;font-size:0.78rem;font-weight:500;letter-spacing:1px;">📅 ${partida.data} &nbsp;⏰ ${partida.hora}</small>`;
  document.getElementById('resumo-total').textContent =
    `TOTAL: R$ ${precoFinal.toFixed(2).replace('.', ',')}`;

  const blocoSocio = document.getElementById('bloco-codigo-socio');
  if (blocoSocio) {
    const temPlano = (estado.usuarioLogado?.plano > 0);
    blocoSocio.style.display = temPlano ? 'block' : 'none';
    const input = document.getElementById('input-codigo-socio');
    if (input) {
      input.value = '';
      // [PIM-WEB Cartão 8] Placeholder fixo. Motivo: antes mostrava o código real do sócio na tela.
      input.placeholder = 'SEU CÓDIGO DE SÓCIO';
    }
  }

  const primeiroBtn = document.querySelector('#metodos-compra .btn-metodo');
  selecionarMetodoCompra('credito', primeiroBtn);
  irPara('screen-pagamento');
}