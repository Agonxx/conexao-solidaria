# Mensageria, Workers e o segundo banco de dados — discussão em andamento

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

## Em aberto — é AQUI que a conversa parou

### Como compartilhar o contrato do evento entre repos separados

No FCG (monorepo), o padrão documentado em `PADRAO-CODIGO.md` era um projeto `Shared.Contracts.Events` referenciado por quem publica e por quem consome — mesmo assembly, mesmo tipo C#, sem duplicar.

Agora que virou multi-repo (API publicadora + 2 Workers consumidores, cada um no seu próprio repositório `F5-CS-*`), isso deixa de ser trivial. O motivo técnico: o MassTransit, por padrão, identifica o tipo da mensagem pelo **nome completo do tipo + namespace** (ex: `Shared.Contracts.Events.DoacaoRecebidaEvent`) pra rotear no RabbitMQ (exchange/routing key). Se cada repo declarar sua própria classe num namespace diferente, o MassTransit trata como mensagens diferentes e a entrega simplesmente não acontece — é um erro clássico e chato de debugar em sistemas distribuídos.

Três caminhos discutidos, nenhum escolhido ainda:

1. **Pacote NuGet privado** com os contratos de evento, publicado uma vez, referenciado pelos repos que publicam/consomem. Mais correto arquiteturalmente, mas dá trabalho extra de versionamento/publish num prazo de 1 mês.
2. **Repositório de contratos como git submodule**, referenciado pelos outros repos. Meio-termo, mas submodule é notoriamente incômodo no dia a dia (fácil esquecer de atualizar o ponteiro do submodule).
3. **Duplicar a classe do evento em cada repo**, garantindo que namespace + nome completo fiquem idênticos em todos. Mais simples de montar agora; o risco é humano — se alguém mudar uma propriedade num repo e esquecer nos outros, a falha é silenciosa (a mensagem é entregue, mas desserializa errado ou perde campo).

**Próximo passo ao retomar**: perguntar ao Rafael qual dessas três opções ele quer explorar, e só então desenhar/codar a API de Campanhas + Doações e os dois Workers.

### Ainda não resolvido, sem bloquear nada

- Nome definitivo dos dois repositórios de Worker
- Nome do serviço de Campanhas + Doações (ex.: `F5-CS-CampanhasApi`)
- Tecnologia do frontend
- Como o Grafana coleta métricas (Prometheus no meio, como no FCG4, ou exporter direto)
- Escopo de ElasticSearch e Kong Gateway — ainda nem começamos essa conversa
