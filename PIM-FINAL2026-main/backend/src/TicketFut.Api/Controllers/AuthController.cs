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
    /// <summary>Cadastro facial. multipart/form-data: selfie (arquivo) + consent (true).</summary>
    [Authorize, HttpPost("face/enroll"), EnableRateLimiting("face"), RequestSizeLimit(6 * 1024 * 1024)]
    public async Task<ActionResult<UserDto>> EnrollFace([FromForm] IFormFile selfie, [FromForm] bool consent, CancellationToken ct)
    {
        await using var ms = new MemoryStream();
        await selfie.CopyToAsync(ms, ct);
        return Ok(await _auth.EnrollFaceAsync(User.GetUserId(), ms.ToArray(), consent, ct));
    }

    /// <summary>LGPD: apaga o template facial do usuário.</summary>
    [Authorize, HttpDelete("face")]
    public async Task<IActionResult> DeleteFace(CancellationToken ct)
    {
        await _auth.DeleteFaceAsync(User.GetUserId(), ct);
        return NoContent();
    }
}
