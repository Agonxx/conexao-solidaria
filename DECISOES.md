# Decisões do projeto

## Estrutura do repositório

Multi-repo, seguindo o mesmo padrão do FCG4: um repositório por serviço, prefixo `F5-CS-{Servico}` (em vez de `F4-FCG-MS-{Servico}`). Este repositório (`conexao-solidaria`) concentra documentação, decisões e diagrama; cada serviço mora no seu próprio repo:

- [`F5-CS-UsersApi`](https://github.com/Agonxx/F5-CS-UsersApi) — autenticação JWT + cadastro de doador
- [`F5-CS-CampanhasApi`](https://github.com/Agonxx/F5-CS-CampanhasApi) — campanhas + doações, publica `DoacaoRecebidaEvent`
- [`F5-CS-DoacaoWorker`](https://github.com/Agonxx/F5-CS-DoacaoWorker) — consome `DoacaoRecebidaEvent`, atualiza valor arrecadado
- [`F5-CS-FeedbackApi`](https://github.com/Agonxx/F5-CS-FeedbackApi) — feedback do doador sobre a doação

## Stack

| Item | Decisão |
|---|---|
| API Gateway | Kong |
| Broker de mensageria | RabbitMQ |
| Observabilidade | Grafana, com Prometheus no meio |
| CI/CD | GitHub Actions |
| Kubernetes | Local (Docker Desktop) — o desafio não exige nuvem |
| Testes unitários | Sim, nos 4 serviços |
| Diagrama de arquitetura | Entregue como SVG/PNG |
| Frontend | Fora do escopo — demo via Swagger/Postman |

### Bancos de dados

- **SQL Server** para `UsersApi` e para a API de Campanhas + Doações — dados transacionais e relacionais, com integridade referencial e atomicidade no recálculo do valor arrecadado.
- **MongoDB** para o feedback do doador sobre a doação (`F5-CS-FeedbackApi`) — schema mais fluido, documento auto-contido (rapidez, dificuldade, pretende voltar a doar, comentário).

## Reaproveitamento do projeto FCG (Fase 4)

Boa parte da arquitetura já tinha sido resolvida no projeto anterior (`Agonxx/F4-FCG-MS-*`) e foi adaptada para este domínio:

- `F4-FCG-MS-UsersAPI` — base para autenticação JWT + hash de senha (com BCrypt de verdade, diferente do AES reversível usado lá)
- `F4-FCG-MS-PaymentsAPI` — molde para o fluxo orientado a eventos (MassTransit/RabbitMQ): Doação → `DoacaoRecebidaEvent` → Worker
- `F4-FCG-MS-Orchestration` — base para o k8s com RabbitMQ, Prometheus, Grafana e Kong
- Pipeline de CI/CD do `UsersAPI`/`CatalogAPI` (build + test + Docker), sem o estágio de deploy AWS

Padrão de código detalhado em [`PADRAO-CODIGO.md`](./PADRAO-CODIGO.md).

## Multitenancy

Decidido não implementar. A plataforma atende uma única ONG (Esperança Solidária), com dois perfis (`GestorONG`/`Doador`) e sem conceito de múltiplas organizações isoladas — não é um requisito do desafio.

## Contrato de evento entre serviços

Classe duplicada por repositório, mesmo padrão do FCG4 (`PaymentProcessedEvent` em Payments e Catalog): o record `DoacaoRecebidaEvent` é copiado na API de Campanhas e no Worker, ambos em `namespace Shared.Contracts.Events` (o MassTransit roteia pelo nome completo do tipo). Mitigação do risco de divergência: teste unitário no Worker conferindo o `FullName`. Detalhes em [`MENSAGERIA.md`](./MENSAGERIA.md).
