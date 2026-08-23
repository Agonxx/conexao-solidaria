# Conexão Solidária — Hackathon (último semestre FIAP)

Projeto novo, construído do zero (não é continuação do FCG de `C:\FIAP\Fase3`/`Fase4` — mesmo espírito de arquitetura de microsserviços, mas domínio e requisitos diferentes). MVP de plataforma digital para a ONG **Esperança Solidária**, gestão de doadores e campanhas de arrecadação, com foco em escalabilidade, observabilidade e automação.

Enunciado completo em `C:\Claude\Arquivos\conexao-solidaria-hackathon.md`.

## Requisitos funcionais (resumo)

- **Auth/RBAC**: JWT, dois perfis — `GestorONG` e `Doador`. Endpoints de gestão só para `GestorONG`.
- **Campanhas** (GestorONG): criar/editar com `Título`, `Descricao`, `DataInicio`, `DataFim`, `MetaFinanceira`, `Status` (`Ativa`/`Concluida`/`Cancelada`). Regras: `DataFim` não pode ser passado; `MetaFinanceira` > 0.
- **Cadastro de doador** (público): Nome, Email (único), CPF (validar formato), Senha (hash — BCrypt).
- **Painel de transparência** (público): lista campanhas `Ativa` com Título, Meta e Valor Total Arrecadado.
- **Doação** (Doador logado): `IdCampanha` + `ValorDoacao`. Não pode doar para campanha encerrada/cancelada.

## Requisitos técnicos obrigatórios

| Área | Requisito |
|---|---|
| Microsserviços | ≥2 serviços distintos (ex.: API Campanhas/Usuários + Worker de doações) |
| Mensageria | Doação recebida **não** atualiza o banco direto — publica `DoacaoRecebidaEvent` no broker; um Worker/Consumer separado consome e atualiza o valor arrecadado |
| Kubernetes | Cluster **local** (Docker Desktop K8s), yamls de Deployments/Services/ConfigMaps |
| Observabilidade | `/health` ou `/metrics` exposto; dashboard Grafana com métricas reais (CPU/memória dos pods ou contagem de requests) |
| CI/CD | Pipeline no push pra `main`: build .NET + gera imagem Docker. Deploy automatizado é opcional |

**Bônus (não afeta nota)**: testes unitários (xUnit/NUnit) na esteira de CI; API Gateway roteando pros microsserviços.

## Decisões do grupo (fechadas)

| Item | Decisão |
|---|---|
| API Gateway | Kong |
| Broker | RabbitMQ |
| Observabilidade | Grafana |
| CI/CD | GitHub Actions |
| Kubernetes | Docker Desktop K8s (local, não cloud) |
| Testes unitários | Sim, serão implementados |
| Diagrama de arquitetura | Miro (versão simples inicial, detalhar depois) |
| Frontend | Confirmado que vai existir; stack ainda em aberto |

### Bancos de dados
- **SQL Server** → `UsersApi` e API da ONG (Campanhas + Doações)
- **MongoDB** → terceira API, escopo ainda a definir

### Serviços planejados
- `UsersApi` — SQL Server
- API da ONG (nome em aberto) — Campanhas + Doações — SQL Server
- API MongoDB (nome e escopo em aberto)

## Entregáveis

1. Repositório público com `README.md` passo a passo (infra + app local).
2. Diagrama de arquitetura (microsserviços, bancos, broker, observabilidade) + PDF justificando escolha dos bancos.
3. Vídeo de demonstração (máx. 15 min): diagrama → pipeline CI gerando imagem → `kubectl get pods` + Grafana ao vivo → fluxo completo (login JWT → criar campanha → doação → mensagem na fila → Worker atualiza valor → painel público reflete).
4. Relatório de entrega (PDF/TXT): grupo, participantes + Discord, links de doc/repo/vídeo.

## Pontos ainda em aberto

- [ ] Nome da API da ONG (Campanhas + Doações)
- [ ] Nome e escopo da API MongoDB
- [ ] Onde mora o Worker/Consumer do RabbitMQ — serviço dedicado ou dentro de uma API existente
- [ ] Tecnologia/escopo do Frontend (cogitado Blazor)
- [ ] Como o Grafana coleta métricas (exporter direto vs. Prometheus no meio)

## Estrutura de pastas (a criar)

Ainda não há repositórios/código nesta pasta — só este contexto. Ao decidir os nomes dos serviços, seguir o padrão das fases anteriores: cada serviço em sua própria subpasta/repo dentro de `C:\Claude\FIAP5`.
