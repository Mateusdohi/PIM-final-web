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
    const logo1 = logoHtml(t1, 18);
    const logo2 = logoHtml(t2, 18);

    const precoHtml = plano > 0
      ? `<span class="preco-original">R$ ${p.preco.toFixed(2).replace('.', ',')}</span> <span class="preco-desconto">R$ ${precoFinal.toFixed(2).replace('.', ',')} <span class="badge-desc">-${plano}%</span></span>`
      : `R$ ${precoFinal.toFixed(2).replace('.', ',')}`;

    item.innerHTML = `
      <p>${logo1}${t1.toUpperCase()} vs ${logo2}${t2.toUpperCase()}</p>
      <span>📅 ${p.data} &nbsp;⏰ ${p.hora} &nbsp;·&nbsp; ${precoHtml}</span>
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