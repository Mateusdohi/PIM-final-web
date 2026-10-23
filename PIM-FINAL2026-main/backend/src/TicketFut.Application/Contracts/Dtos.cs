namespace TicketFut.Application.Contracts;

public record RegisterRequest(string Name, string Cpf, string Email, string Password, string Team);
public record LoginRequest(string Email, string Password);
public record RefreshRequest(string RefreshToken);

// [PIM-WEB Cartão 3] Campo Role acrescentado: o site usa para mostrar ou esconder a área administrativa.
public record UserDto(Guid Id, string Name, string Email, string Team, int PlanPercent, string PlanName, string? MemberCode, bool HasFace, string Role);
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
public record SeatMapDto(string Sector, int Rows, int SeatsPerRow, bool Available, string? Reason, List<SeatDto> Taken);
// [PIM-WEB Cartão 4] SeatRow e SeatNumber são opcionais: o app mobile continua comprando só por setor.
public record CreateIntentRequest(int MatchId, string Sector, string Method, string? MemberCode, int? SeatRow = null, int? SeatNumber = null);
public record IntentDto(Guid IntentId, string Nonce, decimal Amount, decimal OriginalAmount, int DiscountPercent, DateTime ExpiresAt, string Method);

// [PIM-WEB Cartão 4] O ingresso passa a informar o assento (quando houver).
public record TicketDto(Guid Id, int MatchId, string MatchName, string Sector, string Code, decimal Amount, DateTime KickoffAt, DateTime IssuedAt, int? SeatRow = null, int? SeatNumber = null);
public record ConfirmResponse(TicketDto Ticket, string? PixPayload);
// [PIM-WEB Cartão 5] Confirmação pela web: nonce da compra, senha (reautenticação) e token do cartão. O número do cartão nunca chega ao servidor.
public record ConfirmWebRequest(string Nonce, string Password, string? CardToken);

public record MatchQuery(string? Team, string? Status, string? Search);
