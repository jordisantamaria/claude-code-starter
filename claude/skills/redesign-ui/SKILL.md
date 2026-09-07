---
name: redesign-ui
description: Genera un prompt optimizado para AI especializadas en diseño UI (Google Stitch, Figma AI, v0, Lovable, Galileo) usando el contexto real del proyecto (stack, branding, copy, componentes actuales). Claude Code escribe el prompt; tú haces copy-paste en la herramienta externa para explorar opciones rápido. Úsalo cuando el usuario diga "/redesign-ui <página>", "rediseñar UI de X", "necesito explorar diseño de Y", "generar prompt para Stitch/Figma/v0".
---

# Skill: redesign-ui

Claude Code tiene limitaciones haciendo UI visualmente atractiva. Esta skill **no diseña** — genera el prompt perfecto para que lo hagan herramientas especializadas, con todo el contexto del proyecto pre-cargado.

## Cuándo se activa

- `/redesign-ui <ruta o componente>`
- "rediseñar la página de eventos"
- "necesito un prompt para Stitch sobre el dashboard"
- "explorar UI alternativas para login"

## Por qué existe esta skill

- Claude Code es bueno escribiendo lógica, malo en visual hierarchy / typographic taste / animation feel
- Herramientas como Google Stitch, Figma AI, v0, Lovable son entrenadas específicamente en diseño y output coherente
- El cuello de botella NO es la herramienta — es **el prompt**: sin contexto del producto, branding, stack y goals, el output es genérico
- Esta skill resuelve eso: genera un prompt 10× más rico que lo que escribirías manualmente, copia-pegable en cualquier tool

## Inputs

Si no se proveen, preguntar:

1. **Página o componente** a rediseñar (path tipo `apps/saas/modules/events/components/EventsList.tsx` o ruta tipo `/events`)
2. **Goal del rediseño** (opcional, default "explorar opciones más visualmente atractivas"):
   - "más visual / menos denso"
   - "mobile-first"
   - "más profesional / corporate"
   - "más playful / cálido"
   - "convertir mejor (CTAs)"
   - <texto libre>
3. **Tool target** (opcional, default "auto"):
   - `stitch` — Google Stitch, mobile UI flows
   - `figma` — Figma AI, design exploration sin código
   - `v0` — Vercel v0, Next.js + Tailwind + shadcn directo a código
   - `lovable` — Lovable, full app generation
   - `galileo` — Galileo AI, mocks rápidos
   - `auto` — la skill recomienda según stack y goal

## Flujo

### Paso 1 — Detectar contexto del proyecto

```bash
PROJECT_ROOT=$(pwd)
# Stack detection
HAS_NEXT=$(test -f package.json && grep -q '"next"' package.json && echo "yes" || echo "no")
HAS_TAILWIND=$(test -f tailwind.config.ts -o -f tailwind.config.js && echo "yes" || echo "no")
HAS_SHADCN=$(test -d apps/saas/modules/ui/components -o -d components/ui && echo "yes" || echo "no")
HAS_PWA=$(grep -q "next-pwa\|@serwist" package.json 2>/dev/null && echo "yes" || echo "no")
PRIMARY_LANG=$(grep -E "i18n|locale|defaultLocale" next.config.* 2>/dev/null | head -1 || echo "")
```

### Paso 2 — Leer branding del proyecto

```bash
# Producto identity
test -f docs/branding/product-identity.md && cat docs/branding/product-identity.md
test -f docs/branding/visual-system.md && cat docs/branding/visual-system.md
test -f docs/branding/messaging.md && cat docs/branding/messaging.md

# Founder voice-tone (heredado)
test -f branding/founder/voice-tone.md && cat branding/founder/voice-tone.md
```

Si los branding files NO existen → marcar como "branding pendiente, prompt usará defaults" + recomendar al user rellenar las plantillas antes de iterar diseño en serio.

### Paso 3 — Leer la página/componente actual

Si el input es path TSX → leer el archivo + componentes children directos (1 nivel).

Si el input es ruta `/X` → buscar en `apps/saas/app/(saas)/X/page.tsx` o `app/X/page.tsx` (depende de la convención del proyecto).

Capturar:
- JSX structure (qué se renderiza)
- Componentes shadcn usados (`<Button>`, `<Card>`, etc.)
- Tailwind classes prominentes
- Estado / data shape (qué data se pinta)
- Copy text actual (placeholders, labels, CTAs)

### Paso 4 — Screenshot (opcional)

Si dev server corre (`pnpm dev`) y la ruta es accesible:

```bash
# Verificar dev server
curl -sf http://localhost:3000 >/dev/null && echo "dev server running"
```

Si corre → preguntar al user si quiere capturar screenshot via Playwright MCP. Si dice sí → `mcp__plugin_everything-claude-code_playwright__browser_navigate` + `browser_take_screenshot` y guardar en `/tmp/redesign-ui-current.png`.

Si no corre → skip, sólo prompt textual.

### Paso 5 — Tool selection (si "auto")

| Goal + Stack | Tool recomendada |
|---|---|
| Stack Next.js + shadcn + Tailwind, goal: código directo | **v0** |
| Goal: explorar opciones rápidas sin código | **Figma AI** |
| Goal: mobile flow completo (no una pantalla) | **Google Stitch** |
| Goal: full app del cero | **Lovable** |
| Goal: wireframe rápido low-fi | **Galileo / Uizard** |

Si user fija tool, override.

### Paso 6 — Generar el prompt

Estructura del prompt (markdown, copy-pasteable):

```markdown
# Redesign request: <PÁGINA/COMPONENTE>

## Product context

- **Name**: <PRODUCT_NAME desde product-identity.md>
- **One-liner**: <DESC desde product-identity.md>
- **Target user**: <de target-audience.md, primer perfil real>
- **Domain**: <ej. "Japanese idol fan community / oshikatsu">
- **Primary UI language**: <JP / EN / multi>

## Stack constraints (output debe respetar)

- Next.js 15 App Router + React Server Components
- TypeScript strict
- Tailwind CSS (sólo utility classes, no CSS custom)
- shadcn/ui components (`<Button>`, `<Card>`, `<Dialog>`, `<Form>`, `<Input>`, etc.)
- Mobile-first responsive (PWA, no native app inicialmente)
- Dark mode soportado (todos los colores via tokens, no hardcoded)
- Iconos: Lucide React

## Brand guidelines

### Visual tone

<Pegar contenido de visual-system.md "Tono visual", paleta, tipografía>

### Voice tone

<Pegar foundation de voice-tone.md — bullets clave, sin todo el doc>

- Casual con substancia, no corporate
- Honesto sobre limitaciones
- Sin urgencia performativa ("🔥 LAST CHANCE")
- Sin LinkedIn-guru posturing

### Idioma del copy

<JP nativo / EN profesional / multi>. Ejemplos de copy actual en la app:
- <pegar 3-4 strings reales del componente actual>

## Current screen — qué hace hoy

<DESCRIPCIÓN breve de la página: qué data muestra, qué acciones permite, qué states tiene (loading, empty, error).>

### Componentes presentes

- <lista de componentes principales>

### Copy actual (literal)

<pegar strings literales para que la AI mantenga el dominio del producto>

### Pain points del diseño actual

<si user los menciona; si no, dejar genérico tipo "denso visualmente, sin jerarquía clara">

## Goal del rediseño

<lo que el user pidió, tal cual>

## Output esperado

<según tool seleccionada:>

- **v0**: React component completo, JSX + Tailwind, listo para `pnpm dlx shadcn@latest add` cualquier shadcn nuevo
- **Figma AI**: 3-5 variantes exploratorias del frame, en mobile-first viewport (375×812)
- **Stitch**: full flow del feature (no solo una pantalla — el journey completo)
- **Lovable**: standalone preview con interactividad básica
- **Galileo**: wireframes annotated low-fi con anotaciones del rationale

## Constraints negativas (NO hacer)

- NO usar gradientes saturados / neon (no es la estética)
- NO añadir CTAs falsos urgentes ("Limited offer!")
- NO inventar features que no estén en la lista actual
- NO cambiar la lógica del componente — solo presentación
- NO usar imágenes stock genéricas (placeholder solo)
```

### Paso 7 — Output al user

1. Guardar el prompt en `/tmp/redesign-ui-prompt.md` para inspección
2. Copiar al clipboard usando la skill `copy` (Wayland: `wl-copy`):

```bash
wl-copy < /tmp/redesign-ui-prompt.md
```

3. Mostrar al user:

```
📐 Prompt generado para redesign de <PÁGINA>

Tool recomendada: <TOOL>
Razón: <una frase>

✅ Prompt copiado al clipboard (wl-copy)
📄 Guardado en /tmp/redesign-ui-prompt.md

Siguiente paso:
1. Abre <URL de la tool>
2. Pega el prompt (Ctrl+V)
3. Si tool soporta image input → adjunta /tmp/redesign-ui-current.png (si se capturó)

URLs:
- v0: https://v0.dev
- Figma AI: https://figma.com (cmd+K → "Generate")
- Google Stitch: https://stitch.withgoogle.com
- Lovable: https://lovable.dev
- Galileo: https://usegalileo.ai

Cuando tengas resultados que te gusten:
- Pásamelos por chat (link, screenshot, o código)
- /implement-redesign (skill futura) o sólo "implementa esta variante"
```

## Anti-patrones

- ❌ Generar prompt sin leer el componente actual (output será genérico)
- ❌ Asumir stack — siempre detectar via package.json
- ❌ Olvidar el voice-tone (output corporativo cuando producto es casual oshi fan)
- ❌ Pedir "diseño bonito" sin goal específico (vague in, vague out)
- ❌ Copiar TODO el contenido de docs/ al prompt (overflow del context window de la tool destino — extraer solo lo relevante)
- ❌ Recomendar v0 cuando el goal es "explorar opciones rápidas" (v0 da una sola variante de código; para explorar usa Figma AI o Stitch)

## Cuándo NO usar esta skill

- **Cambios menores de UI** (color tweak, spacing) — Claude Code lo hace bien directo
- **Bug visual específico** (texto cortado, alineación rota) — debug, no redesign
- **Cuando branding aún no está definido** — primero rellena `branding/product/`, sino el prompt sale vacío

## Frecuencia recomendada

- 1× por feature mayor cuando llegue a "funciona pero feo"
- NO usar para iterar 5 veces la misma página — si la primera variante no convence, el problema es el prompt, no la tool

## Output cache

`/tmp/redesign-ui-prompt.md` se sobreescribe cada vez. Si quieres preservarlo:

```bash
cp /tmp/redesign-ui-prompt.md ~/redesigns/$(date +%Y%m%d-%H%M)-<página>.md
```

## Relación con otras skills

- Lee de `branding/founder/` y `docs/branding/product/` (heredados de indie-starter)
- Usa la skill `copy` (wl-copy) para clipboard
- Complementa Claude Code, no reemplaza — la implementación final del rediseño la hace Claude Code de vuelta
- Futuro: `/implement-redesign` que tome el output de la tool externa y lo aterrice en el proyecto
