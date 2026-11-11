using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using TicketFut.Application.Abstractions;
using TicketFut.Infrastructure.Persistence;
using TicketFut.Infrastructure.Persistence.Repositories;
using TicketFut.Infrastructure.Services;

namespace TicketFut.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructure(this IServiceCollection services, IConfiguration config)
    {
        // [PIM-WEB Demonstração] Com Database:UseInMemory=true a API roda com banco em memória (sem SQL Server). O padrão continua sendo o SQL Server.
        if (config.GetValue<bool>("Database:UseInMemory"))
            services.AddDbContext<AppDbContext>(o => o.UseInMemoryDatabase("ticketfut-demo"));   // só para demonstração
        else
            services.AddDbContext<AppDbContext>(o => o.UseSqlServer(config.GetConnectionString("Default")));

        services.Configure<JwtOptions>(config.GetSection("Jwt"));
        services.Configure<MfaOptions>(config.GetSection("Mfa"));
        services.AddMemoryCache();

        services.AddScoped<IUnitOfWork, UnitOfWork>();
        services.AddScoped<IUserRepository, UserRepository>();
        services.AddScoped<IMfaRecoveryRepository, MfaRecoveryRepository>();
        services.AddScoped<IRefreshTokenRepository, RefreshTokenRepository>();
        services.AddScoped<IMatchRepository, MatchRepository>();
        services.AddScoped<IPaymentRepository, PaymentRepository>();

        services.AddSingleton<IClock, SystemClock>();
        services.AddSingleton<Application.Abstractions.IPasswordHasher, AspNetPasswordHasher>();
        services.AddSingleton<ITokenService, TokenService>();
        services.AddSingleton<ISecretProtector, AesSecretProtector>();
        services.AddSingleton<IQrService, QrService>();
        services.AddSingleton<ICaptchaService, CaptchaService>();
        services.AddSingleton<IPaymentGateway, SandboxPaymentGateway>();   // troque pelo gateway real

        return services;
    }
}
