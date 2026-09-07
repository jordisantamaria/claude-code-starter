---
name: review
description: Revisión de código en 2 modos — PR de GitHub (por URL/número/branch) o local (cambios uncommitted). Para PR mode genera artefacto persistente, aplica el checklist del `AGENTS.md` del repo, detecta referencias huérfanas que otros bots no cazan (i18n keys, componentes con nombre repetido en paths distintos, hooks) y código nuevo que nace sin consumidor (campos calculados que la UI no pinta, helpers exportados que nadie importa, args de callback que el caller ignora), y produce plan de QA manual con URL Amplify del PR + cuentas e2e + escenarios concretos. NUNCA publica el review en GitHub sin confirmación explícita. Úsalo con "/review [pr-number | pr-url | branch | blank]".
argument-hints: [pr-number | pr-url | branch-name | blank for local review]
allowed-tools:
  - Bash(gh pr view:*)
  - Bash(gh pr diff:*)
  - Bash(gh pr checks:*)
  - Bash(gh pr list:*)
  - Bash(gh api:*)
  - Bash(git fetch:*)
  - Bash(git diff:*)
  - Bash(git log:*)
  - Bash(git show:*)
  - Bash(git branch:*)
  - Bash(git ls-tree:*)
  - Bash(git grep:*)
  - Bash(mkdir:*)
  - Bash(jira:*)
  - Read
  - Grep
  - Glob
  - Edit
  - Write
  - AskUserQuestion
  - mcp__notion__notion-search
  - mcp__notion__notion-fetch
  - mcp__slack__conversations_search_messages
  - mcp__slack__conversations_history
  - mcp__slack__conversations_replies
  - mcp__slack__channels_list
---

# /review

Code review en 2 modos. Inspirado en `everything-claude-code:code-review`, ampliado durante meses con lo que fue apareciendo en reviews reales.

**Está pensado para que lo adaptes, no para usarlo tal cual.** Las fuentes de contexto (Jira, Notion, Slack) y las validaciones son las de mi trabajo: cambia las tuyas.

**Input**: `$ARGUMENTS`

---

## Mode Selection

| Input | Modo |
|---|---|
| Número (ej. `1218`, `#1218`) | PR Review Mode |
| URL GitHub (`github.com/.../pull/1218`) | PR Review Mode (extrae número, ignora `#issuecomment-...`) |
| Branch name (ej. `feature/PROJ-123-foo`) | PR Review Mode (busca con `gh pr list --head`) |
| Vacío | PR Review Mode si la rama actual tiene PR asociada; si no, Local Review Mode |

---

## PR Review Mode

Review completo de PR de GitHub. Produce artefacto persistente en `docs/reviews/pr-<N>-review.md` (repo personal del usuario, NO el repo del proyecto cliente — evita commits accidentales y no requiere tocar el `.gitignore` del equipo).

### Phase 1 — FETCH

Resolver input a `{ repo, pr_number }`. El `repo` real se resuelve del PR/branch actual (`gh` detecta el repo del cwd; si el input es un branch, `gh pr list --head` ya lo localiza en su repo). No asumir un repo fijo: dentro de una misma organización cada equipo puede vivir en el suyo. Usar un repo por defecto solo como fallback cuando no se pueda determinar de otro modo.

```bash
gh pr view <N> --repo <repo> --json number,title,body,author,state,baseRefName,headRefName,additions,deletions,changedFiles,files,labels,mergeable
gh pr diff <N> --repo <repo>
gh pr checks <N> --repo <repo>
gh api repos/<repo>/pulls/<N>/comments --paginate    # inline review comments
gh api repos/<repo>/issues/<N>/comments --paginate   # general PR comments
```

Si es del mismo repo que el cwd, fetch del branch para `git grep`:
```bash
git fetch origin pull/<N>/head:pr-<N>-review
git diff main...pr-<N>-review --stat
git log main..pr-<N>-review --oneline
```

Si el PR no existe o `state != OPEN`, abortar con el motivo.

### Phase 2 — CONTEXT

Extraer el contexto del cambio **antes** de leer el diff. El PR description suele ser escueto; el "porqué" del cambio vive fuera del repo (gestor de tickets, docs, chat). Sin esto el review juzga el *cómo* sin saber el *qué*.

| Fuente | Qué extraer | Cómo |
|---|---|---|
| `AGENTS.md` del repo | Reglas vigentes (testing, Prisma, i18n, componentes, exports, naming) | `Read` |
| `docs/` del repo | Convenciones propias del proyecto (modelado de datos, naming) | `Read` |
| PR description | Objetivo, Jira ticket (`<KEY>-<NUM>`, ej. `PROJ-123`), linked issues, test plan | `gh pr view` (Phase 1) |
| Comentarios previos | Qué ya señalaron humanos y bots (`claude[bot]`) — **no duplicar** | `gh api /pulls/<N>/comments` (Phase 1) |
| **PR-Agent (`github-actions`)** | Bloques `PR Reviewer Guide` (entradas `要修正`) y `PR Code Suggestions` (incl. `Previous suggestions`). Comprobar **cuáles siguen sin atender ni justificar** en el código o en un comment del autor | `gh pr view <N> --json comments` |
| **Jira ticket** | Summary, descripción, acceptance criteria, status, assignee, epic | `jira issue view <KEY> --plain` (KEY = ticket extraído, ej. `PROJ-123`) |
| **Notion** | Páginas del equipo que mencionan el ticket (specs, dailies, decisiones) | `mcp__notion__notion-search` con query `<KEY>` (el KEY-NUM extraído) |
| **Slack** | Threads donde se discutió el ticket — decisiones de diseño, aclaraciones del PdM | `mcp__slack__conversations_search_messages` con query `<KEY>` (el KEY-NUM extraído; limita a ~5 mensajes más relevantes) |
| Archivos cambiados | Categorizar: source / test / config / i18n / schema | `gh pr view --json files` (Phase 1) |

**Reglas de uso externo**:

1. Ejecutar Jira + Notion + Slack **en paralelo** (una llamada por herramienta, no secuencial).
2. Extraer el ticket Jira del branch name o título del PR con regex `[A-Z][A-Z0-9]+-\d+` (captura el KEY-NUM completo: `PROJ-123`, `SE-12`...). El project key puede ser cualquiera del proyecto, no solo uno. Usar el KEY-NUM extraído tal cual en las búsquedas de abajo. Si hay varios, priorizar el del título.
3. Si Jira/Notion/Slack no devuelven nada relevante, **no forzar** — anota "sin contexto externo encontrado" y continúa.
4. **Nunca citar tokens ni URLs privadas** en el artefacto final. Citar solo: ticket ID, título, fragmento de decisión textual, fecha.
5. **Privacidad**: si el thread de Slack contiene DMs privados o información sensible (salarios, términos contractuales), excluirlo del artefacto y mencionarlo solo como "existe thread privado relevante, consultar manualmente".

### Phase 3 — REVIEW

Leer cada archivo cambiado **completo**, no solo los hunks del diff. Aplicar checklist en este orden de prioridad:

#### 3a. Referencias huérfanas (alto valor — los bots genéricos fallan aquí)

Si el PR borra algo, `git grep` el símbolo en la rama del PR (no en main) para confirmar cero referencias restantes:

| Tipo de símbolo | Dónde buscar |
|---|---|
| i18n key | `app/i18n/locales/{ja,en}/*.json` + todos los `.tsx` |
| tRPC endpoint | `client/**/*.{ts,tsx}` buscando `trpc.<router>.<endpoint>` |
| Custom hook | Import por nombre en todo `client/` |
| Componente con nombre repetido | Distinguir por path completo (ej. `aggregationPeriod/CurrencyAlert.tsx` ≠ `answerManagement/CurrencyAlert.tsx`) |
| Función logic | Import en routers y otros archivos logic |
| Columna Prisma | `$queryRaw`, mappers, logic |

#### 3b. Código nuevo sin consumidor (dead-on-arrival)

El espejo de 3a: 3a caza referencias que quedan colgando al **borrar** algo; esto caza código que nace **sin nadie que lo llame**. Es el finding que más veces han levantado revisores humanos, y no lo caza nada automático: el símbolo está exportado y su test lo importa, así que `tsc`, los tests y knip pasan en verde.

Para cada símbolo **añadido** por el PR (campo de type, función exportada, prop, parámetro, i18n key), `git grep` en la rama del PR descontando su propio archivo y su `.test.*`. Si no queda ningún hit, es dead-on-arrival:

```bash
git grep -n "<símbolo>" pr-<N>-review -- '*.ts' '*.tsx' | grep -v '\.test\.'
```

| Forma que toma | Señal concreta |
|---|---|
| Campo de un type/union calculado y testeado, pero nunca renderizado | `{ type: "delete"; name: string; rowCount: number }` y la UI solo pinta `name` |
| Helper exportado que nadie importa | el componente hace el `.some(...)` / `.filter(...)` inline en vez de llamarlo |
| Argumento de callback que el caller ignora | `onApply: (entries, changes) => void` y el padre firma `onApply={(entries) => …}` |
| Prop que se pasa pero el hijo no usa, o solo usa para alimentar código muerto | `parentRowCount` / `subItems` que solo entran al helper del punto anterior |
| Parámetro que ninguna llamada varía | todas las llamadas pasan el mismo literal |
| i18n key añadida sin uso | key en `ja` + `en` sin ningún hit en `.tsx` |

Al confirmar uno, **tirar del hilo hacia arriba**: quitar el campo suele dejar sin uso al helper que lo calculaba, y ese a los parámetros y props que lo alimentaban. El finding es la cascada completa, no la línea suelta.

Severidad **MEDIUM** por defecto (cleanup, no bloqueante). Sube a **HIGH** si el código muerto delata una feature a medias — p.ej. un confirm dialog que calcula cuántas filas se borran pero no lo enseña cuando el diseño sí lo pide: ahí el finding real es la funcionalidad que falta, no el código sobrante.

Excepción legítima: código que un ticket ya abierto va a consumir. Solo vale si el PR lo dice explícitamente (descripción o comentario, con el ticket citado). "Por si acaso" no cuenta.

#### 3c. AGENTS.md compliance (solo para código del PR — no audit de lo pre-existente)

| Regla | Verificar |
|---|---|
| **Tests** | Usan `test`, no `it`. Archivo `.test.ts` en mismo directorio que target. |
| **AppError assertion** | `expect(fn()).rejects.toThrow(new AppError({ code, message }))` en un solo `expect`. |
| **Prisma en logic layer** | No usar `prisma` directo en `app/routers/*`. Debe ir en `app/logic/`. |
| **Nested create** | Relaciones padre-hijo con `create` anidado, no 2 inserts separados. |
| **Prisma enum** | Import de `@prisma/client`, no strings literales (`metric_input_type.FORMULA` no `"FORMULA"`). |
| **`lock_version`** | En toda tabla con escritura desde la app. |
| **Zod schemas** | En `app/input/<dominio>/<nombre>Schema.ts`, no inline en routers. |
| **tRPC en hooks** | UI no llama `trpc.xxx.useMutation` directo — va en custom hooks. |
| **Props sin `?` innecesarios** | Si el caller siempre pasa el valor, prop debe ser required. |
| **Sin `as`** | Usar type guards (`x is T`). |
| **Tokens MUI** | `grey.200`, `error.main`. No hardcoded `#EEE`. |
| **i18n ja + en sincronizados** | Mismas keys en ambos. |
| **Named exports** | `export const X = ...`, no `export default`. |
| **Naming** | Evitar `filteredXxx`. Preferir `??` sobre `\|\|`. |
| **Client view boundaries** | `view/<A>` no importa de `view/<B>`. Compartido va a `client/src/{hook,component,types}`. |

#### 3d. Checklist general (7 categorías tipo `everything-claude-code`)

| Categoría | Qué revisar |
|---|---|
| **Correctness** | Off-by-one, condiciones invertidas, arrays vacíos / null, edge cases |
| **Type Safety** | `any`, casts unsafe, opcionales tratados como required, generics faltantes |
| **Pattern Compliance** | AGENTS.md + convenciones del repo (sufijo `__`, T字形ER) |
| **Security** | Injection, auth gaps, secretos, SSRF, path traversal, XSS |
| **Performance** | N+1, missing indexes, loops sin bound, payloads grandes, recalcs innecesarios |
| **Completeness** | Tests, error handling, migraciones incompletas, i18n keys huérfanas |
| **Maintainability** | Magic numbers, nesting > 4, naming pobre (el dead code va en 3b, con su propia cascada) |
| **AI feedback 未対応** | Puntos `要修正` / suggestions de importance alta del PR-Agent que el autor no corrigió ni justificó. Verificar primero contra el código (el bot se equivoca a menudo); si el punto es válido y sigue vivo, es un finding propio del review |

### Phase 4 — VALIDATE

Si el CI remoto ya cubre tsc/lint/test/build, por defecto **no ejecutar local**: leer su estado y ahorrarse la vuelta.

```bash
gh pr checks <N> --repo <repo>
```

Recoger pass/fail de cada check. Solo ejecutar local si:
- El usuario pide validación local explícita.
- CI rojo y quieres reproducir antes de revisar.
- Cambios muy grandes y duda de cobertura.

### Phase 5 — DECIDE

GitHub solo tiene 3 estados de review: **Approve** (✅ verde, puede mergearse), **Comment** (neutral, solo feedback), **Request changes** (🛑 bloquea merge).

| Condición | Decisión |
|---|---|
| 0 CRITICAL/HIGH + CI verde | **Approve** (los MEDIUM/LOW si los hay van como inline nits) |
| HIGH o CI rojo | **Request changes** |
| CRITICAL (vuln de seguridad, data loss) | **Request changes** (con énfasis en el body — "blocker") |
| PR en `draft`, o no quieres aprobar todavía | **Comment** |

Notas:

- "Approve con nits" no es un estado distinto en GitHub — es **Approve** con comentarios inline adjuntos. No inventar etiquetas como "Approve with comments" ni "Block".
- Si en duda entre Approve y Request changes, usar **Comment** y discutir antes.

Severidades:

| Nivel | Criterio |
|---|---|
| **CRITICAL** | Vulnerabilidad de seguridad, pérdida de datos, data corruption |
| **HIGH** | Runtime error probable, breaking change no documentado, regression en feature crítica |
| **MEDIUM** | Calidad / consistencia / cleanup incompleto. No bloqueante. |
| **LOW** | Style, nits, sugerencias opcionales |

### Phase 6 — REPORT

Crear artefacto persistente en `docs/reviews/pr-<N>-review.md` (con `mkdir -p` si la carpeta no existe). **Nunca** dentro del repo del proyecto cliente.

```markdown
# PR Review: #<N> — <title>

**Reviewed**: YYYY-MM-DD
**Author**: <login>
**Branch**: <head> → <base>
**Decision**: Approve | Comment | Request changes

## Summary
<1-3 líneas: qué hace el PR + contexto relevante (ticket `<KEY>-<NUM>`, decisión de chat si aplica) + veredicto alto nivel + estado de comentarios previos resueltos>

## Findings

### CRITICAL
<lista o "None">

### HIGH
<lista o "None">

### MEDIUM
<lista o "None">

### LOW
<lista o "None">

Cada finding:
- **Files**: `path:line` (cita concreta)
- **Issue**: qué pasa
- **Fix**: sugerencia accionable
- **No detectada por**: (si aplica) para justificar que aporta valor sobre bots previos

## Validation Results

| Check | Result | Notes |
|---|---|---|
| tsc | Pass/Fail/Skipped | |
| lint | Pass/Fail/Skipped | |
| test | Pass/Fail/Skipped | |
| build | Pass/Fail/Skipped | |
| format | Pass/Fail/Skipped | |
| knip | Pass/Fail/Skipped | (ojo: knip no detecta i18n keys huérfanas en JSON) |
| Amplify preview | Pass/Fail | URL |

## Files Reviewed
<tabla con file + change type Added/Modified/Deleted + delta lines>

## AGENTS.md Compliance
<lista de checks con ✅/❌ de lo relevante al diff>

## Manual QA Plan

URL del preview del PR (si el proyecto genera uno)

### Smoke check (5 min)
1. Login con la cuenta de pruebas del proyecto.
2. Ir a <ruta afectada>.
3. Confirmar <observación clave>.
4. DevTools console → sin errores rojos.

### Regresión cross-view (si el PR borra algo)
<si aplica: qué otra pantalla usa el símbolo / componente parecido y cómo confirmar que sigue OK>

### Escenarios detallados
<si hace falta, 1-3 escenarios con Precondiciones + Pasos + Resultado esperado + Edge cases>

## Cross-Domain Notes
<contexto del dominio que ayuda al próximo revisor:
 - Decisiones de Slack relacionadas (Plan A, etc.)
 - PRs futuras previstas en la misma línea
 - Deudas técnicas que este PR amplifica o resuelve>

## Decision Rationale
<tabla condición → cumplimiento → decisión>
```

**Imprimir en la conversación solo**: Summary + Findings + Decision + path del artefacto. No pegar el markdown entero (ocupa contexto).

### Phase 7 — PUBLISH (solo con confirmación explícita)

**Reglas durables — leer antes de cualquier `gh` que toque GitHub:**

1. **NUNCA publicar a GitHub automáticamente.** Solo con confirmación explícita del usuario en el turno actual.

2. **NUNCA submitar comments/reviews desde la cuenta humana del usuario.** El submit final es una decisión humana consciente desde la UI de GitHub: la IA redacta, la persona submitea. Un comando que postea de inmediato hace pasar el output del modelo por un comentario humano que nadie ha leído entero.

   **Comandos prohibidos** (todos submitean inmediato):
   - ❌ `gh pr comment <N> --body "..."` (issue comment se postea ya)
   - ❌ `gh pr review <N> --comment --body "..."` (review submitted)
   - ❌ `gh pr review <N> --approve --body "..."` (review submitted)
   - ❌ `gh api .../pulls/<N>/reviews` con `event` = `"COMMENT"` / `"APPROVE"` / `"REQUEST_CHANGES"` (review submitted)

   **Comandos permitidos**:
   - ✅ `gh api .../pulls/<N>/reviews` con JSON SIN `event` y SIN `body` global → crea **pending review**. Usuario submitea desde la UI eligiendo evento + body global.
   - ✅ Copiar al portapapeles para pegarlo a mano en GitHub web (cuando no aplica un review formal — p. ej. un issue comment).

3. **NUNCA imitar en un comentario humano el prefijo o la firma que usa un bot del equipo.** Si el CI comenta con una marca reconocible, esa marca identifica al bot: usarla desde una cuenta humana confunde a quien lee sobre quién escribió qué. Comprobar en el historial de PRs qué marca usa cada uno antes de escribir.

Al final del review, ofrecer opciones (solo las permitidas):

```
¿Cómo dejo el review preparado para que tú lo submites?
1. Pending review con inline comments (default si hay anclajes a líneas)
   → yo dejo el JSON sin event/body global; tú abres la PR, revisas anclas, escribes
     body global y submites desde la UI con Approve/Comment/Request changes.
2. /copy al portapapeles del body global (para issue comment sin review formal)
   → tú lo pegas en GitHub web y le das a "Comment".
3. No postear nada (queda solo en el artefacto local).
```

**Default recomendado: Option 1** (pending review) siempre que haya findings con `path:line` específicos.

Comando para Option 1:

```bash
# Crear el JSON
cat > /tmp/pr-<N>-pending.json <<'EOF'
{
  "commit_id": "<headRefOid>",
  "comments": [
    {
      "path": "ruta/al/archivo.ts",
      "line": 42,
      "side": "RIGHT",
      "body": "comentario inline en japonés (sin prefijo 🤖)"
    }
  ]
}
EOF

# Postear (devuelve state: "PENDING", no submitea)
gh api repos/<repo>/pulls/<N>/reviews --input /tmp/pr-<N>-pending.json
```

Después confirmar al usuario:
- "Review pending creado. Abre <PR_URL> y verás 'You have a pending review (N)'. Botón 'Finish your review' arriba a la derecha de Files changed."

Formato del comentario (review firmada por una persona):
- **Sin** `🤖 [AGENTS.md 参照済]` (eso es solo para `claude[bot]` en CI).
- Tono conciso y profesional, en el registro que ya use el equipo en ese repo.
- Citar `path:line` con backticks.
- Sugerencia de fix concreta, no ambigua.
- Si un bot ya revisó el mismo PR: no duplicar sus puntos; confirmar cuáles quedaron resueltos y aportar lo que no cubrió.

### Phase 8 — OUTPUT

Resumen final al usuario (español, conciso):

```
PR #<N>: <title>
Decision: <Approve | Comment | Request changes>

Issues: <C> critical, <H> high, <M> medium, <L> low
Validation: <X>/<Y> CI checks passed

Artifacts:
  Review: .claude/PRPs/reviews/pr-<N>-review.md
  GitHub: <PR URL>
  Preview del PR: <URL si el proyecto genera una>

Next steps:
  <contextual>
```

---

## Local Review Mode

Revisa cambios uncommitted en el working tree actual antes de hacer commit.

### Phase 1 — GATHER

```bash
git diff --name-only HEAD
git diff HEAD
```

Si no hay cambios: abortar con "Nothing to review."

### Phase 2 — REVIEW

Aplicar secciones **3a** (referencias huérfanas), **3b** (código nuevo sin consumidor) y **3c** (AGENTS.md compliance) del PR Mode. Para 3b, con cambios uncommitted el grep va sobre el working tree: `git grep -n "<símbolo>" -- '*.ts' '*.tsx' | grep -v '\.test\.'`. Omitir 3d general excepto security critical.

### Phase 3 — REPORT

Reportar hallazgos directamente en la conversación (no artefacto). Objetivo: que decidas si commitear o corregir primero.

Si hay CRITICAL, avisar de forma clara antes del commit:

```
⚠ Fix antes de commitear:
  - <critical finding>
  - ...
```

Si solo hay MEDIUM/LOW, dar la info y dejarte decidir.

---

## Reglas de redacción del review

1. **No repetir hallazgos previos** como si fueran nuevos. Si `claude[bot]` ya lo dijo y se resolvió, mencionar "✅ resuelto en `<sha>`". Si no se resolvió, "⚠ pendiente".
2. **Evidencia siempre**: `archivo:línea` + 2-3 líneas de código si ayuda. Sin path concreto un finding no es accionable.
3. **Distinguir severidades claramente** y usar la tabla del Phase 5.
4. **Honestidad sobre lo no revisado**: si no verificaste algo (lógica de negocio específica, UX, integraciones externas), decirlo explícitamente.
5. **Sin emojis en el código**. Emojis solo permitidos en headers de secciones del artefacto (✅ 🐛 ⚠ 🧪) y en el formato `🤖 [AGENTS.md 参照済]`.

## Anti-patrones a evitar

- ❌ Auditar código pre-existente que el PR no toca (scope creep).
- ❌ Repetir findings de `claude[bot]` o revisores humanos previos sin valor añadido.
- ❌ QA manual genérico ("haz click y verifica que funciona"). Tiene que ser específico al cambio.
- ❌ Publicar review en GitHub sin confirmación explícita del usuario.
- ❌ Asumir "CI verde = correcto". Los bugs de UX, lógica de negocio y referencias huérfanas en JSON pasan los tests.
- ❌ Aprobar sin cross-check explícito de referencias huérfanas cuando el PR borra símbolos.
- ❌ Dar por vivo un símbolo nuevo porque tiene test. El test es un consumidor artificial: el grep de 3b lo descuenta, y CI verde no dice nada sobre esto.
- ❌ Pegar el markdown completo del artefacto en la conversación. Solo el summary + path.

## Integración con otras skills

- **copy**: para mandar rápido el comentario japonés al portapapeles antes de postear manualmente.
- **slack**: si el review descubre algo que conviene discutir con el equipo.
- **commit**: tras aplicar cambios sugeridos.
- **daily-notion / daily-prep**: si el PR es relevante para la daily.

## Notas operacionales

- **PR > 20 archivos**: avisar al usuario, preguntar si quiere enfocarse en subset (solo backend, solo un módulo).
- **Merge conflicts** (`mergeable: false`): señalar al principio, bloquea el merge.
- **CI rojo**: listar failing checks al principio, antes del code review.
- **PR no encuentra branch local**: fetch del head del PR via `git fetch origin pull/<N>/head:pr-<N>-review` para permitir `git grep`.
- **Repos sin `AGENTS.md`**: el skill aplica igual, pero el bloque de compliance se queda sin fuente — verificar si el repo tiene su propio documento de convenciones y adaptar el checklist a él.
