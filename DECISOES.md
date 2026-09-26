# Decisões do projeto

## Estrutura do repositório

**Multi-repo, revertido em 2026-08-25** — decisão original (2026-08-22) era monorepo, mas o grupo optou por seguir o mesmo padrão do FCG4: um repositório por serviço, prefixo `F5-CS-{Servico}` (em vez de `F4-FCG-MS-{Servico}`). Este repositório (`conexao-solidaria`) passa a concentrar só documentação/decisões/diagrama; cada serviço mora no seu próprio repo:

- [`F5-CS-UsersApi`](https://github.com/Agonxx/F5-CS-UsersApi) — autenticação JWT + cadastro de doador (pronto e testado)

## Stack (decidido pelo grupo antes deste documento)

| Item | Decisão |
|---|---|
| API Gateway | Kong |
| Broker de mensageria | RabbitMQ |
| Observabilidade | Grafana |
| CI/CD | GitHub Actions |
| Kubernetes | Local (Docker Desktop K8s / Minikube / Kind) — **não precisa de nuvem**, confirmado no PDF de requisitos |
| Testes unitários | Sim, serão implementados (bônus, mas vale o esforço) |
| Diagrama de arquitetura | Miro |
| Frontend | **Fora do escopo** (decidido em 2026-09-26) — o PDF não exige; demo via Swagger/Postman |

### Bancos de dados
- **SQL Server** → confirmado para `UsersApi` e API da ONG (Campanhas + Doações)
- **MongoDB** → **revisado em 2026-09-26**: passa a guardar o **feedback do doador** sobre a doação (documento flexível: rapidez, dificuldade, pretende voltar a doar, comentário). Substitui o snapshot de encerramento de campanha (decidido em 2026-08-25, descartado). Serviço próprio: `F5-CS-FeedbackApi`. Detalhes em [`MENSAGERIA.md`](./MENSAGERIA.md).

## Estratégia: reaproveitar o projeto FCG (Fase 4)

Este projeto é nominalmente "do zero", mas boa parte do trabalho de arquitetura já foi resolvido no projeto anterior e dá pra reaproveitar como esqueleto, adaptando o domínio. Os repositórios locais antigos (`C:\FIAP\Fase3`, `C:\FIAP\Fase4`) não existem mais após reformatações da máquina — a fonte confiável agora são os repositórios públicos no GitHub, clonados em `C:\Dev\Claudia\FIAP4\` sempre que precisar consultar:

- [`Agonxx/F4-FCG-MS-UsersAPI`](https://github.com/Agonxx/F4-FCG-MS-UsersAPI) — JWT + hash de senha (**atenção**: o `CryptoUtils` de lá é AES reversível com chave hardcoded, não é BCrypt de verdade apesar do que a documentação antiga dizia — já corrigido no `F5-CS-UsersApi`)
- [`Agonxx/F4-FCG-MS-PaymentsAPI`](https://github.com/Agonxx/F4-FCG-MS-PaymentsAPI) — orientado a eventos (MassTransit/RabbitMQ), molde pro fluxo Doação → `DoacaoRecebidaEvent` → Worker
- [`Agonxx/F4-FCG-MS-Orchestration`](https://github.com/Agonxx/F4-FCG-MS-Orchestration) — k8s com RabbitMQ, Prometheus, Grafana e Kong já funcionando, copiar/adaptar
- CI/CD: pipeline GitHub Actions do `UsersAPI`/`CatalogAPI` (build + test + Docker) reaproveitável quase direto, removendo o estágio de deploy AWS

Detalhes completos da stack/arquitetura do FCG4 em [`PADRAO-CODIGO.md`](./PADRAO-CODIGO.md).

## Observação sobre o PDF de requisitos

O título da seção de observabilidade no PDF é "Observabilidade (Zabbix e Grafana)", mas o corpo do requisito só cobra `/health`/`/metrics` + dashboard **Grafana** — Zabbix não aparece em nenhum item concreto. Tratando como resquício de template por ora; vale confirmar no Discord da FIAP se restar dúvida.

## Multitenancy

**Decidido não fazer** (2026-08-24). O PDF não pede — plataforma é pra uma única ONG (Esperança Solidária), só dois perfis (`GestorONG`/`Doador`), sem conceito de múltiplas organizações isoladas. Tecnicamente seria simples de adicionar (EF Core `HasQueryFilter` + `TenantId`), mas o custo se espalha por toda entidade/config/teste e não vale nada na nota — tempo melhor investido no que é avaliado (fluxo de evento, observabilidade, pipeline, vídeo). Pode voltar como extra depois do MVP obrigatório estar pronto, se sobrar tempo.

## Padrão de código

Ver [`PADRAO-CODIGO.md`](./PADRAO-CODIGO.md) — análise do estilo usado nas APIs da Fase 3/4 (Program.cs enxuto via extension methods, middlewares separados, `InfoToken` scoped, etc.) que vamos reaproveitar aqui.

## Pontos em aberto

- [x] Segundo banco de dados → MongoDB, feedback do doador (`F5-CS-FeedbackApi`); snapshot de encerramento descartado em 2026-09-26
- [x] Onde mora o Worker/Consumer do RabbitMQ → um único Worker (`F5-CS-DoacaoWorker`, consome `DoacaoRecebidaEvent`); o segundo Worker deixou de existir com a troca do Mongo
- [x] Contrato do evento entre repos → **classe duplicada** em cada repo, mesmo padrão do FCG4 (`PaymentProcessedEvent` em Payments e Catalog), decidido em 2026-09-26. Namespace fixo `Shared.Contracts.Events` em todos os repos (MassTransit roteia pelo nome completo do tipo) + teste unitário em cada Worker conferindo o `FullName`. Ver [`MENSAGERIA.md`](./MENSAGERIA.md)
- [x] Nomes dos serviços (2026-09-26): `F5-CS-UsersApi` (pronto), `F5-CS-CampanhasApi` (Campanhas+Doações, SQL Server), `F5-CS-DoacaoWorker`, `F5-CS-FeedbackApi` (Mongo)
- [x] Frontend → descartado, fora do escopo (2026-09-26)
- [x] Grafana coleta via **Prometheus no meio**, reaproveitando o `F4-FCG-MS-Orchestration` (2026-09-26)
- [x] Kong Gateway sim (roteamento simples, declarative config, depois do MVP); **ElasticSearch fora do escopo** (2026-09-26)
