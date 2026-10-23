using System.Collections.Concurrent;
using TicketFut.Application.Abstractions;

namespace TicketFut.Api.Queue;

// [PIM-WEB Cartão 7] Configuração da fila virtual (seção "Queue" do appsettings).
public class QueueOptions
{
    public bool Enabled { get; set; }                  // desligada por padrão: o app mobile compra sem fila
    public int MaxActive { get; set; } = 100;          // quantas pessoas compram ao mesmo tempo, por partida
    public int AdmissionSeconds { get; set; } = 600;   // tempo para comprar depois de liberado
}

// [PIM-WEB Cartão 7] Estado de uma pessoa na fila. Status: waiting | admitted | expired | none.
public record QueueState(string Status, int Position, int Total, DateTime? ExpiresAt);

/// <summary>
/// [PIM-WEB Cartão 7] Fila virtual em memória, uma por partida. Quem chega entra no fim da fila;
/// a cada segundo o servidor libera os próximos enquanto houver vaga (MaxActive).
/// Quem foi liberado tem AdmissionSeconds para comprar. Reiniciar a API zera as filas.
/// </summary>
public class QueueService : IQueueGate
{
    private readonly object _lock = new();
    private readonly Dictionary<int, List<Guid>> _waiting = new();                    // fila por partida (ordem de chegada)
    private readonly Dictionary<int, Dictionary<Guid, DateTime>> _admitted = new();   // quem pode comprar e até quando
    private readonly Dictionary<(Guid, int), string> _lastSent = new();               // último estado enviado (só notifica o que mudou)
    private readonly ConcurrentDictionary<Guid, int> _connections = new();            // conexões abertas por usuário
    private readonly QueueOptions _opt;
    private readonly IClock _clock;

    public QueueService(QueueOptions opt, IClock clock) { _opt = opt; _clock = clock; }

    public bool Enabled => _opt.Enabled;

    /// <summary>Usado pelo PaymentService: com a fila desligada, todo mundo pode comprar.</summary>
    public bool IsAdmitted(Guid userId, int matchId)
    {
        if (!_opt.Enabled) return true;
        lock (_lock) return IsAdmittedLocked(userId, matchId);
    }

    public QueueState Join(Guid userId, int matchId)
    {
        if (!_opt.Enabled) return new QueueState("admitted", 0, 0, null);
        lock (_lock)
        {
            if (!IsAdmittedLocked(userId, matchId) && !WaitingList(matchId).Contains(userId))
                WaitingList(matchId).Add(userId);
            Promote(matchId);
            return StateLocked(userId, matchId);
        }
    }

    public void Leave(Guid userId, int matchId)
    {
        lock (_lock)
        {
            WaitingList(matchId).Remove(userId);
            if (_admitted.TryGetValue(matchId, out var d)) d.Remove(userId);
            _lastSent.Remove((userId, matchId));
            Promote(matchId);
        }
    }

    public QueueState GetState(Guid userId, int matchId)
    {
        lock (_lock) return StateLocked(userId, matchId);
    }

    public void Connected(Guid userId) => _connections.AddOrUpdate(userId, 1, (_, n) => n + 1);

    /// <summary>Quando a última conexão da pessoa cai (fechou a aba), ela sai das filas de espera.</summary>
    public void Disconnected(Guid userId)
    {
        var left = _connections.AddOrUpdate(userId, 0, (_, n) => Math.Max(0, n - 1));
        if (left > 0) return;
        _connections.TryRemove(userId, out _);
        lock (_lock)
        {
            foreach (var (matchId, list) in _waiting.ToList())
                if (list.Remove(userId)) { _lastSent.Remove((userId, matchId)); Promote(matchId); }
        }
    }

    /// <summary>Chamado a cada segundo: expira liberações, libera os próximos e devolve só o que mudou.</summary>
    public List<(Guid UserId, int MatchId, QueueState State)> Tick()
    {
        var changes = new List<(Guid, int, QueueState)>();
        lock (_lock)
        {
            var now = _clock.UtcNow;
            foreach (var matchId in _waiting.Keys.Union(_admitted.Keys).ToList())
            {
                if (_admitted.TryGetValue(matchId, out var adm))
                    foreach (var u in adm.Where(x => x.Value <= now).Select(x => x.Key).ToList())
                    {
                        adm.Remove(u);
                        _lastSent.Remove((u, matchId));
                        changes.Add((u, matchId, new QueueState("expired", 0, 0, null)));
                    }

                Promote(matchId);

                var people = WaitingList(matchId).ToList();
                if (_admitted.TryGetValue(matchId, out var now2)) people.AddRange(now2.Keys);
                foreach (var u in people)
                {
                    var s = StateLocked(u, matchId);
                    var key = $"{s.Status}:{s.Position}";
                    if (_lastSent.TryGetValue((u, matchId), out var last) && last == key) continue;
                    _lastSent[(u, matchId)] = key;
                    changes.Add((u, matchId, s));
                }
            }
        }
        return changes;
    }

    // ---- internos (sempre chamados com o lock) ----
    private List<Guid> WaitingList(int matchId)
    {
        if (!_waiting.TryGetValue(matchId, out var l)) _waiting[matchId] = l = new List<Guid>();
        return l;
    }

    private Dictionary<Guid, DateTime> AdmittedMap(int matchId)
    {
        if (!_admitted.TryGetValue(matchId, out var d)) _admitted[matchId] = d = new Dictionary<Guid, DateTime>();
        return d;
    }

    private bool IsAdmittedLocked(Guid userId, int matchId) =>
        _admitted.TryGetValue(matchId, out var d) && d.TryGetValue(userId, out var exp) && exp > _clock.UtcNow;

    /// <summary>Libera os próximos da fila enquanto houver vaga. Vagas ocupadas = liberados que ainda não expiraram.</summary>
    private void Promote(int matchId)
    {
        var waiting = WaitingList(matchId);
        var admitted = AdmittedMap(matchId);
        var now = _clock.UtcNow;
        while (waiting.Count > 0 && admitted.Count(x => x.Value > now) < _opt.MaxActive)
        {
            var u = waiting[0];
            waiting.RemoveAt(0);
            admitted[u] = now.AddSeconds(_opt.AdmissionSeconds);
        }
    }

    private QueueState StateLocked(Guid userId, int matchId)
    {
        var waiting = WaitingList(matchId);
        if (_admitted.TryGetValue(matchId, out var d) && d.TryGetValue(userId, out var exp) && exp > _clock.UtcNow)
            return new QueueState("admitted", 0, waiting.Count, exp);
        var idx = waiting.IndexOf(userId);
        return idx >= 0 ? new QueueState("waiting", idx + 1, waiting.Count, null)
                        : new QueueState("none", 0, waiting.Count, null);
    }
}
