// ===========================
// TELA 3: PARTIDAS
// [PIM-WEB Cartão 8] Partidas vêm de GET /api/matches. A lista fixa PARTIDAS (dados.js) deixa de ser usada.
// ===========================

// [PIM-WEB Cartão 8] Traduz o MatchDto da API para o formato que mapa e pagamento já usam.
// Motivo: tela-mapa.js e tela-pagamento.js leem nome, preco, times, data e hora; assim não quebram.
function partidaDaApi(m) {
  const t1 = normalizarTime(timeDaApi(m.homeTeam));
  const t2 = normalizarTime(timeDaApi(m.awayTeam));
  const quando = new Date(m.kickoffAt);
  return {
    id: m.id,
    nome: `${m.homeName} vs ${m.awayName}`,
    preco: m.basePrice,          // preço cheio; calcularPreco aplica o desconto do plano
    precoApi: m.price,           // preço já com desconto calculado pelo servidor
    descontoApi: m.discountPercent,
    status: m.status,
    times: [t1, t2],
    data: quando.toLocaleDateString('pt-BR'),
    hora: quando.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' }),
  };
}

// [PIM-WEB Cartão 8] Busca as partidas na API. Motivo: preço e dados reais vêm do servidor, não do navegador.
async function carregarPartidas() {
  const lista   = document.getElementById('lista-partidas');
  const noticia = document.getElementById('noticia-time');
  lista.innerHTML = '<p style="color:#888;text-align:center;padding:20px;">CARREGANDO...</p>';
  if (noticia) noticia.textContent = obterNoticiaTime();

  // [PIM-WEB Visual] Saudação e inicial do avatar com o nome real do usuário. textContent: sem innerHTML.
  const nomeUsuario = estado.usuarioLogado?.nome || '';
  const elNome   = document.getElementById('rd-usuario-nome');
  const elAvatar = document.getElementById('rd-avatar');
  if (elNome)   elNome.textContent   = nomeUsuario.split(' ')[0];
  if (elAvatar) elAvatar.textContent = nomeUsuario.charAt(0).toUpperCase();

  let partidas;
  try {
    partidas = (await apiFetch('/api/matches')).map(partidaDaApi);
  } catch (e) {
    lista.innerHTML = '';
    mostrarToast(e instanceof ApiErro ? e.message : 'Erro inesperado.', 'error');
    return;
  }

  const time = estado.timeDoUsuario;
  const partidasFiltradas = (time === 'default')
    ? partidas
    : partidas.filter(p => p.times.includes(time));

  lista.innerHTML = '';
  if (partidasFiltradas.length === 0) {
    lista.innerHTML = `<p style="color:#888;text-align:center;padding:20px;font-size:0.85rem;letter-spacing:1px;">NENHUMA PARTIDA DISPONÍVEL PARA SEU TIME.</p>`;
    return;
  }

  const plano = estado.usuarioLogado?.plano || 0;

  partidasFiltradas.forEach(p => {
    const precoFinal = calcularPreco(p.preco);
    const item = document.createElement('div');
    item.className = 'partida-item';

    const [t1, t2] = p.times;
    // [PIM-WEB Visual] Escudos maiores (32px) para o layout novo.
    const logo1 = logoHtml(t1, 32);
    const logo2 = logoHtml(t2, 32);

    const precoHtml = plano > 0
      ? `<span class="preco-original">R$ ${p.preco.toFixed(2).replace('.', ',')}</span> <span class="preco-desconto">R$ ${precoFinal.toFixed(2).replace('.', ',')} <span class="badge-desc">-${plano}%</span></span>`
      : `R$ ${precoFinal.toFixed(2).replace('.', ',')}`;

    // [PIM-WEB Visual] Nova estrutura da linha. O botão é só visual: o clique sobe para o item, que chama selecionarPartida(p).
    item.innerHTML = `
      <div class="rd-times">${logo1}<b>${t1.toUpperCase()}</b><i>vs</i>${logo2}<b>${t2.toUpperCase()}</b></div>
      <div class="rd-info">
        <div class="rd-quando"><span class="rd-data">${p.data}</span><span class="rd-hora">${p.hora}</span></div>
        <div class="rd-preco">${precoHtml}</div>
      </div>
      <button type="button" class="rd-btn-ingresso">Ver ingressos &rarr;</button>
    `;
    item.addEventListener('click', () => selecionarPartida(p));
    lista.appendChild(item);
  });
}

function selecionarPartida(partida) {
  estado.partidaSelecionada = partida;
  estado.ehVisitante = (partida.times[1] === estado.timeDoUsuario);
  atualizarMapaArena();
  irPara('screen-mapa');
}

// [PIM-WEB Cartão 8] Sair apaga o token da memória. Motivo: sem isso a sessão continuava válida após "SAIR".
function sair() {
  definirToken(null);
    limparChat(); // [PIM-WEB Cartão 10] Motivo: não deixar a conversa para o próximo usuário.
  estado.usuarioLogado      = null;
  estado.timeDoUsuario      = 'default';
  estado.partidaSelecionada = null;
  estado.setorSelecionado   = null;
  aplicarTema('default');
  document.getElementById('login-email').value = '';
  document.getElementById('login-senha').value = '';
  irPara('screen-login');
}