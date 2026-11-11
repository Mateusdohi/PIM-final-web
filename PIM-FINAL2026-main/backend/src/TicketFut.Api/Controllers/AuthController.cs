using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using TicketFut.Api.Extensions;
using TicketFut.Application.Contracts;
using TicketFut.Application.Services;

namespace TicketFut.Api.Controllers;

[ApiController]
[Route("api/auth")]
public class AuthController : ControllerBase
{
    private readonly AuthService _auth;
    public AuthController(AuthService auth) => _auth = auth;

    [HttpPost("register"), EnableRateLimiting("auth")]
    public async Task<ActionResult<AuthResponse>> Register(RegisterRequest req, CancellationToken ct) =>
        Ok(await _auth.RegisterAsync(req, ct));

    /// <summary>Gera um captcha novo (imagem SVG em data URI + id). Vale 3 minutos e uma única tentativa.</summary>
    [HttpGet("captcha"), EnableRateLimiting("captcha")]
    public ActionResult<CaptchaDto> Captcha() => Ok(_auth.NewCaptcha());

    [HttpPost("login"), EnableRateLimiting("auth")]
    public async Task<ActionResult<AuthResponse>> Login(LoginRequest req, CancellationToken ct) =>
        Ok(await _auth.LoginAsync(req, ct));

    [HttpPost("refresh"), EnableRateLimiting("auth")]
    public async Task<ActionResult<AuthResponse>> Refresh(RefreshRequest req, CancellationToken ct) =>
        Ok(await _auth.RefreshAsync(req, ct));

    [Authorize, HttpPost("logout")]
    public async Task<IActionResult> Logout(CancellationToken ct)
    {
        await _auth.LogoutAsync(User.GetUserId(), ct);
        return NoContent();
    }

    [Authorize, HttpGet("me")]
    public async Task<ActionResult<UserDto>> Me(CancellationToken ct) =>
        Ok(await _auth.GetMeAsync(User.GetUserId(), ct));

    // [PIM-WEB Perfil] Edita nome e time do próprio usuário.
    [Authorize, HttpPut("me")]
    public async Task<ActionResult<UserDto>> UpdateMe(UpdateProfileRequest req, CancellationToken ct) =>
        Ok(await _auth.UpdateProfileAsync(User.GetUserId(), req, ct));

    // [PIM-WEB Perfil] Troca de senha. Mesmo limite do login (10 por minuto por IP): impede tentar a senha atual várias vezes.
    [Authorize, HttpPost("change-password"), EnableRateLimiting("auth")]
    public async Task<IActionResult> ChangePassword(ChangePasswordRequest req, CancellationToken ct)
    {
        await _auth.ChangePasswordAsync(User.GetUserId(), req, ct);
        return NoContent();
    }
}

/// <summary>MFA por aplicativo autenticador (TOTP): ativação, desativação e códigos de recuperação.</summary>
[ApiController, Authorize, Route("api/mfa")]
public class MfaController : ControllerBase
{
    private readonly MfaService _mfa;
    public MfaController(MfaService mfa) => _mfa = mfa;

    [HttpGet("status")]
    public async Task<ActionResult<MfaStatusDto>> Status(CancellationToken ct) =>
        Ok(await _mfa.StatusAsync(User.GetUserId(), ct));

    /// <summary>Gera o segredo e devolve a chave em texto, o endereço otpauth:// e o QR Code (SVG). Só vale depois de confirmar um código.</summary>
    [HttpPost("setup"), EnableRateLimiting("auth")]
    public async Task<ActionResult<MfaSetupDto>> Setup(CancellationToken ct) =>
        Ok(await _mfa.BeginSetupAsync(User.GetUserId(), ct));

    /// <summary>Confirma o primeiro código, ativa o MFA e devolve os códigos de recuperação (aparecem só agora).</summary>
    [HttpPost("enable"), EnableRateLimiting("auth")]
    public async Task<ActionResult<MfaRecoveryCodesDto>> Enable(MfaCodeRequest req, CancellationToken ct) =>
        Ok(await _mfa.EnableAsync(User.GetUserId(), req.Code, ct));

    /// <summary>Desativa o MFA. Exige a senha atual.</summary>
    [HttpPost("disable"), EnableRateLimiting("auth")]
    public async Task<IActionResult> Disable(MfaPasswordRequest req, CancellationToken ct)
    {
        await _mfa.DisableAsync(User.GetUserId(), req.Password, ct);
        return NoContent();
    }

    /// <summary>Gera novos códigos de recuperação (os antigos deixam de valer). Exige a senha atual.</summary>
    [HttpPost("recovery-codes"), EnableRateLimiting("auth")]
    public async Task<ActionResult<MfaRecoveryCodesDto>> RecoveryCodes(MfaPasswordRequest req, CancellationToken ct) =>
        Ok(await _mfa.RegenerateRecoveryCodesAsync(User.GetUserId(), req.Password, ct));
}
