namespace TicketFut.Domain.Rules;

/// <summary>Mapa fixo de cada setor: fileiras de 1 a Rows e cadeiras de 1 a SeatsPerRow.</summary>
public static class SeatLayout
{
    public const int Rows = 10;
    public const int SeatsPerRow = 20;

    public static bool IsValid(int row, int number) =>
        row is >= 1 and <= Rows && number is >= 1 and <= SeatsPerRow;
}