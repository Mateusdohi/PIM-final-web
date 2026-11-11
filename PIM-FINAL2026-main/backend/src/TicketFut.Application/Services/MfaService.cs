using System.Security.Cryptography;
using System.Text;
using TicketFut.Application.Abstractions;
using TicketFut.Application.Common;
using TicketFut.Application.Contracts;
using TicketFut.Domain.Entities;
using TicketFut.Domain.Rules;

namespace TicketFut.Application.Services;

/// <summary>
/// MFA por aplicativo autenticador (TOTP, RFC 6238): ativação com QR Code + chave em texto, códigos de recuperação,
/// desativação e geração de novos códigos (ambas exigem a senha atual) e conferência do código na hora do pagamento.
/// </summary>
public class MfaService
{
    private const string Issuer = "TicketFut";
    private const int RecoveryCodeCount = 8;
    private const string RecoveryAlphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";   // sem 0/O/1/I

    private readonly IUserRepository _users;
    private readonly IMfaRecoveryRepository _recovery;
    private readonly ISecretProtector _protector;
    private readonly IQrService _qr;
    private readonly IPasswordHasher _hasher;
    private readonly IUnitOfWork _uow;
    private readonly IClock _clock;

    public MfaService(IUserRepository users, IMfaRecoveryRepository recovery, ISecretProtector protector, IQrService qr,
        IPasswordHasher hasher, IUnitOfWork uow, IClock clock)
    {
        _users = users; _recovery = recovery; _protector = protector; _qr = qr; _hasher = hasher; _uow = uow; _clock = clock;
    }

    public async Task<MfaStatusDto> StatusAsync(Guid userId, CancellationToken ct)
    {
        var user = await LoadAsync(userId, ct);
        var left = user.MfaEnabled ? (await _recovery.ListUnusedAsync(userId, ct)).Count : 0;
        return new MfaStatusDto(user.MfaEnabled, left);
    }

    /// <summary>
    /// Passo 1: gera um segredo novo e devolve o mesmo valor como texto (Base32), como otpauth:// e como QR Code.
    /// O MFA só passa a valer depois que o usuário digita um código correto (passo 2).
    /// </summary>
    public async Task<MfaSetupDto> BeginSetupAsync(Guid userId, CancellationToken ct)
    {
        var user = await LoadAsync(userId, ct);
        if (user.MfaEnabled)
            throw AppException.Conflict("mfa_already_enabled", "O autenticador já está ativado. Desative-o antes de configurar outro.");

        var secret = Totp.GenerateSecret();
        user.MfaSecretProtected = _protector.Protect(secret);
        user.MfaLastStep = 0;
        await _uow.SaveChangesAsync(ct);

        var uri = Totp.BuildUri(Issuer, user.Email, secret);
        return new MfaSetupDto(FormatSecret(secret), uri, _qr.ToSvgDataUri(uri));
    }

    /// <summary>Passo 2: confere o primeiro código, ativa o MFA e entrega os códigos de recuperação (única vez em que aparecem).</summary>
    public async Task<MfaRecoveryCodesDto> EnableAsync(Guid userId, string? code, CancellationToken ct)
    {
        var user = await LoadAsync(userId, ct);
        if (user.MfaEnabled)
            throw AppException.Conflict("mfa_already_enabled", "O autenticador já está ativado.");
        if (user.MfaSecretProtected is null)
            throw AppException.Conflict("mfa_not_started", "Gere o QR Code antes de confirmar o código.");

        var secret = _protector.Unprotect(user.MfaSecretProtected);
        if (!Totp.Verify(secret, code, _clock.UtcNow, user.MfaLastStep, out var step))
            throw AppException.Validation("mfa_invalid_code", "Código incorreto. Confira o código de 6 dígitos no aplicativo e a hora do celular.");

        user.MfaEnabled = true;
        user.MfaEnabledAt = _clock.UtcNow;
        user.MfaLastStep = step;
        var codes = NewRecoveryCodes();
        await _recovery.ReplaceAllAsync(userId, codes.Select(HashRecovery), ct);
        await _uow.SaveChangesAsync(ct);
        return new MfaRecoveryCodesDto(codes);
    }

    /// <summary>Desativa o MFA. Exige a senha atual; apaga o segredo e os códigos de recuperação.</summary>
    public async Task DisableAsync(Guid userId, string? password, CancellationToken ct)
    {
        var user = await LoadAsync(userId, ct);
        RequirePassword(user, password);
        user.MfaEnabled = false;
        user.MfaSecretProtected = null;
        user.MfaLastStep = 0;
        user.MfaEnabledAt = null;
        await _recovery.DeleteAllAsync(userId, ct);
        await _uow.SaveChangesAsync(ct);
    }

    /// <summary>Gera 8 códigos de recuperação novos (os antigos deixam de valer). Exige a senha atual.</summary>
    public async Task<MfaRecoveryCodesDto> RegenerateRecoveryCodesAsync(Guid userId, string? password, CancellationToken ct)
    {
        var user = await LoadAsync(userId, ct);
        if (!user.MfaEnabled)
            throw AppException.Conflict("mfa_not_enabled", "Ative o autenticador primeiro.");
        RequirePassword(user, password);
        var codes = NewRecoveryCodes();
        await _recovery.ReplaceAllAsync(userId, codes.Select(HashRecovery), ct);
        await _uow.SaveChangesAsync(ct);
        return new MfaRecoveryCodesDto(codes);
    }

    /// <summary>
    /// Usado no pagamento: aceita o código de 6 dígitos do autenticador ou um código de recuperação.
    /// Códigos de recuperação valem uma vez. O código do app nunca vale para um passo de tempo mais antigo que o último aceito;
    /// com <paramref name="allowSameStep"/> ele pode repetir dentro do mesmo passo de 30 s (várias compras do carrinho com um só código).
    /// NÃO salva: quem chama salva junto com o resto da operação.
    /// </summary>
    public async Task<bool> VerifyAsync(User user, string? code, CancellationToken ct, bool allowSameStep = false)
    {
        if (!user.MfaEnabled || user.MfaSecretProtected is null) return false;
        var typed = (code ?? "").Trim();
        if (typed.Length == 0 || typed.Length > 32) return false;

        var digits = new string(typed.Where(char.IsDigit).ToArray());
        if (digits.Length == Totp.Digits && typed.All(c => char.IsDigit(c) || c == ' '))
        {
            var secret = _protector.Unprotect(user.MfaSecretProtected);
            if (Totp.Verify(secret, digits, _clock.UtcNow, allowSameStep ? user.MfaLastStep - 1 : user.MfaLastStep, out var step))
            {
                user.MfaLastStep = Math.Max(user.MfaLastStep, step);
                return true;
            }
            return false;
        }

        var hash = HashRecovery(NormalizeRecovery(typed));
        var match = (await _recovery.ListUnusedAsync(user.Id, ct)).FirstOrDefault(r =>
            CryptographicOperations.FixedTimeEquals(Encoding.ASCII.GetBytes(r.CodeHash), Encoding.ASCII.GetBytes(hash)));
        if (match is null) return false;
        match.UsedAt = _clock.UtcNow;
        return true;
    }

    // ---- auxiliares ----

    private async Task<User> LoadAsync(Guid userId, CancellationToken ct) =>
        await _users.GetByIdAsync(userId, ct) ?? throw AppException.NotFound("Usuário não encontrado.");

    // Senha errada devolve 403 (não 401), para o app/site não achar que o login expirou.
    private void RequirePassword(User user, string? password)
    {
        if (string.IsNullOrEmpty(password) || password.Length > 128 || !_hasher.Verify(user.PasswordHash, password))
            throw AppException.Forbidden("invalid_password", "Senha incorreta.");
    }

    /// <summary>Mostra o segredo em grupos de 4 letras para facilitar a digitação (o autenticador ignora os espaços).</summary>
    private static string FormatSecret(string secret) =>
        string.Join(" ", Enumerable.Range(0, (secret.Length + 3) / 4).Select(i => secret.Substring(i * 4, Math.Min(4, secret.Length - i * 4))));

    private static List<string> NewRecoveryCodes()
    {
        var list = new List<string>(RecoveryCodeCount);
        for (var i = 0; i < RecoveryCodeCount; i++)
        {
            var chars = new char[8];
            for (var k = 0; k < chars.Length; k++) chars[k] = RecoveryAlphabet[RandomNumberGenerator.GetInt32(RecoveryAlphabet.Length)];
            list.Add(new string(chars, 0, 4) + "-" + new string(chars, 4, 4));
        }
        return list;
    }

    private static string NormalizeRecovery(string text) =>
        new string(text.ToUpperInvariant().Where(char.IsLetterOrDigit).ToArray());

    private static string HashRecovery(string code) =>
        Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(NormalizeRecovery(code)))).ToLowerInvariant();
}
