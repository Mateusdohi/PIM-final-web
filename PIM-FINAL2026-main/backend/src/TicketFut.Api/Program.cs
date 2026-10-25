using System.Text;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using TicketFut.Api.Middleware;
using TicketFut.Api.Chat; // [PIM-WEB Cartão 10] Serviço do chatbot
using TicketFut.Api.Queue;
using TicketFut.Application.Abstractions;
using TicketFut.Application.Services;
using TicketFut.Infrastructure;
using TicketFut.Infrastructure.Persistence;

var builder = WebApplication.CreateBuilder(args);
var config = builder.Configuration;

// ---- Segurança: falha cedo se a configuração crítica estiver faltando ----
var jwtKey = config["Jwt:Key"];
if (string.IsNullOrWhiteSpace(jwtKey) || jwtKey.Length < 32)
    throw new InvalidOperationException("Configure Jwt:Key com 32+ caracteres (user-secrets ou variável de ambiente Jwt__Key).");
if (string.IsNullOrWhiteSpace(config["Face:EncryptionKey"]))
    throw new InvalidOperationException("Configure Face:EncryptionKey (base64, 32 bytes). Gere com: openssl rand -base64 32");

builder.Services.AddInfrastructure(config);

// ---- Application ----
builder.Services.AddSingleton(config.GetSection("Face:Policy").Get<FacePolicy>() ?? new FacePolicy());
builder.Services.AddScoped<AuthService>();
builder.Services.AddScoped<MembershipService>();
builder.Services.AddScoped<MatchService>();
builder.Services.AddScoped<PaymentService>();
// [PIM-WEB Cartão 10] Chatbot (modo simulado). Singleton porque não guarda estado.
builder.Services.AddSingleton<ChatService>();
// ---- Auth (JWT) ----
// [PIM-WEB Cartão 6] CSRF não se aplica: o token JWT vai no cabeçalho Authorization (nunca em cookie), que o navegador não envia sozinho para outros sites.
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(o =>
    {
        o.MapInboundClaims = false;   // mantém "sub" como "sub"
        o.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true, ValidIssuer = config["Jwt:Issuer"],
            ValidateAudience = true, ValidAudience = config["Jwt:Audience"],
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtKey)),
            ValidateLifetime = true, ClockSkew = TimeSpan.FromSeconds(30),
            // [PIM-WEB Cartão 3] Diz ao ASP.NET onde estão o papel e o id do usuário no token (necessário porque MapInboundClaims = false).
            RoleClaimType = "role", NameClaimType = "sub",
        };
        // [PIM-WEB Cartão 7] WebSocket não envia cabeçalhos: no SignalR o token chega na query string (só nas rotas /hubs).
        o.Events = new JwtBearerEvents
        {
            OnMessageReceived = ctx =>
            {
                var token = ctx.Request.Query["access_token"];
                if (!string.IsNullOrEmpty(token) && ctx.HttpContext.Request.Path.StartsWithSegments("/hubs"))
                    ctx.Token = token;
                return Task.CompletedTask;
            },
        };
    });
builder.Services.AddAuthorization();

// ---- Fila virtual (SignalR) ----
// [PIM-WEB Cartão 7] Fila virtual em tempo real para jogos muito disputados. Desligada por padrão (Queue:Enabled = false).
var queueOptions = config.GetSection("Queue").Get<QueueOptions>() ?? new QueueOptions();
builder.Services.AddSingleton(queueOptions);
builder.Services.AddSingleton<QueueService>();
builder.Services.AddSingleton<IQueueGate>(sp => sp.GetRequiredService<QueueService>());
builder.Services.AddSingleton<IUserIdProvider, SubUserIdProvider>();
builder.Services.AddSignalR();
builder.Services.AddHostedService<QueueWorker>();

// ---- Rate limiting (anti força-bruta em login e verificação facial) ----
builder.Services.AddRateLimiter(o =>
{
    o.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    // limite geral por IP (todas as rotas), além das políticas específicas abaixo
    // [PIM-WEB Cartão 6] Limite geral: 120 requisições por minuto por IP em todas as rotas.
    o.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(ctx =>
        RateLimitPartition.GetFixedWindowLimiter(
            ctx.Connection.RemoteIpAddress?.ToString() ?? "anon",
            _ => new FixedWindowRateLimiterOptions { PermitLimit = 120, Window = TimeSpan.FromMinutes(1) }));
    o.AddPolicy("auth", ctx => RateLimitPartition.GetFixedWindowLimiter(
        ctx.Connection.RemoteIpAddress?.ToString() ?? "anon",
        _ => new FixedWindowRateLimiterOptions { PermitLimit = 10, Window = TimeSpan.FromMinutes(1) }));
    o.AddPolicy("face", ctx => RateLimitPartition.GetFixedWindowLimiter(
        ctx.User.FindFirst("sub")?.Value ?? ctx.Connection.RemoteIpAddress?.ToString() ?? "anon",
        _ => new FixedWindowRateLimiterOptions { PermitLimit = 10, Window = TimeSpan.FromMinutes(1) }));
            // [PIM-WEB Cartão 10] Chat: 15 mensagens por minuto por usuário. Motivo: limita abuso e custo de um provedor real.
    o.AddPolicy("chat", ctx => RateLimitPartition.GetFixedWindowLimiter(
        ctx.User.FindFirst("sub")?.Value ?? ctx.Connection.RemoteIpAddress?.ToString() ?? "anon",
        _ => new FixedWindowRateLimiterOptions { PermitLimit = 15, Window = TimeSpan.FromMinutes(1) }));
});

// ---- CORS: só os sites listados em Cors:AllowedOrigins podem chamar a API pelo navegador ----
// [PIM-WEB Cartão 6] CORS: só os sites listados em Cors:AllowedOrigins podem chamar a API pelo navegador.
var allowedOrigins = config.GetSection("Cors:AllowedOrigins").Get<string[]>() ?? Array.Empty<string>();
builder.Services.AddCors(o => o.AddPolicy("web", p => p
    .WithOrigins(allowedOrigins)
    .WithHeaders("Authorization", "Content-Type", "x-requested-with", "x-signalr-user-agent")   // os dois últimos são do SignalR
    .WithMethods("GET", "POST", "PUT", "DELETE")));

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
// [PIM-WEB Cartão 3] Botão Authorize no Swagger: permite testar os endpoints protegidos colando o accessToken.
builder.Services.AddSwaggerGen(c =>
{
    c.AddSecurityDefinition("Bearer", new Microsoft.OpenApi.Models.OpenApiSecurityScheme
    {
        Name = "Authorization",
        Type = Microsoft.OpenApi.Models.SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT",
        In = Microsoft.OpenApi.Models.ParameterLocation.Header,
        Description = "Cole apenas o accessToken (sem a palavra Bearer)."
    });
    c.AddSecurityRequirement(new Microsoft.OpenApi.Models.OpenApiSecurityRequirement
    {
        {
            new Microsoft.OpenApi.Models.OpenApiSecurityScheme
            {
                Reference = new Microsoft.OpenApi.Models.OpenApiReference
                {
                    Type = Microsoft.OpenApi.Models.ReferenceType.SecurityScheme,
                    Id = "Bearer"
                }
            },
            Array.Empty<string>()
        }
    });
});
builder.Services.AddHealthChecks();

var app = builder.Build();

// ---- Banco ----
if (config.GetValue<bool>("Database:AutoCreate"))
{
    using var scope = app.Services.CreateScope();
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    var hasher = scope.ServiceProvider.GetRequiredService<TicketFut.Application.Abstractions.IPasswordHasher>();
    // Em produção prefira migrations: dotnet ef database update
    await db.Database.EnsureCreatedAsync();
    await DbSeeder.SeedAsync(db, hasher, seedDevAdmin: app.Environment.IsDevelopment());
}

// [PIM-WEB Cartão 6] Cabeçalhos que protegem o navegador do usuário: sem sniffing de tipo, sem iframe, sem cache de dados pessoais.
// ---- Cabeçalhos de segurança (valem para todas as respostas) ----
app.Use(async (ctx, next) =>
{
    var h = ctx.Response.Headers;
    h["X-Content-Type-Options"] = "nosniff";
    h["X-Frame-Options"] = "DENY";
    h["Referrer-Policy"] = "no-referrer";
    h["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()";
    if (ctx.Request.Path.StartsWithSegments("/api"))
    {
        h["Cache-Control"] = "no-store";   // respostas com token ou dados pessoais não ficam em cache
        h["Content-Security-Policy"] = "default-src 'none'; frame-ancestors 'none'";
    }
    await next();
});

app.UseMiddleware<ExceptionMiddleware>();
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}
else
{
    // [PIM-WEB Cartão 6] HTTPS: HSTS e redirecionamento ficam ativos fora do ambiente de desenvolvimento.
    app.UseHsts();              // o navegador passa a exigir HTTPS neste domínio
    app.UseHttpsRedirection();
}
app.UseCors("web");             // antes da autenticação: o preflight (OPTIONS) não leva token
app.UseAuthentication();
app.UseRateLimiter();           // depois do auth: a política "face" particiona por usuário
app.UseAuthorization();
app.MapControllers();
// [PIM-WEB Cartão 7] Endereço do hub da fila virtual (WebSocket).
app.MapHub<QueueHub>("/hubs/queue");
app.MapHealthChecks("/health");
app.Run();
