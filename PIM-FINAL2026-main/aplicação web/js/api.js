// [PIM-WEB Cartão 8] Cliente da API. Token só em memória (sem localStorage).
const API_URL = 'http://localhost:5080';
let _accessToken = null;

class ApiErro extends Error {
  constructor(status, code, message) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

function definirToken(token) { _accessToken = token; }
function temToken() { return !!_accessToken; }

async function apiFetch(caminho, { metodo = 'GET', corpo } = {}) {
  const headers = { 'Content-Type': 'application/json' };
  if (_accessToken) headers['Authorization'] = 'Bearer ' + _accessToken;

  let resp;
  try {
    resp = await fetch(API_URL + caminho, {
      method: metodo,
      headers,
      body: corpo !== undefined ? JSON.stringify(corpo) : undefined,
    });
  } catch {
    throw new ApiErro(0, 'network', 'Sem conexão com o servidor.');
  }

  let dados = null;
  try { dados = await resp.json(); } catch { /* corpo vazio */ }

  if (!resp.ok) {
    if (resp.status === 429) throw new ApiErro(429, 'rate_limited', 'Muitas tentativas. Aguarde um minuto.');
    if (resp.status === 401) throw new ApiErro(401, dados?.code || 'unauthorized', dados?.message || 'Sessão expirada. Entre de novo.');
    throw new ApiErro(resp.status, dados?.code || 'error', dados?.message || 'Erro inesperado.');
  }
  return dados;
}

// Gateway simulado: token tok_sandbox_<últimos4>_<aleatório>. Número e CVV não saem do navegador.
function gerarTokenCartao(numero) {
  const digitos = String(numero).replace(/\D/g, '');
  if (digitos.length < 13) throw new ApiErro(0, 'invalid_card', 'Número de cartão inválido.');
  const ult4 = digitos.slice(-4);
  const rnd = Array.from(crypto.getRandomValues(new Uint8Array(4)))
    .map(b => b.toString(16).padStart(2, '0')).join('');
  return `tok_sandbox_${ult4}_${rnd}`;
}

const Api = {
  login:     (email, password) => apiFetch('/api/auth/login', { metodo: 'POST', corpo: { email, password } }),
  registrar: (name, cpf, email, password, team) =>
             apiFetch('/api/auth/register', { metodo: 'POST', corpo: { name, cpf, email, password, team } }),
  assinar:   (plan, method, cardToken) =>
             apiFetch('/api/membership/subscribe', { metodo: 'POST', corpo: { plan, method, cardToken } }),
  // [PIM-WEB Admin] Lista de ingressos da área admin. O servidor responde 403 se o role não for Admin.
  adminIngressos: () => apiFetch('/api/admin/tickets'),
};

// [PIM-WEB Cartão 8] Converte "sao_paulo" (API) em "sao paulo" (chave de temas/logos do front).
function timeDaApi(slug) { return (slug || 'default').replace(/_/g, ' '); }

// [PIM-WEB Cartão 8] Traduz o UserDto da API para o formato que as telas já usam.
function usuarioDaApi(u) {
  return {
    id: u.id,
    nome: u.name,
    email: u.email,
    time: timeDaApi(u.team),
    plano: u.planPercent,          // desconto %, usado por calcularPreco
    nomePlano: u.planName,
    codigoSocio: u.memberCode,
    role: u.role,
  };
}

// [PIM-WEB Cartão 8] Guarda token (memória) e usuário no estado, aplica o tema.
function iniciarSessao(authResponse) {
  definirToken(authResponse.accessToken);
  estado.usuarioLogado = usuarioDaApi(authResponse.user);
  estado.timeDoUsuario = estado.usuarioLogado.time;
  aplicarTema(estado.timeDoUsuario);
}