-- Champions Card / TicketFut - ZERAR AS VENDAS (so para preparar a demonstracao)
-- Apaga: ingressos, pagamentos e auditoria.
-- Mantem: usuarios (logins e MFA), estadios e partidas.
-- Faca um backup antes (BACKUP DATABASE). NAO use em banco com dados reais.
-- Executar com: sqlcmd -S <servidor> -E -d <banco> -I -b -i 06-zerar-vendas-demo.sql
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;

BEGIN TRANSACTION;

-- O trigger que protege os ingressos e desligado so durante a limpeza.
DISABLE TRIGGER dbo.TR_Tickets_NaoApagar ON dbo.Tickets;
DELETE FROM dbo.Tickets;
ENABLE TRIGGER dbo.TR_Tickets_NaoApagar ON dbo.Tickets;

DELETE FROM dbo.TicketAudit;
DELETE FROM dbo.PaymentIntents;

COMMIT TRANSACTION;

SELECT (SELECT COUNT(*) FROM dbo.Tickets) AS Ingressos,
       (SELECT COUNT(*) FROM dbo.PaymentIntents) AS Pagamentos,
       (SELECT COUNT(*) FROM dbo.TicketAudit) AS Auditoria,
       (SELECT COUNT(*) FROM dbo.Users) AS UsuariosMantidos,
       (SELECT COUNT(*) FROM dbo.Users WHERE MfaEnabled = 1) AS UsuariosComMfaMantidos,
       (SELECT COUNT(*) FROM dbo.Matches) AS PartidasMantidas,
       (SELECT COUNT(*) FROM sys.triggers WHERE is_disabled = 1) AS TriggersDesligados;
