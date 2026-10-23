namespace TicketFut.Domain.Rules;

/// <summary>Mapa fixo de cada setor: fileiras de 1 a Rows e cadeiras de 1 a SeatsPerRow.</summary>
public static class SeatLayout
{
    // [PIM-WEB Cartão 4] Mapa fixo: 10 fileiras de 20 cadeiras por setor (200 por setor). O banco guarda só o que foi vendido ou reservado.
    public const int Rows = 10;
    public const int SeatsPerRow = 20;

    public static bool IsValid(int row, int number) =>
        row is >= 1 and <= Rows && number is >= 1 and <= SeatsPerRow;
}