# Backup de memória do Claude (não é parte do projeto)

> Arquivo pessoal, sem relação com o hackathon Conexão Solidária. Existe só porque a máquina do Rafael vai ser formatada e a memória persistente do Claude Code (`C:\Users\rafaf\.claude\...`) seria perdida junto. **Remover ou mover pra outro lugar antes de tornar este repositório público.**

## Projeto "Hub" pessoal (`C:\Claude`, fora do FIAP)

App pessoal mobile-first, com login, hospedando mini-utilitários que crescem com o tempo: Finanças (transações + resumo mensal + contas recorrentes), Treino de academia (fichas, log de sessão, gráfico de progresso de carga), ToDo. Pensado pra instalar como PWA e acessar do celular de qualquer lugar, não só na rede local.

**Stack:**
- Next.js 16 (App Router, Turbopack no dev) + TypeScript + Tailwind CSS
- Auth: `iron-session` + `bcryptjs` artesanal (sem NextAuth — usuário único fixo, não compensa a dependência). Lógica em `src/lib/session.ts`; toda Server Action chama `requireSession()` direto (proxy matcher não cobre Server Actions).
- Roteamento protegido: `src/proxy.ts` (Next 16 renomeou `middleware.ts` → `proxy.ts`).
- DB: Drizzle ORM + libSQL. Dev local em `file:./local.db`; produção aponta pra Turso via `TURSO_DATABASE_URL`/`TURSO_AUTH_TOKEN`. `drizzle.config.ts` troca de dialect sozinho conforme a env var existir.
- PWA: `@serwist/next`. **Gotcha:** o build do service worker precisa de webpack, mas o Next 16 usa Turbopack por padrão — por isso o script `build` do `package.json` é `next build --webpack`, e o `next.config.ts` desliga o Serwist em dev.
- Gerenciador de pacotes: **npm**, não pnpm (pnpm não instalado, `corepack enable` falha com EPERM sem admin nesta máquina). Turso CLI também não instalado.

**Antes de deployar:** `ADMIN_PASSWORD` em `.env.local` ainda é o placeholder `troque-esta-senha` — trocar antes de produção. Precisa criar um banco Turso real (`turso db create`) e um projeto Vercel, setar as 3 env vars lá, rodar o seed contra o banco de produção.

## Pegadinha do ambiente: teste de apps locais via navegador embutido

Ao testar um app rodando localmente com as ferramentas `mcp__Claude_Browser__*`, cliques (`computer left_click`/`type`) e `screenshot` podem falhar silenciosamente quando o painel do navegador não está sendo renderizado/composto de verdade — o clique "funciona" (retorna sucesso) mas nunca chega na página (`document.activeElement` continua `body`).

**Como aplicar:** se isso acontecer (verificável checando `document.activeElement` ou o `.value` do input via `javascript_tool` depois do clique+type), parar de confiar em `computer` pra formulários. Em vez disso, manipular o DOM direto via `javascript_tool`: setar valores com o truque do native-setter + `dispatchEvent(new Event('input', {bubbles:true}))` (necessário porque React ignora `.value =` direto), depois `form.requestSubmit()`. Sempre escopar a busca do form de forma restrita (ex. `form:has(input[name=foo])`), não `document.querySelector('form')` — páginas com múltiplos forms (ex. um form de logout em outro lugar do layout) podem submeter o form errado. `read_page`/`get_page_text` continuam confiáveis pra ler o estado resultante.
