// [PIM-WEB Admin] Área administrativa. Quem barra o acesso é o servidor (401/403); aqui só se esconde o botão.

// [PIM-WEB Admin] Mostra o botão apenas se o usuário logado tem role Admin.
function atualizarBotaoAdmin() {
  const btn = document.getElementById('btn-area-admin');
  if (btn) btn.style.display = estado.usuarioLogado?.role === 'Admin' ? '' : 'none';
}

// [PIM-WEB Admin] Busca os ingressos na API e monta a tabela. Usa textContent (sem innerHTML) contra XSS.
async function abrirAreaAdmin() {
  irPara('screen-admin');
  const corpo = document.getElementById('admin-tabela-corpo');
  const resumo = document.getElementById('admin-resumo');
  corpo.textContent = '';
  resumo.textContent = 'Carregando...';
  try {
    const lista = await Api.adminIngressos();
    let total = 0;
    lista.forEach(t => {
      total += t.amount;
      const tr = document.createElement('tr');
      const assento = t.seatRow != null ? `F${t.seatRow} / N${t.seatNumber}` : '-';
      const celulas = [
        new Date(t.issuedAt).toLocaleString('pt-BR'),
        t.matchName,
        t.sector,
        assento,
        'R$ ' + t.amount.toFixed(2).replace('.', ','),
        t.code,
        String(t.userId).slice(0, 8),
      ];
      celulas.forEach(valor => {
        const td = document.createElement('td');
        td.style.padding = '6px';
        td.style.borderTop = '1px solid rgba(255,255,255,0.2)';
        td.textContent = valor;
        tr.appendChild(td);
      });
      corpo.appendChild(tr);
    });
    resumo.textContent = `${lista.length} ingresso(s). Total: R$ ${total.toFixed(2).replace('.', ',')}`;
  } catch (e) {
    resumo.textContent = e.status === 403 ? 'Acesso negado.' : e.message;
  }
}