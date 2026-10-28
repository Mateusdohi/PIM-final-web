using System.Globalization;
using System.Text;

namespace TicketFut.Api.Chat;

// [PIM-WEB Chat] Assistente de dúvidas frequentes. Responde por temas e palavras-chave, sem IA externa e sem chave.
// Motivo: demonstra a arquitetura (endpoint protegido, limites, papel fixo) sem custo.
// Uma palavra solta devolve as dúvidas do tema como botões (suggestions). Um provedor real entraria no lugar de Responder().
public record ChatReply(string Reply, List<string> Suggestions);

public class ChatService
{
    // [PIM-WEB Cartão 10] Limite de tamanho. Motivo: evita abuso e custo se um provedor real for ligado.
    public const int MaxLength = 500;

    // [PIM-WEB Chat] Uma dúvida: palavras que a reconhecem, a pergunta mostrada no botão e a resposta.
    private record Faq(string[] Chaves, string Pergunta, string Resposta);
    // [PIM-WEB Chat] Um tema: nome, palavras que o reconhecem e suas dúvidas.
    private record Tema(string Nome, string[] Chaves, Faq[] Faqs);

    // Textos reais do sistema: tudo abaixo existe hoje. Onde não existe regra, a resposta diz isso.
    private static readonly Tema[] Temas =
    {
        new("Ingressos", new[] { "ingresso", "comprar", "compra", "bilhete", "jogo", "partida" }, new[]
        {
            new Faq(new[] { "como comprar", "como compro", "passo a passo", "comprar ingresso" },
                "Como comprar um ingresso?",
                "Na tela de partidas, clique em VER INGRESSOS. Escolha o setor no mapa e depois o assento. Confirme o pagamento com sua senha. O ingresso é emitido ao final."),
            new Faq(new[] { "onde vejo", "meus ingressos", "ver ingresso", "ingresso comprado" },
                "Onde vejo meus ingressos?",
                "O site ainda não tem uma tela de meus ingressos. Ao comprar, aparece a tela de confirmação. Não tenho como consultar ingressos antigos por aqui."),
            new Faq(new[] { "cancelar", "cancelamento", "reembolso", "devolver", "devolucao", "estorno" },
                "Posso cancelar ou pedir reembolso?",
                "O site não tem cancelamento nem reembolso, e o chat não tem informação sobre essa política."),
            new Faq(new[] { "transferir", "transferencia", "outra pessoa", "passar o ingresso" },
                "Posso transferir o ingresso?",
                "O site não tem transferência de ingresso, e o chat não tem informação sobre essa regra."),
            new Faq(new[] { "quantos", "limite", "varios ingressos", "mais de um" },
                "Posso comprar mais de um ingresso?",
                "Sim. Use o carrinho: ele aceita até 5 ingressos por compra, cada um com seu assento."),
        }),
        new("Assentos", new[] { "assento", "cadeira", "fileira", "lugar", "mapa", "setor" }, new[]
        {
            new Faq(new[] { "escolher", "como escolho", "selecionar", "marcar" },
                "Como escolho meu assento?",
                "Depois de escolher a partida e o setor, o mapa mostra as cadeiras. Cinza é ocupado e verde é livre. Clique numa livre e confirme."),
            new Faq(new[] { "reserva", "reservado", "segurar", "tempo", "minutos", "expira" },
                "Por quanto tempo o assento fica reservado?",
                "A reserva dura 10 minutos, a partir do início do pagamento. Passado esse tempo, outra pessoa pode comprar a cadeira."),
            new Faq(new[] { "ocupado", "tomado", "ja foi", "indisponivel", "sumiu" },
                "O assento que escolhi deu erro. E agora?",
                "Alguém reservou ou comprou essa cadeira antes. Volte ao mapa e escolha outra. A grade é atualizada ao reabrir."),
            new Faq(new[] { "leste", "visitante", "setor bloqueado", "cinza" },
                "Por que não consigo escolher o setor Leste?",
                "O Leste é exclusivo da torcida visitante. Se o seu time é o mandante da partida, ele fica bloqueado. Se o seu time é o visitante, só o Leste fica liberado."),
            new Faq(new[] { "numeracao", "fileira 1", "perto do campo", "proximo do gramado" },
                "Como é a numeração dos assentos?",
                "A fileira 1 é a mais próxima do gramado. Cada setor tem 12 fileiras, e o número de cadeiras muda por fileira."),
        }),
        new("Planos de sócio", new[] { "plano", "socio", "sócio", "desconto", "bronze", "prata", "ouro", "assinar", "assinatura" }, new[]
        {
            new Faq(new[] { "quais planos", "tipos", "bronze", "prata", "ouro", "quanto desconto" },
                "Quais são os planos de sócio?",
                "Há três planos: Bronze (5% de desconto nos ingressos), Prata (10%) e Ouro (20%)."),
            new Faq(new[] { "como assinar", "virar socio", "ser socio", "assinar plano", "como me torno" },
                "Como me torno sócio?",
                "Na tela de login, clique em QUERO SER SÓCIO. Escolha o plano, preencha o pagamento, informe e-mail e senha e confirme. Você recebe um código de sócio."),
            new Faq(new[] { "codigo", "código", "meu codigo", "codigo de socio" },
                "Para que serve o código de sócio?",
                "É obrigatório para receber o desconto na compra. Informe o código no pagamento. O servidor confere o código antes de aplicar o desconto."),
            new Faq(new[] { "esqueci o codigo", "perdi o codigo", "nao tenho o codigo" },
                "Esqueci meu código de sócio.",
                "O chat não consegue consultar o código. Se você tentar assinar de novo, a mensagem de erro mostra o código que você já tem."),
            new Faq(new[] { "ja sou socio", "trocar de plano", "mudar de plano", "upgrade" },
                "Posso trocar de plano?",
                "O site não tem troca de plano. Quem já é sócio recebe um aviso ao tentar assinar de novo."),
        }),
        new("Pagamento", new[] { "pagamento", "pagar", "cartao", "cartão", "pix", "credito", "crédito", "debito", "débito", "cobranca", "cobrança" }, new[]
        {
            new Faq(new[] { "formas", "aceitam", "meios", "como pagar", "aceito" },
                "Quais formas de pagamento existem?",
                "Aceitamos crédito, débito e PIX."),
            new Faq(new[] { "seguro", "seguranca", "dados do cartao", "numero do cartao", "cvv" },
                "Meus dados de cartão estão seguros?",
                "O número e o CVV do cartão ficam no seu navegador. Só um código gerado a partir do cartão (token) vai ao servidor. Na confirmação, o site pede sua senha de novo."),
            new Faq(new[] { "recusado", "recusou", "negado", "nao passou", "erro no cartao" },
                "Meu pagamento foi recusado.",
                "A cobrança foi recusada. Confira os dados e tente outro cartão. Se for pelo carrinho, o item continua lá com o motivo."),
            new Faq(new[] { "senha pedindo", "pede senha", "por que senha", "confirmar com senha" },
                "Por que o site pede minha senha na compra?",
                "É uma segurança extra: a senha confirma que é você quem está comprando."),
            new Faq(new[] { "pix", "qr", "chave pix" },
                "Como pago com PIX?",
                "Escolha PIX no pagamento. O site mostra o QR Code e a chave. Esta versão é uma demonstração: o pagamento é simulado."),
        }),
        new("Carrinho", new[] { "carrinho" }, new[]
        {
            new Faq(new[] { "como usar", "adicionar", "como funciona" },
                "Como usar o carrinho?",
                "Na tela de assentos, escolha uma cadeira e clique em ADICIONAR AO CARRINHO. Repita para outras. Depois abra o carrinho no menu e finalize a compra de uma vez."),
            new Faq(new[] { "limite", "quantos", "maximo", "máximo" },
                "Quantos ingressos cabem no carrinho?",
                "Até 5 ingressos. Cada item é um assento."),
            new Faq(new[] { "perdi", "sumiu", "recarregar", "atualizar a pagina", "fechar" },
                "O carrinho some quando saio?",
                "Sim. O carrinho fica só na memória do navegador. Ao sair ou recarregar a página, ele esvazia."),
            new Faq(new[] { "um deu erro", "ficou no carrinho", "alguns ingressos", "parcial" },
                "Alguns itens ficaram no carrinho. Por quê?",
                "Cada ingresso é comprado separadamente. Se um falhar (assento tomado, por exemplo), os outros continuam. O que falhou fica no carrinho com o motivo."),
        }),
        new("Fila virtual", new[] { "fila", "espera", "liberado", "liberacao" }, new[]
        {
            new Faq(new[] { "o que e", "como funciona", "fila virtual" },
                "O que é a fila virtual?",
                "Em jogos muito procurados pode haver fila virtual. Você entra na fila e é liberado por tempo limitado para comprar."),
            new Faq(new[] { "fechar a aba", "sair da fila", "perdi a vez", "perdi meu lugar" },
                "Perco meu lugar se fechar a página?",
                "Sim. Fechar a aba tira você da fila. Não dá para recuperar a posição."),
            new Faq(new[] { "nao tem fila", "nao aparece", "sem fila" },
                "Não apareceu fila para mim. Por quê?",
                "A fila só funciona quando está ligada no servidor. Nesta versão ela vem desligada por padrão."),
        }),
        new("Conta e senha", new[] { "senha", "login", "entrar", "cadastro", "conta", "email", "e-mail", "cpf" }, new[]
        {
            new Faq(new[] { "como entrar", "fazer login", "logar" },
                "Como entro na minha conta?",
                "Na tela inicial, informe e-mail e senha e clique em FAZER LOGIN."),
            new Faq(new[] { "como cadastrar", "criar conta", "me cadastrar", "nao tenho conta" },
                "Como me cadastro?",
                "Na tela de login, clique em FAZER CADASTRO. Informe nome, CPF, e-mail, senha e o time."),
            new Faq(new[] { "regra da senha", "senha fraca", "tamanho da senha", "senha invalida" },
                "Qual é a regra da senha?",
                "A senha tem de 8 a 128 caracteres, com pelo menos uma letra e um número."),
            new Faq(new[] { "esqueci minha senha", "recuperar senha", "perdi a senha", "redefinir" },
                "Esqueci minha senha.",
                "O site ainda não tem recuperação de senha, e o chat não consegue redefini-la."),
            new Faq(new[] { "deslogou", "sessao expirou", "caiu a sessao", "pediu login de novo" },
                "O site pediu login de novo. Por quê?",
                "O login fica só na memória do navegador. Se você recarregar a página, precisa entrar de novo."),
        }),
        new("Seu time", new[] { "time", "torcida", "mandante", "filiacao" }, new[]
        {
            new Faq(new[] { "so aparece", "partidas do meu time", "por que so", "poucas partidas" },
                "Por que só aparecem as partidas do meu time?",
                "A lista é filtrada pelo time escolhido no seu cadastro."),
            new Faq(new[] { "mudar de time", "trocar de time", "trocar time" },
                "Posso mudar de time?",
                "O site não tem troca de time depois do cadastro."),
        }),
    };

    // Temas que aparecem quando a mensagem não é reconhecida.
    private static readonly string[] TemasPrincipais = { "Ingressos", "Assentos", "Planos de sócio", "Pagamento", "Carrinho", "Fila virtual", "Conta e senha" };

    public ChatReply Responder(string mensagem)
    {
        var texto = Normalizar(mensagem);

        // 1) Frase que bate com uma dúvida específica: responde e sugere as outras do mesmo tema.
        Tema? melhorTema = null; Faq? melhorFaq = null; int melhorTam = 0;
        foreach (var tema in Temas)
            foreach (var faq in tema.Faqs)
                foreach (var chave in faq.Chaves)
                {
                    var c = Normalizar(chave);
                    if (c.Length > melhorTam && texto.Contains(c)) { melhorTema = tema; melhorFaq = faq; melhorTam = c.Length; }
                }
        if (melhorFaq is not null && melhorTema is not null)
            return new ChatReply(melhorFaq.Resposta, Relacionadas(melhorTema, melhorFaq));

        // 2) Palavra de tema (ex.: "pagamento"): mostra as dúvidas do tema como botões.
        foreach (var tema in Temas)
            if (tema.Chaves.Any(c => texto.Contains(Normalizar(c))))
                return new ChatReply($"Sobre {tema.Nome.ToLowerInvariant()}, escolha uma dúvida:",
                                     tema.Faqs.Select(f => f.Pergunta).ToList());

        // 3) Não reconheceu: papel fixo + temas principais como botões.
        return new ChatReply("Só consigo ajudar com dúvidas sobre o TicketFut. Escolha um assunto:", TemasPrincipais.ToList());
    }

    private static List<string> Relacionadas(Tema tema, Faq atual) =>
        tema.Faqs.Where(f => f != atual).Select(f => f.Pergunta).Take(3).ToList();

    // Minúsculas, sem acentos e sem pontuação. Motivo: "Sócio", "socio" e "SÓCIO?" valem o mesmo.
    private static string Normalizar(string s)
    {
        var d = s.ToLowerInvariant().Normalize(NormalizationForm.FormD);
        var sb = new StringBuilder(d.Length);
        foreach (var ch in d)
        {
            var cat = CharUnicodeInfo.GetUnicodeCategory(ch);
            if (cat == UnicodeCategory.NonSpacingMark) continue;
            sb.Append(char.IsLetterOrDigit(ch) ? ch : ' ');
        }
        return string.Join(' ', sb.ToString().Split(' ', StringSplitOptions.RemoveEmptyEntries));
    }
}