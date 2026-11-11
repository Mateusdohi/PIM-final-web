using System.Security.Cryptography;
using System.Text;

namespace TicketFut.Domain.Rules;

/// <summary>
/// Senha de uso único baseada em tempo (TOTP, RFC 6238): é o código de 6 dígitos que muda a cada 30 segundos
/// nos aplicativos autenticadores (Microsoft Authenticator, Google Authenticator, Authy e outros).
/// Usa HMAC-SHA1, passo de 30 s e 6 dígitos, que é o padrão aceito por todos eles.
/// </summary>
public static class Totp
{
    public const int StepSeconds = 30;
    public const int Digits = 6;
    private const string Base32Alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";

    /// <summary>Segredo aleatório de 20 bytes (160 bits) em Base32, que é o formato digitado no autenticador.</summary>
    public static string GenerateSecret() => Base32Encode(RandomNumberGenerator.GetBytes(20));

    /// <summary>Endereço otpauth://, o mesmo texto do QR Code. Contém o segredo: só deve ser mostrado ao dono da conta.</summary>
    public static string BuildUri(string issuer, string account, string secretBase32)
    {
        var label = Uri.EscapeDataString(issuer) + ":" + Uri.EscapeDataString(account);
        return $"otpauth://totp/{label}?secret={secretBase32}&issuer={Uri.EscapeDataString(issuer)}&algorithm=SHA1&digits={Digits}&period={StepSeconds}";
    }

    public static long StepFor(DateTime utc) =>
        new DateTimeOffset(DateTime.SpecifyKind(utc, DateTimeKind.Utc)).ToUnixTimeSeconds() / StepSeconds;

    /// <summary>Código de 6 dígitos do passo de tempo informado.</summary>
    public static string Compute(string secretBase32, long step)
    {
        var key = Base32Decode(secretBase32);
        var counter = BitConverter.GetBytes(step);
        if (BitConverter.IsLittleEndian) Array.Reverse(counter);
        using var hmac = new HMACSHA1(key);
        var hash = hmac.ComputeHash(counter);
        var offset = hash[^1] & 0x0F;
        var binary = ((hash[offset] & 0x7F) << 24) | (hash[offset + 1] << 16) | (hash[offset + 2] << 8) | hash[offset + 3];
        return (binary % 1_000_000).ToString().PadLeft(Digits, '0');
    }

    /// <summary>
    /// Confere o código aceitando o passo atual e um passo para cada lado (tolera até 30 s de diferença de relógio).
    /// Só aceita passos maiores que <paramref name="lastUsedStep"/>: o mesmo código não vale duas vezes.
    /// </summary>
    public static bool Verify(string secretBase32, string? code, DateTime utcNow, long lastUsedStep, out long matchedStep)
    {
        matchedStep = 0;
        var typed = new string((code ?? "").Where(char.IsDigit).ToArray());
        if (typed.Length != Digits) return false;
        var current = StepFor(utcNow);
        for (var step = current - 1; step <= current + 1; step++)
        {
            if (step <= lastUsedStep) continue;
            var expected = Compute(secretBase32, step);
            if (CryptographicOperations.FixedTimeEquals(Encoding.ASCII.GetBytes(expected), Encoding.ASCII.GetBytes(typed)))
            {
                matchedStep = step;
                return true;
            }
        }
        return false;
    }

    public static string Base32Encode(byte[] data)
    {
        var sb = new StringBuilder((data.Length * 8 + 4) / 5);
        int buffer = 0, bits = 0;
        foreach (var b in data)
        {
            buffer = (buffer << 8) | b; bits += 8;
            while (bits >= 5) { sb.Append(Base32Alphabet[(buffer >> (bits - 5)) & 31]); bits -= 5; }
        }
        if (bits > 0) sb.Append(Base32Alphabet[(buffer << (5 - bits)) & 31]);
        return sb.ToString();
    }

    public static byte[] Base32Decode(string text)
    {
        var clean = new string((text ?? "").ToUpperInvariant().Where(c => c != '=' && c != ' ' && c != '-').ToArray());
        var bytes = new List<byte>(clean.Length * 5 / 8);
        int buffer = 0, bits = 0;
        foreach (var c in clean)
        {
            var v = Base32Alphabet.IndexOf(c);
            if (v < 0) throw new FormatException("Segredo Base32 inválido.");
            buffer = (buffer << 5) | v; bits += 5;
            if (bits >= 8) { bytes.Add((byte)((buffer >> (bits - 8)) & 0xFF)); bits -= 8; }
        }
        return bytes.ToArray();
    }
}
