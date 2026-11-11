-- Champions Card / TicketFut - testes das regras do banco (demonstracao para o professor)
-- Pre-requisito: 01-esquema.sql e 03-regras-procedures-triggers.sql ja executados.
-- Executar com: sqlcmd -S <servidor> -E -d <banco> -I -i 05-testes-demonstracao.sql
-- Cria dados de teste (estadio ZZ_TESTE, usuario de teste), prova cada regra e apaga tudo no fim.
-- Cada linha de resultado comeca com "OK" (regra funcionou) ou "ERRO" (regra falhou).
SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;

DECLARE @stadium int, @match int, @user uniqueidentifier = NEWID(), @intent uniqueidentifier = NEWID(),
        @intent2 uniqueidentifier = NEWID(), @ticket uniqueidentifier = NEWID(), @msg nvarchar(300);

-- ---------- dados de teste ----------
INSERT INTO Stadiums (Name, City, TeamSlug, Latitude, Longitude) VALUES (N'ZZ_TESTE', N'Teste', N'teste', 0, 0);
SET @stadium = SCOPE_IDENTITY();
INSERT INTO Matches (HomeTeam, AwayTeam, BasePrice, KickoffAt, StadiumId)
VALUES (N'TimeA', N'TimeB', 100, DATEADD(day, 30, SYSUTCDATETIME()), @stadium);
SET @match = SCOPE_IDENTITY();
INSERT INTO Users (Id, Name, Cpf, Email, PasswordHash, Team, [Plan], Role, MemberCode, CreatedAt)
VALUES (@user, N'Usuario Teste Banco', N'99999999999', N'zz-teste-banco@teste.local', N'x', N'TimeA', 10, N'User', NULL, SYSUTCDATETIME());
INSERT INTO PaymentIntents (Id, UserId, MatchId, Sector, SeatRow, SeatNumber, Method, OriginalAmount, DiscountPercent, Amount,
                            Status, Nonce, ExpiresAt, ConfirmAttempts, CreatedAt)
VALUES (@intent, @user, @match, N'Norte', 3, 7, N'Pix', 100, 10, 90, N'Pending', N'n1', DATEADD(minute, 10, SYSUTCDATETIME()), 0, SYSUTCDATETIME());

-- ---------- 1) trigger de auditoria ----------
INSERT INTO Tickets (Id, PaymentIntentId, UserId, MatchId, Sector, SeatRow, SeatNumber, Code, Amount, IssuedAt)
VALUES (@ticket, @intent, @user, @match, N'Norte', 3, 7, N'ZZTESTE001', 90, SYSUTCDATETIME());
SELECT CASE WHEN EXISTS (SELECT 1 FROM TicketAudit WHERE TicketId = @ticket AND Action = N'EMITIDO')
            THEN N'OK   - 1 trigger de auditoria: ingresso emitido gerou linha em TicketAudit'
            ELSE N'ERRO - 1 trigger de auditoria nao gravou' END AS resultado;

-- ---------- 2) ingresso nao pode ser alterado ----------
BEGIN TRY
    UPDATE Tickets SET Sector = N'Sul' WHERE Id = @ticket;
    SELECT N'ERRO - 2 ingresso foi alterado' AS resultado;
END TRY
BEGIN CATCH
    SELECT N'OK   - 2 ingresso imutavel: ' + ERROR_MESSAGE() AS resultado;
END CATCH

-- ---------- 3) ingresso nao pode ser apagado ----------
BEGIN TRY
    DELETE FROM Tickets WHERE Id = @ticket;
    SELECT N'ERRO - 3 ingresso foi apagado' AS resultado;
END TRY
BEGIN CATCH
    SELECT N'OK   - 3 ingresso nao apaga: ' + ERROR_MESSAGE() AS resultado;
END CATCH

-- ---------- 4) status de pagamento invalido e recusado (CHECK) ----------
BEGIN TRY
    UPDATE PaymentIntents SET Status = N'Hacker' WHERE Id = @intent;
    SELECT N'ERRO - 4 aceitou status invalido' AS resultado;
END TRY
BEGIN CATCH
    SELECT N'OK   - 4 CHECK: status invalido recusado (erro ' + CAST(ERROR_NUMBER() AS nvarchar(10)) + N')' AS resultado;
END CATCH

-- ---------- 5) mesma cadeira nao vende duas vezes (indice unico) ----------
BEGIN TRY
    INSERT INTO Tickets (Id, PaymentIntentId, UserId, MatchId, Sector, SeatRow, SeatNumber, Code, Amount, IssuedAt)
    VALUES (NEWID(), @intent2, @user, @match, N'Norte', 3, 7, N'ZZTESTE002', 90, SYSUTCDATETIME());
    SELECT N'ERRO - 5 vendeu a mesma cadeira duas vezes' AS resultado;
END TRY
BEGIN CATCH
    SELECT N'OK   - 5 cadeira unica: erro ' + CAST(ERROR_NUMBER() AS nvarchar(10)) + N' (indice unico)' AS resultado;
END CATCH

-- ---------- 6) restricoes CHECK ----------
BEGIN TRY
    INSERT INTO Users (Id, Name, Cpf, Email, PasswordHash, Team, [Plan], Role, MemberCode, CreatedAt)
    VALUES (NEWID(), N'Invalido', N'99999999998', N'zz-invalido@teste.local', N'x', N'TimeA', 0, N'Hacker', NULL, SYSUTCDATETIME());
    SELECT N'ERRO - 6 aceitou papel invalido' AS resultado;
END TRY
BEGIN CATCH
    SELECT N'OK   - 6 CHECK: papel invalido recusado (erro ' + CAST(ERROR_NUMBER() AS nvarchar(10)) + N')' AS resultado;
END CATCH

-- ---------- 7) procedures e views ----------
SELECT N'--- sp_VendasPorPartida (partida de teste) ---' AS resultado;
EXEC dbo.sp_VendasPorPartida @MatchId = @match;
SELECT N'--- sp_IngressosDoUsuario ---' AS resultado;
EXEC dbo.sp_IngressosDoUsuario @UserId = @user;
SELECT N'--- sp_AssentosOcupados ---' AS resultado;
EXEC dbo.sp_AssentosOcupados @MatchId = @match;
SELECT N'--- sp_ExpirarIntencoesPendentes ---' AS resultado;
EXEC dbo.sp_ExpirarIntencoesPendentes;

-- ---------- limpeza (os triggers de apagar/alterar sao desligados so aqui) ----------
DISABLE TRIGGER dbo.TR_Tickets_NaoApagar ON dbo.Tickets;
DELETE FROM Tickets WHERE UserId = @user;
ENABLE TRIGGER dbo.TR_Tickets_NaoApagar ON dbo.Tickets;
DELETE FROM TicketAudit WHERE UserId = @user;
DELETE FROM PaymentIntents WHERE UserId = @user;
DELETE FROM Users WHERE Id = @user;
DELETE FROM Matches WHERE Id = @match;
DELETE FROM Stadiums WHERE Id = @stadium;
SELECT N'Limpeza concluida: dados de teste removidos.' AS resultado;
