using Microsoft.AspNetCore.SignalR;

namespace TicketFut.Api.Queue;

/// <summary>[PIM-WEB Cartão 7] Roda em segundo plano: a cada segundo libera os próximos da fila e avisa só quem mudou de estado.</summary>
public class QueueWorker : BackgroundService
{
    private readonly QueueService _queue;
    private readonly IHubContext<QueueHub> _hub;
    private readonly ILogger<QueueWorker> _log;

    public QueueWorker(QueueService queue, IHubContext<QueueHub> hub, ILogger<QueueWorker> log)
    { _queue = queue; _hub = hub; _log = log; }

    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        using var timer = new PeriodicTimer(TimeSpan.FromSeconds(1));
        while (!ct.IsCancellationRequested)
        {
            try
            {
                if (!await timer.WaitForNextTickAsync(ct)) break;
                foreach (var (userId, matchId, state) in _queue.Tick())
                    await _hub.Clients.User(userId.ToString()).SendAsync("QueueUpdated", matchId, state, ct);
            }
            catch (OperationCanceledException) { break; }
            catch (Exception ex) { _log.LogError(ex, "Falha ao atualizar a fila virtual."); }
        }
    }
}
