using TicketFut.Domain.Enums;

namespace TicketFut.Domain.Rules;

/// <summary>Mapa de assentos: fileiras de 1 a Rows; cada fileira tem a sua quantidade de cadeiras, conforme o estádio do mandante.</summary>
public static class SeatLayout
{
    // [PIM-WEB Visual] 12 fileiras, até 28 cadeiras por fileira. Fileira 1 é a mais próxima do gramado.
    public const int Rows = 12;
    public const int SeatsPerRow = 28;

    // [PIM-WEB Visual] Perfil de um estádio: cadeiras por fileira nos setores Norte/Sul e nos laterais (Oeste/Leste).
    private record Perfil(int[] NorteSul, int[] Lateral);

    // [PIM-WEB Visual] Um perfil por time da casa. Todos os tamanhos são pares, para as cadeiras ficarem centralizadas.
    private static readonly Dictionary<string, Perfil> Perfis = new()
    {
        // Allianz Parque: trapézio com ponta arredondada (o desenho original).
        ["palmeiras"] = new(
            new[] { 20, 20, 22, 24, 26, 26, 28, 28, 26, 26, 24, 22 },
            new[] { 20, 22, 22, 24, 24, 26, 28, 28, 24, 22, 18, 10 }),
        // Morumbis: oval. Norte e Sul longos; laterais bem curvas.
        ["sao_paulo"] = new(
            new[] { 24, 24, 26, 26, 26, 28, 28, 28, 28, 28, 28, 28 },
            new[] { 10, 12, 14, 16, 18, 20, 22, 24, 26, 26, 28, 28 }),
        // Maracanã: círculo. Os quatro setores são cunhas iguais.
        ["flamengo"] = new(
            new[] { 16, 18, 18, 20, 22, 22, 24, 24, 26, 26, 28, 28 },
            new[] { 16, 18, 18, 20, 22, 22, 24, 24, 26, 26, 28, 28 }),
        // Neo Química Arena: retângulo com as quinas levemente cortadas.
        ["corinthians"] = new(
            new[] { 26, 26, 28, 28, 28, 28, 28, 28, 28, 28, 26, 26 },
            new[] { 18, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 18 }),
        // Vila Belmiro: retângulo compacto.
        ["santos"] = new(
            new[] { 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24 },
            new[] { 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16 }),
    };

    // Estádio desconhecido usa o perfil do Palmeiras.
    private static readonly Perfil Padrao = Perfis["palmeiras"];

    private static Perfil PerfilDe(string? homeTeam) =>
        homeTeam is not null && Perfis.TryGetValue(homeTeam, out var p) ? p : Padrao;

    /// <summary>Cadeiras de cada fileira do setor no estádio do mandante, da fileira 1 em diante.</summary>
    public static IReadOnlyList<int> RowSizes(Sector sector, string? homeTeam)
    {
        var p = PerfilDe(homeTeam);
        return sector is Sector.Oeste or Sector.Leste ? p.Lateral : p.NorteSul;
    }

    // Mantido para não quebrar chamadas antigas: usa o perfil padrão.
    public static IReadOnlyList<int> RowSizes(Sector sector) => RowSizes(sector, null);

    // [PIM-WEB Visual] Valida a cadeira contra o desenho do estádio. Motivo: o servidor não aceita assento fora do formato.
    public static bool IsValid(Sector sector, string? homeTeam, int row, int number)
    {
        var sizes = RowSizes(sector, homeTeam);
        if (row < 1 || row > sizes.Count) return false;
        var margin = (SeatsPerRow - sizes[row - 1]) / 2;   // cadeiras centralizadas na fileira
        return number > margin && number <= SeatsPerRow - margin;
    }

    public static bool IsValid(Sector sector, int row, int number) => IsValid(sector, null, row, number);

    // Mantido para não quebrar chamadas antigas: valida só os limites máximos.
    public static bool IsValid(int row, int number) =>
        row is >= 1 and <= Rows && number is >= 1 and <= SeatsPerRow;
}