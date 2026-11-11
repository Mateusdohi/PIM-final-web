using TicketFut.Domain.Rules;
using Xunit;

namespace TicketFut.Domain.Tests;

public class TotpTests
{
    // Segredo de teste da RFC 6238 ("12345678901234567890") em Base32.
    private const string Rfc = "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ";

    // Valores da RFC 6238 (tabela do apêndice B, HMAC-SHA1), reduzidos aos 6 últimos dígitos.
    [Theory]
    [InlineData(59L, "287082")]
    [InlineData(1111111109L, "081804")]
    [InlineData(1111111111L, "050471")]
    [InlineData(1234567890L, "005924")]
    [InlineData(2000000000L, "279037")]
    public void Compute_matches_rfc6238_vectors(long unixSeconds, string expected) =>
        Assert.Equal(expected, Totp.Compute(Rfc, unixSeconds / Totp.StepSeconds));

    [Fact]
    public void Base32_round_trip()
    {
        var bytes = new byte[] { 1, 2, 3, 250, 251, 252, 0, 77, 78, 79 };
        Assert.Equal(bytes, Totp.Base32Decode(Totp.Base32Encode(bytes)));
    }

    [Fact]
    public void GenerateSecret_has_32_base32_chars_and_is_random()
    {
        var a = Totp.GenerateSecret();
        var b = Totp.GenerateSecret();
        Assert.Equal(32, a.Length);
        Assert.NotEqual(a, b);
        Assert.Matches("^[A-Z2-7]+$", a);
    }

    [Fact]
    public void Verify_accepts_current_and_adjacent_steps_only()
    {
        var now = new DateTime(2026, 11, 10, 15, 0, 10, DateTimeKind.Utc);
        var step = Totp.StepFor(now);
        Assert.True(Totp.Verify(Rfc, Totp.Compute(Rfc, step), now, 0, out var m1));
        Assert.Equal(step, m1);
        Assert.True(Totp.Verify(Rfc, Totp.Compute(Rfc, step - 1), now, 0, out _));
        Assert.True(Totp.Verify(Rfc, Totp.Compute(Rfc, step + 1), now, 0, out _));
        Assert.False(Totp.Verify(Rfc, Totp.Compute(Rfc, step - 2), now, 0, out _));
        Assert.False(Totp.Verify(Rfc, Totp.Compute(Rfc, step + 2), now, 0, out _));
    }

    [Fact]
    public void Verify_rejects_reuse_of_the_same_code()
    {
        var now = new DateTime(2026, 11, 10, 15, 0, 10, DateTimeKind.Utc);
        var code = Totp.Compute(Rfc, Totp.StepFor(now));
        Assert.True(Totp.Verify(Rfc, code, now, 0, out var step));
        Assert.False(Totp.Verify(Rfc, code, now, step, out _));
    }

    [Theory]
    [InlineData("")]
    [InlineData("12345")]
    [InlineData("1234567")]
    [InlineData("abcdef")]
    public void Verify_rejects_malformed_codes(string code) =>
        Assert.False(Totp.Verify(Rfc, code, DateTime.UtcNow, 0, out _));

    [Fact]
    public void Verify_ignores_spaces_typed_by_the_user()
    {
        var now = new DateTime(2026, 11, 10, 15, 0, 10, DateTimeKind.Utc);
        var code = Totp.Compute(Rfc, Totp.StepFor(now));
        Assert.True(Totp.Verify(Rfc, code[..3] + " " + code[3..], now, 0, out _));
    }

    [Fact]
    public void BuildUri_has_the_fields_authenticators_expect()
    {
        var uri = Totp.BuildUri("TicketFut", "ana@exemplo.com", Rfc);
        Assert.StartsWith("otpauth://totp/TicketFut:ana%40exemplo.com?", uri);
        Assert.Contains("secret=" + Rfc, uri);
        Assert.Contains("issuer=TicketFut", uri);
        Assert.Contains("digits=6", uri);
        Assert.Contains("period=30", uri);
    }
}
