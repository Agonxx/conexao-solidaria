# Estado atual — Conexão Solidária

**Atualizado em 2026-09-26 (noite).** Checklist visual em [`checklist.md`](checklist.md).

## Onde paramos
Decisões de arquitetura fechadas (ver [`../DECISOES.md`](../DECISOES.md)). Quatro serviços prontos: `F5-CS-UsersApi`, `F5-CS-CampanhasApi`, `F5-CS-DoacaoWorker` e `F5-CS-FeedbackApi`. O próximo bloco é infra: k8s, RabbitMQ, Prometheus/Grafana e CI/CD.

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

## Próximos passos
1. Orquestração k8s (Deployments, Services, ConfigMaps) + RabbitMQ + Prometheus/Grafana (copiar do `F4-FCG-MS-Orchestration`); incluir Mongo e a FeedbackApi (`CampanhasApi__BaseUrl` = nome do Service). Cuidar da ordem de subida do Worker (ver achado acima).
2. CI/CD (GitHub Actions: build, testes, imagem Docker), Kong, diagrama Miro, PDF dos bancos, vídeo, relatório.

## Repos
`Agonxx/F5-CS-CampanhasApi` e `Agonxx/F5-CS-DoacaoWorker` estão **privados** e `Agonxx/F5-CS-FeedbackApi` estão privados; tornar públicos (com UsersApi, FeedbackApi e conexao-solidaria) antes da entrega. Identidade git `Rafael <rafhita1@gmail.com>` configurada só localmente nesses repos (a máquina não tem config global). `gh repo create --public` é bloqueado pelo classificador de permissões: criar privado ou pedir ao usuário.

## Convenção
Cada repo novo: nome da subpasta já definido (dentro de `FIAP5`, repo `F5-CS-*`). Ao fechar item, atualizar `checklist.md`.
