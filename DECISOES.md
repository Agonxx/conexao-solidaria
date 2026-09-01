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
- **MongoDB** → **decidido em 2026-08-25**, para relatório de encerramento de campanha (snapshot enxuto: valor arrecadado, % da meta, quantidade de doações — sem lista individual). Gatilho: `Update` de campanha pra `Status = Concluida` publica um evento, um consumer grava o snapshot. Detalhe completo da discussão em [`MENSAGERIA.md`](./MENSAGERIA.md).

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

- [x] Segundo banco de dados → MongoDB, relatório de encerramento de campanha (ver acima e `MENSAGERIA.md`)
- [x] Onde mora o Worker/Consumer do RabbitMQ → dois Workers separados, um por tipo de evento (ver `MENSAGERIA.md`)
- [ ] Como compartilhar o contrato do evento entre repos separados (NuGet privado / git submodule / classe duplicada) — **discussão em andamento, ver [`MENSAGERIA.md`](./MENSAGERIA.md)**
- [ ] Nome e escopo definitivo dos serviços: API de Campanhas+Doações, e os dois Workers (`F5-CS-DoacaoWorker`/`F5-CS-RelatorioWorker` são só sugestão)
- [ ] Tecnologia do Frontend
- [ ] Como o Grafana coleta métricas (exporter direto vs. Prometheus no meio — Fase 4 já usa Prometheus como intermediário, reaproveitável)
- [ ] Escopo de ElasticSearch e do Kong Gateway — ainda não discutido
