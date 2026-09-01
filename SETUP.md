# Setup de ambiente local

Checklist de ferramentas pra desenvolver este projeto do zero numa máquina Windows recém-formatada. Ordem sugerida abaixo.

## 1. Git e GitHub CLI

```
winget install --id Git.Git -e
winget install --id GitHub.cli -e
```

Depois de instalar, **abra um terminal novo** (o PATH só atualiza em sessões novas) e rode:

```
gh auth login
```

Escolha: GitHub.com → HTTPS → Login with a web browser.

Configure a identidade de commit:

```
git config --global user.name "Rafael"
git config --global user.email "rafhita1@gmail.com"
```

## 2. .NET SDK

```
winget install Microsoft.DotNet.SDK.9
winget install Microsoft.DotNet.SDK.8
```

Confirma com `dotnet --list-sdks`. (Se instalar o Visual Studio 2022 com o workload "ASP.NET e desenvolvimento web", o .NET 9 já vem junto — só falta o 8 pra a eventual Lambda/Worker que precisar dele.)

## 3. Docker Desktop + WSL2 + Kubernetes

```
winget install Docker.DockerDesktop
```

O Docker Desktop no Windows precisa do WSL2. Abra um **PowerShell como Administrador** e rode:

```
wsl --install
```

Reinicie a máquina. Depois, abra o Docker Desktop, vá em **Settings → Kubernetes → Enable Kubernetes**, tipo de cluster **Kind**, 1 node (suficiente pra esse projeto, não precisa mais que isso).

Se o Docker reclamar de "Virtualization support not detected" mesmo com a BIOS ok, é sinal de que o WSL2 ainda não foi instalado/reiniciado.

## 4. AWS CLI + SAM CLI (só necessário se for mexer com Lambda/deploy AWS real)

```
winget install Amazon.AWSCLI
winget install Amazon.SAM-CLI
```

## 5. kubectl

Vem junto se habilitar Kubernetes no Docker Desktop. Senão: `winget install Kubernetes.kubectl`.

## 6. IDE

Visual Studio 2022 (17.13+, por causa do formato `.slnx`), JetBrains Rider, ou VS Code + extensão C# Dev Kit.

## 7. Extras úteis

- Postman ou Insomnia (`winget install Postman.Postman`) — ou só `curl`, que já vem no Git Bash
- Azure Data Studio, se quiser inspecionar o SQL Server visualmente (opcional — dá pra fazer tudo via Swagger)

## Estrutura de pastas

`C:\Dev\Claudia` é a pasta raiz de tudo que é trabalhado com Claude Code. Cada repositório do projeto fica como subpasta direta dela (não aninhado):

```
C:\Dev\Claudia\
  conexao-solidaria\      <- este repo (docs/decisões, sem código)
  F5-CS-UsersApi\         <- auth + cadastro de doador
  F5-CS-...\              <- próximos serviços, mesmo padrão
```

## Retomando o projeto depois de clonar de novo

```
gh repo clone Agonxx/conexao-solidaria
gh repo clone Agonxx/F5-CS-UsersApi
```

Leia primeiro `DECISOES.md` (decisões fechadas e pontos em aberto) e `MENSAGERIA.md` (discussão de arquitetura de mensageria/Worker em andamento) antes de continuar o desenvolvimento.
