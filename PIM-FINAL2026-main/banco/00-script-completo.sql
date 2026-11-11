-- Champions Card / TicketFut - SCRIPT COMPLETO DO BANCO (SQL Server)
-- Cria o banco TicketFut do zero: tabelas, chaves, indices, restricoes, views, procedures e triggers.
-- E a juncao de 01-esquema.sql + 03-regras-procedures-triggers.sql.
-- Executar com: sqlcmd -S <servidor> -E -I -b -i 00-script-completo.sql
-- Os dados iniciais (estadios, partidas, admin de demonstracao) vem do DbSeeder da API.
-- ATENCAO: so para banco NOVO. Em banco que ja existe, rode apenas o 03 (ele pode repetir).

IF DB_ID(N'TicketFut') IS NULL CREATE DATABASE TicketFut;
GO
USE TicketFut;
GO

-- Champions Card / TicketFut - esquema do banco (SQL Server)
-- Escrito a partir do banco TicketFutLocal, criado pelo EF Core (EnsureCreated).
-- Banco vazio. Dados iniciais (estadios, partidas, admin) vem do DbSeeder da API.
-- Executar com: sqlcmd -S <servidor> -E -d <banco> -I -i 01-esquema.sql
-- O SET abaixo e obrigatorio: os indices filtrados exigem QUOTED_IDENTIFIER ON.

SET QUOTED_IDENTIFIER ON;
GO

CREATE TABLE Stadiums (
    Id int IDENTITY(1,1) NOT NULL,
    Name nvarchar(100) NOT NULL,
    City nvarchar(60) NOT NULL,
    TeamSlug nvarchar(30) NOT NULL,
    Latitude float NOT NULL,
    Longitude float NOT NULL,
    CONSTRAINT PK_Stadiums PRIMARY KEY (Id)
);
GO

CREATE TABLE Matches (
    Id int IDENTITY(1,1) NOT NULL,
    HomeTeam nvarchar(30) NOT NULL,
    AwayTeam nvarchar(30) NOT NULL,
    BasePrice decimal(18,2) NOT NULL,
    KickoffAt datetime2 NOT NULL,
    StadiumId int NOT NULL,
    CONSTRAINT PK_Matches PRIMARY KEY (Id),
    CONSTRAINT FK_Matches_Stadiums_StadiumId FOREIGN KEY (StadiumId) REFERENCES Stadiums (Id)
);
CREATE INDEX IX_Matches_StadiumId ON Matches (StadiumId);
GO

CREATE TABLE Users (
    Id uniqueidentifier NOT NULL,
    Name nvarchar(120) NOT NULL,
    Cpf nvarchar(11) NOT NULL,
    Email nvarchar(254) NOT NULL,
    PasswordHash nvarchar(512) NOT NULL,
    Team nvarchar(30) NOT NULL,
    [Plan] int NOT NULL,
    Role nvarchar(20) NOT NULL,
    MemberCode nvarchar(6) NULL,
    CreatedAt datetime2 NOT NULL,
    -- MFA (aplicativo autenticador, TOTP). O segredo fica criptografado (AES-GCM) pela API; nunca em texto puro.
    MfaEnabled bit NOT NULL CONSTRAINT DF_Users_MfaEnabled DEFAULT 0,
    MfaSecretProtected varbinary(max) NULL,
    MfaLastStep bigint NOT NULL CONSTRAINT DF_Users_MfaLastStep DEFAULT 0,
    MfaEnabledAt datetime2 NULL,
    CONSTRAINT PK_Users PRIMARY KEY (Id)
);
CREATE UNIQUE INDEX IX_Users_Cpf ON Users (Cpf);
CREATE UNIQUE INDEX IX_Users_Email ON Users (Email);
CREATE UNIQUE INDEX IX_Users_MemberCode ON Users (MemberCode) WHERE MemberCode IS NOT NULL;
GO

CREATE TABLE MfaRecoveryCodes (
    Id uniqueidentifier NOT NULL,
    UserId uniqueidentifier NOT NULL,
    CodeHash nvarchar(64) NOT NULL,
    UsedAt datetime2 NULL,
    CreatedAt datetime2 NOT NULL,
    CONSTRAINT PK_MfaRecoveryCodes PRIMARY KEY (Id),
    CONSTRAINT FK_MfaRecoveryCodes_Users_UserId FOREIGN KEY (UserId) REFERENCES Users (Id) ON DELETE CASCADE
);
CREATE INDEX IX_MfaRecoveryCodes_UserId ON MfaRecoveryCodes (UserId);
GO
CREATE TABLE PaymentIntents (
    Id uniqueidentifier NOT NULL,
    UserId uniqueidentifier NOT NULL,
    MatchId int NOT NULL,
    Sector nvarchar(10) NOT NULL,
    SeatRow int NULL,
    SeatNumber int NULL,
    Method nvarchar(10) NOT NULL,
    OriginalAmount decimal(18,2) NOT NULL,
    DiscountPercent int NOT NULL,
    Amount decimal(18,2) NOT NULL,
    Status nvarchar(10) NOT NULL,
    Nonce nvarchar(64) NOT NULL,
    ExpiresAt datetime2 NOT NULL,
    ConfirmAttempts int NOT NULL,
    GatewayReference nvarchar(100) NULL,
    CreatedAt datetime2 NOT NULL,
    PaidAt datetime2 NULL,
    CONSTRAINT PK_PaymentIntents PRIMARY KEY (Id),
    CONSTRAINT FK_PaymentIntents_Matches_MatchId FOREIGN KEY (MatchId) REFERENCES Matches (Id)
);
CREATE INDEX IX_PaymentIntents_UserId ON PaymentIntents (UserId);
-- Um assento so pode ter uma compra ativa (ignora compras falhas ou expiradas).
CREATE UNIQUE INDEX IX_PaymentIntents_MatchId_Sector_SeatRow_SeatNumber
    ON PaymentIntents (MatchId, Sector, SeatRow, SeatNumber)
    WHERE SeatRow IS NOT NULL AND Status <> 'Failed' AND Status <> 'Expired';
GO

CREATE TABLE RefreshTokens (
    Id uniqueidentifier NOT NULL,
    UserId uniqueidentifier NOT NULL,
    TokenHash nvarchar(64) NOT NULL,
    ExpiresAt datetime2 NOT NULL,
    RevokedAt datetime2 NULL,
    CreatedAt datetime2 NOT NULL,
    CONSTRAINT PK_RefreshTokens PRIMARY KEY (Id)
);
CREATE UNIQUE INDEX IX_RefreshTokens_TokenHash ON RefreshTokens (TokenHash);
CREATE INDEX IX_RefreshTokens_UserId ON RefreshTokens (UserId);
GO

CREATE TABLE Tickets (
    Id uniqueidentifier NOT NULL,
    PaymentIntentId uniqueidentifier NOT NULL,
    UserId uniqueidentifier NOT NULL,
    MatchId int NOT NULL,
    Sector nvarchar(10) NOT NULL,
    SeatRow int NULL,
    SeatNumber int NULL,
    Code nvarchar(20) NOT NULL,
    Amount decimal(18,2) NOT NULL,
    IssuedAt datetime2 NOT NULL,
    CONSTRAINT PK_Tickets PRIMARY KEY (Id),
    CONSTRAINT FK_Tickets_Matches_MatchId FOREIGN KEY (MatchId) REFERENCES Matches (Id)
);
CREATE UNIQUE INDEX IX_Tickets_Code ON Tickets (Code);
CREATE UNIQUE INDEX IX_Tickets_PaymentIntentId ON Tickets (PaymentIntentId);
CREATE INDEX IX_Tickets_UserId ON Tickets (UserId);
-- Um assento so pode ter um ingresso emitido.
CREATE UNIQUE INDEX IX_Tickets_MatchId_Sector_SeatRow_SeatNumber
    ON Tickets (MatchId, Sector, SeatRow, SeatNumber)
    WHERE SeatRow IS NOT NULL;
GO
GO

-- Champions Card / TicketFut - regras do banco (SQL Server)
-- Procedures, triggers, views, restricoes (CHECK) e tabela de auditoria.
--
-- Pre-requisito: 01-esquema.sql ja executado (as 8 tabelas existem).
-- Executar com: sqlcmd -S <servidor> -E -d <banco> -I -b -i 03-regras-procedures-triggers.sql
-- Pode ser executado mais de uma vez (idempotente): usa CREATE OR ALTER e IF NOT EXISTS.
--
-- Este arquivo NAO altera nenhuma tabela nem coluna usada pela API. So acrescenta:
--   1) tabela TicketAudit (auditoria de ingressos emitidos)
--   2) restricoes CHECK e chaves estrangeiras de usuario (dados validos mesmo se alguem escrever direto no banco)
--   3) views de consulta (sem CPF e sem hash de senha)
--   4) procedures de relatorio e de manutencao
--   5) triggers de regra de negocio (so na tabela Tickets)
-- Os dados seguem o padrao da API: datas em UTC, status e setor como texto.

SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

-- =====================================================================
-- 1) AUDITORIA
-- =====================================================================
IF OBJECT_ID(N'dbo.TicketAudit', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TicketAudit (
        Id bigint IDENTITY(1,1) NOT NULL,
        TicketId uniqueidentifier NOT NULL,
        UserId uniqueidentifier NOT NULL,
        MatchId int NOT NULL,
        Sector nvarchar(10) NOT NULL,
        SeatRow int NULL,
        SeatNumber int NULL,
        Amount decimal(18,2) NOT NULL,
        Action nvarchar(10) NOT NULL,
        AuditedAt datetime2 NOT NULL CONSTRAINT DF_TicketAudit_AuditedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_TicketAudit PRIMARY KEY (Id)
    );
    CREATE INDEX IX_TicketAudit_TicketId ON dbo.TicketAudit (TicketId);
END
GO

-- =====================================================================
-- 2) RESTRICOES CHECK
-- =====================================================================
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_Users_Role')
    ALTER TABLE dbo.Users ADD CONSTRAINT CK_Users_Role CHECK (Role IN (N'User', N'Admin'));
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_Users_Plan')
    ALTER TABLE dbo.Users ADD CONSTRAINT CK_Users_Plan CHECK ([Plan] IN (0, 5, 10, 20));
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_Users_Cpf')
    ALTER TABLE dbo.Users ADD CONSTRAINT CK_Users_Cpf CHECK (LEN(Cpf) = 11 AND Cpf NOT LIKE N'%[^0-9]%');

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_Matches_Times')
    ALTER TABLE dbo.Matches ADD CONSTRAINT CK_Matches_Times CHECK (HomeTeam <> AwayTeam);
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_Matches_BasePrice')
    ALTER TABLE dbo.Matches ADD CONSTRAINT CK_Matches_BasePrice CHECK (BasePrice > 0);

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_PaymentIntents_Sector')
    ALTER TABLE dbo.PaymentIntents ADD CONSTRAINT CK_PaymentIntents_Sector CHECK (Sector IN (N'Norte', N'Sul', N'Oeste', N'Leste'));
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_PaymentIntents_Method')
    ALTER TABLE dbo.PaymentIntents ADD CONSTRAINT CK_PaymentIntents_Method CHECK (Method IN (N'Credit', N'Debit', N'Pix'));
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_PaymentIntents_Status')
    ALTER TABLE dbo.PaymentIntents ADD CONSTRAINT CK_PaymentIntents_Status CHECK (Status IN (N'Pending', N'Paid', N'Failed', N'Expired'));
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_PaymentIntents_Valores')
    ALTER TABLE dbo.PaymentIntents ADD CONSTRAINT CK_PaymentIntents_Valores
        CHECK (OriginalAmount >= 0 AND Amount >= 0 AND Amount <= OriginalAmount AND DiscountPercent BETWEEN 0 AND 100);
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_PaymentIntents_Assento')
    ALTER TABLE dbo.PaymentIntents ADD CONSTRAINT CK_PaymentIntents_Assento
        CHECK ((SeatRow IS NULL AND SeatNumber IS NULL) OR (SeatRow > 0 AND SeatNumber > 0));

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_Tickets_Sector')
    ALTER TABLE dbo.Tickets ADD CONSTRAINT CK_Tickets_Sector CHECK (Sector IN (N'Norte', N'Sul', N'Oeste', N'Leste'));
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_Tickets_Amount')
    ALTER TABLE dbo.Tickets ADD CONSTRAINT CK_Tickets_Amount CHECK (Amount >= 0);
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_Tickets_Assento')
    ALTER TABLE dbo.Tickets ADD CONSTRAINT CK_Tickets_Assento
        CHECK ((SeatRow IS NULL AND SeatNumber IS NULL) OR (SeatRow > 0 AND SeatNumber > 0));
GO

-- Chaves estrangeiras de usuario (o usuario sempre existe antes do pagamento, do ingresso e do token).
-- Tickets.PaymentIntentId nao recebe FK: a API grava pagamento e ingresso no mesmo SaveChanges
-- e o Entity Framework nao garante a ordem entre os dois.
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_PaymentIntents_Users_UserId')
    ALTER TABLE dbo.PaymentIntents ADD CONSTRAINT FK_PaymentIntents_Users_UserId FOREIGN KEY (UserId) REFERENCES dbo.Users (Id);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Tickets_Users_UserId')
    ALTER TABLE dbo.Tickets ADD CONSTRAINT FK_Tickets_Users_UserId FOREIGN KEY (UserId) REFERENCES dbo.Users (Id);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_RefreshTokens_Users_UserId')
    ALTER TABLE dbo.RefreshTokens ADD CONSTRAINT FK_RefreshTokens_Users_UserId FOREIGN KEY (UserId) REFERENCES dbo.Users (Id) ON DELETE CASCADE;
GO

-- =====================================================================
-- 3) VIEWS (nao expoem CPF nem hash de senha)
-- =====================================================================
CREATE OR ALTER VIEW dbo.vw_IngressosDetalhados AS
SELECT t.Id        AS TicketId,
       t.Code      AS Codigo,
       t.IssuedAt  AS EmitidoEm,
       t.Sector    AS Setor,
       t.SeatRow   AS Fileira,
       t.SeatNumber AS Cadeira,
       t.Amount    AS Valor,
       m.Id        AS MatchId,
       m.HomeTeam  AS TimeCasa,
       m.AwayTeam  AS TimeVisitante,
       m.KickoffAt AS DataJogo,
       s.Name      AS Estadio,
       s.City      AS Cidade,
       u.Id        AS UserId,
       u.Name      AS Torcedor,
       u.Email     AS Email
FROM dbo.Tickets t
JOIN dbo.Matches m  ON m.Id = t.MatchId
JOIN dbo.Stadiums s ON s.Id = m.StadiumId
JOIN dbo.Users u    ON u.Id = t.UserId;
GO

CREATE OR ALTER VIEW dbo.vw_VendasPorPartida AS
SELECT m.Id        AS MatchId,
       m.HomeTeam  AS TimeCasa,
       m.AwayTeam  AS TimeVisitante,
       m.KickoffAt AS DataJogo,
       s.Name      AS Estadio,
       COUNT(t.Id)                  AS Ingressos,
       ISNULL(SUM(t.Amount), 0)     AS Receita,
       ISNULL(AVG(t.Amount), 0)     AS TicketMedio
FROM dbo.Matches m
JOIN dbo.Stadiums s ON s.Id = m.StadiumId
LEFT JOIN dbo.Tickets t ON t.MatchId = m.Id
GROUP BY m.Id, m.HomeTeam, m.AwayTeam, m.KickoffAt, s.Name;
GO

-- =====================================================================
-- 4) PROCEDURES
-- =====================================================================

-- Relatorio de vendas: todas as partidas ou uma so.
CREATE OR ALTER PROCEDURE dbo.sp_VendasPorPartida
    @MatchId int = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT MatchId, TimeCasa, TimeVisitante, DataJogo, Estadio, Ingressos, Receita, TicketMedio
    FROM dbo.vw_VendasPorPartida
    WHERE @MatchId IS NULL OR MatchId = @MatchId
    ORDER BY DataJogo;
END
GO

-- Ingressos de um torcedor, do mais recente para o mais antigo.
CREATE OR ALTER PROCEDURE dbo.sp_IngressosDoUsuario
    @UserId uniqueidentifier
AS
BEGIN
    SET NOCOUNT ON;
    SELECT Codigo, EmitidoEm, TimeCasa, TimeVisitante, DataJogo, Estadio, Setor, Fileira, Cadeira, Valor
    FROM dbo.vw_IngressosDetalhados
    WHERE UserId = @UserId
    ORDER BY EmitidoEm DESC;
END
GO

-- Assentos que nao podem mais ser escolhidos numa partida:
-- vendidos (ingresso emitido) e reservados (pagamento pendente que ainda nao expirou).
CREATE OR ALTER PROCEDURE dbo.sp_AssentosOcupados
    @MatchId int,
    @Sector nvarchar(10) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT Sector AS Setor, SeatRow AS Fileira, SeatNumber AS Cadeira, N'Vendido' AS Situacao
    FROM dbo.Tickets
    WHERE MatchId = @MatchId AND SeatRow IS NOT NULL AND (@Sector IS NULL OR Sector = @Sector)
    UNION ALL
    SELECT Sector, SeatRow, SeatNumber, N'Reservado'
    FROM dbo.PaymentIntents
    WHERE MatchId = @MatchId AND SeatRow IS NOT NULL AND (@Sector IS NULL OR Sector = @Sector)
      AND Status = N'Pending' AND ExpiresAt > SYSUTCDATETIME()
    ORDER BY Setor, Fileira, Cadeira;
END
GO

-- Manutencao: libera os assentos de pagamentos pendentes que passaram do prazo.
-- Faz o mesmo que a API faz ao abrir o mapa de assentos. Devolve quantas foram expiradas.
CREATE OR ALTER PROCEDURE dbo.sp_ExpirarIntencoesPendentes
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.PaymentIntents
       SET Status = N'Expired'
     WHERE Status = N'Pending' AND ExpiresAt <= SYSUTCDATETIME();
    SELECT @@ROWCOUNT AS Expiradas;
END
GO

-- Resumo da area administrativa: totais, por setor e por plano de socio.
CREATE OR ALTER PROCEDURE dbo.sp_ResumoAdmin
AS
BEGIN
    SET NOCOUNT ON;

    SELECT COUNT(*) AS Ingressos,
           ISNULL(SUM(Amount), 0) AS Receita,
           (SELECT COUNT(*) FROM dbo.Users) AS Usuarios,
           (SELECT COUNT(*) FROM dbo.PaymentIntents WHERE Status = N'Pending' AND ExpiresAt > SYSUTCDATETIME()) AS PagamentosPendentes
    FROM dbo.Tickets;

    SELECT Sector AS Setor, COUNT(*) AS Ingressos, SUM(Amount) AS Receita
    FROM dbo.Tickets
    GROUP BY Sector
    ORDER BY Receita DESC;

    SELECT CASE u.[Plan] WHEN 5 THEN N'Bronze' WHEN 10 THEN N'Prata' WHEN 20 THEN N'Ouro' ELSE N'Sem plano' END AS Plano,
           COUNT(*) AS Ingressos, SUM(t.Amount) AS Receita
    FROM dbo.Tickets t
    JOIN dbo.Users u ON u.Id = t.UserId
    GROUP BY u.[Plan]
    ORDER BY Receita DESC;
END
GO

-- =====================================================================
-- 5) TRIGGERS
-- =====================================================================

-- Todo ingresso emitido gera uma linha de auditoria.
CREATE OR ALTER TRIGGER dbo.TR_Tickets_Auditoria
ON dbo.Tickets
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.TicketAudit (TicketId, UserId, MatchId, Sector, SeatRow, SeatNumber, Amount, Action)
    SELECT Id, UserId, MatchId, Sector, SeatRow, SeatNumber, Amount, N'EMITIDO'
    FROM inserted;
END
GO

-- Ingresso emitido nao pode ser apagado.
CREATE OR ALTER TRIGGER dbo.TR_Tickets_NaoApagar
ON dbo.Tickets
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW 50001, N'Ingresso emitido nao pode ser apagado.', 1;
END
GO

-- Ingresso emitido nao pode mudar de dono, jogo, assento, codigo ou valor.
CREATE OR ALTER TRIGGER dbo.TR_Tickets_Imutavel
ON dbo.Tickets
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF UPDATE(UserId) OR UPDATE(MatchId) OR UPDATE(Sector) OR UPDATE(SeatRow) OR UPDATE(SeatNumber)
       OR UPDATE(Code) OR UPDATE(Amount) OR UPDATE(PaymentIntentId)
    BEGIN
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW 50002, N'Ingresso emitido nao pode ser alterado.', 1;
    END
END
GO

-- Nao ha trigger em PaymentIntents de proposito: a API atualiza essa tabela com "OUTPUT",
-- e o SQL Server recusa OUTPUT em tabela com trigger (o pagamento falhava com erro 500).
-- Se uma versao antiga deste script criou o trigger abaixo, ele e removido aqui.
IF OBJECT_ID(N'dbo.TR_PaymentIntents_StatusFinal', N'TR') IS NOT NULL
    DROP TRIGGER dbo.TR_PaymentIntents_StatusFinal;
GO
