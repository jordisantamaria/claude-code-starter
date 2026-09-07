# Instrucciones globales

> Plantilla. Lo que hay aquí es la **estructura**, no el contenido: las reglas buenas
> salen de tus propios fallos, no de este fichero. Bórralo entero y ve añadiendo.

## Cómo se añade una regla aquí

Cuando algo salga mal —Claude toca un fichero que no debía, repite un error ya corregido,
usa una convención que no es la del proyecto— **se arregla en ese momento**, no después.
Al día siguiente ya no tienes el contexto para saber si la regla que escribiste funciona.

Y antes de escribirla aquí, la pregunta es **dónde va**:

| Si es… | Va a… |
|---|---|
| Un hecho que no debe olvidarse | memoria |
| Un procedimiento que se repite | una skill |
| Algo que, si no se cumple, es un accidente | un hook o un script del repo |
| Una preferencia general | aquí |

Todo lo que se mete aquí compite por prioridad con lo demás que hay aquí. Un fichero con
cuarenta reglas no tiene cuarenta reglas: tiene cuarenta cosas con el mismo peso.

## Formato de los enlaces

URLs literales y completas (`https://...`), nunca `[texto](url)`: la terminal solo hace
clicables las literales.

## Git

- Formato de commit: `<tipo>: <descripción>` — `feat`, `fix`, `refactor`, `docs`, `test`,
  `chore`, `perf`, `ci`.
- Sin firmas de IA en el mensaje de commit ni en la descripción del PR.
- Antes de abrir un PR, mirar el historial completo de la rama, no solo el último commit.

## Antes de dar algo por terminado

- Los errores se gestionan explícitamente; nada de tragárselos en silencio.
- La entrada externa se valida en el borde del sistema.
- Nada de credenciales escritas en el código.
- Si hay tests, pasan. Si no pasan, se dice — no se da por terminado igualmente.
