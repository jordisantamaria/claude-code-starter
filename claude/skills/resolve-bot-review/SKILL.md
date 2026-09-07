---
name: resolve-bot-review
description: Atender reviews de BOTS en GitHub PRs (GitHub Copilot, PR-Agent/qodo, github-actions). Cubre las DOS superficies del bot - los review threads inline Y los issue comments del PR-Agent ("PR Reviewer Guide" con sus 要修正 y "PR Code Suggestions" con sus suggestions). Clasifica cada punto (fix válido / intencional / obsoleto / incorrecto), aplica los fixes que tocan (con verificación + commit/push), responde DENTRO de cada thread + lo resuelve, y para los issue comments deja UN comment con el veredicto punto por punto. Distinto de /resolve-review (que es para reviews de HUMANOS y solo genera drafts a mano). Úsalo con "/resolve-bot-review [pr-number | blank=PR de la branch actual]".
argument-hints: [pr-number | blank]
allowed-tools:
  - Bash(gh pr view:*)
  - Bash(gh pr diff:*)
  - Bash(gh api:*)
  - Bash(git:*)
  - Bash(npx:*)
  - Bash(grep:*)
  - Read
  - Edit
  - Write
  - Grep
  - Glob
---

# /resolve-bot-review

Skill para **atender una review de un BOT** en un GitHub PR (GitHub Copilot, PR-Agent/qodo, github-actions).

> **Diferencia clave con `/resolve-review`**: aquél es para HUMANOS — genera drafts en un archivo y el usuario los pega a mano, NUNCA postea automáticamente. Esta skill es para BOTS — **sí responde en el thread y lo resuelve directamente**, porque las respuestas a un bot son mecánicas (qué se arregló / por qué es intencional) y no requieren el matiz de una respuesta a un compañero. Si el reviewer es humano → usar `/resolve-review`.

**Input**: `$ARGUMENTS` = número de PR, o vacío = PR de la branch actual (`gh pr view --json number`).

---

## Reglas durables (los errores a no repetir)

- Un bot deja feedback en **dos superficies**. Atender siempre **las dos**:
  1. **Review threads inline** (Copilot, y PR-Agent con `/improve --extended`).
  2. **Issue comments del PR-Agent** (`github-actions`): `## PR Reviewer Guide 🔍` (bloque `⚡ Recommended focus areas`, con entradas marcadas **要修正**) y `## PR Code Suggestions ✨` (tabla de suggestions + `<details>Previous suggestions</details>`).
- ✅ Threads → responder dentro (`addPullRequestReviewThreadReply`) y **resolverlos** (`resolveReviewThread`).
- ✅ Issue comments → **no tienen thread que resolver**: dejar **UN** issue comment con el veredicto punto por punto (ver §4b). Es la única excepción a la regla de abajo.
- ❌ **NUNCA** un issue comment general que resuma los *threads*. El feedback de thread vive en su thread; un comment suelto los deja sin resolver y ensucia el timeline.
- ❌ No resolver un thread cuyo fix válido aún no se aplicó. Primero el fix (o la justificación), luego responder + resolver.
- ❌ No ignorar un 要修正 por venir de un bot. Si no se corrige, hay que **escribir la razón en el PR**: un revisor humano leerá el bloque del bot y pedirá cuentas (`対応するか、しない理由をコメントください`).

---

## Flujo

### 1. FETCH — threads no resueltos del bot

```bash
PR=<n>   # o: gh pr view --json number -q .number
gh api graphql -f query='
query($o:String!,$r:String!,$n:Int!){
  repository(owner:$o,name:$r){ pullRequest(number:$n){
    reviewThreads(first:60){ nodes{
      id isResolved isOutdated path
      comments(first:1){ nodes{ author{login} body } }
    }}
  }}
}' -f o=<org> -f r=<repo> -F n=$PR \
  --jq '.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved==false)'
```

Filtrar por autor bot: `copilot-pull-request-reviewer`, `github-actions`, `qodo*`, cualquier `*[bot]`.

### 1b. FETCH — issue comments del PR-Agent

```bash
gh pr view $PR --json comments \
  --jq '.comments[] | select(.author.login=="github-actions") | .body' > /tmp/pr-agent.md
```

Extraer de ahí **todos** los puntos, sin saltarse ninguno:

| Bloque | Qué extraer |
|---|---|
| `## PR Reviewer Guide 🔍` → `⚡ Recommended focus areas for review` | cada `<details>` cuyo `<summary>` empieza por **要修正** (o `Possible issue` en inglés) |
| `## PR Code Suggestions ✨` | cada fila de la tabla: categoría (`Possible issue` / `Security` / `General`), título, diff propuesto, `Suggestion importance[1-10]` e Impact |
| `<details><summary>Previous suggestions</summary>` | **también cuenta**: son suggestions de commits anteriores que nunca se atendieron. Descartar solo las que el código actual ya haya resuelto (verificando el archivo, no asumiendo) |

Los `importance ≥ 6` / Impact Medium y **todo lo marcado 要修正** son de atención obligatoria: se corrigen o se justifica por escrito.

### 2. CLASSIFY — cada punto (thread o issue comment), uno de:

| Tipo | Señal | Acción |
|---|---|---|
| **fix válido** | apunta a código actual, mejora real (a11y, key inestable, bug) | aplicar fix → responder con commit hash → resolver |
| **intencional** | el "problema" es una decisión tomada (mock hasta tarea X, valor de diseño Figma, scope) | NO cambiar código → responder explicando por qué → resolver |
| **incorrecto** | la premisa del bot es falsa (p.ej. "regresión respecto al comportamiento anterior" cuando el código anterior hacía lo mismo) | NO cambiar código → responder **citando el código previo/actual que lo desmiente** → resolver |
| **obsoleto** | `isOutdated=true`, apunta a archivo borrado/movido/refactorizado | responder "ya no aplica / resuelto en el refactor" → resolver |
| **PR description** | pide actualizar descripción | actualizar body con `gh pr edit` → responder → resolver |

Verificar siempre el código antes de clasificar como "intencional / incorrecto / obsoleto" — **leer el diff y el archivo, y en regresiones alegadas leer también la versión de la base branch** (`git show <base>:<path>`). No asumir.

### 3. FIX — aplicar los de "fix válido"

- Editar el código. Verificar: `npx tsc --noEmit`, `npx eslint <files>`, `npx prettier --check <files>`, `npx vitest run <dir>`.
- Agrupar los fixes y hacer **un commit + push** (estilo del repo). Capturar el hash para citarlo en las respuestas.
- Si un fix dispara el `format-check` del CI, correr `prettier --write` antes (error común: correr eslint pero no prettier).

### 4. REPLY + RESOLVE — por cada thread

```bash
REPLY='mutation($tid:ID!,$body:String!){addPullRequestReviewThreadReply(input:{pullRequestReviewThreadId:$tid,body:$body}){comment{id}}}'
RESOLVE='mutation($tid:ID!){resolveReviewThread(input:{threadId:$tid}){thread{isResolved}}}'
gh api graphql -f query="$REPLY"   -f tid="$TID" -f body="$MSG"
gh api graphql -f query="$RESOLVE" -f tid="$TID" --jq '.data.resolveReviewThread.thread.isResolved'
```

- Respuesta **en el idioma del PR** (el del PR), breve (1-2 líneas).
  - fix válido → `<qué se cambió>（<commit hash>）。`
  - intencional → `<por qué es así>。<referencia: tarea/Figma/scope>。`
  - obsoleto → `共通化/リファクタに伴い当該箇所は削除済みです。<dónde quedó ahora>。`
- Loop sobre todos los threads (un `while read` con `thread_id|||mensaje`).

### 4b. COMMENT — veredicto de los puntos del PR-Agent (issue comments)

Un solo comment, en japonés, con **una línea por punto** y el mismo orden que el bot. Formato:

```markdown
PR-Agent の指摘を一通り確認しました。

**対応したもの**
- <指摘のタイトル>: <何をどう直したか>（<commit hash>）
**対応しないもの**
- <指摘のタイトル>: <理由>。<根拠となるコード/仕様/設計への参照>
```

Reglas de esa respuesta:
- Nunca dejar un punto fuera de la lista, ni siquiera los `Low`. Si es un nit sin valor, decirlo explícitamente (`影響が無いため見送ります`).
- El "no" siempre lleva **razón verificable** (código citado, decisión de diseño, alcance de la tarea), no `必須ではない` a secas.
- Si un punto abre una pregunta de especificación (comportamiento de filtros, UX), no decidir solo: preguntar al usuario antes de redactar.
- **Nunca postear sin confirmación explícita del usuario** — mismo criterio que `/review`: se le enseña el draft y él dice si va.

### 5. VERIFY

```bash
gh api graphql -f query='query($o:String!,$r:String!,$n:Int!){repository(owner:$o,name:$r){pullRequest(number:$n){reviewThreads(first:60){nodes{isResolved}}}}}' \
  -f o=<org> -f r=<repo> -F n=$PR \
  --jq '[.data.repository.pullRequest.reviewThreads.nodes[]|select(.isResolved==false)]|length'
```

Debe devolver `0`. Reportar al usuario: N threads atendidos (X fixes en `<hash>`, Y intencionales, Z obsoletos) **+ M puntos del PR-Agent** (Reviewer Guide / Code Suggestions) con su veredicto.

Comprobar además que **ningún 要修正 ni suggestion con importance ≥ 6 quedó sin mención** en el comment de §4b.

---

## No tocar el estado del PR

- **NO** marcar el PR como Ready for review (`gh pr ready`). Eso lo hace el usuario tras su QA. Esta skill solo atiende los threads.
- LOW/nits sin regla y "QA visual" no son fixes de código — anotarlos en el reporte, no commitear por ellos.

---

## Anti-patrones

- ❌ Issue comment general resumiendo los **threads** (los deja sin resolver). Responder en cada thread. El comment de §4b es solo para los bloques del PR-Agent, que no tienen thread.
- ❌ Atender solo los threads y dar el PR por limpio: el `PR Reviewer Guide` y las `PR Code Suggestions` (incluidas las `Previous suggestions`) son feedback igual de visible para los revisores humanos.
- ❌ Resolver un thread con fix válido sin aplicar el fix.
- ❌ Clasificar "intencional/obsoleto" sin leer el código.
- ❌ Marcar el PR Ready o tocar el draft state.
- ❌ Usar esta skill con reviewer humano → usar `/resolve-review`.

## Integración

- **`/resolve-review`**: la versión para HUMANOS (drafts a mano, nunca auto-post).
- **`/pr`**: si un thread pide actualizar la descripción del PR.
