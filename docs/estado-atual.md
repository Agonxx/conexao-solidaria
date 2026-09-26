# Estado atual — Conexão Solidária

**Atualizado em 2026-09-26 (fim do dia).** Checklist visual em [`checklist.md`](checklist.md).

## Onde paramos
Decisões de arquitetura fechadas (ver [`../DECISOES.md`](../DECISOES.md)). Três serviços prontos: `F5-CS-UsersApi`, `F5-CS-CampanhasApi` e `F5-CS-DoacaoWorker`. O próximo é o `F5-CS-FeedbackApi`.

## Estrutura local
- `C:\Dev\Claudia\FIAP4\` — 5 repos F4-FCG-MS-* (CatalogAPI, NotificationsFunction, PaymentsAPI, UsersAPI, Orchestration), **referência**.
- `C:\Dev\Claudia\FIAP5\` — `conexao-solidaria` (docs), `F5-CS-UsersApi`, `F5-CS-CampanhasApi` e `F5-CS-DoacaoWorker`.

## Fechado
- Contrato de evento: classe duplicada por repo, `namespace Shared.Contracts.Events`, teste de `FullName` no Worker (padrão do FCG4). Isso substitui a sugestão de projeto `Shared/` do `PADRAO-CODIGO.md`.
- Mongo = feedback do doador (`F5-CS-FeedbackApi`); snapshot de encerramento e 2º Worker descartados.
- Frontend e ElasticSearch fora do escopo; Kong só roteamento simples, depois do MVP.
- Grafana via Prometheus (copiar do `F4-FCG-MS-Orchestration`).

## F5-CS-CampanhasApi (pronto, ainda sem repo no GitHub nem commit)
- Mesmas camadas e estilo do UsersApi; porta 5002; banco `CampanhasDB`; valida o JWT do UsersApi (mesma `JwtSettings:SecretKey`).
- Endpoints: `GET Campanha/Transparencia` (público); `GetAll`, `GetById/{id}`, `Criar`, `Atualizar/{id}` (`GestorONG`); `POST Doacao/Doar` e `GET Doacao/MinhasDoacoes` (`Doador`).
- Doação grava `Doacao` e publica `DoacaoRecebidaEvent(DoacaoId, CampanhaId, DoadorId, Valor, DoadoEm)`; **não** mexe em `ValorArrecadado` (é do Worker).
- Regras: `Meta > 0`; `DataFim` não pode ser passado (no `Atualizar`, só se a data mudou, para permitir concluir campanha vencida); doar só em campanha `Ativa`.
- Validado: 14 testes passando; smoke test com SQL Server + RabbitMQ reais (tokens gerados à mão com a mesma chave). O login real pelo UsersApi não foi testado (os dois compose usam o container `sqlserver` e a porta 1433: subir um de cada vez).
- Limitação conhecida: salva a doação e depois publica o evento (sem outbox). Vale citar no PDF.
- Máquina sem `dotnet`: build e testes rodam via `docker run mcr.microsoft.com/dotnet/sdk:9.0`.

## F5-CS-DoacaoWorker (pronto, ainda sem repo no GitHub nem commit)
- Projeto Web SDK com MassTransit (`DoacaoRecebidaConsumer`), `/health` e `/metrics` (contadores `doacoes_processadas_total` e `doacoes_ignoradas_total`); porta 5003. Camadas Domain/Application/Infrastructure/Worker/Tests.
- **Recalcula** `ValorArrecadado` como soma das `Doacoes` da campanha, num único `UPDATE` com subquery (idempotente na reentrega, sem race entre doações simultâneas). Não soma o valor do evento.
- Campanha inexistente: ignora com aviso. Falha transitória: 3 retries de 5 s, depois fila `_error`.
- Schema é da CampanhasApi: o Worker só mapeia `Campanhas.ValorArrecadado` e `Doacoes`, sem `EnsureCreated`.
- Validado: 3 testes; smoke test real (CampanhasApi + Worker + SQL Server + RabbitMQ): 3 doações (10,5 + 20 + 30) e a transparência mostrou 60,50. O login real pelo UsersApi segue não testado.
- Rodar: ver README (o Worker entra na rede do compose da CampanhasApi).

## Próximos passos
1. Criar repos no GitHub e commitar `F5-CS-CampanhasApi` e `F5-CS-DoacaoWorker`; teste integrado com o login do UsersApi.
2. `F5-CS-FeedbackApi` (Mongo, JWT do UsersApi, um feedback por doação).
3. Orquestração k8s + RabbitMQ + Prometheus/Grafana (copiar do Orchestration), CI/CD, Kong, diagrama Miro, PDF dos bancos, vídeo, relatório.

## Convenção
Cada repo novo: nome da subpasta já definido (dentro de `FIAP5`, repo `F5-CS-*`). Ao fechar item, atualizar `checklist.md`.
