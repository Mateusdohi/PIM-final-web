using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;

namespace TicketFut.Api.Queue;

/// <summary>
/// [PIM-WEB Cartão 7] Hub do SignalR em /hubs/queue (exige login). O site chama Join(matchId) e passa a
/// receber o evento "QueueUpdated" (matchId, estado) sempre que a posição muda, sem recarregar a página.
/// </summary>
[Authorize]
public class QueueHub : Hub
{
    private readonly QueueService _queue;
    public QueueHub(QueueService queue) { _queue = queue; }

    private Guid UserId =>
        Guid.TryParse(Context.UserIdentifier, out var id) ? id : throw new HubException("Não autenticado.");

    public override Task OnConnectedAsync() { _queue.Connected(UserId); return base.OnConnectedAsync(); }

    public override Task OnDisconnectedAsync(Exception? exception) { _queue.Disconnected(UserId); return base.OnDisconnectedAsync(exception); }

    public QueueState Join(int matchId) => _queue.Join(UserId, Valid(matchId));
    public void Leave(int matchId) => _queue.Leave(UserId, Valid(matchId));
    public QueueState State(int matchId) => _queue.GetState(UserId, Valid(matchId));

    private static int Valid(int matchId) =>
        matchId is > 0 and < 1_000_000 ? matchId : throw new HubException("Partida inválida.");
}

/// <summary>[PIM-WEB Cartão 7] O SignalR identifica o usuário pelo claim "sub" do token (a API não mapeia claims).</summary>
public class SubUserIdProvider : IUserIdProvider
{
    public string? GetUserId(HubConnectionContext connection) => connection.User.FindFirst("sub")?.Value;
}
