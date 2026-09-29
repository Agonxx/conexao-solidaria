# Estado atual — Conexão Solidária

**Atualizado em 2026-09-28.** Checklist visual em [`checklist.md`](checklist.md).

## Onde paramos
Decisões de arquitetura fechadas (ver [`../DECISOES.md`](../DECISOES.md)). Quatro serviços prontos: `F5-CS-UsersApi`, `F5-CS-CampanhasApi`, `F5-CS-DoacaoWorker` e `F5-CS-FeedbackApi`. K8s local (Docker Desktop) com RabbitMQ, Mongo, Prometheus, Grafana e agora **Kong** está de pé e validado (ver seções abaixo). Falta só os entregáveis finais (diagrama, PDF, vídeo, relatório) e o README consolidado.

## Kong (API Gateway) — pronto e validado (2026-09-28)
Manifests em [`../k8s/`](../k8s/) (`kong-configmap.yaml`, `kong-deployment.yaml`, `kong-service.yaml`). DB-less (`KONG_DATABASE=off`), config declarativa via ConfigMap — sem Postgres extra no cluster.
- Roteamento simples, como decidido: cada API continua validando o próprio JWT, o Kong só encaminha por prefixo de path (`/api/Usuario` → `usersapi`, `/api/Campanha` e `/api/Doacao` → `campanhasapi`, `/api/Feedback` → `feedbackapi`), `strip_path: false`. Sem plugin JWT no Kong (diferente do FCG4) — decisão consciente de manter simples.
- `doacaoworker` não entra no gateway (não expõe API pública, só `/health`/`/metrics` scrapeado direto pelo Prometheus).
- Validado no cluster já de pé: login real do gestor seed via `POST /api/Usuario/Auth` através do Kong (retornou JWT válido), `GET /api/Campanha/Transparencia` retornou dados reais, `GET /api/Feedback/Meus` sem token retornou 401 (backend validando normalmente atrás do proxy), rota inexistente retornou 404.
- Acesso único agora é `kubectl port-forward svc/kong 15000:8000` (proxy) — os `port-forward` direto nos serviços de app viram redundantes, mas continuam funcionando para debug.

## Kubernetes local (Docker Desktop) — pronto e validado (2026-09-27)
Manifests em [`../k8s/`](../k8s/) (ver [README próprio](../k8s/README.md) para o passo a passo). Namespace `conexao-solidaria`, tudo `ClusterIP` (sem Kong ainda).
- Imagens buildadas localmente (`f5-cs-*:local`) e importadas manualmente no containerd do node (`docker exec desktop-control-plane ctr -n k8s.io images import -`) — o Docker Desktop Kubernetes **não** compartilha automaticamente as imagens do `docker build` com o containerd do cluster.
- Ordem de subida: `sqlserver`/`rabbitmq`/`mongo` → `usersapi` + `doacaoworker` (Worker antes da CampanhasApi, por causa do achado da fila) → `campanhasapi` → `feedbackapi`. `UsersApi` e `CampanhasApi` fazem `EnsureCreated`, sem migração manual.
- Secrets criados via `kubectl create secret generic` (os `*-secret.yaml` no repo são só templates com `PREENCHER_BASE64`).
- Prometheus descobrindo os 4 pods via annotation `prometheus.io/scrape`; Grafana com dashboard próprio (`cs-dashboard.json`, painéis de RPS, erros 5xx, latência P95, `doacoes_processadas_total`/`doacoes_ignoradas_total` do Worker).
- **Fluxo ponta a ponta validado**: cadastro de doador → login → login do gestor seed (`gestor@esperancasolidaria.org` / `Gestor@123`) → criar campanha → doar (R$123,45) → evento no RabbitMQ → Worker recalculou → transparência mostrou 123,45 → FeedbackApi validou a doação chamando `campanhasapi:8080` internamente e gravou no Mongo.
- Pendências: sem PersistentVolumes (dados somem se os pods forem recriados — ok para demo local); Kong fora dos manifests ainda.

## Estrutura local
- `C:\Dev\Claudia\FIAP4\` — 5 repos F4-FCG-MS-* (CatalogAPI, NotificationsFunction, PaymentsAPI, UsersAPI, Orchestration), **referência**.
- `C:\Dev\Claudia\FIAP5\` — `conexao-solidaria` (docs), `F5-CS-UsersApi`, `F5-CS-CampanhasApi`, `F5-CS-DoacaoWorker` e `F5-CS-FeedbackApi`.

## Fechado
- Contrato de evento: classe duplicada por repo, `namespace Shared.Contracts.Events`, teste de `FullName` no Worker (padrão do FCG4). Isso substitui a sugestão de projeto `Shared/` do `PADRAO-CODIGO.md`.
- Mongo = feedback do doador (`F5-CS-FeedbackApi`); snapshot de encerramento e 2º Worker descartados.
- Frontend e ElasticSearch fora do escopo; Kong só roteamento simples, depois do MVP.
- Grafana via Prometheus (copiar do `F4-FCG-MS-Orchestration`).

## F5-CS-CampanhasApi (pronto; repo privado no GitHub, commit inicial feito)
- Mesmas camadas e estilo do UsersApi; porta 5002; banco `CampanhasDB`; valida o JWT do UsersApi (mesma `JwtSettings:SecretKey`).
- Endpoints: `GET Campanha/Transparencia` (público); `GetAll`, `GetById/{id}`, `Criar`, `Atualizar/{id}` (`GestorONG`); `POST Doacao/Doar` e `GET Doacao/MinhasDoacoes` (`Doador`).
- Doação grava `Doacao` e publica `DoacaoRecebidaEvent(DoacaoId, CampanhaId, DoadorId, Valor, DoadoEm)`; **não** mexe em `ValorArrecadado` (é do Worker).
- Regras: `Meta > 0`; `DataFim` não pode ser passado (no `Atualizar`, só se a data mudou, para permitir concluir campanha vencida); doar só em campanha `Ativa`.
- Validado: 14 testes passando; smoke test com SQL Server + RabbitMQ reais (tokens gerados à mão com a mesma chave). Login real pelo UsersApi testado depois (ver "Teste integrado").
- Limitação conhecida: salva a doação e depois publica o evento (sem outbox). Vale citar no PDF.
- Máquina sem `dotnet`: build e testes rodam via `docker run mcr.microsoft.com/dotnet/sdk:9.0`.

## F5-CS-DoacaoWorker (pronto; repo privado no GitHub, commit inicial feito)
- Projeto Web SDK com MassTransit (`DoacaoRecebidaConsumer`), `/health` e `/metrics` (contadores `doacoes_processadas_total` e `doacoes_ignoradas_total`); porta 5003. Camadas Domain/Application/Infrastructure/Worker/Tests.
- **Recalcula** `ValorArrecadado` como soma das `Doacoes` da campanha, num único `UPDATE` com subquery (idempotente na reentrega, sem race entre doações simultâneas). Não soma o valor do evento.
- Campanha inexistente: ignora com aviso. Falha transitória: 3 retries de 5 s, depois fila `_error`.
- Schema é da CampanhasApi: o Worker só mapeia `Campanhas.ValorArrecadado` e `Doacoes`, sem `EnsureCreated`.
- Validado: 3 testes; smoke test real (CampanhasApi + Worker + SQL Server + RabbitMQ): 3 doações (10,5 + 20 + 30) e a transparência mostrou 60,50.
- Rodar: ver README (o Worker entra na rede do compose da CampanhasApi).

## Teste integrado (2026-09-26, tudo com login real)
Subidos juntos na mesma rede Docker: SQL Server, RabbitMQ, UsersApi, CampanhasApi, DoacaoWorker, FeedbackApi e MongoDB.
- Login do `GestorONG` (seed) e de doadores cadastrados pelo UsersApi; o JWT vale nos três serviços (mesma `SecretKey`).
- RBAC: doador criando campanha = 403; sem token = 401; gestor enviando feedback = 403.
- Fluxo: campanha → doações → evento → Worker → transparência (70,00 = 10,5 + 20 + 30 + 9,5).
- **Achado:** evento publicado enquanto o Worker não está consumindo se perde (a fila só é criada quando o consumidor sobe). Como o Worker **recalcula** a soma, a doação seguinte corrigiu o valor. Vale citar no PDF; em k8s, subir o Worker antes da CampanhasApi ou declarar a fila.
- Como subir: compose da CampanhasApi (SQL Server + RabbitMQ + API) e os demais como `docker run` na rede `f5-cs-campanhasapi_conexao-solidaria-network`. No Git Bash use `MSYS_NO_PATHCONV=1`, senão `RabbitMQ__VHost=/` vira caminho do Windows.

## F5-CS-FeedbackApi (pronto; repo privado no GitHub, commit inicial feito)
- Mesmas camadas do UsersApi; porta 5004; MongoDB (`FeedbackDB`, coleção `feedbacks`), driver oficial. Entidade sem atributos do Mongo: mapeamento e índices em `Infrastructure/Data/MongoConfig.cs`.
- Endpoints: `POST Feedback/Enviar` e `GET Feedback/Meus` (`Doador`); `GET Feedback/Resumo` (`GestorONG`: total, média de rapidez e dificuldade, % que pretende voltar, por campanha).
- Documento: `IdDoacao`, `IdCampanha`, `IdDoador`, `CriadoEm`, `Rapidez` e `Dificuldade` (1–5), `PretendeVoltar` (Sim/Talvez/Nao, gravado como texto), `Comentario` (até 500).
- "Só do dono": consulta `GET Doacao/MinhasDoacoes` na CampanhasApi repassando o JWT do doador (`DoacaoClient`, `CampanhasApi:BaseUrl`). Se a CampanhasApi estiver fora, o envio falha.
- "Um por doação": checagem no service + índice único em `IdDoacao` (garantia contra corrida).
- Enums em JSON são numéricos (`pretendeVoltar`: 1 Sim, 2 Talvez, 3 Nao), como no resto do projeto.
- Validado: 10 testes; smoke test real cobrindo envio, repetição, doação alheia, nota inválida, 401/403 e resumo.

## CI/CD (GitHub Actions) — pronto (2026-09-27)
Workflow `.github/workflows/ci-cd.yml` nos 4 repos (`build-and-test` + `build-image`): `dotnet build`, `dotnet test` com upload do `.trx`, depois `docker build` só para validar que a imagem builda. **Não publica em nenhum registry** — decisão explícita do usuário para não criar pacotes públicos em `ghcr.io` sem necessidade (o requisito do desafio é só "build .NET + imagem Docker", deploy é opcional). Os 4 pipelines rodaram com sucesso no primeiro push. Sem job de deploy: o cluster k8s é local (Docker Desktop, na máquina do usuário), não alcançável pelo runner do GitHub Actions — deploy continua manual, ver `k8s/README.md`.

## Diagrama de arquitetura e PDF dos bancos — pronto (2026-09-28)
Em [`../entregaveis/`](../entregaveis/): `diagrama-arquitetura.svg`/`.png` (microsserviços, Kong, SQL Server, MongoDB, RabbitMQ, Prometheus/Grafana, com legenda de tipos de chamada) e `justificativa-bancos-de-dados.pdf` (SQL Server para Users/Campanhas/Doações por integridade referencial e atomicidade no recálculo do valor arrecadado; MongoDB para o Feedback por schema mais fluido e documento auto-contido).
- **Sem integração com Miro nesta sessão** (nenhum conector disponível) — o diagrama foi entregue como imagem (PNG, pronta pra colar num board do Miro) e SVG fonte, em vez de montado direto no board.

## README consolidado — pronto (2026-09-28)
[`../README.md`](../README.md) reescrito: status atual, diagrama embutido, tabela de requisitos atendidos, links dos 5 repos, passo a passo resumido do k8s (build → secrets → infra → serviços na ordem certa → Kong), como acessar via Kong, observabilidade, CI/CD e limitações conhecidas. O `k8s/README.md` continua como referência detalhada (valores completos dos secrets, troubleshooting).

## Script de load test da fila — pronto (2026-09-28)
[`scripts/load-test-doacoes.ps1`](../scripts/load-test-doacoes.ps1): dispara N doações concorrentes (`RunspacePool`, compatível com Windows PowerShell 5.1 — máquina não tem `pwsh` 7) contra `POST /api/Doacao/Doar` via Kong. Loga (ou cadastra) um doador de teste, descobre a campanha ativa automaticamente via `Transparencia` (ou aceita `-CampanhaId`), e no fim mostra sucesso/falha, latência média e RPS. Pensado para o vídeo: rodar com RabbitMQ Management e Grafana abertos lado a lado, pra mostrar a fila enchendo e sendo drenada pelo Worker em tempo real.

## Próximos passos
1. Vídeo de demonstração (≤15 min) — usar o load test acima pra ilustrar a fila.
2. Relatório de entrega (grupo, participantes/Discord, links de doc/repo/vídeo).

## Repos
`Agonxx/F5-CS-UsersApi`, `Agonxx/F5-CS-CampanhasApi`, `Agonxx/F5-CS-DoacaoWorker`, `Agonxx/F5-CS-FeedbackApi` e `Agonxx/conexao-solidaria` estão todos **públicos** (verificado em 27/09/2026). Identidade git `Rafael <rafhita1@gmail.com>` configurada só localmente nesses repos (a máquina não tem config global). `gh repo edit --visibility public` é bloqueado pelo classificador de permissões para o Claude Code: o usuário precisa rodar o comando ele mesmo.

## Convenção
Cada repo novo: nome da subpasta já definido (dentro de `FIAP5`, repo `F5-CS-*`). Ao fechar item, atualizar `checklist.md`.
