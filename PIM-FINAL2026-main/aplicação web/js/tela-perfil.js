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
  ['pf-msg-dados', 'pf-msg-senha', 'pf-msg-face'].forEach(id => pfMsg(id, ''));
  ['pf-senha-atual', 'pf-senha-nova', 'pf-senha-confirma'].forEach(id => { const e = document.getElementById(id); if (e) e.value = ''; });
  pfCodigoVisivel = false;
  irPara('screen-perfil');
  try {
    const u = await apiFetch('/api/auth/me');
    estado.usuarioLogado = usuarioDaApi(u);
    estado.temFace = !!u.hasFace;
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

  document.getElementById('pf-face').textContent = u.hasFace
    ? 'Há uma biometria facial cadastrada na sua conta.'
    : 'Você não tem biometria facial cadastrada.';
  document.getElementById('pf-btn-face').style.display = u.hasFace ? 'inline-block' : 'none';
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
// [PIM-WEB Perfil] Remove a biometria (LGPD). Pede confirmação antes. O endpoint já existia.
async function removerBiometriaPerfil() {
  pfMsg('pf-msg-face', '');
  const ok = window.confirm('Remover sua biometria facial? Você poderá cadastrá-la de novo depois.');
  if (!ok) return;
  try {
    await apiFetch('/api/auth/face', { metodo: 'DELETE' });
    document.getElementById('pf-face').textContent = 'Você não tem biometria facial cadastrada.';
    document.getElementById('pf-btn-face').style.display = 'none';
    pfMsg('pf-msg-face', 'Biometria removida.', 'ok');
  } catch (e) {
    pfMsg('pf-msg-face', e instanceof ApiErro ? e.message : 'Erro inesperado.', 'erro');
  }
}

// [PIM-WEB Perfil] Ao sair, limpa a tela. Motivo: não deixar dados do usuário anterior para o próximo.
(function ligarLimpezaPerfil() {
  const sairOrig = sair;
  sair = function () {
    ['pf-nome', 'pf-email-leitura', 'pf-senha-atual', 'pf-senha-nova', 'pf-senha-confirma'].forEach(id => { const e = document.getElementById(id); if (e) e.value = ''; });
    ['pf-nome-titulo', 'pf-email', 'pf-avatar', 'pf-plano', 'pf-face'].forEach(id => { const e = document.getElementById(id); if (e) e.textContent = ''; });
    const cod = document.getElementById('pf-codigo');
    if (cod) { cod.textContent = '••••••'; cod.dataset.valor = ''; }
    ['pf-msg-dados', 'pf-msg-senha', 'pf-msg-face'].forEach(id => pfMsg(id, ''));
    sairOrig();
  };
})();