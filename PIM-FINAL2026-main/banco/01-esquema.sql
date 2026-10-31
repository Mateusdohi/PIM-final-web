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
    CONSTRAINT PK_Users PRIMARY KEY (Id)
);
CREATE UNIQUE INDEX IX_Users_Cpf ON Users (Cpf);
CREATE UNIQUE INDEX IX_Users_Email ON Users (Email);
CREATE UNIQUE INDEX IX_Users_MemberCode ON Users (MemberCode) WHERE MemberCode IS NOT NULL;
GO

CREATE TABLE FaceTemplates (
    Id uniqueidentifier NOT NULL,
    UserId uniqueidentifier NOT NULL,
    EncryptedEmbedding varbinary(max) NOT NULL,
    ModelVersion nvarchar(60) NOT NULL,
    ConsentAt datetime2 NOT NULL,
    CreatedAt datetime2 NOT NULL,
    CONSTRAINT PK_FaceTemplates PRIMARY KEY (Id),
    CONSTRAINT FK_FaceTemplates_Users_UserId FOREIGN KEY (UserId) REFERENCES Users (Id) ON DELETE CASCADE
);
CREATE UNIQUE INDEX IX_FaceTemplates_UserId ON FaceTemplates (UserId);
GO

CREATE TABLE FaceVerificationLogs (
    Id uniqueidentifier NOT NULL,
    UserId uniqueidentifier NOT NULL,
    PaymentIntentId uniqueidentifier NULL,
    Purpose nvarchar(20) NOT NULL,
    Similarity float NOT NULL,
    IsMatch bit NOT NULL,
    CreatedAt datetime2 NOT NULL,
    CONSTRAINT PK_FaceVerificationLogs PRIMARY KEY (Id)
);
CREATE INDEX IX_FaceVerificationLogs_UserId ON FaceVerificationLogs (UserId);
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
    FaceAttempts int NOT NULL,
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