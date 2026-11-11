using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Configuration;
using QRCoder;
using TicketFut.Application.Abstractions;

namespace TicketFut.Infrastructure.Services;

/// <summary>QR Code em SVG gerado no servidor (offline). O texto otpauth:// contém o segredo e nunca sai para serviços externos.</summary>
public class QrService : IQrService
{
    public string ToSvgDataUri(string text)
    {
        using var gen = new QRCodeGenerator();
        using var data = gen.CreateQrCode(text, QRCodeGenerator.ECCLevel.M);
        var svg = new SvgQRCode(data).GetGraphic(new System.Drawing.Size(220, 220), "#000000", "#ffffff", drawQuietZones: true, SvgQRCode.SizingMode.ViewBoxAttribute);
        return "data:image/svg+xml;base64," + Convert.ToBase64String(Encoding.UTF8.GetBytes(svg));
    }
}

/// <summary>
/// Captcha próprio: 5 caracteres sem formas ambíguas (sem 0/O, 1/I/L), desenhados em fonte matricial (sem texto no SVG), rotacionados, coloridos e com ruído.
/// A resposta fica só na memória do servidor por 3 minutos e cada desafio vale uma única tentativa (maiúsculas/minúsculas tanto faz).
/// Desligue com Captcha:Enabled = false (testes automáticos).
/// </summary>
public class CaptchaService : ICaptchaService
{
    private const string Alphabet = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
    private const int Length = 5;
    private static readonly TimeSpan Lifetime = TimeSpan.FromMinutes(3);
    private static readonly string[] Colors = { "#1b4332", "#7b2cbf", "#9d0208", "#0b3c5d", "#a34700", "#264653" };

    private readonly IMemoryCache _cache;
    public bool Enabled { get; }

    public CaptchaService(IMemoryCache cache, IConfiguration config)
    {
        _cache = cache;
        Enabled = config.GetValue("Captcha:Enabled", true);
    }

    public CaptchaChallenge Generate()
    {
        var id = Convert.ToHexString(RandomNumberGenerator.GetBytes(16)).ToLowerInvariant();
        var answer = new string(Enumerable.Range(0, Length).Select(_ => Alphabet[RandomNumberGenerator.GetInt32(Alphabet.Length)]).ToArray());
        _cache.Set("captcha:" + id, answer, Lifetime);
        return new CaptchaChallenge(id, "data:image/svg+xml;base64," + Convert.ToBase64String(Encoding.UTF8.GetBytes(Render(answer))));
    }

    public bool Validate(string? id, string? answer)
    {
        if (!Enabled) return true;
        if (string.IsNullOrWhiteSpace(id) || string.IsNullOrWhiteSpace(answer) || id.Length > 64) return false;
        var key = "captcha:" + id;
        if (!_cache.TryGetValue(key, out string? expected) || expected is null) return false;
        _cache.Remove(key);   // uso único: errou, precisa de uma imagem nova
        var typed = answer.Trim().ToUpperInvariant();
        return CryptographicOperations.FixedTimeEquals(Encoding.ASCII.GetBytes(expected), Encoding.ASCII.GetBytes(typed));
    }

    private static int Rnd(int min, int max) => RandomNumberGenerator.GetInt32(min, max + 1);
    private static string F(double v) => v.ToString("0.#", CultureInfo.InvariantCulture);

    // Fonte matricial 5x7 própria: as letras são desenhadas com quadradinhos (nenhum texto legível no SVG),
    // então um robô não consegue ler a resposta no código da imagem; precisa reconhecer o desenho.
    private static readonly Dictionary<char, string[]> Glyphs = new string[]
    {
        "A:.###.|#...#|#...#|#####|#...#|#...#|#...#",
        "B:####.|#...#|#...#|####.|#...#|#...#|####.",
        "C:.###.|#...#|#....|#....|#....|#...#|.###.",
        "D:####.|#...#|#...#|#...#|#...#|#...#|####.",
        "E:#####|#....|#....|####.|#....|#....|#####",
        "F:#####|#....|#....|####.|#....|#....|#....",
        "G:.###.|#...#|#....|#.###|#...#|#...#|.###.",
        "H:#...#|#...#|#...#|#####|#...#|#...#|#...#",
        "J:..###|...#.|...#.|...#.|...#.|#..#.|.##..",
        "K:#...#|#..#.|#.#..|##...|#.#..|#..#.|#...#",
        "M:#...#|##.##|#.#.#|#.#.#|#...#|#...#|#...#",
        "N:#...#|##..#|#.#.#|#..##|#...#|#...#|#...#",
        "P:####.|#...#|#...#|####.|#....|#....|#....",
        "Q:.###.|#...#|#...#|#...#|#.#.#|#..#.|.##.#",
        "R:####.|#...#|#...#|####.|#.#..|#..#.|#...#",
        "S:.####|#....|#....|.###.|....#|....#|####.",
        "T:#####|..#..|..#..|..#..|..#..|..#..|..#..",
        "U:#...#|#...#|#...#|#...#|#...#|#...#|.###.",
        "V:#...#|#...#|#...#|#...#|#...#|.#.#.|..#..",
        "W:#...#|#...#|#...#|#.#.#|#.#.#|##.##|#...#",
        "X:#...#|#...#|.#.#.|..#..|.#.#.|#...#|#...#",
        "Y:#...#|#...#|.#.#.|..#..|..#..|..#..|..#..",
        "Z:#####|....#|...#.|..#..|.#...|#....|#####",
        "2:.###.|#...#|....#|...#.|..#..|.#...|#####",
        "3:####.|....#|....#|.###.|....#|....#|####.",
        "4:...#.|..##.|.#.#.|#..#.|#####|...#.|...#.",
        "5:#####|#....|####.|....#|....#|#...#|.###.",
        "6:.###.|#....|#....|####.|#...#|#...#|.###.",
        "7:#####|....#|...#.|..#..|.#...|.#...|.#...",
        "8:.###.|#...#|#...#|.###.|#...#|#...#|.###.",
        "9:.###.|#...#|#...#|.####|....#|....#|.###.",
    }.ToDictionary(l => l[0], l => l[2..].Split('|'));

    private static string Render(string text)
    {
        const int w = 190, h = 64;
        const double cell = 5.2;
        var sb = new StringBuilder();
        sb.Append($"<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"{w}\" height=\"{h}\" viewBox=\"0 0 {w} {h}\">");
        sb.Append($"<rect width=\"{w}\" height=\"{h}\" rx=\"8\" fill=\"#f1f5f9\"/>");
        for (var i = 0; i < 6; i++)   // linhas de ruído por trás
            sb.Append($"<line x1=\"{Rnd(0, w)}\" y1=\"{Rnd(0, h)}\" x2=\"{Rnd(0, w)}\" y2=\"{Rnd(0, h)}\" stroke=\"{Colors[Rnd(0, Colors.Length - 1)]}\" stroke-opacity=\"0.35\" stroke-width=\"{Rnd(1, 2)}\"/>");
        // Cada quadradinho vira um polígono com a rotação/inclinação do caractere já aplicada às coordenadas,
        // e todos são embaralhados: não há grade nem agrupamento por letra no código da imagem.
        var shapes = new List<string>();
        for (var i = 0; i < text.Length; i++)
        {
            var color = Colors[Rnd(0, Colors.Length - 1)];
            var cx = 12 + i * 33 + Rnd(-2, 2);
            var cy = 14 + Rnd(-4, 4);
            var rot = Rnd(-16, 16) * Math.PI / 180.0;
            var skew = Math.Tan(Rnd(-10, 10) * Math.PI / 180.0);
            var rows = Glyphs[text[i]];
            (double X, double Y) Map(double px, double py)
            {
                var x = px + skew * py;                       // inclinação
                double dx = x - 13, dy = py - 18;             // rotação em torno do centro do caractere
                return (cx + 13 + dx * Math.Cos(rot) - dy * Math.Sin(rot), cy + 18 + dx * Math.Sin(rot) + dy * Math.Cos(rot));
            }
            for (var r = 0; r < rows.Length; r++)
                for (var c = 0; c < rows[r].Length; c++)
                {
                    if (rows[r][c] != '#') continue;
                    var sz = cell - 0.3 + Rnd(0, 6) / 10.0;
                    double x0 = c * cell + Rnd(-4, 4) / 10.0, y0 = r * cell + Rnd(-4, 4) / 10.0;
                    var a = Map(x0, y0); var b = Map(x0 + sz, y0); var d = Map(x0 + sz, y0 + sz); var e = Map(x0, y0 + sz);
                    shapes.Add($"<polygon points=\"{F(a.X)},{F(a.Y)} {F(b.X)},{F(b.Y)} {F(d.X)},{F(d.Y)} {F(e.X)},{F(e.Y)}\" fill=\"{color}\"/>");
                }
        }
        for (var k = shapes.Count - 1; k > 0; k--)   // embaralha (Fisher-Yates)
        {
            var m = RandomNumberGenerator.GetInt32(k + 1);
            (shapes[k], shapes[m]) = (shapes[m], shapes[k]);
        }
        foreach (var sh in shapes) sb.Append(sh);
        for (var i = 0; i < 3; i++)   // curvas por cima, atrapalham leitores automáticos
        {
            sb.Append($"<path d=\"M{Rnd(0, 20)} {Rnd(10, h - 10)} Q{Rnd(50, 90)} {Rnd(0, h)} {Rnd(100, 130)} {Rnd(10, h - 10)} T{w} {Rnd(10, h - 10)}\" fill=\"none\" stroke=\"{Colors[Rnd(0, Colors.Length - 1)]}\" stroke-opacity=\"0.55\" stroke-width=\"1.6\"/>");
        }
        for (var i = 0; i < 30; i++)
            sb.Append($"<circle cx=\"{Rnd(0, w)}\" cy=\"{Rnd(0, h)}\" r=\"{F(Rnd(5, 12) / 10.0)}\" fill=\"{Colors[Rnd(0, Colors.Length - 1)]}\" fill-opacity=\"0.5\"/>");
        sb.Append("</svg>");
        return sb.ToString();
    }
}
