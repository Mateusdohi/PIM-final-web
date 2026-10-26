using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TicketFut.Application.Contracts;
using TicketFut.Application.Services;

namespace TicketFut.Api.Controllers;

// [PIM-WEB Admin] Área administrativa. O servidor exige role Admin: sem token dá 401, usuário comum dá 403.
[ApiController, Authorize(Roles = "Admin"), Route("api/admin")]
public class AdminController : ControllerBase
{
    private readonly PaymentService _svc;
    public AdminController(PaymentService svc) => _svc = svc;

    // [PIM-WEB Admin] Lista os ingressos vendidos, sem e-mail nem CPF.
    [HttpGet("tickets")]
    public async Task<ActionResult<List<AdminTicketDto>>> Tickets(CancellationToken ct) =>
        Ok(await _svc.ListAllTicketsAsync(ct));
}