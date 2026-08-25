# Conexão Solidária

MVP de plataforma digital para a ONG **Esperança Solidária**, criado para o Hackathon da Pós Tech (FIAP). A ONG atua há mais de 10 anos acolhendo crianças em situação de vulnerabilidade e hoje gerencia doadores e campanhas de arrecadação manualmente — o objetivo do projeto é digitalizar isso com foco em escalabilidade, observabilidade e automação.

> Status: em desenvolvimento — estrutura de serviços ainda sendo definida. Ver [`DECISOES.md`](./DECISOES.md).

## Requisitos funcionais

- **Autenticação e autorização (RBAC)**: JWT, com dois perfis — `GestorONG` e `Doador`. Endpoints de gestão só para `GestorONG`.
- **Gestão de campanhas** (GestorONG): criar/editar campanha com `Título`, `Descricao`, `DataInicio`, `DataFim`, `MetaFinanceira`, `Status` (`Ativa`/`Concluida`/`Cancelada`). Regras: `DataFim` não pode estar no passado; `MetaFinanceira` > 0.
- **Cadastro de doador** (público): Nome Completo, Email (único), CPF (validar formato), Senha (hash — BCrypt).
- **Painel de transparência** (público): lista campanhas `Ativa` com Título, Meta Financeira e Valor Total Arrecadado.
- **Doação** (Doador logado): envia `IdCampanha` + `ValorDoacao`. Não pode doar para campanha encerrada ou cancelada.

## Requisitos técnicos obrigatórios

| Área | Requisito |
|---|---|
| Microsserviços | Pelo menos 2 serviços distintos |
| Mensageria | Doação recebida publica `DoacaoRecebidaEvent` num broker (RabbitMQ ou Kafka) — a API **não** atualiza o valor arrecadado direto no banco; um Worker/Consumer separado consome a fila e atualiza |
| Kubernetes | Cluster local (Minikube, Kind ou Docker Desktop K8s) com yamls de Deployments, Services e ConfigMaps |
| Observabilidade | Endpoint `/health` ou `/metrics`; dashboard Grafana com métricas reais (CPU/memória dos pods ou contagem de requests) |
| CI/CD | Pipeline no push pra `main`: build .NET + geração de imagem Docker (deploy automatizado é opcional) |

**Bônus (não afeta nota)**: testes unitários (xUnit/NUnit) rodando na esteira de CI; API Gateway roteando pros microsserviços.

## Entregáveis

1. Repositório público¹ com este `README.md` contendo passo a passo de como subir a infraestrutura e a aplicação localmente.
2. Diagrama de arquitetura (microsserviços, bancos, broker, observabilidade) + PDF justificando a escolha dos bancos de dados.
3. Vídeo de demonstração (máx. 15 min): diagrama → pipeline de CI gerando imagem → `kubectl get pods` + Grafana ao vivo → fluxo completo (JWT → criar campanha → doação → fila → Worker atualiza → painel público reflete).
4. Relatório de entrega (PDF/TXT): grupo, participantes + Discord, links de documentação/repositório/vídeo.

¹ *Este repositório está privado durante o desenvolvimento; será aberto antes da entrega, conforme exigido.*

## Estrutura de repositórios

Este repositório concentra documentação e decisões. Cada serviço mora em seu próprio repositório, prefixo `F5-CS-{Servico}` (mesmo padrão do FCG4):

- [`F5-CS-UsersApi`](https://github.com/Agonxx/F5-CS-UsersApi) — autenticação JWT + cadastro de doador

## Como rodar localmente

Cada serviço tem seu próprio `docker-compose.yml` e instruções no README do respectivo repositório.
