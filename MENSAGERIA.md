# Mensageria, Workers e o segundo banco de dados

Este documento existe porque o Rafael pediu explicitamente pra ir com calma nessa parte (mensageria, Worker, ElasticSearch, Gateway) — é o que ele quer aprender e validar de verdade, não só ter implementado. Antes de escrever qualquer código dessa área, releia isso com ele e retome de onde parou.

## Decidido até agora (2026-08-25)

### Segundo banco de dados: MongoDB, para relatório de encerramento de campanha

Não faz sentido forçar o Mongo em cima de `Campanha`/`Doacao` — esses dados são estruturados e relacionais por natureza (datas, status, valores), cabem bem no SQL Server. O uso que justifica o Mongo de verdade:

- Quando o `GestorONG` atualiza uma campanha e muda `Status` para `Concluida`, isso dispara um evento (nome de trabalho: `CampanhaEncerradaEvent`).
- Um consumer escuta esse evento e grava um **snapshot enxuto** no MongoDB: valor total arrecadado, percentual da meta atingido, quantidade de doações.
- **Decidido explicitamente**: sem lista de doações individuais no snapshot — só o resumo agregado.
- O gatilho é a ação manual do Gestor (`Update` → `Concluida`), **não** uma varredura automática de datas (`DataFim` passando não fecha a campanha sozinha — não existe esse comportamento no enunciado).

Isso dá uma justificativa real e defensável pro PDF de "por que os bancos X e Y foram escolhidos": SQL Server pra dados transacionais normalizados, Mongo pra um documento de leitura/relatório desnormalizado, escrito de forma assíncrona.

### Dois Workers separados, não um só

Existem dois fluxos de evento distintos:

1. `DoacaoRecebidaEvent` (publicado pela API de Campanhas/Doações) → atualiza `ValorArrecadado` da campanha no SQL Server
2. `CampanhaEncerradaEvent` (publicado pela mesma API, ao Status virar `Concluida`) → grava o snapshot no MongoDB

Cheguei a sugerir um Worker só (menos peça pra manter num prazo curto), mas o Rafael decidiu **separar em dois serviços/repos**, pelo aprendizado de isolamento de falha/deploy independente. Ainda não batemos o martelo no nome dos repos — sugestão em aberto: `F5-CS-DoacaoWorker` e `F5-CS-RelatorioWorker`.

## Decidido em 2026-09-26: contrato do evento = classe duplicada

Escolhida a opção 3 (das três discutidas: NuGet privado, git submodule, classe duplicada), o mesmo padrão do FCG4: `PaymentsAPI` e `CatalogAPI` duplicam `PaymentProcessedEvent` com `namespace Shared.Contracts.Events`. Sem NuGet/submodule: menos peças num prazo curto.

- Record `DoacaoRecebidaEvent` copiados na API de Campanhas e no Worker, todos em `namespace Shared.Contracts.Events` (o MassTransit roteia pelo nome completo do tipo).
- Mitigação do risco de divergência silenciosa: teste unitário no Worker conferindo o `FullName` do tipo .

### Ainda não resolvido, sem bloquear nada

- Nome definitivo do repositório do Worker e da FeedbackApi
- Nome do serviço de Campanhas + Doações (ex.: `F5-CS-CampanhasApi`)
- Como o Grafana coleta métricas (Prometheus no meio, como no FCG4, ou exporter direto)
- Kong entra depois do MVP; ElasticSearch descartado (ver `DECISOES.md`)

## Revisão em 2026-09-26: Mongo passa a ser o feedback do doador

Substitui o snapshot de encerramento de campanha (seções acima sobre `CampanhaEncerradaEvent`, snapshot e segundo Worker ficam como histórico, **descartadas**).

- **Serviço:** `F5-CS-FeedbackApi`, API síncrona com MongoDB. Sem Worker nem evento — só o fluxo `DoacaoRecebidaEvent` → `DoacaoWorker` usa mensageria.
- **Quem envia:** `Doador` logado (JWT do UsersApi), um feedback por doação, só do dono da doação.
- **Documento:** `IdDoacao`, `IdCampanha`, `IdDoador`, data, respostas (rapidez 1–5, dificuldade 1–5, pretende voltar a doar sim/talvez/não, comentário opcional).
- **Gestor:** endpoint de leitura agregada (média por campanha, % que pretende voltar) para `GestorONG`.
- **Justificativa pro PDF:** SQL Server pra dados transacionais; Mongo pra documento de formato flexível (perguntas podem mudar sem migração).
- **Sem frontend:** o doador envia o feedback direto no endpoint (Swagger/Postman) após a doação; sem convite automático.
