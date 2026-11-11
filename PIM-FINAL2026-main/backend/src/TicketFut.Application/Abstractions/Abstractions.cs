using TicketFut.Domain.Entities;
using TicketFut.Domain.Enums;

namespace TicketFut.Application.Abstractions;

public interface IUnitOfWork { Task SaveChangesAsync(CancellationToken ct = default); }

public interface IClock { DateTime UtcNow { get; } }

public interface IUserRepository
{
    Task<User?> GetByIdAsync(Guid id, CancellationToken ct = default);
    Task<User?> GetByEmailAsync(string email, CancellationToken ct = default);
    Task<bool> CpfExistsAsync(string cpf, CancellationToken ct = default);
    Task<bool> MemberCodeExistsAsync(string code, CancellationToken ct = default);
    Task AddAsync(User user, CancellationToken ct = default);
}

public interface IMfaRecoveryRepository
{
    Task<List<MfaRecoveryCode>> ListUnusedAsync(Guid userId, CancellationToken ct = default);
    /// <summary>Apaga todos os códigos do usuário e grava os novos (hashes).</summary>
    Task ReplaceAllAsync(Guid userId, IEnumerable<string> hashes, CancellationToken ct = default);
    Task DeleteAllAsync(Guid userId, CancellationToken ct = default);
}

public interface IRefreshTokenRepository
{
    Task AddAsync(RefreshToken token, CancellationToken ct = default);
    Task<RefreshToken?> GetByHashAsync(string hash, CancellationToken ct = default);
    Task RevokeAllForUserAsync(Guid userId, DateTime now, CancellationToken ct = default);
}

public interface IMatchRepository
{
    Task<List<Match>> ListAsync(CancellationToken ct = default);
    Task<Match?> GetAsync(int id, CancellationToken ct = default);
}

public interface IPaymentRepository
{
    Task AddIntentAsync(PaymentIntent intent, CancellationToken ct = default);
    Task<PaymentIntent?> GetIntentAsync(Guid id, CancellationToken ct = default);
    Task AddTicketAsync(Ticket ticket, CancellationToken ct = default);
    Task<List<Ticket>> ListTicketsAsync(Guid userId, CancellationToken ct = default);
    // [PIM-WEB Admin] Lista todos os ingressos vendidos, para a área admin.
    Task<List<Ticket>> ListAllTicketsAsync(CancellationToken ct = default);
    // [PIM-WEB Cartão 4] Consultas de assentos: lista os ocupados, confere se um assento está tomado e libera reservas vencidas.
    Task<List<TakenSeat>> ListTakenSeatsAsync(int matchId, Sector sector, DateTime now, CancellationToken ct = default);
    Task<bool> IsSeatTakenAsync(int matchId, Sector sector, int row, int number, DateTime now, CancellationToken ct = default);
    /// <summary>Cancela a reserva pendente da PRÓPRIA pessoa para este assento (ex.: errou o código e tenta de novo).</summary>
    Task CancelOwnPendingSeatIntentsAsync(Guid userId, int matchId, Sector sector, int row, int number, CancellationToken ct = default);
    Task ExpireStaleSeatIntentsAsync(int matchId, Sector sector, int row, int number, DateTime now, CancellationToken ct = default);
}

/// <summary>Assento indisponível: vendido (Sold = true) ou reservado por uma compra em andamento.</summary>
public record TakenSeat(int Row, int Number, bool Sold);

public interface IPasswordHasher
{
    string Hash(string password);
    bool Verify(string hash, string password);
}

public record AccessToken(string Value, int ExpiresInSeconds);

public interface ITokenService
{
    AccessToken CreateAccessToken(User user);
    /// <summary>Token opaco aleatório; só o hash SHA-256 é persistido.</summary>
    (string Plain, string Hash, DateTime ExpiresAt) CreateRefreshToken();
    string HashRefreshToken(string plain);
}

/// <summary>Protege (AES-256-GCM) o segredo do autenticador guardado no banco.</summary>
public interface ISecretProtector
{
    byte[] Protect(string secret);
    string Unprotect(byte[] protectedData);
}

/// <summary>Gera o QR Code (SVG em data URI) a partir do texto otpauth://. Feito no servidor: o segredo não sai para serviços externos.</summary>
public interface IQrService { string ToSvgDataUri(string text); }

public record CaptchaChallenge(string Id, string ImageDataUri);

/// <summary>Captcha próprio: imagem SVG gerada pela API, resposta guardada na memória por poucos minutos e de uso único.</summary>
public interface ICaptchaService
{
    bool Enabled { get; }
    CaptchaChallenge Generate();
    /// <summary>Confere e consome o desafio (vale uma única vez). Com o captcha desligado, sempre devolve true.</summary>
    bool Validate(string? id, string? answer);
}

public record ChargeRequest(decimal Amount, PaymentMethod Method, string? CardToken, string Reference, string Description);
public record ChargeResult(bool Approved, string Reference, string? PixPayload, string? DeclineReason);

/// <summary>Dados de cartão NUNCA chegam ao backend: só um token gerado pelo SDK do gateway.</summary>
public interface IPaymentGateway { Task<ChargeResult> ChargeAsync(ChargeRequest request, CancellationToken ct = default); }

public class PaymentPolicy
{
    /// <summary>Tentativas de código MFA por compra antes de a compra ser cancelada.</summary>
    public int MaxConfirmAttemptsPerIntent { get; set; } = 5;
}

// [PIM-WEB Cartão 7] Portão da fila virtual: com a fila ligada, só compra quem foi liberado para a partida.
public interface IQueueGate
{
    bool Enabled { get; }
    bool IsAdmitted(Guid userId, int matchId);
}