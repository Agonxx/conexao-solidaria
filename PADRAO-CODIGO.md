# Padrão de código a seguir (herdado do FCG — Fase 3/4)

Análise do estilo usado nas APIs .NET do projeto anterior (`UsersAPI`, `PaymentsAPI`, repos `Agonxx/F4-FCG-MS-*`), pra reaproveitar aqui. A base desse estilo (Program.cs enxuto, extension methods, separação em Extensions/Middlewares) foi escrita pelo Rafael; ajustes pontuais foram feitos com o Claude Code.

## Camadas (Clean Architecture pragmático)

`Api` → `Application` → `Domain` ← `Infrastructure` (Domain não depende de nada, nem de EF/ASP.NET).

- **Domain**: entidades (com DataAnnotations: `[Required]`, `[MaxLength]`, `[Index]`), DTOs, `Interfaces/Repositories`, `Interfaces/Services`, `Interfaces/Utils`, `Events/`, `Constants/` (rotas e roles).
- **Application**: um Service por agregado — injeta repo + utils + publishers de evento, lança `Exception` simples com mensagem em português pra regra de negócio violada (pego genericamente pelo `ExceptionMiddleware`). Zero HTTP aqui.
- **Infrastructure**: `Data/` (DbContext + `Data/ContextConfig/` com `IEntityTypeConfiguration<T>` por entidade, inclusive seed via `HasData` — mantém `OnModelCreating` um one-liner) e `Services/` (implementações de interfaces do Domain, ex. `TokenService`).
- **Api**: só composição e HTTP. Controllers finos, `Extensions/`, `Middlewares/`, `Program.cs`.

## Program.cs como índice, não como lógica

Nada de lógica solta — tudo delegado a extension methods encadeados:

```csharp
builder.Services.AddDatabase(builder.Configuration)
                .AddApplicationServices(builder.Configuration)
                .AddApiDocumentation()
                .AddJWTConfig(builder.Configuration)
                .AddApiCors()
                .AddMessaging(builder.Configuration);
```

Cada um mora em `Api/Extensions/ServiceCollectionExtensions.cs`, convenção `Add<Preocupação>(this IServiceCollection, ...)`. Middlewares custom (`CorrelationIdMiddleware`, `ExceptionMiddleware`, `RequestLoggingMiddleware`, `JwtMiddleware`) em `Api/Middlewares/`, uma classe por preocupação (~20-35 linhas cada), encadeados via `.UseMiddleware<T>()` em ordem fixa: CorrelationId → Exception → RequestLogging → Cors → HttpsRedirection → HttpMetrics → Authentication → Authorization.

## Padrões específicos que valem replicar

- **`InfoToken` scoped**: DTO populado uma vez pelo `JwtMiddleware` a partir das claims do JWT, injetado onde precisar (controllers, repositórios) — evita reparsear claims ou passar `userId` por todo método.
- **Rotas e roles centralizados**: constants tipo `UsuarioApi.Auth`/`.GetById` em vez de strings soltas nos atributos; `Roles.AdminAccess` como string composta (`"Administrador"`, `"Administrador,Usuario"`), lida por um `RoleAuthorize : AuthorizeAttribute, IAuthorizationFilter` customizado.
- **`BaseController` abstrato**: `[Route("api/[controller]")][ApiController][Authorize]` + injeta `InfoToken`, controllers concretos só chamam o service e devolvem `Ok(...)`.
- **Repositórios flat, sem `IRepository<T>` genérico**: métodos exatos que o service precisa (`EmailExists`, `GetMe`), não um CRUD genérico.
- **Consumer de evento (MassTransit)**: `IConsumer<TEvent>` injeta o service de domínio, processa, publica o evento seguinte. É o molde direto pro Worker de Doações deste projeto (`DoacaoRecebidaConsumer`).
- **Eventos em projeto compartilhado**: no FCG, os eventos MassTransit moram em `Shared.Contracts.Events`, referenciado tanto por quem publica quanto por quem consome — mesmo tipo, sem duplicar. Faz sentido replicar como um projeto `Shared/` dentro deste monorepo.
- **Observabilidade de fábrica**: pacote `Prometheus` + `UseHttpMetrics()`/`MapMetrics()` em todo `Program.cs`, mais `CorrelationIdMiddleware`/`RequestLoggingMiddleware` — já cobre o `/metrics` + logs estruturados que o hackathon pede.

## O que NÃO trazer desta vez

O FCG publicava em dois lugares (RabbitMQ + AWS SQS via `SqsPublisher`, com `AddAwsSqs()` e branch condicional pra Lambda). Este projeto não usa nuvem — então é só RabbitMQ via MassTransit, sem `AddAwsSqs`, sem publish condicional, sem SDK da AWS. Mais simples que o original.
