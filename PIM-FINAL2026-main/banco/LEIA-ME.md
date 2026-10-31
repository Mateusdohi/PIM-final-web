# Banco de dados - Champions Card / TicketFut

Esta pasta traz o que é preciso para ligar a API a um banco SQL Server.

## Arquivos

- `01-esquema.sql`: cria as 8 tabelas, as chaves e os índices, inclusive os 2 índices únicos filtrados de assento. Foi comparado coluna a coluna com o banco criado pelo Entity Framework Core.
- `02-verificar.sql`: só lê o banco e mostra OK ou FALTA para o que o código usa. Não altera nada.

## Segurança: o que NUNCA vai para o Git

A connection string, a `Jwt:Key` e a `Face:EncryptionKey` ficam em variáveis de ambiente, só no terminal que roda a API. Se o repositório for público, troque a `Jwt:Key` por uma nova.

## Cenário A: banco novo e vazio

1. Crie o banco vazio no SQL Server.
2. Rode o esquema:

        sqlcmd -S <SERVIDOR> -E -d <BANCO> -I -b -i 01-esquema.sql

3. Suba a API (a seção "Subir a API" explica as variáveis). Com `Database__AutoCreate=true`, a API insere os estádios, as partidas e, em Development, o usuário admin de demonstração (admin@ticketfut.com).

## Cenário B: banco que já existe (criado à mão)

1. Confira o que falta:

        sqlcmd -S <SERVIDOR> -E -d <BANCO> -W -s " | " -i 02-verificar.sql

2. Linhas com FALTA precisam ser corrigidas. As colunas e os índices que o projeto web acrescentou são: `Users.Role`, `PaymentIntents.SeatRow` e `SeatNumber`, `Tickets.SeatRow` e `SeatNumber`, e o índice único filtrado de assento em cada uma das duas tabelas.
3. Só ligue `Database__AutoCreate=true` se as tabelas estiverem vazias. Com tabelas que já existem, o `EnsureCreated` não faz nada, e o preenchimento inicial falha se faltar coluna.
## Subir a API

Na pasta `backend\src\TicketFut.Api`, no terminal que vai rodar a API:

    $env:ConnectionStrings__Default = "Server=<SERVIDOR>;Database=<BANCO>;Trusted_Connection=True;TrustServerCertificate=True"
    $env:Database__UseInMemory = "false"
    $env:Database__AutoCreate = "true"
    $env:Jwt__Key = "<texto aleatório com 32 caracteres ou mais>"
    dotnet run

Se a API recusar iniciar por falta de `Face:EncryptionKey`, gere uma chave de 32 bytes em base64 e defina `$env:Face__EncryptionKey`:

    $b = New-Object byte[] 32; [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($b); [Convert]::ToBase64String($b)

Observações:

- `Trusted_Connection=True` usa o login do Windows e só funciona na máquina que tem o SQL Server. Para outra máquina, use um login do SQL Server.
- A API sobe em `http://localhost:5080`. O Swagger fica em `/swagger`.
- O site abre pelo Live Server, na porta 5501.
- O usuário admin de demonstração só é criado em ambiente Development.

## Roteiro de demonstração

1. Subir a API no banco.
2. Abrir o Swagger e mostrar os endpoints.
3. No site: cadastrar, escolher partida, setor e assento, e pagar.
4. Mostrar o ingresso gravado:

        sqlcmd -S <SERVIDOR> -E -d <BANCO> -Q "SELECT MatchId, Sector, SeatRow, SeatNumber, Amount FROM Tickets"

5. Mostrar o bloqueio de assento duplicado: um segundo usuário, na mesma cadeira, recebe `409 seat_taken`.
6. Entrar como admin e abrir a área administrativa.

## Contrato com o app mobile

O projeto web só acrescentou campos. O app mobile continua comprando por setor, sem assento.

- `UserDto.role`.
- `TicketDto.seatRow` e `seatNumber`.
- `CreateIntentRequest.seatRow` e `seatNumber`, opcionais.
- `SeatMapDto.rowSizes`, campo novo. O mapa agora tem 12 fileiras e até 28 cadeiras, com tamanho por estádio do time da casa.
- A fila virtual vem desligada (`Queue:Enabled=false`).

O app precisa ignorar campos que não conhece. Vale testar o app com a API nova antes de juntar.

## O que foi e o que não foi testado

- Testado em SQL Server 2025 Express (LocalDB): criação do esquema, compra com assento, bloqueio de assento duplicado e ingresso gravado.
- Não testado: o banco CHAMPIONS-CARD, o app mobile, o face-service, e duas reservas simultâneas do mesmo assento.