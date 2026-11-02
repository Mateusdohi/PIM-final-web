// ===========================
// CARTÃO VISUAL
// [PIM-WEB Cartão Visual] Desenha um cartão que se preenche conforme o usuário digita (número, validade, bandeira).
// Motivo: deixa a compra mais clara. Só LÊ os campos que já existem; nada é enviado, guardado ou registrado.
// O CVV nunca aparece no desenho. Todo texto vai por textContent (sem innerHTML).
// ===========================

// [PIM-WEB Cartão Visual] Cartão de teste do gateway simulado (final 1111 é aprovado; final 0000 é recusado).
const CV_TESTE = { numero: '4111 1111 1111 1111', validade: '10/30', cvv: '123' };

const cvInstancias = [];

function cvEl(tag, classe, texto) {
  const el = document.createElement(tag);
  if (classe) el.className = classe;
  if (texto !== undefined) el.textContent = texto;
  return el;
}

// [PIM-WEB Cartão Visual] Bandeira pelo início do número. Só para o desenho; o servidor não recebe isso.
function cvBandeira(digitos) {
  if (/^4/.test(digitos)) return 'VISA';
  if (/^(5[1-5]|2(2[2-9]|[3-6]\d|7[01]|720))/.test(digitos)) return 'MASTERCARD';
  if (/^3[47]/.test(digitos)) return 'AMEX';
  return 'CARTÃO';
}

// [PIM-WEB Cartão Visual] Cria o cartão e o atalho de teste dentro do bloco de campos.
function cvIniciar(containerId, grupoMetodosId) {
  const cont = document.getElementById(containerId);
  if (!cont || cont.dataset.cv === '1') return;
  const campos = cont.querySelectorAll('input');
  if (campos.length < 3) return;
  cont.dataset.cv = '1';
  const [num, val, cvv] = campos;

  const cartao = cvEl('div', 'cv-cartao');
  cartao.setAttribute('aria-hidden', 'true');
  const topo = cvEl('div', 'cv-topo');
  const tipo = cvEl('span', 'cv-tipo', 'CRÉDITO');
  const bandeira = cvEl('span', 'cv-bandeira', 'CARTÃO');
  topo.append(tipo, bandeira);
  const chip = cvEl('div', 'cv-chip');
  const numero = cvEl('div', 'cv-numero', '•••• •••• •••• ••••');
  const rodape = cvEl('div', 'cv-rodape');
  const nome = cvEl('span', 'cv-nome', 'SEU NOME');
  const validade = cvEl('span', 'cv-validade', 'MM/AA');
  rodape.append(nome, validade);
  cartao.append(topo, chip, numero, rodape);

  const teste = cvEl('button', 'cv-teste', 'Preencher com o cartão de teste');
  teste.type = 'button';

  cont.insertBefore(cartao, cont.firstChild);
  cont.appendChild(teste);

  function atualizar() {
    const d = num.value.replace(/\D/g, '').slice(0, 16);
    const completo = (d + '••••••••••••••••').slice(0, 16);
    numero.textContent = completo.replace(/(.{4})/g, '$1 ').trim();
    bandeira.textContent = cvBandeira(d);
    validade.textContent = val.value || 'MM/AA';
    const nomeUsuario = (typeof estado !== 'undefined' && estado.usuarioLogado && estado.usuarioLogado.nome) || '';
    nome.textContent = nomeUsuario ? nomeUsuario.toUpperCase() : 'SEU NOME';
    const ativo = document.querySelector(`#${grupoMetodosId} .btn-metodo.active`);
    tipo.textContent = ativo ? ativo.textContent.trim().toUpperCase() : 'CRÉDITO';
    // [PIM-WEB Cartão Visual] O atalho do cartão de teste só aparece para o Admin. É conveniência de tela, não segurança: o gateway é simulado.
    teste.hidden = !(typeof estado !== 'undefined' && estado.usuarioLogado && estado.usuarioLogado.role === 'Admin');
  }

  // [PIM-WEB Cartão Visual] Máscaras: número em grupos de 4, validade MM/AA, CVV só dígitos.
  num.addEventListener('input', () => {
    const v = num.value.replace(/\D/g, '').slice(0, 16);
    num.value = v.replace(/(.{4})/g, '$1 ').trim();
    atualizar();
  });
  val.addEventListener('input', () => {
    let v = val.value.replace(/\D/g, '').slice(0, 4);
    if (v.length > 2) v = v.slice(0, 2) + '/' + v.slice(2);
    val.value = v;
    atualizar();
  });
  cvv.addEventListener('input', () => { cvv.value = cvv.value.replace(/\D/g, '').slice(0, 4); });

  // O tipo (crédito/débito) muda quando o usuário troca o método; espera o clique terminar.
  const grupo = document.getElementById(grupoMetodosId);
  if (grupo) grupo.addEventListener('click', () => setTimeout(atualizar, 0));

  teste.addEventListener('click', () => {
    [[num, CV_TESTE.numero], [val, CV_TESTE.validade], [cvv, CV_TESTE.cvv]].forEach(([campo, valor]) => {
      campo.value = valor;
      campo.dispatchEvent(new Event('input', { bubbles: true }));
    });
  });

  cvInstancias.push(atualizar);
  atualizar();
}

// [PIM-WEB Cartão Visual] Chamado a cada troca de tela: atualiza nome, tipo e número (os campos podem ter sido limpos após uma compra).
function cvAtualizarTodos() {
  cvInstancias.forEach(fn => fn());
}
