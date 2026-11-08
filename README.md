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

Tudo fica na pasta `PIM-FINAL2026-main`.

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

**1. Servidor (banco, API e serviço facial)**, na pasta `PIM-FINAL2026-main`:

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
