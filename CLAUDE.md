# Conexão Solidária — Hackathon (último semestre FIAP)

Projeto novo (mesmo espírito de arquitetura de microsserviços do FCG, mas domínio e requisitos diferentes), com base no código do FCG em `C:\Dev\Claudia\FIAP4`. MVP de plataforma digital para a ONG **Esperança Solidária**, gestão de doadores e campanhas de arrecadação, com foco em escalabilidade, observabilidade e automação.

Este repo (`conexao-solidaria`) guarda só documentação. Cada serviço tem seu próprio repo em `C:\Dev\Claudia\FIAP5`. **Fonte de verdade das decisões: [`DECISOES.md`](./DECISOES.md)** (mensageria em [`MENSAGERIA.md`](./MENSAGERIA.md), padrão de código em [`PADRAO-CODIGO.md`](./PADRAO-CODIGO.md)). Enunciado: `Desafio Fiap 5.pdf` neste repo.

## Requisitos funcionais (resumo)

- **Auth/RBAC**: JWT, dois perfis — `GestorONG` e `Doador`. Endpoints de gestão só para `GestorONG`.
- **Campanhas** (GestorONG): criar/editar com `Título`, `Descricao`, `DataInicio`, `DataFim`, `MetaFinanceira`, `Status` (`Ativa`/`Concluida`/`Cancelada`). Regras: `DataFim` não pode ser passado; `MetaFinanceira` > 0.
- **Cadastro de doador** (público): Nome, Email (único), CPF (validar formato), Senha (hash — BCrypt).
- **Painel de transparência** (público): lista campanhas `Ativa` com Título, Meta e Valor Total Arrecadado.
- **Doação** (Doador logado): `IdCampanha` + `ValorDoacao`. Não pode doar para campanha encerrada/cancelada.

## Requisitos técnicos obrigatórios

| Área | Requisito |
|---|---|
| Microsserviços | ≥2 serviços distintos |
| Mensageria | Doação recebida **não** atualiza o banco direto — publica `DoacaoRecebidaEvent`; um Worker separado consome e atualiza o valor arrecadado |
| Kubernetes | Cluster **local** (Docker Desktop K8s), yamls de Deployments/Services/ConfigMaps |
| Observabilidade | `/health` ou `/metrics`; dashboard Grafana com métricas reais |
| CI/CD | Push pra `main`: build .NET + imagem Docker. Deploy opcional |

**Bônus**: testes unitários na esteira de CI; API Gateway (Kong).

## Decisões fechadas

| Item | Decisão |
|---|---|
| API Gateway | Kong (roteamento simples, depois do MVP) |
| Broker | RabbitMQ |
| Observabilidade | Grafana, com Prometheus no meio (copiar do `F4-FCG-MS-Orchestration`) |
| CI/CD | GitHub Actions |
| Kubernetes | Docker Desktop K8s (local) |
| Testes unitários | Sim |
| Diagrama | Miro (versão simples inicial) |
| Frontend | Fora do escopo (demo via Swagger/Postman) |
| ElasticSearch | Fora do escopo |
| Contrato de evento | Classe duplicada por repo, `namespace Shared.Contracts.Events` + teste de `FullName` |

### Serviços e bancos
- `F5-CS-UsersApi` — SQL Server (pronto)
- `F5-CS-CampanhasApi` — Campanhas + Doações, SQL Server, publica `DoacaoRecebidaEvent`
- `F5-CS-DoacaoWorker` — consome `DoacaoRecebidaEvent`, atualiza valor arrecadado
- `F5-CS-FeedbackApi` — MongoDB, feedback do doador sobre a doação

## Entregáveis

1. Repositório público com `README.md` passo a passo (infra + app local).
2. Diagrama de arquitetura + PDF justificando escolha dos bancos.
3. Vídeo de demonstração (máx. 15 min): diagrama → pipeline CI → `kubectl get pods` + Grafana ao vivo → fluxo completo (login JWT → campanha → doação → fila → Worker → painel público).
4. Relatório de entrega (PDF/TXT): grupo, participantes + Discord, links.

## Pontos em aberto

Nenhum decisório no momento; próximo passo é começar `F5-CS-CampanhasApi`.
