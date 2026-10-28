using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using TicketFut.Api.Chat;

namespace TicketFut.Api.Controllers;

// [PIM-WEB Cartão 10] Chat protegido: exige login e tem limite por usuário.
// Motivo: só quem está logado usa, e ninguém abusa.
public record ChatRequest(string? Message);
// [PIM-WEB Chat] Suggestions: botões de dúvidas que o site mostra abaixo da resposta. Campo novo e opcional.
public record ChatResponse(string Reply, List<string>? Suggestions = null);

[ApiController, Authorize, Route("api/chat")]
public class ChatController : ControllerBase
{
    private readonly ChatService _chat;
    public ChatController(ChatService chat) => _chat = chat;

    [HttpPost, EnableRateLimiting("chat")]
    public ActionResult<ChatResponse> Send(ChatRequest req)
    {
        var msg = (req.Message ?? "").Trim();
        if (msg.Length == 0)
            return BadRequest(new { code = "empty_message", message = "Digite uma mensagem." });

        // [PIM-WEB Cartão 10] Valida o tamanho no servidor. Motivo: o limite do navegador pode ser contornado.
        if (msg.Length > ChatService.MaxLength)
            return BadRequest(new { code = "message_too_long", message = $"A mensagem pode ter até {ChatService.MaxLength} caracteres." });

           var r = _chat.Responder(msg);
        return Ok(new ChatResponse(r.Reply, r.Suggestions));
    }
}