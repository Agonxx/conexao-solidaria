# Checklist — Conexão Solidária

**Atualizado em 2026-09-27.** Progresso: 30 de 38 itens.

Legenda: `[x]` feito · `[ ]` pendente. Detalhe do momento atual em [`estado-atual.md`](estado-atual.md).

## Decisões e planejamento (6 de 6)
- [x] Arquitetura de microsserviços definida
- [x] Contrato de evento: classe duplicada + teste de `FullName`
- [x] Mongo = feedback do doador (snapshot descartado)
- [x] Frontend e ElasticSearch fora do escopo
- [x] Grafana via Prometheus; Kong só roteamento simples
- [x] Padrão de código documentado (`PADRAO-CODIGO.md`)

## F5-CS-UsersApi (2 de 2)
- [x] JWT, cadastro de doador, BCrypt, `GetMe`
- [x] Testes unitários

## F5-CS-CampanhasApi (8 de 8)
- [x] Estrutura em camadas no padrão do projeto
- [x] CRUD de campanhas (`GestorONG`) e regras de validação
- [x] Painel de transparência público
- [x] Doação (`Doador`) + publica `DoacaoRecebidaEvent`
- [x] Dockerfile, docker-compose e README
- [x] 14 testes passando e smoke test com RabbitMQ real
- [x] Repo privado no GitHub (Agonxx/F5-CS-CampanhasApi) e commit inicial
- [x] Login pelo UsersApi de verdade (teste integrado, com Worker, em 2026-09-26)

## F5-CS-DoacaoWorker (5 de 5)
- [x] Estrutura em camadas, Dockerfile, compose e README (padrão do PaymentsAPI)
- [x] Repo privado no GitHub (Agonxx/F5-CS-DoacaoWorker) e commit inicial
- [x] `DoacaoRecebidaConsumer` atualiza `ValorArrecadado`
- [x] Evento duplicado + teste de `FullName`
- [x] Testes unitários (3) e smoke test ponta a ponta com a CampanhasApi

## F5-CS-FeedbackApi (5 de 5)
- [x] API com MongoDB e JWT do UsersApi (porta 5004; Dockerfile, compose e README)
- [x] Um feedback por doação, só do dono (dono conferido via `MinhasDoacoes` da CampanhasApi; índice único no Mongo)
- [x] Leitura agregada para `GestorONG` (`Feedback/Resumo`)
- [x] 10 testes unitários passando + smoke test real com Mongo, UsersApi, CampanhasApi e Worker
- [x] Repo privado no GitHub (Agonxx/F5-CS-FeedbackApi) e commit inicial

## Infra, observabilidade e CI/CD (4 de 5)
- [x] Yamls k8s: Deployments, Services, ConfigMaps (`conexao-solidaria/k8s/`)
- [x] RabbitMQ no cluster local
- [x] Prometheus + dashboard Grafana com métricas reais
- [ ] GitHub Actions: build, testes e imagem Docker
- [ ] Kong (roteamento simples, depois do MVP)

## Entregáveis (1 de 7)
- [x] Tornar públicos os repos (UsersApi, CampanhasApi, DoacaoWorker, FeedbackApi, conexao-solidaria) antes da entrega
- [ ] README passo a passo (infra + app)
- [ ] Diagrama de arquitetura no Miro
- [ ] PDF justificando SQL Server e Mongo
- [ ] Vídeo de demonstração (até 15 min)
- [ ] Relatório de entrega
- [ ] Atualizar `estado-atual.md` com o que foi feito
