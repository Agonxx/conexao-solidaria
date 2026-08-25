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
| Frontend | Confirmado que vai existir; tecnologia ainda em aberto (cogitado Blazor) |

### Bancos de dados
- **SQL Server** → confirmado para `UsersApi` e API da ONG (Campanhas + Doações)
- Segundo banco (Mongo ou outro) → ainda em aberto. O requisito pede um PDF "justificando por que os bancos de dados X e Y foram escolhidos" (plural), o que sugere que o avaliador espera mais de uma tecnologia — decidir isso é um dos próximos passos.

## Estratégia: reaproveitar o projeto FCG (Fase 3/4)

Este projeto é nominalmente "do zero", mas boa parte do trabalho de arquitetura já foi resolvido no projeto anterior (`C:\FIAP\Fase3`, `C:\FIAP\Fase4`) e dá pra reaproveitar como esqueleto, adaptando o domínio:

- **Padrão de evento assíncrono**: o `FCG-MS-PaymentsAPI` da Fase 4 já é orientado a eventos (`Consumers/`, `Domain/Events/`) — mesma forma exigida aqui pro fluxo Doação → `DoacaoRecebidaEvent` → Worker. Dá pra usar a mesma Clean Architecture (Api/Application/Domain/Infrastructure) trocando o domínio Payment→Doação.
- **Auth**: `FCG-MS-UsersAPI` já tem JWT + hash de senha (BCrypt) implementado — só trocar os roles pelos exigidos aqui (`GestorONG`/`Doador`).
- **K8s manifests**: `FCG-MS-Orchestration/k8s/` já tem RabbitMQ, Prometheus, Grafana e Kong funcionando — copiar/adaptar em vez de montar do zero.
- **CI/CD**: pipeline GitHub Actions do `UsersAPI`/`CatalogAPI` (build + test + Docker) é reaproveitável quase direto, só removendo o estágio de deploy AWS (aqui é opcional e local).
- **O que fica de fora desta vez** (não exigido pelo PDF): MongoDB avançado, Elasticsearch/OpenSearch, AWS/Lambda/SQS, Terraform/eksctl, Secrets Manager gerenciado.

## Observação sobre o PDF de requisitos

O título da seção de observabilidade no PDF é "Observabilidade (Zabbix e Grafana)", mas o corpo do requisito só cobra `/health`/`/metrics` + dashboard **Grafana** — Zabbix não aparece em nenhum item concreto. Tratando como resquício de template por ora; vale confirmar no Discord da FIAP se restar dúvida.

## Multitenancy

**Decidido não fazer** (2026-08-24). O PDF não pede — plataforma é pra uma única ONG (Esperança Solidária), só dois perfis (`GestorONG`/`Doador`), sem conceito de múltiplas organizações isoladas. Tecnicamente seria simples de adicionar (EF Core `HasQueryFilter` + `TenantId`), mas o custo se espalha por toda entidade/config/teste e não vale nada na nota — tempo melhor investido no que é avaliado (fluxo de evento, observabilidade, pipeline, vídeo). Pode voltar como extra depois do MVP obrigatório estar pronto, se sobrar tempo.

## Padrão de código

Ver [`PADRAO-CODIGO.md`](./PADRAO-CODIGO.md) — análise do estilo usado nas APIs da Fase 3/4 (Program.cs enxuto via extension methods, middlewares separados, `InfoToken` scoped, etc.) que vamos reaproveitar aqui.

## Pontos em aberto

- [ ] Segundo banco de dados (qual e para quê)
- [ ] Nome e escopo definitivo dos serviços (API da ONG, Worker de Doações)
- [ ] Onde mora o Worker/Consumer do RabbitMQ — serviço dedicado ou dentro de uma API existente
- [ ] Tecnologia do Frontend
- [ ] Como o Grafana coleta métricas (exporter direto vs. Prometheus no meio — Fase 4 já usa Prometheus como intermediário, reaproveitável)
