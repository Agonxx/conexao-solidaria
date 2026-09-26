# Estado atual — Conexão Solidária

**Atualizado em 2026-09-26.**

## Onde paramos
Todas as decisões de arquitetura estão fechadas (ver [`../DECISOES.md`](../DECISOES.md)). Nenhum código novo ainda além do `F5-CS-UsersApi` (pronto e testado).

## Estrutura local
- `C:\Dev\Claudia\FIAP4\` — 5 repos F4-FCG-MS-* (CatalogAPI, NotificationsFunction, PaymentsAPI, UsersAPI, Orchestration), **referência**.
- `C:\Dev\Claudia\FIAP5\` — `conexao-solidaria` (docs) e `F5-CS-UsersApi`.

## Fechado nesta etapa
- Contrato de evento: classe duplicada por repo, `namespace Shared.Contracts.Events`, teste de `FullName` no Worker (padrão do FCG4).
- Mongo = feedback do doador (`F5-CS-FeedbackApi`); snapshot de encerramento e 2º Worker descartados.
- Frontend e ElasticSearch fora do escopo; Kong só roteamento simples, depois do MVP.
- Grafana via Prometheus (copiar do `F4-FCG-MS-Orchestration`).
- Serviços: UsersApi (pronto), CampanhasApi, DoacaoWorker, FeedbackApi.

## Próximos passos
1. Criar `F5-CS-CampanhasApi` (Campanhas + Doações, SQL Server, publica `DoacaoRecebidaEvent`) — base: `F5-CS-UsersApi` + `F4-FCG-MS-PaymentsAPI`.
2. `F5-CS-DoacaoWorker` (consome o evento, atualiza `ValorArrecadado`).
3. `F5-CS-FeedbackApi` (Mongo, JWT do UsersApi, um feedback por doação).
4. Orquestração k8s + RabbitMQ + Prometheus/Grafana (copiar do Orchestration), CI/CD, Kong, diagrama Miro, PDF dos bancos, vídeo.

## Convenção
Cada repo novo: perguntar nome da subpasta antes (já definido: dentro de `FIAP5`, nome do repo `F5-CS-*`).
