namespace TicketFut.Application.Contracts;

public record RegisterRequest(string Name, string Cpf, string Email, string Password, string Team);
public record LoginRequest(string Email, string Password, string? CaptchaId = null, string? CaptchaAnswer = null);
public record CaptchaDto(string CaptchaId, string Image);
public record RefreshRequest(string RefreshToken);
// [PIM-WEB Perfil] Edição do próprio perfil. Só nome e time; e-mail, CPF, plano e papel não mudam por aqui.
public record UpdateProfileRequest(string Name, string Team);
public record ChangePasswordRequest(string CurrentPassword, string NewPassword);

// [PIM-WEB Cartão 3] Campo Role acrescentado: o site usa para mostrar ou esconder a área administrativa.
public record UserDto(Guid Id, string Name, string Email, string Team, int PlanPercent, string PlanName, string? MemberCode, bool MfaEnabled, string Role);
public record AuthResponse(string AccessToken, string RefreshToken, int ExpiresInSeconds, UserDto User);

public record SubscribeRequest(int Plan, string Method, string? CardToken);
public record SubscribeResponse(UserDto User, string MemberCode, string? PixPayload);

public record StadiumDto(string Name, string City, double Latitude, double Longitude);
public record MatchDto(
    int Id, string HomeTeam, string AwayTeam, string HomeName, string AwayName,
    DateTime KickoffAt, string Status, decimal BasePrice, decimal Price, int DiscountPercent,
    bool IsAway, StadiumDto Stadium);
public record SectorDto(string Sector, bool Available, string? Reason);
// [PIM-WEB Cartão 4] Mapa de assentos: só os OCUPADOS são devolvidos (sold = vendido, held = reservado por 10 min). O resto está livre.
public record SeatDto(int Row, int Number, string Status);
// [PIM-WEB Visual] RowSizes: cadeiras de cada fileira (fileira 1 primeiro). Campo novo e opcional: o app mobile ignora.
public record SeatMapDto(string Sector, int Rows, int SeatsPerRow, bool Available, string? Reason, List<SeatDto> Taken, List<int>? RowSizes = null);// [PIM-WEB Cartão 4] SeatRow e SeatNumber são opcionais: o app mobile continua comprando só por setor.
public record CreateIntentRequest(int MatchId, string Sector, string Method, string? MemberCode, int? SeatRow = null, int? SeatNumber = null);
public record IntentDto(Guid IntentId, string Nonce, decimal Amount, decimal OriginalAmount, int DiscountPercent, DateTime ExpiresAt, string Method);

// [PIM-WEB Cartão 4] O ingresso passa a informar o assento (quando houver).
public record TicketDto(Guid Id, int MatchId, string MatchName, string Sector, string Code, decimal Amount, DateTime KickoffAt, DateTime IssuedAt, int? SeatRow = null, int? SeatNumber = null);


// [PIM-WEB Admin] DTO da área admin. Não inclui e-mail nem CPF, para expor só o necessário.
public record AdminTicketDto(Guid Id, Guid UserId, int MatchId, string MatchName, string Sector, string Code, decimal Amount, DateTime IssuedAt, int? SeatRow = null, int? SeatNumber = null);

public record ConfirmResponse(TicketDto Ticket, string? PixPayload);
// Confirmação da compra: nonce da intenção + código de 6 dígitos do autenticador (ou um código de recuperação) + token do cartão.
// O número do cartão nunca chega ao servidor.
public record ConfirmRequest(string Nonce, string Code, string? CardToken);

// ---- MFA (aplicativo autenticador) ----
public record MfaStatusDto(bool Enabled, int RecoveryCodesLeft);
/// <summary>Início da ativação: o mesmo segredo em três formas (texto, otpauth:// e QR Code em SVG).</summary>
public record MfaSetupDto(string Secret, string OtpAuthUri, string QrSvg);
public record MfaCodeRequest(string Code);
public record MfaPasswordRequest(string Password);
public record MfaRecoveryCodesDto(List<string> RecoveryCodes);

public record MatchQuery(string? Team, string? Status, string? Search);
