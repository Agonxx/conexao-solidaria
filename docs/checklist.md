# Checklist — Conexão Solidária

**Atualizado em 2026-09-26.** Progresso: 18 de 35 itens.

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

## F5-CS-CampanhasApi (6 de 8)
- [x] Estrutura em camadas no padrão do projeto
- [x] CRUD de campanhas (`GestorONG`) e regras de validação
- [x] Painel de transparência público
- [x] Doação (`Doador`) + publica `DoacaoRecebidaEvent`
- [x] Dockerfile, docker-compose e README
- [x] 14 testes passando e smoke test com RabbitMQ real
- [ ] Criar repo no GitHub e commitar
- [ ] Login pelo UsersApi de verdade (teste integrado)

## F5-CS-DoacaoWorker (4 de 5)
- [x] Estrutura em camadas, Dockerfile, compose e README (padrão do PaymentsAPI)
- [ ] Criar repo no GitHub e commitar
- [x] `DoacaoRecebidaConsumer` atualiza `ValorArrecadado`
- [x] Evento duplicado + teste de `FullName`
- [x] Testes unitários (3) e smoke test ponta a ponta com a CampanhasApi

## F5-CS-FeedbackApi (0 de 4)
- [ ] API com MongoDB e JWT do UsersApi
- [ ] Um feedback por doação, só do dono
- [ ] Leitura agregada para `GestorONG`
- [ ] Testes unitários

## Infra, observabilidade e CI/CD (0 de 5)
- [ ] Yamls k8s: Deployments, Services, ConfigMaps
- [ ] RabbitMQ no cluster local
- [ ] Prometheus + dashboard Grafana com métricas reais
- [ ] GitHub Actions: build, testes e imagem Docker
- [ ] Kong (roteamento simples, depois do MVP)

## Entregáveis (0 de 6)
- [ ] README passo a passo (infra + app)
- [ ] Diagrama de arquitetura no Miro
- [ ] PDF justificando SQL Server e Mongo
- [ ] Vídeo de demonstração (até 15 min)
- [ ] Relatório de entrega
- [ ] Atualizar `estado-atual.md` com o que foi feito
