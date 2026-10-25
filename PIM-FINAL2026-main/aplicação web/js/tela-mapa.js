// ===========================
// TELA 4: MAPA DA ARENA
// [PIM-WEB Cartão 8] Mapa continua por setor (assentos individuais são o Cartão 9).
// Só ajustes de segurança nesta etapa.
// ===========================
function atualizarMapaArena() {
  const ehVisitante = estado.ehVisitante;
  const setores = {
    'Norte': document.querySelector('.setor-norte'),
    'Sul':   document.querySelector('.setor-sul'),
    'Oeste': document.querySelectorAll('.setor-lado')[0],
    'Leste': document.querySelectorAll('.setor-lado')[1],
  };
  Object.entries(setores).forEach(([nome, el]) => {
    if (!el) return;
    const bloqueado = ehVisitante ? nome !== 'Leste' : nome === 'Leste';
    if (bloqueado) {
      el.classList.add('setor-bloqueado');
      el.onclick = ehVisitante
        ? () => mostrarToast('Seu time é o visitante nesta partida.\nApenas o setor LESTE está disponível para torcedores visitantes.', 'warning')
        : () => mostrarToast('O setor LESTE é exclusivo para a torcida visitante.', 'warning');
    } else {
      el.classList.remove('setor-bloqueado');
      el.onclick = () => escolherSetor(nome);
    }
  });
  const aviso = document.getElementById('aviso-visitante');
  const avisoMandante = document.getElementById('aviso-mandante');
  if (aviso) aviso.style.display = ehVisitante ? 'block' : 'none';
  if (avisoMandante) avisoMandante.style.display = !ehVisitante ? 'block' : 'none';
}

function escolherSetor(setor) {
  // [PIM-WEB Cartão 8] Sem token, não segue. Motivo: o pagamento exige login na API.
  if (!temToken()) {
    mostrarToast('Sua sessão expirou. Entre de novo.', 'warning');
    irPara('screen-login', false);
    return;
  }

  estado.setorSelecionado = setor;
  const partida    = estado.partidaSelecionada;
  // [PIM-WEB Cartão 8] Valor só para exibição. O servidor recalcula o preço no pagamento.
  const precoFinal = calcularPreco(partida.preco);

  document.getElementById('resumo-partida').innerHTML =
    `${partida.nome} (${setor.toUpperCase()})<br><small style="color:#888;font-size:0.78rem;font-weight:500;letter-spacing:1px;">📅 ${partida.data} &nbsp;⏰ ${partida.hora}</small>`;
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