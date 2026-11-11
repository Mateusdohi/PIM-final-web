// ===========================
// PERFIL DO USUÁRIO
// [PIM-WEB Perfil] Mostra e edita o próprio perfil. Nome e time vão para PUT /api/auth/me; a senha para POST /api/auth/change-password.
// Sem CPF na tela. Senhas só nos campos e limpas após o envio. Textos por textContent.
// ===========================

let pfCodigoVisivel = false;

// [PIM-WEB Perfil] Define o texto de uma mensagem de status. tipo: 'ok' ou 'erro'.
function pfMsg(id, texto, tipo) {
  const el = document.getElementById(id);
  if (!el) return;
  el.textContent = texto || '';
  el.className = 'pf-msg' + (texto ? (tipo === 'ok' ? ' pf-msg-ok' : ' pf-msg-erro') : '');
}

// [PIM-WEB Perfil] Abre a tela e carrega o perfil atual do servidor (GET /api/auth/me).
async function abrirPerfil() {
  if (!temToken()) {
    mostrarToast('Sua sessão expirou. Entre de novo.', 'warning');
    irPara('screen-login', false);
    return;
  }
  ['pf-msg-dados', 'pf-msg-senha', 'pf-msg-mfa'].forEach(id => pfMsg(id, ''));
  esconderSetupMfa();
  ['pf-senha-atual', 'pf-mfa-senha', 'pf-senha-nova', 'pf-senha-confirma'].forEach(id => { const e = document.getElementById(id); if (e) e.value = ''; });
  pfCodigoVisivel = false;
  irPara('screen-perfil');
  try {
    const u = await apiFetch('/api/auth/me');
    estado.usuarioLogado = usuarioDaApi(u);
    preencherPerfil(u);
  } catch (e) {
    mostrarToast(e instanceof ApiErro ? e.message : 'Erro inesperado.', 'error');
  }
}

// [PIM-WEB Perfil] Preenche os campos com os dados do servidor. Tudo por textContent ou value.
function preencherPerfil(u) {
  const nome = u.name || '';
  document.getElementById('pf-avatar').textContent = nome.charAt(0).toUpperCase();
  document.getElementById('pf-nome-titulo').textContent = nome;
  document.getElementById('pf-email').textContent = u.email || '';
  document.getElementById('pf-nome').value = nome;
  document.getElementById('pf-email-leitura').value = u.email || '';

  // O select usa o nome de exibição do time ("São Paulo"), vindo do slug da API.
  const nomes = { palmeiras: 'Palmeiras', corinthians: 'Corinthians', flamengo: 'Flamengo', sao_paulo: 'São Paulo', santos: 'Santos' };
  const sel = document.getElementById('pf-time');
  sel.value = nomes[u.team] || 'Palmeiras';
  sel.dataset.original = sel.value;

  const plano = u.planPercent || 0;
  document.getElementById('pf-plano').textContent = plano > 0
    ? `Plano ${u.planName || 'de sócio'}: ${plano}% de desconto nos ingressos.`
    : 'Você ainda não é sócio.';
  const bloco = document.getElementById('pf-bloco-codigo');
  bloco.style.display = (plano > 0 && u.memberCode) ? 'flex' : 'none';
  document.getElementById('pf-codigo').textContent = '••••••';
  document.getElementById('pf-btn-codigo').textContent = 'Mostrar';
  document.getElementById('pf-codigo').dataset.valor = u.memberCode || '';

  renderizarMfa(!!u.mfaEnabled, null);
}

// [PIM-WEB Perfil] Mostra ou esconde o código de sócio.
function alternarCodigoPerfil() {
  const el = document.getElementById('pf-codigo');
  pfCodigoVisivel = !pfCodigoVisivel;
  el.textContent = pfCodigoVisivel ? (el.dataset.valor || '') : '••••••';
  document.getElementById('pf-btn-codigo').textContent = pfCodigoVisivel ? 'Esconder' : 'Mostrar';
}
// [PIM-WEB Perfil] Salva nome e time. Trocar de time pede confirmação: muda o tema, a lista de partidas e a regra dos setores.
async function salvarPerfil() {
  const nome = document.getElementById('pf-nome').value.trim();
  const sel = document.getElementById('pf-time');
  const time = sel.value;
  pfMsg('pf-msg-dados', '');

  if (nome.length < 3) { pfMsg('pf-msg-dados', 'Informe seu nome completo.', 'erro'); return; }
  if (time !== sel.dataset.original) {
    const ok = window.confirm('Trocar de time muda o tema do site, a lista de partidas e os setores disponíveis. Deseja continuar?');
    if (!ok) { sel.value = sel.dataset.original; return; }
  }
  try {
    const u = await apiFetch('/api/auth/me', { metodo: 'PUT', corpo: { name: nome, team: time } });
    estado.usuarioLogado = usuarioDaApi(u);
    estado.timeDoUsuario = estado.usuarioLogado.time;
    aplicarTema(estado.timeDoUsuario);
    preencherPerfil(u);
    pfMsg('pf-msg-dados', 'Dados atualizados.', 'ok');
    mostrarToast('Perfil atualizado.', 'success');
  } catch (e) {
    pfMsg('pf-msg-dados', e instanceof ApiErro ? e.message : 'Erro inesperado.', 'erro');
  }
}

// [PIM-WEB Perfil] Troca a senha. Confere o formato e a confirmação no site; o servidor confere a senha atual.
async function trocarSenhaPerfil() {
  const atual = document.getElementById('pf-senha-atual').value;
  const nova = document.getElementById('pf-senha-nova').value;
  const conf = document.getElementById('pf-senha-confirma').value;
  pfMsg('pf-msg-senha', '');

  if (!atual || !nova || !conf) { pfMsg('pf-msg-senha', 'Preencha os três campos.', 'erro'); return; }
  if (nova.length < 8 || nova.length > 128 || !/[A-Za-z]/.test(nova) || !/[0-9]/.test(nova)) {
    pfMsg('pf-msg-senha', 'A nova senha deve ter de 8 a 128 caracteres, com letras e números.', 'erro'); return;
  }
  if (nova !== conf) { pfMsg('pf-msg-senha', 'A confirmação não é igual à nova senha.', 'erro'); return; }
  if (nova === atual) { pfMsg('pf-msg-senha', 'A nova senha deve ser diferente da atual.', 'erro'); return; }

  try {
    await apiFetch('/api/auth/change-password', { metodo: 'POST', corpo: { currentPassword: atual, newPassword: nova } });
    ['pf-senha-atual', 'pf-senha-nova', 'pf-senha-confirma'].forEach(id => { document.getElementById(id).value = ''; });
    pfMsg('pf-msg-senha', 'Senha alterada. Use a nova senha no próximo login.', 'ok');
    mostrarToast('Senha alterada.', 'success');
  } catch (e) {
    pfMsg('pf-msg-senha', e instanceof ApiErro ? e.message : 'Erro inesperado.', 'erro');
  }
}
// ---------------------------------------------------------------
// Autenticador (MFA, TOTP): ativação com QR Code + chave, códigos de recuperação, desativar e gerar novos (pedem a senha atual).
// O segredo só existe na tela durante a ativação; textContent/src, nunca innerHTML com dados da API.
// ---------------------------------------------------------------
function esconderSetupMfa() {
  const setup = document.getElementById('pf-mfa-setup');
  if (setup) setup.style.display = 'none';
  const qr = document.getElementById('pf-mfa-qr');
  if (qr) qr.removeAttribute('src');
  ['pf-mfa-chave'].forEach(id => { const e = document.getElementById(id); if (e) e.textContent = ''; });
  ['pf-mfa-codigo', 'pf-mfa-senha'].forEach(id => { const e = document.getElementById(id); if (e) e.value = ''; });
  const rec = document.getElementById('pf-mfa-recuperacao');
  if (rec) rec.style.display = 'none';
  const lista = document.getElementById('pf-mfa-lista');
  if (lista) lista.textContent = '';
}

// Mostra o estado do MFA. codigos: lista de códigos de recuperação recém-gerados (ou null).
function renderizarMfa(ativo, codigos) {
  if (estado.usuarioLogado) estado.usuarioLogado.mfaAtivo = ativo;
  document.getElementById('pf-mfa-texto').textContent = ativo
    ? 'Autenticador ATIVADO. A compra de ingressos pede o código de 6 dígitos do seu aplicativo.'
    : 'Autenticador DESATIVADO. Para comprar ingressos é preciso ativar: a compra é confirmada com um código de 6 dígitos do seu aplicativo (Microsoft Authenticator, Google Authenticator, Authy...).';
  document.getElementById('pf-mfa-ativar').style.display = ativo ? 'none' : 'block';
  document.getElementById('pf-mfa-ativo').style.display = ativo ? 'block' : 'none';
  document.getElementById('pf-mfa-btn-iniciar').style.display = 'inline-block';
  document.getElementById('pf-mfa-setup').style.display = 'none';
  const rec = document.getElementById('pf-mfa-recuperacao');
  const lista = document.getElementById('pf-mfa-lista');
  lista.textContent = '';
  if (codigos && codigos.length) {
    codigos.forEach(c => { const li = document.createElement('li'); li.textContent = c; lista.appendChild(li); });
    rec.style.display = 'block';
  } else {
    rec.style.display = 'none';
  }
}

// Passo 1: pede o segredo ao servidor e mostra QR Code e chave (o mesmo valor).
async function iniciarMfaPerfil() {
  pfMsg('pf-msg-mfa', '');
  try {
    const s = await Api.mfaSetup();
    document.getElementById('pf-mfa-qr').src = s.qrSvg;
    document.getElementById('pf-mfa-chave').textContent = s.secret;
    document.getElementById('pf-mfa-codigo').value = '';
    document.getElementById('pf-mfa-setup').style.display = 'block';
    document.getElementById('pf-mfa-btn-iniciar').style.display = 'none';
  } catch (e) {
    pfMsg('pf-msg-mfa', e instanceof ApiErro ? e.message : 'Erro inesperado.', 'erro');
  }
}

async function copiarChaveMfa() {
  const chave = (document.getElementById('pf-mfa-chave').textContent || '').replace(/\s/g, '');
  try {
    await navigator.clipboard.writeText(chave);
    pfMsg('pf-msg-mfa', 'Chave copiada.', 'ok');
  } catch {
    pfMsg('pf-msg-mfa', 'Não foi possível copiar. Selecione a chave e copie manualmente.', 'erro');
  }
}

// Passo 2: confere o primeiro código; ao acertar o MFA liga e os códigos de recuperação aparecem (só agora).
async function confirmarMfaPerfil() {
  const codigo = document.getElementById('pf-mfa-codigo').value.trim();
  pfMsg('pf-msg-mfa', '');
  if (!codigo) { pfMsg('pf-msg-mfa', 'Digite o código de 6 dígitos do aplicativo.', 'erro'); return; }
  try {
    const r = await Api.mfaAtivar(codigo);
    esconderSetupMfa();
    renderizarMfa(true, r.recoveryCodes);
    pfMsg('pf-msg-mfa', 'Autenticador ativado. Guarde os códigos de recuperação abaixo.', 'ok');
    mostrarToast('Autenticador ativado.', 'success');
  } catch (e) {
    pfMsg('pf-msg-mfa', e instanceof ApiErro ? e.message : 'Erro inesperado.', 'erro');
  }
}

async function novosCodigosMfaPerfil() {
  const senha = document.getElementById('pf-mfa-senha').value;
  pfMsg('pf-msg-mfa', '');
  if (!senha) { pfMsg('pf-msg-mfa', 'Digite sua senha atual.', 'erro'); return; }
  try {
    const r = await Api.mfaCodigos(senha);
    document.getElementById('pf-mfa-senha').value = '';
    renderizarMfa(true, r.recoveryCodes);
    pfMsg('pf-msg-mfa', 'Novos códigos gerados. Os anteriores deixaram de valer.', 'ok');
  } catch (e) {
    pfMsg('pf-msg-mfa', e instanceof ApiErro ? e.message : 'Erro inesperado.', 'erro');
  }
}

async function desativarMfaPerfil() {
  const senha = document.getElementById('pf-mfa-senha').value;
  pfMsg('pf-msg-mfa', '');
  if (!senha) { pfMsg('pf-msg-mfa', 'Digite sua senha atual.', 'erro'); return; }
  if (!window.confirm('Desativar o autenticador? Sem ele você não poderá comprar ingressos até ativar de novo.')) return;
  try {
    await Api.mfaDesativar(senha);
    esconderSetupMfa();
    renderizarMfa(false, null);
    pfMsg('pf-msg-mfa', 'Autenticador desativado.', 'ok');
  } catch (e) {
    pfMsg('pf-msg-mfa', e instanceof ApiErro ? e.message : 'Erro inesperado.', 'erro');
  }
}

// [PIM-WEB Perfil] Ao sair, limpa a tela. Motivo: não deixar dados do usuário anterior para o próximo.
(function ligarLimpezaPerfil() {
  const sairOrig = sair;
  sair = function () {
    ['pf-nome', 'pf-email-leitura', 'pf-senha-atual', 'pf-senha-nova', 'pf-senha-confirma'].forEach(id => { const e = document.getElementById(id); if (e) e.value = ''; });
    ['pf-nome-titulo', 'pf-email', 'pf-avatar', 'pf-plano', 'pf-mfa-texto'].forEach(id => { const e = document.getElementById(id); if (e) e.textContent = ''; });
    const cod = document.getElementById('pf-codigo');
    if (cod) { cod.textContent = '••••••'; cod.dataset.valor = ''; }
    ['pf-msg-dados', 'pf-msg-senha', 'pf-msg-mfa'].forEach(id => pfMsg(id, ''));
    esconderSetupMfa();
    sairOrig();
  };
})();