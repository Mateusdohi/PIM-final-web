using System.Security.Cryptography;
using System.Text;
using TicketFut.Application.Abstractions;
using TicketFut.Application.Common;
using TicketFut.Application.Contracts;
using TicketFut.Domain.Entities;
using TicketFut.Domain.Enums;
using TicketFut.Domain.Rules;

namespace TicketFut.Application.Services;

public class PaymentService
{
    private static readonly TimeSpan IntentLifetime = TimeSpan.FromMinutes(10);

    private readonly IUserRepository _users;
    private readonly IMatchRepository _matches;
    private readonly IPaymentRepository _payments;
    private readonly IPaymentGateway _gateway;
    private readonly IUnitOfWork _uow;
    private readonly IClock _clock;
    private readonly PaymentPolicy _policy;
    // MFA: o código de 6 dígitos do autenticador confirma a compra (no lugar da selfie do app e da senha do site).
    private readonly MfaService _mfa;
    // [PIM-WEB Cartão 7] Consulta a fila virtual antes de criar a compra.
    private readonly IQueueGate _queue;

    public PaymentService(IUserRepository users, IMatchRepository matches, IPaymentRepository payments,
        IPaymentGateway gateway, IUnitOfWork uow, IClock clock, PaymentPolicy policy, MfaService mfa, IQueueGate queue)
    {
        _users = users; _matches = matches; _payments = payments; _gateway = gateway; _uow = uow;
        _clock = clock; _policy = policy; _mfa = mfa; _queue = queue;
    }

    /// <summary>Passo 1 do checkout: valida regras (setor, sócio), calcula o valor e emite o nonce.</summary>
    public async Task<IntentDto> CreateIntentAsync(Guid userId, CreateIntentRequest req, CancellationToken ct)
    {
        var user = await _users.GetByIdAsync(userId, ct) ?? throw AppException.NotFound("Usuário não encontrado.");
        // Sem autenticador ativado não há compra: o app/site leva a pessoa ao perfil para ativar (código mfa_required).
        if (!user.MfaEnabled)
            throw AppException.Forbidden("mfa_required", "Para comprar, ative o autenticador (MFA) no seu perfil.");
        var match = await _matches.GetAsync(req.MatchId, ct) ?? throw AppException.NotFound("Partida não encontrada.");
        // [PIM-WEB Cartão 7] Fila virtual: com a fila ligada, só compra quem foi liberado para esta partida (403 queue_required).
        if (!_queue.IsAdmitted(userId, req.MatchId))
            throw AppException.Forbidden("queue_required", "Entre na fila virtual e aguarde sua vez para comprar.");
        var now = _clock.UtcNow;

        if (match.IsFinished(now) || match.KickoffAt <= now)
            throw AppException.Validation("match_unavailable", "Vendas encerradas para esta partida.");
        if (!Enum.TryParse<Sector>(req.Sector, ignoreCase: true, out var sector) || !Enum.IsDefined(sector))
            throw AppException.Validation("invalid_sector", "Setor inválido.");
        if (!Enum.TryParse<PaymentMethod>(req.Method, ignoreCase: true, out var method) || !Enum.IsDefined(method))
            throw AppException.Validation("invalid_method", "Forma de pagamento inválida.");

        var isAway = user.Team != Teams.Default && match.AwayTeam == user.Team;
        var blocked = SectorRules.BlockReason(sector, isAway);
        if (blocked is not null) throw AppException.Validation("sector_blocked", blocked);

        // Regra do app web: sócio precisa informar o código para ter o desconto.
        if (user.Plan != MemberPlan.None)
        {
            var typed = (req.MemberCode ?? "").Trim();
            if (typed.Length == 0)
                throw AppException.Validation("member_code_required", "Informe seu código de sócio para aplicar o desconto.");
            if (!string.Equals(typed, user.MemberCode, StringComparison.OrdinalIgnoreCase))
                throw AppException.Validation("member_code_invalid", "Código de sócio incorreto. Verifique o código recebido no seu cadastro.");
        }

        // [PIM-WEB Cartão 4] Reserva de assento: precisa existir no mapa e estar livre (nem vendido, nem reservado por outra pessoa).
        // Assento (opcional): o app mobile continua comprando só por setor.
        if (req.SeatRow.HasValue != req.SeatNumber.HasValue)
            throw AppException.Validation("invalid_seat", "Informe a fileira e o número do assento.");
        if (req.SeatRow.HasValue)
        {
            var row = req.SeatRow.Value;
            var number = req.SeatNumber!.Value;
                      // [PIM-WEB Visual] Valida pelo desenho do setor (cada fileira tem seu tamanho).
                      if (!SeatLayout.IsValid(sector, match.HomeTeam, row, number)) // [PIM-WEB Visual] valida pelo estádio do mandante
                throw AppException.Validation("invalid_seat", "Esse assento não existe no setor.");

            // libera reservas antigas (expiradas) desse assento antes de checar
            await _payments.ExpireStaleSeatIntentsAsync(match.Id, sector, row, number, now, ct);
            // Tentar de novo (ex.: errou o código MFA) não pode esbarrar na reserva que a própria pessoa fez antes.
            await _payments.CancelOwnPendingSeatIntentsAsync(userId, match.Id, sector, row, number, ct);
            await _uow.SaveChangesAsync(ct);
            if (await _payments.IsSeatTakenAsync(match.Id, sector, row, number, now, ct))
                throw AppException.Conflict("seat_taken", "Esse assento já foi reservado ou vendido. Escolha outro.");
        }
        var intent = new PaymentIntent
        {
            UserId = userId, MatchId = match.Id, Sector = sector, Method = method,
             SeatRow = req.SeatRow, SeatNumber = req.SeatNumber,
            OriginalAmount = match.BasePrice, DiscountPercent = (int)user.Plan,
            Amount = Pricing.Apply(match.BasePrice, user.Plan),
            Nonce = Convert.ToBase64String(RandomNumberGenerator.GetBytes(32)),
            ExpiresAt = now + IntentLifetime,
        };
        await _payments.AddIntentAsync(intent, ct);
               try { await _uow.SaveChangesAsync(ct); }
        // [PIM-WEB Cartão 4] Se duas pessoas reservarem ao mesmo tempo, o índice único do banco recusa a segunda, que recebe 409 seat_taken.
        catch (AppException ex) when (ex.Code == "conflict" && req.SeatRow.HasValue)
        {
            throw AppException.Conflict("seat_taken", "Esse assento acabou de ser reservado por outra pessoa. Escolha outro.");
        }
        return new IntentDto(intent.Id, intent.Nonce, intent.Amount, intent.OriginalAmount, intent.DiscountPercent, intent.ExpiresAt, method.ToString());
    }

    /// <summary>
    /// Passo 2: confirma a compra com o código de 6 dígitos do autenticador (ou um código de recuperação).
    /// O servidor decide: expiração, nonce, limite de tentativas e conferência do código.
    /// </summary>
    public async Task<ConfirmResponse> ConfirmAsync(Guid userId, Guid intentId, ConfirmRequest req, CancellationToken ct)
    {
        var now = _clock.UtcNow;
        var intent = await _payments.GetIntentAsync(intentId, ct);
        if (intent is null || intent.UserId != userId) throw AppException.NotFound("Intenção de pagamento não encontrada.");
        if (intent.Status != PaymentStatus.Pending)
            throw AppException.Conflict("intent_closed", "Esta compra já foi finalizada ou cancelada.");
        if (intent.ExpiresAt <= now)
        {
            intent.Status = PaymentStatus.Expired;
            await _uow.SaveChangesAsync(ct);
            throw new AppException(410, "intent_expired", "O tempo para confirmar a compra expirou. Inicie novamente.");
        }
        if (!FixedTimeEquals(intent.Nonce, req.Nonce ?? ""))
            throw AppException.Forbidden("invalid_nonce", "Requisição inválida.");
        if (intent.Method != PaymentMethod.Pix && string.IsNullOrWhiteSpace(req.CardToken))
            throw AppException.Validation("card_required", "Informe os dados do cartão.");

        var user = await _users.GetByIdAsync(userId, ct) ?? throw AppException.Unauthorized();
        if (!user.MfaEnabled)
            throw AppException.Forbidden("mfa_required", "Para comprar, ative o autenticador (MFA) no seu perfil.");

        if (intent.ConfirmAttempts >= _policy.MaxConfirmAttemptsPerIntent)
        {
            intent.Status = PaymentStatus.Failed;
            await _uow.SaveChangesAsync(ct);
            throw new AppException(429, "too_many_attempts", "Muitas tentativas. Inicie a compra novamente.");
        }

        // Conta a tentativa ANTES de verificar, para que abortar a requisição não dê tentativas grátis.
        intent.ConfirmAttempts++;
        await _uow.SaveChangesAsync(ct);

        // Código errado devolve 403 (e não 401), para o app/site não achar que o login expirou.
        if (!await _mfa.VerifyAsync(user, req.Code, ct, allowSameStep: true))
        {
            await _uow.SaveChangesAsync(ct);
            throw AppException.Forbidden("invalid_mfa_code", "Código incorreto ou já usado. Digite o código de 6 dígitos que aparece agora no autenticador.");
        }

        return await ChargeAndIssueAsync(intent, req.CardToken, now, ct);
    }

    /// <summary>Cobra no gateway e emite o ingresso. Usada após a conferência do código MFA.</summary>
    private async Task<ConfirmResponse> ChargeAndIssueAsync(PaymentIntent intent, string? cardToken, DateTime now, CancellationToken ct)
    {
        var charge = await _gateway.ChargeAsync(new ChargeRequest(
            intent.Amount, intent.Method, cardToken, $"intent-{intent.Id}", $"Ingresso partida {intent.MatchId}"), ct);
        if (!charge.Approved)
        {
            await _uow.SaveChangesAsync(ct);
            throw new AppException(402, "payment_declined", charge.DeclineReason ?? "Pagamento recusado.");
        }

        intent.Status = PaymentStatus.Paid;
        intent.PaidAt = now;
        intent.GatewayReference = charge.Reference;
        var ticket = new Ticket
        {
            PaymentIntentId = intent.Id, UserId = intent.UserId, MatchId = intent.MatchId, Sector = intent.Sector,
            SeatRow = intent.SeatRow, SeatNumber = intent.SeatNumber,
            Amount = intent.Amount, Code = "TF-" + Convert.ToHexString(RandomNumberGenerator.GetBytes(4)),
            IssuedAt = now,
        };
        await _payments.AddTicketAsync(ticket, ct);
        await _uow.SaveChangesAsync(ct);

        ticket.Match = intent.Match;
        return new ConfirmResponse(Mapping.ToDto(ticket), charge.PixPayload);
    }
    public async Task<List<TicketDto>> ListTicketsAsync(Guid userId, CancellationToken ct) =>
        (await _payments.ListTicketsAsync(userId, ct)).Select(Mapping.ToDto).ToList();

            // [PIM-WEB Admin] Lista todos os ingressos para a área admin (o controller exige role Admin).
    public async Task<List<AdminTicketDto>> ListAllTicketsAsync(CancellationToken ct) =>
        (await _payments.ListAllTicketsAsync(ct)).Select(Mapping.ToAdminDto).ToList();

    private static bool FixedTimeEquals(string a, string b) =>
        CryptographicOperations.FixedTimeEquals(Encoding.UTF8.GetBytes(a), Encoding.UTF8.GetBytes(b ?? ""));
}
