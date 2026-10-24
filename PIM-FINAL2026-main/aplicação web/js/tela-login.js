// ===========================
// TELA 1: LOGIN
// [PIM-WEB Cartão 8] Login e assinatura de sócio pela API. Sem localStorage.
// ===========================

// [PIM-WEB Cartão 8] Login pela API (POST /api/auth/login). Senha não é guardada.
async function fazerLogin() {
  const email = document.getElementById('login-email').value.trim();
  const senha = document.getElementById('login-senha').value; // sem trim: não altera a senha
  if (!email || !senha) { mostrarToast('Preencha e-mail e senha.', 'warning'); return; }

  try {
    const resp = await Api.login(email, senha);
    iniciarSessao(resp);
    document.getElementById('login-senha').value = '';
    mostrarSplashTime(estado.timeDoUsuario, () => {
      carregarPartidas();
      irPara('screen-partidas');
    });
  } catch (e) {
    mostrarToast(e instanceof ApiErro ? e.message : 'Erro inesperado.', 'error');
  }
}

// --- PAINEL SÓCIO NO LOGIN ---
let planoLoginSelecionado = 0;

function toggleOpcaoSocioLogin() {
  const painel = document.getElementById('login-socio-painel');
  const btn    = document.getElementById('btn-toggle-socio-login');
  const aberto = painel.classList.contains('aberto');
  painel.classList.toggle('aberto', !aberto);
  btn.textContent = aberto ? 'QUERO SER SÓCIO' : 'FECHAR';
  planoLoginSelecionado = 0;
  if (!aberto) renderizarPlanosSocio();
}

function renderizarPlanosSocio() {
  const container = document.getElementById('login-planos-socio');
  const planos = [
    { valor: 5,  label: 'SÓCIO BRONZE', desc: '5% de desconto nos ingressos',  cor: '#cd7f32' },
    { valor: 10, label: 'SÓCIO PRATA',  desc: '10% de desconto nos ingressos', cor: '#aaaaaa' },
    { valor: 20, label: 'SÓCIO OURO',   desc: '20% de desconto nos ingressos', cor: '#ffc400' },
  ];
  container.innerHTML = planos.map(p => `
    <div class="plano-card" style="border-color:${p.cor}"
         onclick="selecionarPlanoLogin(${p.valor}, this, '${p.cor}')">
      <span class="plano-nome" style="color:${p.cor}">${p.label}</span>
      <span class="plano-desc">${p.desc}</span>
    </div>
  `).join('');
}

function selecionarPlanoLogin(valor, el, cor) {
  planoLoginSelecionado = valor;
  document.querySelectorAll('.plano-card').forEach(c => {
    c.style.background = 'var(--bg-item)';
  });
  el.style.background = cor + '20';
  document.getElementById('login-socio-pagamento').classList.remove('hidden');
  const primeiroBtn = document.querySelector('#login-metodos-adesao .btn-metodo');
  selecionarMetodoAdesaoLogin('credito', primeiroBtn);
}

function selecionarMetodoAdesaoLogin(metodo, btn) {
  estado.metodoPagamentoAdesao = metodo;
  atualizarBotoesMetodo('login-metodos-adesao', btn);
  const camposCartao = document.getElementById('login-campos-cartao-adesao');
  const camposPix    = document.getElementById('login-pix-adesao');
  if (metodo === 'pix') {
    camposCartao.style.display = 'none';
    camposPix.classList.remove('hidden');
  } else {
    camposCartao.style.display       = 'flex';
    camposCartao.style.flexDirection = 'column';
    camposCartao.style.gap           = '10px';
    camposPix.classList.add('hidden');
  }
}

// [PIM-WEB Cartão 8] Assinatura: login -> POST /api/membership/subscribe com token do cartão.
async function confirmarSocioLogin() {
  const email = document.getElementById('login-email').value.trim();
  const senha = document.getElementById('login-senha').value;

  if (!email || !senha) { mostrarToast('Preencha seu e-mail e senha acima antes de assinar o plano.', 'warning'); return; }
  if (!planoLoginSelecionado) { mostrarToast('Selecione um plano de sócio.', 'warning'); return; }

  // [PIM-WEB Cartão 8] Método e token do cartão (número e CVV nunca vão à API).
  const metodoUi = estado.metodoPagamentoAdesao;
  const metodo = { credito: 'Credit', debito: 'Debit', pix: 'Pix' }[metodoUi];
  let cardToken = null;
  if (metodo !== 'pix' && metodo !== 'Pix') {
    const numeroEl = document.querySelector('#login-campos-cartao-adesao .input-field');
    try { cardToken = gerarTokenCartao(numeroEl ? numeroEl.value : ''); }
    catch (e) { mostrarToast(e.message, 'warning'); return; }
  }

  try {
    const auth = await Api.login(email, senha);
    iniciarSessao(auth);
    document.getElementById('login-senha').value = '';
    document.querySelectorAll('#login-campos-cartao-adesao input').forEach(i => i.value = '');

    const sub = await Api.assinar(planoLoginSelecionado, metodo, cardToken);
    estado.usuarioLogado = usuarioDaApi(sub.user);

    mostrarToast(`Parabéns! Você agora é sócio!\n🎫 SEU CÓDIGO: ${sub.memberCode}\nGuarde este código para usar nos ingressos.`, 'success');

    document.getElementById('login-socio-painel').classList.remove('aberto');
    document.getElementById('btn-toggle-socio-login').textContent = 'QUERO SER SÓCIO';

    setTimeout(() => {
      mostrarSplashTime(estado.timeDoUsuario, () => {
        carregarPartidas();
        irPara('screen-partidas');
      });
    }, 1500);
    } catch (e) {
    // already_member (409) cai aqui com a mensagem da API, que inclui o código de sócio.
    mostrarToast(e instanceof ApiErro ? e.message : 'Erro inesperado.', e && e.status === 409 ? 'info' : 'error');
  }
}