namespace TicketFut.Api.Controllers;

// [PIM-WEB Swagger] Formulários multipart agrupados em classes. Motivo: o Swagger não aceita [FromForm] IFormFile misturado com outros parâmetros soltos.
// Os nomes dos campos são os mesmos de antes (selfie, consent, nonce, cardToken): o contrato com o mobile não muda.
public class EnrollFaceForm
{
    public IFormFile Selfie { get; set; } = default!;
    public bool Consent { get; set; }
}

public class ConfirmForm
{
    public IFormFile Selfie { get; set; } = default!;
    public string Nonce { get; set; } = "";
    public string? CardToken { get; set; }
}