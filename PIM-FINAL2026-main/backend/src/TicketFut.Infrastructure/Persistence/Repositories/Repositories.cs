using Microsoft.EntityFrameworkCore;
using TicketFut.Application.Abstractions;
using TicketFut.Application.Common;
using TicketFut.Domain.Entities;
using TicketFut.Domain.Enums;
namespace TicketFut.Infrastructure.Persistence.Repositories;

public class UnitOfWork : IUnitOfWork
{
    private readonly AppDbContext _db;
    public UnitOfWork(AppDbContext db) => _db = db;
        public async Task SaveChangesAsync(CancellationToken ct = default)
    {
        try { await _db.SaveChangesAsync(ct); }
        // [PIM-WEB Cartão 4] Violação de índice único (SQL Server 2601/2627) vira erro 409 em vez de 500.
        catch (DbUpdateException ex) when (ex.InnerException is Microsoft.Data.SqlClient.SqlException { Number: 2601 or 2627 })
        {
            // violação de índice único (duas pessoas ao mesmo tempo): vira 409 em vez de 500
            throw AppException.Conflict("conflict", "Esse registro acabou de ser criado por outra pessoa. Tente novamente.");
        }
    }
}

public class UserRepository : IUserRepository
{
    private readonly AppDbContext _db;
    public UserRepository(AppDbContext db) => _db = db;

    public Task<User?> GetByIdAsync(Guid id, CancellationToken ct = default) =>
        _db.Users.FirstOrDefaultAsync(u => u.Id == id, ct);

    public Task<User?> GetByEmailAsync(string email, CancellationToken ct = default) =>
        _db.Users.FirstOrDefaultAsync(u => u.Email == email, ct);

    public Task<bool> CpfExistsAsync(string cpf, CancellationToken ct = default) =>
        _db.Users.AnyAsync(u => u.Cpf == cpf, ct);

    public Task<bool> MemberCodeExistsAsync(string code, CancellationToken ct = default) =>
        _db.Users.AnyAsync(u => u.MemberCode == code, ct);

    public async Task AddAsync(User user, CancellationToken ct = default) => await _db.Users.AddAsync(user, ct);
}

public class FaceTemplateRepository : IFaceTemplateRepository
{
    private readonly AppDbContext _db;
    public FaceTemplateRepository(AppDbContext db) => _db = db;

    public Task<FaceTemplate?> GetByUserAsync(Guid userId, CancellationToken ct = default) =>
        _db.FaceTemplates.FirstOrDefaultAsync(f => f.UserId == userId, ct);

    public async Task UpsertAsync(FaceTemplate template, CancellationToken ct = default)
    {
        var existing = await GetByUserAsync(template.UserId, ct);
        if (existing is null) { await _db.FaceTemplates.AddAsync(template, ct); return; }
        existing.EncryptedEmbedding = template.EncryptedEmbedding;
        existing.ModelVersion = template.ModelVersion;
        existing.ConsentAt = template.ConsentAt;
        existing.CreatedAt = DateTime.UtcNow;
    }

    public async Task DeleteByUserAsync(Guid userId, CancellationToken ct = default)
    {
        var existing = await GetByUserAsync(userId, ct);
        if (existing is not null) _db.FaceTemplates.Remove(existing);
    }
}

public class RefreshTokenRepository : IRefreshTokenRepository
{
    private readonly AppDbContext _db;
    public RefreshTokenRepository(AppDbContext db) => _db = db;

    public async Task AddAsync(RefreshToken token, CancellationToken ct = default) =>
        await _db.RefreshTokens.AddAsync(token, ct);

    public Task<RefreshToken?> GetByHashAsync(string hash, CancellationToken ct = default) =>
        _db.RefreshTokens.FirstOrDefaultAsync(t => t.TokenHash == hash, ct);

    public async Task RevokeAllForUserAsync(Guid userId, DateTime now, CancellationToken ct = default)
    {
        var active = await _db.RefreshTokens.Where(t => t.UserId == userId && t.RevokedAt == null).ToListAsync(ct);
        foreach (var t in active) t.RevokedAt = now;
    }
}

public class MatchRepository : IMatchRepository
{
    private readonly AppDbContext _db;
    public MatchRepository(AppDbContext db) => _db = db;

    public Task<List<Match>> ListAsync(CancellationToken ct = default) =>
        _db.Matches.AsNoTracking().Include(m => m.Stadium).OrderBy(m => m.KickoffAt).ToListAsync(ct);

    public Task<Match?> GetAsync(int id, CancellationToken ct = default) =>
        _db.Matches.AsNoTracking().Include(m => m.Stadium).FirstOrDefaultAsync(m => m.Id == id, ct);
}

public class PaymentRepository : IPaymentRepository
{
    private readonly AppDbContext _db;
    public PaymentRepository(AppDbContext db) => _db = db;

    public async Task AddIntentAsync(PaymentIntent intent, CancellationToken ct = default) =>
        await _db.PaymentIntents.AddAsync(intent, ct);

    public Task<PaymentIntent?> GetIntentAsync(Guid id, CancellationToken ct = default) =>
        _db.PaymentIntents.Include(i => i.Match).FirstOrDefaultAsync(i => i.Id == id, ct);

    public async Task AddTicketAsync(Ticket ticket, CancellationToken ct = default) =>
        await _db.Tickets.AddAsync(ticket, ct);

    public Task<List<Ticket>> ListTicketsAsync(Guid userId, CancellationToken ct = default) =>
        _db.Tickets.AsNoTracking().Include(t => t.Match).Where(t => t.UserId == userId)
            .OrderByDescending(t => t.IssuedAt).ToListAsync(ct);

        public async Task AddFaceLogAsync(FaceVerificationLog log, CancellationToken ct = default) =>
        await _db.FaceVerificationLogs.AddAsync(log, ct);

    // [PIM-WEB Cartão 4] Assentos vendidos (ingressos) e reservados (compras em andamento que ainda não expiraram).
    public async Task<List<TakenSeat>> ListTakenSeatsAsync(int matchId, Sector sector, DateTime now, CancellationToken ct = default)
    {
        var sold = await _db.Tickets.AsNoTracking()
            .Where(t => t.MatchId == matchId && t.Sector == sector && t.SeatRow != null && t.SeatNumber != null)
            .Select(t => new { t.SeatRow, t.SeatNumber })
            .ToListAsync(ct);
        var held = await _db.PaymentIntents.AsNoTracking()
            .Where(i => i.MatchId == matchId && i.Sector == sector && i.SeatRow != null && i.SeatNumber != null
                        && i.Status == PaymentStatus.Pending && i.ExpiresAt > now)
            .Select(i => new { i.SeatRow, i.SeatNumber })
            .ToListAsync(ct);

        var result = sold.Select(s => new TakenSeat(s.SeatRow!.Value, s.SeatNumber!.Value, true)).ToList();
        result.AddRange(held.Select(h => new TakenSeat(h.SeatRow!.Value, h.SeatNumber!.Value, false)));
        return result;
    }

    // [PIM-WEB Cartão 4] Assento tomado = existe ingresso dele, ou compra paga, ou reserva ainda válida.
    public async Task<bool> IsSeatTakenAsync(int matchId, Sector sector, int row, int number, DateTime now, CancellationToken ct = default)
    {
        var sold = await _db.Tickets.AnyAsync(t =>
            t.MatchId == matchId && t.Sector == sector && t.SeatRow == row && t.SeatNumber == number, ct);
        if (sold) return true;
        return await _db.PaymentIntents.AnyAsync(i =>
            i.MatchId == matchId && i.Sector == sector && i.SeatRow == row && i.SeatNumber == number
            && (i.Status == PaymentStatus.Paid || (i.Status == PaymentStatus.Pending && i.ExpiresAt > now)), ct);
    }

    // [PIM-WEB Cartão 4] Reservas vencidas (10 min) são marcadas como Expired para liberar o assento.
    public async Task ExpireStaleSeatIntentsAsync(int matchId, Sector sector, int row, int number, DateTime now, CancellationToken ct = default)
    {
        var stale = await _db.PaymentIntents
            .Where(i => i.MatchId == matchId && i.Sector == sector && i.SeatRow == row && i.SeatNumber == number
                        && i.Status == PaymentStatus.Pending && i.ExpiresAt <= now)
            .ToListAsync(ct);
        foreach (var i in stale) i.Status = PaymentStatus.Expired;
    }
}
