# TicketFut / Champions Card

Sistema de venda de ingressos de futebol com planos de sócio-torcedor, feito para o **PIM IV** do curso de Análise e Desenvolvimento de Sistemas da UNIP.

O sistema tem um **site**, um **aplicativo Android (Flutter)**, uma **API .NET 8**, um **banco SQL Server** e um **serviço de reconhecimento facial em Python**. O site e o aplicativo usam a mesma API e o mesmo banco.

## O que o sistema faz

- Cadastro e login (JWT com renovação de token).
- Lista de partidas, mapa do estádio por setor e escolha da cadeira.
- Carrinho (até 5 cadeiras) e pagamento por cartão ou Pix. **O pagamento é simulado.**
- Confirmação da compra: senha no site; biometria do aparelho e selfie no aplicativo.
- Meus ingressos, perfil, planos de sócio (5%, 10% e 20% de desconto) e assistente de dúvidas.
- Área Admin (só para o administrador) com a lista dos ingressos vendidos.
- Acessibilidade no aplicativo: tamanho do texto e alto contraste.

## Estrutura do repositório

Estas são as pastas do projeto.

| Pasta ou arquivo | O que é |
|---|---|
| `aplicação web/` | Site em HTML, CSS e JavaScript |
| `flutter_app/` | Aplicativo Flutter (camadas `core`, `data`, `domain` e `presentation`) |
| `backend/` | API .NET 8 em camadas: `Domain`, `Application`, `Infrastructure` e `Api`, mais os testes do domínio |
| `face-service/` | Serviço FastAPI de reconhecimento facial (só a API o acessa) |
| `banco/` | Scripts do banco SQL Server: esquema, regras, procedures, triggers, MER, testes e script completo |
| `docker-compose.yml` | Sobe o banco, a API e o serviço facial |
| `.env.example` | Modelo das variáveis de ambiente (copie para `.env`) |

## Como rodar

**1. Servidor (banco, API e serviço facial)**, nesta pasta:

```bash
cp .env.example .env        # troque as senhas e as chaves
docker compose up --build
```

A API responde em `http://localhost:5080` (site) e `http://localhost:8080` (aplicativo). O Swagger fica em `/swagger`.

**2. Site:** abra a pasta `aplicação web` com o Live Server do VS Code. Ele precisa usar a porta **5500** ou **5501**, porque a API só aceita essas origens.

**3. Aplicativo:** com um emulador Android aberto, na pasta `flutter_app`:

```bash
flutter run
```

O aplicativo usa `http://10.0.2.2:8080` por padrão, que é o computador visto pelo emulador. Para outro endereço: `flutter run --dart-define=API_URL=http://<endereço>:8080`.

**Login de teste** (só em ambiente de desenvolvimento): `admin@ticketfut.com` / `Admin@1234`.

## Banco de dados

A pasta `banco/` tem o necessário para criar e conferir o banco. O arquivo `00-script-completo.sql` cria o banco do zero. O `banco/LEIA-ME.md` explica cada arquivo, e o `banco/04-modelo-logico-fisico-MER.md` traz o MER e os modelos lógico e físico.

## Testes

```bash
cd backend && dotnet test TicketFut.sln     # 18 testes das regras de domínio
cd flutter_app && flutter test              # 11 testes (validadores e casos de uso do pagamento)
cd face-service && pytest                   # testes do serviço facial
```

## O que é simulado ou ainda não existe

- O gateway de pagamento é simulado (cartão terminado em `0000` simula recusa).
- A prova de vida por giro de cabeça existe no serviço facial, mas vem **desligada** por padrão (`FACE_LIVENESS=none`). Ela não barra um vídeo gravado.
- O aplicativo foi testado apenas em emulador Android, por HTTP. Em produção, o HTTPS é obrigatório.
- Não há implantação em nuvem nem esteira de CI/CD: ambas estão só como plano no relatório da Etapa 8.
- Segredos (senha do banco, chave do JWT e chaves do serviço facial) ficam no arquivo `.env`, que **não** vai para o repositório.

## Etapas do PIM IV e onde estão

| Etapa do manual | Onde está no repositório |
|---|---|
| 4 – Desenvolvimento web | `backend/` e `aplicação web/` |
| 5 – Desenvolvimento mobile | `flutter_app/` |
| 6 – Arquitetura de software | camadas de `backend/` e `flutter_app/` |
| 7 – Projeto do banco de dados | `banco/` |
| 8 – Nuvem e DevOps | plano descrito no relatório (`docker-compose.yml` e os Dockerfiles são a base) |

As demais etapas (organização, planejamento, responsabilidade social e gerenciamento ágil) estão no documento do PIM, e não neste repositório.

---

# Detalhes técnicos do servidor e do aplicativo

## Como as peças se falam

```
Flutter App ──HTTPS/JWT──▶ Backend C# (.NET 8) ──rede interna + API key──▶ Microsserviço Python (FastAPI)
                                │                                              │
                           SQL Server                                  compara rostos (ArcFace)
                    (usuários, partidas, pagamentos,                   não guarda nada
                     embedding faciais criptografados)
```

**O aplicativo nunca fala com o Python.** Só a API em C# chama o serviço de reconhecimento facial e decide o resultado. O site usa a mesma API.

## Rodar sem Docker

```bash
cd face-service
pip install -r requirements-dev.txt
EMBEDDER=mock uvicorn app.main:app          # "mock" não reconhece rostos de verdade; só para desenvolvimento
```

```bash
cd backend/src/TicketFut.Api
dotnet run                                  # veja appsettings.Development.json
```

Depois configure o Flutter em `flutter_app/platform_setup/README.md`.

## Como as regras do site foram levadas para o aplicativo

- Times, cores, textos de boas-vindas e notícias por time ficam em `flutter_app/lib/core/theme/team_theme.dart`.
- Partidas, preços e horários vêm do `DbSeeder` (as datas de maio de 2026 já passaram; o seed reaproveita o espaçamento a partir do próximo domingo).
- Planos Bronze, Prata e Ouro dão 5%, 10% e 20% de desconto; o **código de sócio** (3 letras e 3 dígitos) é exigido na compra.
- Mapa da arena: **o mandante nunca fica no setor Leste, e o visitante só fica no Leste** (aplicado no servidor e na tela).
- A aba do estádio mostra a localização (OpenStreetMap) e abre a rota.

## Biometria: o que cada camada garante

| Fluxo | Mecanismo | Observação |
|---|---|---|
| Login rápido | `local_auth` destrava o refresh token guardado no Keychain ou Keystore | Conveniência; o servidor não "vê" a biometria |
| Cadastro facial | selfie → API em C# → Python → **embedding** criptografado (AES-GCM) | A foto não é armazenada |
| Confirmar compra | biometria nativa **+ selfie verificada no servidor** | O servidor decide; o aplicativo não consegue "forjar" a aprovação |

Em compras, o servidor exige o `nonce` da intenção, limita as tentativas (5), expira a intenção em 10 minutos e só então cobra.

## Antes de ir para produção

1. **Prova de vida:** o serviço facial tem um provedor por giro de cabeça (`LIVENESS_PROVIDER=head_turn`), mas ele vem **desligado** (`none`). Ele barra foto impressa ou imagem parada, mas não um vídeo gravado. Para ligar: `FACE_LIVENESS=head_turn` e `FACE_REQUIRE_LIVENESS=true` no `.env`.
2. **Gateway de pagamento é sandbox** (`SandboxPaymentGateway`), e o aplicativo usa `SandboxCardTokenizer`. Troque pelo SDK de um gateway real (tokenização no aplicativo); número do cartão e CVV nunca devem chegar ao servidor. Cartões terminados em `0000` simulam recusa.
3. **Limiares** (`THRESHOLD_LOGIN` e `THRESHOLD_PAYMENT`) precisam ser calibrados com dados reais (falsa aceitação contra falsa rejeição). A "porcentagem" devolvida é a similaridade de cosseno, não a probabilidade de ser a mesma pessoa.
4. **LGPD:** dado biométrico é sensível. Há consentimento no cadastro e a rota `DELETE /api/auth/face` para exclusão; revise política de privacidade, retenção e base legal.
5. HTTPS obrigatório, segredos fora do repositório (`.env` e user-secrets), migrações do EF Core em vez de `EnsureCreated`. Os preços dos planos (`MemberPlans`) são valores de exemplo.

## Melhorias em relação ao site original

Senhas com hash (o original guardava em texto puro), nenhum dado de cartão ou CVV armazenado, validação de CPF, limite de requisições no login, JWT com renovação rotativa e tratamento de e-mail e CPF duplicados no servidor.
