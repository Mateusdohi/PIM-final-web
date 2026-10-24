// ===========================
// TELA 2: CADASTRO
// [PIM-WEB Cartão 8] Cadastro pela API. Sem localStorage e sem envio para localhost:5114.
// ===========================
const TIME_CLASSES = {
  "palmeiras":   "time-palmeiras",
  "flamengo":    "time-flamengo",
  "corinthians": "time-corinthians",
  "sao paulo":   "time-sao-paulo",
  "santos":      "time-santos",
};

document.getElementById('cad-plano').addEventListener('change', function () {
  const secao = document.getElementById('secao-pagamento-cadastro');
  const plano = parseInt(this.value);
  if (plano > 0) {
    secao.classList.remove('hidden');
    document.getElementById('cad-bloco-pix').classList.add('hidden');
    const btnPix = document.getElementById('btn-pix-toggle');
    if (btnPix) { btnPix.classList.remove('ativo'); btnPix.textContent = 'PAGAR POR PIX'; }
  } else {
    secao.classList.add('hidden');
  }
  document.getElementById('cad-time').dispatchEvent(new Event('change'));
});

function togglePixCad() {
  const bloco = document.getElementById('cad-bloco-pix');
  const btn   = document.getElementById('btn-pix-toggle');
  const aberto = !bloco.classList.contains('hidden');
  bloco.classList.toggle('hidden', aberto);
  btn.classList.toggle('ativo', !aberto);
  btn.textContent = aberto ? 'PAGAR POR PIX' : 'FECHAR PIX';
}

document.getElementById('cad-time').addEventListener('change', function () {
  const sel = this;
  Object.values(TIME_CLASSES).forEach(c => sel.classList.remove(c));
  const timeNorm = normalizarTime(this.value);
  const classe   = TIME_CLASSES[timeNorm];
  const tema     = TEMAS_TIMES[timeNorm];
  const cor    = (classe && tema) ? tema.primary : 'var(--neon-cyan)';
  const bg     = (classe && tema) ? tema.bg      : 'rgba(0, 229, 255, 0.04)';
  const sombra = (classe && tema) ? `0 0 0 2px ${tema.primary}22` : '0 0 0 2px rgba(0,229,255,0.08)';
  if (classe && tema) sel.classList.add(classe);
  document.querySelectorAll('.secao-cartao').forEach(s => {
    s.style.borderColor = cor;
    s.style.background  = bg;
    s.style.boxShadow   = sombra;
    const label = s.querySelector('.label-pagamento');
    if (label) label.style.color = cor;
  });
  const btnPix = document.getElementById('btn-pix-toggle');
  if (btnPix) { btnPix.style.borderColor = cor; btnPix.style.color = cor; }
  const qrcode   = document.querySelector('#cad-bloco-pix .qrcode');
  const pixChave = document.querySelector('#cad-bloco-pix .pix-chave');
  if (qrcode)   qrcode.style.borderColor = cor;
  if (pixChave) pixChave.style.color = cor;
});

// ============================================================
// [PIM-WEB Cartão 8] CADASTRO PELA API
// Fluxo: POST /api/auth/register -> POST /api/auth/login -> (se plano) POST /api/membership/subscribe.
// Número e CVV do cartão nunca saem do navegador: só o token do gateway simulado vai à API.
// ============================================================
async function finalizarCadastro() {
  const nome  = document.getElementById('cad-nome').value.trim();
  const cpf   = document.getElementById('cad-cpf').value.trim();
  const email = document.getElementById('cad-email').value.trim();
  const senha = document.getElementById('cad-senha').value; // sem trim: não altera a senha
  const time  = document.getElementById('cad-time').value;
  const plano = parseInt(document.getElementById('cad-plano').value) || 0;

  if (!nome || !cpf || !email || !senha || !time) {
    mostrarToast('Preencha todos os campos obrigatórios.', 'warning');
    return;
  }

  // [PIM-WEB Cartão 8] Validação de conforto (a API valida de novo): 8 a 128 caracteres, letra e número.
  if (senha.length < 8 || senha.length > 128 || !/[A-Za-z]/.test(senha) || !/\d/.test(senha)) {
    mostrarToast('A senha deve ter de 8 a 128 caracteres, com letra e número.', 'warning');
    return;
  }

  // [PIM-WEB Cartão 8] Se escolheu plano, define método e gera o token ANTES de criar a conta.
  let metodo = null, cardToken = null;
  if (plano > 0) {
    const pixAberto = !document.getElementById('cad-bloco-pix').classList.contains('hidden');
    const numCred   = document.getElementById('cad-credito-numero').value;
    const numDeb    = document.getElementById('cad-debito-numero').value;
    try {
      if (pixAberto)            { metodo = 'Pix'; }
      else if (numCred.trim())  { metodo = 'Credit'; cardToken = gerarTokenCartao(numCred); }
      else if (numDeb.trim())   { metodo = 'Debit';  cardToken = gerarTokenCartao(numDeb); }
      else { mostrarToast('Informe o cartão ou escolha PIX para o plano de sócio.', 'warning'); return; }
    } catch (e) {
      mostrarToast(e.message, 'warning');
      return;
    }
  }

  try {
    // 1) Cria a conta (o hash da senha é feito no servidor).
    await Api.registrar(nome, cpf, email, senha, time);

    // 2) Login para obter o token.
    const auth = await Api.login(email, senha);
    iniciarSessao(auth);

    // Limpa dados sensíveis dos campos.
    ['cad-senha','cad-credito-numero','cad-credito-validade','cad-credito-cvv',
     'cad-debito-numero','cad-debito-validade','cad-debito-cvv'
    ].forEach(id => { const el = document.getElementById(id); if (el) el.value = ''; });

    // 3) Plano de sócio (opcional). Falha aqui não desfaz a conta.
    let codigoSocio = null;
    if (plano > 0) {
      try {
        const sub = await Api.assinar(plano, metodo, cardToken);
        estado.usuarioLogado = usuarioDaApi(sub.user);
        codigoSocio = sub.memberCode;
      } catch (e) {
        mostrarToast('Conta criada, mas o plano não foi assinado:\n' + e.message, 'warning');
      }
    }

    if (codigoSocio) {
      mostrarToast(`Cadastro realizado!\n🎫 SEU CÓDIGO DE SÓCIO: ${codigoSocio}\nAnote este código para usar nos ingressos.`, 'success');
    }

    setTimeout(() => {
      mostrarSplashTime(estado.timeDoUsuario, () => {
        carregarPartidas();
        irPara('screen-partidas');
      });
    }, codigoSocio ? 1800 : 300);

  } catch (e) {
    mostrarToast(e instanceof ApiErro ? e.message : 'Erro inesperado.', 'error');
  }
}