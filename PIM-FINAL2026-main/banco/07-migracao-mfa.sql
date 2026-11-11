-- =====================================================================
-- 07 - MIGRACAO: reconhecimento facial -> MFA por aplicativo autenticador
-- Use SOMENTE em um banco que ja existe (criado pela versao com facial).
-- Banco novo: use 00-script-completo.sql (ja nasce no formato novo).
-- Pode ser executado mais de uma vez (cada passo confere se ja foi feito).
--
-- ATENCAO: remove as tabelas FaceTemplates e FaceVerificationLogs, ou seja,
-- APAGA os dados biometricos cadastrados. Faca backup antes se precisar.
-- Executar com: sqlcmd -S <servidor> -E -d <banco> -i 07-migracao-mfa.sql
-- =====================================================================
SET NOCOUNT ON;
GO

-- 1) Colunas do MFA em Users
IF COL_LENGTH('dbo.Users', 'MfaEnabled') IS NULL
    ALTER TABLE dbo.Users ADD MfaEnabled bit NOT NULL CONSTRAINT DF_Users_MfaEnabled DEFAULT 0;
IF COL_LENGTH('dbo.Users', 'MfaSecretProtected') IS NULL
    ALTER TABLE dbo.Users ADD MfaSecretProtected varbinary(max) NULL;
IF COL_LENGTH('dbo.Users', 'MfaLastStep') IS NULL
    ALTER TABLE dbo.Users ADD MfaLastStep bigint NOT NULL CONSTRAINT DF_Users_MfaLastStep DEFAULT 0;
IF COL_LENGTH('dbo.Users', 'MfaEnabledAt') IS NULL
    ALTER TABLE dbo.Users ADD MfaEnabledAt datetime2 NULL;
GO

-- 2) Codigos de recuperacao (so o hash SHA-256 fica no banco)
IF OBJECT_ID('dbo.MfaRecoveryCodes', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.MfaRecoveryCodes (
        Id uniqueidentifier NOT NULL,
        UserId uniqueidentifier NOT NULL,
        CodeHash nvarchar(64) NOT NULL,
        UsedAt datetime2 NULL,
        CreatedAt datetime2 NOT NULL,
        CONSTRAINT PK_MfaRecoveryCodes PRIMARY KEY (Id),
        CONSTRAINT FK_MfaRecoveryCodes_Users_UserId FOREIGN KEY (UserId) REFERENCES dbo.Users (Id) ON DELETE CASCADE
    );
    CREATE INDEX IX_MfaRecoveryCodes_UserId ON dbo.MfaRecoveryCodes (UserId);
END
GO

-- 3) FaceAttempts passa a se chamar ConfirmAttempts (tentativas de codigo na compra)
IF COL_LENGTH('dbo.PaymentIntents', 'FaceAttempts') IS NOT NULL AND COL_LENGTH('dbo.PaymentIntents', 'ConfirmAttempts') IS NULL
    EXEC sp_rename 'dbo.PaymentIntents.FaceAttempts', 'ConfirmAttempts', 'COLUMN';
GO

-- 4) Remove o que era do reconhecimento facial
IF OBJECT_ID('dbo.FaceVerificationLogs', 'U') IS NOT NULL DROP TABLE dbo.FaceVerificationLogs;
IF OBJECT_ID('dbo.FaceTemplates', 'U') IS NOT NULL DROP TABLE dbo.FaceTemplates;
GO

SELECT 'MFA' AS item,
       (SELECT COUNT(*) FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Users') AND name LIKE 'Mfa%') AS colunas_em_Users,
       CASE WHEN OBJECT_ID('dbo.MfaRecoveryCodes', 'U') IS NULL THEN 'FALTA' ELSE 'OK' END AS tabela_codigos_recuperacao,
       CASE WHEN COL_LENGTH('dbo.PaymentIntents', 'ConfirmAttempts') IS NULL THEN 'FALTA' ELSE 'OK' END AS coluna_ConfirmAttempts,
       CASE WHEN OBJECT_ID('dbo.FaceTemplates', 'U') IS NULL AND OBJECT_ID('dbo.FaceVerificationLogs', 'U') IS NULL THEN 'OK' ELSE 'AINDA EXISTE' END AS tabelas_faciais_removidas;
GO
