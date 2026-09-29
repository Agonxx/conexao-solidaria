# Mensageria, Worker e o segundo banco de dados

Registro da evolução do desenho de eventos do projeto, da proposta inicial até a versão final implementada.

## Proposta inicial: segundo banco para relatório de encerramento de campanha

Primeira ideia avaliada para justificar o uso do MongoDB, descartada depois (ver seção final):

- Quando o `GestorONG` atualiza uma campanha e muda `Status` para `Concluida`, isso dispararia um evento (`CampanhaEncerradaEvent`).
- Um consumer escutaria esse evento e gravaria um snapshot enxuto no MongoDB: valor total arrecadado, percentual da meta atingido, quantidade de doações — sem lista de doações individuais, só o resumo agregado.
- O gatilho seria a ação manual do Gestor (`Update` → `Concluida`), não uma varredura automática de datas.

A ideia era separar dois fluxos de evento distintos: `DoacaoRecebidaEvent` (atualiza `ValorArrecadado` no SQL Server) e `CampanhaEncerradaEvent` (grava o snapshot no MongoDB), cada um com seu próprio Worker/repo, pelo aprendizado de isolamento de falha e deploy independente.

## Contrato do evento: classe duplicada

Entre as opções avaliadas (NuGet privado, git submodule, classe duplicada), foi escolhida a mesma solução do FCG4: `PaymentsAPI` e `CatalogAPI` duplicam `PaymentProcessedEvent` com `namespace Shared.Contracts.Events`. Sem NuGet/submodule, menos peças de infraestrutura para manter.

- O record `DoacaoRecebidaEvent` é copiado na API de Campanhas e no Worker, ambos em `namespace Shared.Contracts.Events` (o MassTransit roteia pelo nome completo do tipo).
- Mitigação do risco de divergência silenciosa: teste unitário no Worker conferindo o `FullName` do tipo.

## Decisão final: Mongo passa a ser o feedback do doador

O segundo banco de dados deixou de ser o snapshot de encerramento de campanha e passou a guardar o feedback do doador sobre a doação — justificativa mais forte para o PDF de bancos de dados (SQL Server para dados transacionais normalizados; Mongo para um documento de formato flexível, que pode mudar sem migração).

- **Serviço:** `F5-CS-FeedbackApi`, API síncrona com MongoDB. Sem Worker nem evento — só o fluxo `DoacaoRecebidaEvent` → `DoacaoWorker` usa mensageria.
- **Quem envia:** `Doador` logado (JWT do UsersApi), um feedback por doação, só o dono da doação.
- **Documento:** `IdDoacao`, `IdCampanha`, `IdDoador`, data, respostas (rapidez 1–5, dificuldade 1–5, pretende voltar a doar sim/talvez/não, comentário opcional).
- **Gestor:** endpoint de leitura agregada (média por campanha, % que pretende voltar) para `GestorONG`.
- **Sem frontend:** o doador envia o feedback direto no endpoint (Swagger/Postman) após a doação.

Com isso, o segundo Worker e o `CampanhaEncerradaEvent` da proposta inicial deixaram de existir — o projeto usa mensageria só para o fluxo de doação (`DoacaoRecebidaEvent` → `DoacaoWorker`).
