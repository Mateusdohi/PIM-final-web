-- Champions Card / TicketFut - verificacao do banco (SOMENTE LEITURA, nao altera nada)
-- Executar com: sqlcmd -S <servidor> -E -d <banco> -i 02-verificar.sql
-- Cada linha mostra OK ou FALTA. Qualquer FALTA precisa ser corrigida antes de ligar a API.
SET NOCOUNT ON;

-- 1) Tabelas que o codigo usa
SELECT 'Tabela' AS tipo, v.n AS item,
       CASE WHEN OBJECT_ID(v.n, 'U') IS NULL THEN 'FALTA' ELSE 'OK' END AS situacao
FROM (VALUES ('Users'),('Stadiums'),('Matches'),('PaymentIntents'),('Tickets'),
             ('FaceTemplates'),('RefreshTokens'),('FaceVerificationLogs')) v(n);

-- 2) Colunas acrescentadas pelo projeto web (papel, plano, assento)
SELECT 'Coluna' AS tipo, v.t + '.' + v.c AS item,
       CASE WHEN COL_LENGTH(v.t, v.c) IS NULL THEN 'FALTA' ELSE 'OK' END AS situacao
FROM (VALUES ('Users','Role'),('Users','Plan'),('Users','MemberCode'),
             ('PaymentIntents','SeatRow'),('PaymentIntents','SeatNumber'),
             ('Tickets','SeatRow'),('Tickets','SeatNumber')) v(t, c);

-- 3) Indice unico filtrado de assento (contra venda dupla). Procurado pelas colunas, nao pelo nome.
SELECT 'Indice de assento' AS tipo, t.name AS item,
       CASE WHEN EXISTS (
           SELECT 1 FROM sys.indexes i
           JOIN sys.index_columns ic ON ic.object_id = i.object_id AND ic.index_id = i.index_id
           JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
           WHERE i.object_id = t.object_id AND i.is_unique = 1
             AND i.filter_definition IS NOT NULL AND c.name = 'SeatRow')
       THEN 'OK' ELSE 'FALTA' END AS situacao
FROM sys.tables t WHERE t.name IN ('PaymentIntents', 'Tickets');

-- 4) Usuario administrador (so verifica se a coluna Role existir)
IF COL_LENGTH('Users', 'Role') IS NOT NULL
    EXEC('SELECT ''Admin'' AS tipo, ''usuarios com Role = Admin'' AS item,
          CASE WHEN EXISTS (SELECT 1 FROM Users WHERE Role = ''Admin'') THEN ''OK'' ELSE ''FALTA'' END AS situacao');