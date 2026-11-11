using TicketFut.Domain.Enums;

namespace TicketFut.Domain.Entities;

public class User
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string Name { get; set; } = "";
    public string Cpf { get; set; } = "";              // somente dígitos
    public string Email { get; set; } = "";            // minúsculo
    public string PasswordHash { get; set; } = "";
    public string Team { get; set; } = Rules.Teams.Default;   // slug: palmeiras, sao_paulo...
    public MemberPlan Plan { get; set; } = MemberPlan.None;
    // [PIM-WEB Cartão 3] Papel do usuário no sistema (padrão: User). Vai dentro do token JWT.
    public string Role { get; set; } = Rules.Roles.User;
    public string? MemberCode { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    // MFA por aplicativo autenticador (TOTP). O segredo fica criptografado (AES-GCM); nunca em texto puro.
    public bool MfaEnabled { get; set; }
    public byte[]? MfaSecretProtected { get; set; }
    /// <summary>Último passo de 30 s já aceito: impede reutilizar o mesmo código.</summary>
    public long MfaLastStep { get; set; }
    public DateTime? MfaEnabledAt { get; set; }
}

/// <summary>Código de recuperação do MFA: guardamos só o hash (SHA-256); cada um vale uma vez.</summary>
public class MfaRecoveryCode
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid UserId { get; set; }
    public string CodeHash { get; set; } = "";
    public DateTime? UsedAt { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}

public class RefreshToken
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid UserId { get; set; }
    public string TokenHash { get; set; } = "";
    public DateTime ExpiresAt { get; set; }
    public DateTime? RevokedAt { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public bool IsActive(DateTime now) => RevokedAt is null && ExpiresAt > now;
}
