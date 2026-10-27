using TicketFut.Domain.Enums;

namespace TicketFut.Domain.Rules;

/// <summary>Mapa fixo de cada setor: fileiras de 1 a Rows; cada fileira tem a sua quantidade de cadeiras.</summary>
public static class SeatLayout
{
    // [PIM-WEB Visual] Mapa novo: 12 fileiras, até 28 cadeiras por fileira. O formato segue o desenho do estádio.
    // Fileira 1 é a mais próxima do gramado. O banco guarda só o que foi vendido ou reservado.
    public const int Rows = 12;
    public const int SeatsPerRow = 28;

    // [PIM-WEB Visual] Cadeiras por fileira. Norte e Sul: trapézio com ponta arredondada. Oeste e Leste: forma de "D".
    private static readonly int[] NorthSouth = { 20, 20, 22, 24, 26, 26, 28, 28, 26, 26, 24, 22 };
    private static readonly int[] Lateral    = { 20, 22, 22, 24, 24, 26, 28, 28, 24, 22, 18, 10 };

    /// <summary>Cadeiras de cada fileira do setor, da fileira 1 em diante.</summary>
    public static IReadOnlyList<int> RowSizes(Sector sector) =>
        sector is Sector.Oeste or Sector.Leste ? Lateral : NorthSouth;

    // [PIM-WEB Visual] Valida a cadeira contra o tamanho da fileira do setor. Motivo: o servidor não aceita assento fora do desenho.
    public static bool IsValid(Sector sector, int row, int number)
    {
        var sizes = RowSizes(sector);
        if (row < 1 || row > sizes.Count) return false;
        var size = sizes[row - 1];
        var margin = (SeatsPerRow - size) / 2;        // cadeiras centralizadas na fileira
        return number > margin && number <= SeatsPerRow - margin;
    }

    // Mantido para não quebrar chamadas antigas: valida só os limites máximos.
    public static bool IsValid(int row, int number) =>
        row is >= 1 and <= Rows && number is >= 1 and <= SeatsPerRow;
}