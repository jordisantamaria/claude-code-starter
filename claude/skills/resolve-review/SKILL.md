---
name: resolve-review
description: Resolver review recibida hacia mí (no review hecha por mí). Procesa comments en Notion subpages o GitHub PR threads, los clasifica, investiga el código para verificar correcciones técnicas, genera un archivo de seguimiento persistente fuera del repo (~/.claude/reviews/<project>/<slug>.md) con drafts de respuesta en idioma del review, y aplica ediciones al doc/código con confirmación. NUNCA postea respuestas a hilos automáticamente — el usuario las copia y pega a mano. Diferente de /review (que es para HACER review). Úsalo con "/resolve-review [notion-url | github-pr-url | blank=continuar la review más reciente del proyecto]".
argument-hints: [notion-url | github-pr-url | pr-number | blank]
allowed-tools:
  - Bash(mkdir:*)
  - Bash(ls:*)
  - Bash(find:*)
  - Bash(gh pr view:*)
  - Bash(gh pr diff:*)
  - Bash(gh api:*)
  - Bash(git grep:*)
  - Bash(git diff:*)
  - Bash(git log:*)
  - Bash(grep:*)
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - AskUserQuestion
  - mcp__notion__notion-fetch
  - mcp__notion__notion-get-comments
  - mcp__notion__notion-update-page
  - mcp__notion__notion-create-comment
---

# /resolve-review

Skill para **resolver una review recibida hacia mí** (no para hacer review hacia otros — para eso está `/review`).

**Input**: `$ARGUMENTS`

---

## Mode Selection

| Input | Modo |
|---|---|
| URL Notion (`notion.so/...` o `*.notion.site`) | Notion Mode |
| URL GitHub PR (`github.com/.../pull/N`) o número | GitHub Mode |
| Vacío | Continuar la review más reciente del proyecto actual (lee `~/.claude/reviews/<project>/`) |

`<project>` = `basename(cwd)`.

---

## Principios fundamentales

1. **NUNCA postear respuestas en hilos automáticamente.** Esto es regla durable del usuario (ver memoria `feedback_no_auto_commit.md` aplicado a comunicaciones humanas). El usuario copia y pega los drafts a mano.
2. **Aplicar ediciones al doc / código requiere confirmación explícita** del usuario antes de cada batch.
3. **Archivo de seguimiento vive fuera del repo del proyecto** en `~/.claude/reviews/<project-slug>/<review-slug>.md`. Nunca crear archivos de review dentro del repo del cliente (riesgo de commit accidental, además gitignored ya cubre el caso pero no queremos depender de eso).
4. **Idiomas en el archivo**:
   - Comentario original: idioma original (el del PR)
   - Investigación, decisiones, plan: español (idioma del usuario)
   - Mensaje de respuesta drafted: idioma del review (el del PR)
5. **Verificación antes de aceptar correcciones técnicas**: si el revisor dice "X no se chequea aquí", leer el código para confirmar antes de marcar como ✅ accepted. Citar `archivo:línea` en la investigación.
6. **No inventar caracteres difíciles de leer**. Evitar `§` (section sign, U+00A7) — usar el título descriptivo de la sección. Evitar `_` al inicio de palabra fuera de backticks (parser markdown puede activar italic).

---

## Phases

### Phase 1 — DETECT

Resolver `$ARGUMENTS` a `{ source, source_id, source_url, project_slug, review_slug }`:

| Source | Cómo extraer ID |
|---|---|
| Notion | URL → 32-char hex después del último `/` o `-`. Limpiar parámetros `?d=...#...`. |
| GitHub PR | URL `github.com/<org>/<repo>/pull/<N>` → `{ org, repo, N }`. Default org/repo: `<org>/<repo>` si solo se da número. |
| Blank | `ls -t ~/.claude/reviews/<project>/*.md` → archivo más reciente. Abortar con mensaje útil si no hay. |

`project_slug = basename(cwd)`.
`review_slug` se deriva: para Notion `notion-<short-title-slug>`, para GitHub `pr-<N>`.

```bash
mkdir -p ~/.claude/reviews/<project_slug>/
```

### Phase 2 — FETCH

#### Notion Mode

```
mcp__notion__notion-fetch              { id: <source_id>, include_discussions: true }
mcp__notion__notion-get-comments       { page_id: <source_id>, include_all_blocks: true, include_resolved: false }
```

Si la página tiene `<page-discussions discussion-count="N">` con N > shown, llamar también con `include_resolved: true` por completitud.

Si el doc tiene **subpáginas** (común en Notion para docs largos divididos), iterar:
1. `notion-fetch` con `include_discussions: true` en cada subpágina (en paralelo)
2. `notion-get-comments include_all_blocks: true` en cada subpágina

Para cada hilo recolectar:
- `discussion_id`, `block_id`, `comment_id`
- `user_url` del autor
- `datetime`
- `text_context` (la cita del bloque al que está anclado el comentario)
- `image-attached-count`
- Cuerpo del comentario completo

#### GitHub Mode

```bash
gh pr view <N> --repo <repo> --json number,title,body,author,state,baseRefName,headRefName,files,labels
gh pr diff <N> --repo <repo>
gh api repos/<repo>/pulls/<N>/comments --paginate    # inline review comments
gh api repos/<repo>/issues/<N>/comments --paginate   # general PR comments
gh api repos/<repo>/pulls/<N>/reviews --paginate     # review summaries
```

Para inline comments capturar: `path`, `line`, `diff_hunk`, `body`, `user.login`, `created_at`, `id`.
Para general comments: `body`, `user.login`, `created_at`, `id`.

### Phase 3 — CLASSIFY

Para cada hilo, asignar uno de:

| Tipo | Descripción | Acción típica |
|---|---|---|
| **corrección técnica** | "Esto está mal porque X" | Verificar en código, aceptar/rebatir, editar doc |
| **decisión de scope** | "Esto sobra / esto falta" | Confirmar al usuario, aplicar |
| **derivación a tercero** | "@otro pls confirma" | Pingar al tercero por separado, no resolver yo |
| **información** | "FYI esto está en PR #X" | Anotar en doc, agradecer en respuesta |
| **introductorio** | Mensaje meta sin contenido específico | Respuesta corta de ack |
| **pregunta abierta** | Necesita análisis o decisión | Investigar y proponer respuesta |

### Phase 4 — INVESTIGATE

**Solo para correcciones técnicas y preguntas abiertas.** Las decisiones de scope y derivaciones no necesitan investigación de código.

Por cada hilo a investigar:
1. Identificar `archivo:línea` o concepto técnico mencionado
2. `Read` archivo completo (no solo la línea citada — entender contexto)
3. Si la afirmación es del tipo "X no se chequea aquí", trazar la cadena: dónde se llama, qué valida, qué valores produce
4. **Citar evidencia**: `archivo:línea` con la lógica relevante
5. Conclusión: ✅ revisor tiene razón / ❌ revisor se equivoca / 🟡 parcialmente / ⚪ no concluyente

Si el comentario tiene **imagen adjunta** y MCP no la sirve, anotar `🟡 investigating — pendiente describir captura` y pedir al usuario que la describa, O ofrecer leer el código UI relacionado para inferir.

### Phase 5 — DRAFT

Escribir/actualizar el archivo `~/.claude/reviews/<project>/<slug>.md` con el formato siguiente. **Sobrescribe** el archivo entero por consistencia (no edits parciales, evita drift).

**Principio clave del formato**: cada hilo es **autocontenido** — todos los checkboxes (doc aplicado, respondido en Notion, tareas extra) viven dentro del bloque del hilo. NO crear secciones agregadas tipo "Plan de ejecución" / "Bloque 1, 2, 3" al final, porque obligan al usuario a saltar entre secciones para tickear cosas. La tabla resumen al inicio es solo lectura, los `[x]` reales se marcan en cada hilo.

```markdown
# Review: <título>

- **Source**: Notion | GitHub PR
- **URL**: <source_url>
- **Revisor(es)**: <nombres>
- **Created**: YYYY-MM-DD

**Alias** (si aplica):
- `final` = subpágina "..." (URL)
- `TC` = subpágina "..." (URL)

**Cómo usar este archivo:**
- Cada hilo tiene su propio bloque con todos los checks y el draft.
- Para retomar: `grep -n '\- \[ \]' <ruta-archivo>`.
- Marcar `[x]` directamente en cada hilo cuando se postea / se completa una acción.

## Resumen

| # | Sección | Doc | Respondido | Extra |
|---|---------|-----|------------|-------|
| 1 | <alias · sección> | ✅ | ✅ | — |
| 2 | ... | ✅ | ⬜ | ✅ ticket #N |
| 3 | ... | — | ⬜ | ⬜ ping <persona> |

> Convenciones tabla: ✅ hecho · ⬜ pendiente · — no aplica.

---

## #N — <alias · sección descriptiva>

- **Origen**: <URL al hilo específico, con discussion ID>
- **Revisor**: <nombre> · YYYY-MM-DD HH:MM
- **Tipo**: <corrección técnica | decisión scope | derivación | info | intro>

**Comentario** (idioma original):
> <cita literal>

**Investigación:** <solo para correcciones técnicas / preguntas. Citar archivo:línea. Omitir entera si no aplica.>

**Estado:**
- [x/ ] Doc Notion aplicado: <descripción concreta del edit, o "— no requiere doc edit">
- [x/ ] Respondido en Notion (<fecha si ya hecho>)
- [x/ ] <tarea extra: ticket creado / ping persona / crear branch / etc. — solo si aplica>

**Draft** (idioma del review, listo para postear a mano):
> <draft>
```

**Reglas para los checkboxes del bloque "Estado":**

1. **Doc Notion aplicado**: si el hilo no requiere ediciones de doc/código, escribir la línea con `— no requiere doc edit` y marcar `[x]`. Si requiere y aún no está, `[ ]` con descripción.
2. **Respondido en Notion**: SIEMPRE presente, default `[ ]`. Marcar `[x]` solo cuando el usuario haya posteado manualmente en el hilo (verificable vía `notion-get-comments`).
3. **Tareas extra**: una línea por tarea — crear ticket, pingar persona, abrir branch, etc. Si no hay extras, omitir esta línea entera.

**Multi-comentario en mismo hilo (replies):**
Si alguien comenta y otra persona responde en el mismo discussion, **integrar ambos en un solo bloque #N** (no crear #N y #N+1 separados). Mostrar `**Comentario <autor>**` y `**Reply <autor>**` por separado, y un único `Draft` que conteste a ambos. El header lista los dos: `<autor> · ... → reply <autor> · ...`.

### Formato del draft

**GitHub PR propio + fix ya commiteado — formato FIJO y mínimo (2 líneas):**

```
修正しました。https://github.com/<org>/<repo>/commit/<sha-completo>
<1 línea, pocas palabras, de qué incorpora el fix>
```

Nada más. Sin agradecimientos (`ご指摘ありがとうございます`), sin explicar por qué existía el residuo, sin justificar lo que se deja fuera, sin repetir lo que el reviewer ya dijo, sin ofrecer alternativas ni preguntar si quieren más. Si hay algo colateral que el reviewer debe saber, cabe en esa única línea o no va.

El SHA va **completo** (40 chars) porque la URL del commit es clicable — no contradice la regla de no citar SHAs sueltos, que aplica a los comments que YO escribo revisando a otros.

**Otros casos** (Notion, pregunta abierta, decisión de scope, fix aún no commiteado): 1-2 líneas, mismo espíritu. Estilo correcto: `ご指摘の通り、X でした。Y を修正しました。` Los detalles técnicos van en el archivo de seguimiento, no en el hilo.

**Entrega:** el draft se le pasa al usuario y ahí termina el turno. No preguntar "¿lo posteo?" ni "¿marco el hilo como resuelto?" — las respuestas a humanos las postea siempre él. (Bots = caso contrario: ver `/resolve-bot-review`.)

### Reglas de naming

- **Alias para subpáginas con nombres largos**: usar prefijo corto sin underscore inicial (`final`, no `_final`).
- **Referencias a secciones**: usar **título descriptivo** de la sección (ej. `フロント`, `対照表 (C115)`), nunca `§N` (carácter `§` poco legible).
- **Backticks** en nombres con caracteres especiales (`` `_TC様向け` ``) si hay que referenciar el original.
- **Links a hilos específicos**: incluir el discussion ID en la URL para abrir directo en Notion.

### Phase 6 — APPLY (con confirmación)

Tras presentar el archivo al usuario, ofrecer aplicar ediciones agrupadas:

```
He preparado N ediciones al doc Notion / PR código. Aplico ahora?
1. Sí, todas
2. Sí pero solo subset (especifico cuáles)
3. No, lo hago yo a mano
```

Si confirma, aplicar via:

#### Notion
```
mcp__notion__notion-update-page  # con bloque actualizado
```

#### GitHub
- Para inline comment fixes → `Edit` o `Write` en el archivo afectado
- Si requiere commit/push → seguir reglas de `feedback_no_auto_commit.md` (NUNCA auto-commit)

Tras aplicar, en cada hilo del archivo de review marcar el checkbox `[x] Doc Notion aplicado` con descripción concreta. Actualizar también la columna `Doc` en la tabla resumen a ✅. Re-Write del archivo entero.

### Phase 7 — HANDOFF (NO postear)

**No postear respuestas en hilos automáticamente.** Output al usuario:

```
Review procesada: N hilos
- 🟢 ready: <X> (drafts listos)
- 🟡 investigating: <Y> (necesitan input)
- ⚪ pending: <Z> (derivaciones, bloqueos externos)

Archivo: ~/.claude/reviews/<project>/<slug>.md
Atajo nvim: <leader>r

Próximos pasos manuales:
1. Revisar drafts en <leader>r
2. Copiar respuestas y postear a mano en cada hilo (URLs incluidos)
3. Pingar a <tercero> si aplica
```

Si pide ayuda copiando, sugerir `/copy` para mandar al portapapeles cada draft uno a uno.

---

## Persistencia entre sesiones

Si el usuario invoca `/resolve-review` sin args y existe `~/.claude/reviews/<project>/*.md`:
1. Cargar el archivo más reciente
2. Re-fetch del source para detectar:
   - Nuevos comentarios (no estaban antes)
   - Comentarios resueltos (estaban y ya no)
   - Cambios de estado del PR / página
3. Actualizar el archivo: añadir nuevos hilos al final, marcar resueltos, mantener estado existente de los que el usuario ya procesó manualmente
4. Reportar diff: "X hilos nuevos · Y resueltos · Z sin cambio"

---

## Anti-patrones a evitar

- ❌ Postear respuestas automáticamente en GitHub o Notion. Solo drafts.
- ❌ Aplicar edits al doc/código sin confirmación batch del usuario.
- ❌ Crear el archivo de seguimiento dentro del repo del cliente (commit accidental).
- ❌ Marcar hilos como ✅ accepted sin verificar el código (especialmente correcciones técnicas).
- ❌ Usar `§N` o `_alias` sin backticks (problemas de render markdown).
- ❌ Mezclar idiomas dentro de la misma sección (investigación en español, drafts en idioma del review — separados).
- ❌ Generar drafts genéricos tipo "ありがとうございます、修正します". Cada draft debe citar la evidencia técnica concreta.
- ❌ Saltarse la fase INVESTIGATE para correcciones técnicas. Sin verificar el código, los drafts son adivinanza.
- ❌ Crear `CLAUDE.local.md` o `.reviews/` dentro del repo. Siempre `~/.claude/reviews/`.
- ❌ **Crear secciones agregadas tipo "Plan de ejecución" / "Bloque 1, 2, 3" al final del archivo.** El usuario tendría que saltar entre el bloque del hilo y el bloque agregado para tickear cosas. Todos los `[ ]` reales viven dentro del bloque del hilo (en la sección "Estado").
- ❌ **Drafts demasiado largos con explicaciones técnicas profundas.** El revisor ya conoce el contexto; los detalles técnicos van en el doc Notion / la investigación, no en la respuesta. Mantener drafts en 1-2 líneas. Estilo correcto: "ご指摘の通り、X でした。Y を修正しました。" Estilo incorrecto: explicación de la cadena `archivo.ts:L1-L20 → función Y → conclusión Z`.
- ❌ **Crear hilos #N+1 separados para replies en el mismo discussion.** Si hay reply (ej. otro reviewer pregunta tras la primera observación), integrarlo en el mismo bloque #N con `**Comentario X**` y `**Reply Y**` y un único draft que conteste a ambos.
- ❌ **Asumir relaciones causales no afirmadas por el reviewer.** Si reviewer A dice "PR #N cubre el caso (b)" y reviewer B pide tarea para el caso (a), no afirmar "(a) y (b) son el mismo root cause" en el draft o en el ticket. Mantener separados.

---

## Integración con otras skills

- **`/review`**: skill complementaria — `/review` para HACER review hacia otros, `/resolve-review` para resolver review recibida.
- **`/copy`**: copiar drafts al portapapeles para postear a mano.
- **`/slack`**: redactar pings a terceros derivados (e.g., "@幸喜 西村さんからこの点の確認依頼が来ています").
- **`/create-issue`**: para bugs descubiertos durante el review (ej. auto-refresh bug detectado en review TC).
- **`/commit`**: tras aplicar edits que requieran commit (con confirmación).

---

## Notas operacionales

- **Atajo nvim**: `<leader>r` está configurado para abrir el archivo más reciente en `~/.claude/reviews/<project>/`.
- **Archivo gitignored**: `~/.claude/reviews/` está fuera de cualquier repo. Aun así, no escribir info confidencial gratuita.
- **Reviews con > 15 hilos**: avisar al usuario, ofrecer procesar en chunks (ej. solo subpágina A primero).
- **Comentarios con imágenes**: MCP de Notion no sirve imágenes — pedir descripción al usuario o leer código UI relacionado para inferir.
- **Threads largos** (varios comentarios en mismo discussion_id): tratar como un solo hilo, citar el último mensaje del autor relevante en `Comentario`.
- **Re-runs**: la skill es idempotente — siempre se puede volver a ejecutar para refrescar estado, no destruye el progreso manual del usuario en el archivo si el formato sigue convención.
