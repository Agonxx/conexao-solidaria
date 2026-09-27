# Kubernetes local (Docker Desktop) — Conexão Solidária

Manifests para subir toda a plataforma num cluster **Docker Desktop Kubernetes** local (sem AWS/EKS — diferente do padrão do `F4-FCG-MS-Orchestration`, que é AWS-first).

## Pré-requisitos

- Docker Desktop com Kubernetes habilitado (Settings → Kubernetes → Enable Kubernetes).
- `kubectl` apontando pro contexto `docker-desktop` (`kubectl config current-context`).
- Os 4 repositórios clonados junto de `conexao-solidaria` (mesma estrutura de sempre, em `C:\Dev\Claudia\FIAP5\`).

## Etapa 1 — Build das imagens

```bash
docker build -t f5-cs-usersapi:local     ../../F5-CS-UsersApi
docker build -t f5-cs-campanhasapi:local ../../F5-CS-CampanhasApi
docker build -t f5-cs-doacaoworker:local ../../F5-CS-DoacaoWorker
docker build -t f5-cs-feedbackapi:local  ../../F5-CS-FeedbackApi
```

### Importante: Docker Desktop Kubernetes não compartilha as imagens automaticamente

O node do cluster (`desktop-control-plane`) roda um containerd próprio, separado do daemon Docker onde o `docker build` guarda a imagem — mesmo com o storage driver `overlayfs`/containerd habilitado no Docker Desktop. Sem isso, os pods ficam em `ErrImageNeverPull`. É preciso importar cada imagem manualmente para o containerd do node:

```bash
for img in f5-cs-usersapi f5-cs-campanhasapi f5-cs-doacaoworker f5-cs-feedbackapi; do
  docker save "$img:local" | docker exec -i desktop-control-plane ctr -n k8s.io images import -
done
```

Repita essa importação toda vez que rebuildar uma imagem, e depois:

```bash
kubectl rollout restart deployment <nome> -n conexao-solidaria
```

## Etapa 2 — Namespace e secrets

Os arquivos `*-secret.yaml` são **templates** (`PREENCHER_BASE64`) — nunca commitar com valores reais. Crie os secrets via linha de comando:

```bash
kubectl apply -f namespace.yaml

JWT_KEY="troque-esta-chave-em-producao-conexao-solidaria-2026"  # mesma chave nos 3 secrets abaixo

kubectl create secret generic sqlserver-secret -n conexao-solidaria \
  --from-literal=sa-password="Sa12345678!"

kubectl create secret generic usersapi-secret -n conexao-solidaria \
  --from-literal=connection-string="Server=sqlserver;Database=UsersDB;User Id=sa;Password=Sa12345678!;TrustServerCertificate=True" \
  --from-literal=jwt-secret-key="$JWT_KEY"

kubectl create secret generic campanhasapi-secret -n conexao-solidaria \
  --from-literal=connection-string="Server=sqlserver;Database=CampanhasDB;User Id=sa;Password=Sa12345678!;TrustServerCertificate=True" \
  --from-literal=jwt-secret-key="$JWT_KEY" \
  --from-literal=rabbitmq-username="guest" \
  --from-literal=rabbitmq-password="guest"

kubectl create secret generic doacaoworker-secret -n conexao-solidaria \
  --from-literal=connection-string="Server=sqlserver;Database=CampanhasDB;User Id=sa;Password=Sa12345678!;TrustServerCertificate=True" \
  --from-literal=rabbitmq-username="guest" \
  --from-literal=rabbitmq-password="guest"

kubectl create secret generic feedbackapi-secret -n conexao-solidaria \
  --from-literal=jwt-secret-key="$JWT_KEY"
```

> A senha do SQL Server é uma só, usada nos 3 secrets de connection-string. A `jwt-secret-key` também é uma só, usada em `usersapi`, `campanhasapi` e `feedbackapi` (o mesmo token vale nos três).

## Etapa 3 — ConfigMaps e infraestrutura

```bash
kubectl apply -f usersapi-configmap.yaml -f campanhasapi-configmap.yaml -f doacaoworker-configmap.yaml -f feedbackapi-configmap.yaml
kubectl apply -f sqlserver-deployment.yaml -f sqlserver-service.yaml
kubectl apply -f rabbitmq-deployment.yaml -f rabbitmq-service.yaml
kubectl apply -f mongo-deployment.yaml -f mongo-service.yaml
kubectl apply -f prometheus-rbac.yaml -f prometheus-configmap.yaml -f prometheus-deployment.yaml -f prometheus-service.yaml
kubectl apply -f grafana-configmap.yaml -f grafana-deployment.yaml -f grafana-service.yaml

kubectl wait --for=condition=ready pod -l app=sqlserver -n conexao-solidaria --timeout=180s
kubectl wait --for=condition=ready pod -l app=rabbitmq -n conexao-solidaria --timeout=120s
kubectl wait --for=condition=ready pod -l app=mongo -n conexao-solidaria --timeout=120s
```

## Etapa 4 — Subir os serviços da aplicação (ordem importa)

**O `doacaoworker` precisa subir antes do `campanhasapi`.** A fila do RabbitMQ só é criada quando o consumidor (o Worker) sobe; se a CampanhasApi publicar um evento antes disso, ele se perde (achado do teste integrado, ver [`../docs/estado-atual.md`](../docs/estado-atual.md)). `UsersApi` e `FeedbackApi` fazem `EnsureCreated`/não têm essa dependência, então a ordem entre eles não importa.

```bash
kubectl apply -f usersapi-deployment.yaml -f usersapi-service.yaml
kubectl apply -f doacaoworker-deployment.yaml -f doacaoworker-service.yaml
kubectl apply -f campanhasapi-deployment.yaml -f campanhasapi-service.yaml
kubectl apply -f feedbackapi-deployment.yaml -f feedbackapi-service.yaml

kubectl get pods -n conexao-solidaria -w
```

Aguarde todos os pods `Running` (1/1): `sqlserver`, `rabbitmq`, `mongo`, `usersapi`, `campanhasapi`, `doacaoworker`, `feedbackapi`, `prometheus`, `grafana`.

## Acessando os serviços (todos `ClusterIP` — sem Kong ainda)

```bash
kubectl port-forward svc/usersapi     15001:8080 -n conexao-solidaria
kubectl port-forward svc/campanhasapi 15002:8080 -n conexao-solidaria
kubectl port-forward svc/doacaoworker 15003:8080 -n conexao-solidaria
kubectl port-forward svc/feedbackapi  15004:8080 -n conexao-solidaria
kubectl port-forward svc/rabbitmq     15672:15672 -n conexao-solidaria   # management UI (guest/guest)
kubectl port-forward svc/prometheus   15090:9090  -n conexao-solidaria
kubectl port-forward svc/grafana      15300:3000  -n conexao-solidaria   # admin/admin
```

## Validado em 27/09/2026

Fluxo ponta a ponta rodando neste cluster: cadastro de doador → login (`UsersApi`) → login do gestor seed (`gestor@esperancasolidaria.org` / `Gestor@123`) → criar campanha → doar → `DoacaoRecebidaEvent` no RabbitMQ → `DoacaoWorker` recalcula `ValorArrecadado` → painel de transparência atualizado → `FeedbackApi` valida a doação chamando `campanhasapi:8080` internamente e grava no Mongo. Prometheus descobrindo os 4 pods via annotation `prometheus.io/scrape`.

## Pendências

- Kong (API Gateway) ainda não está nos manifests — próximo passo depois deste MVP de k8s.
- Sem PersistentVolumes: dados do SQL Server/Mongo/RabbitMQ somem se os pods forem recriados (aceitável para demo local).
- CI/CD (GitHub Actions) ainda não builda/publica essas imagens automaticamente.
