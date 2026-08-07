# claude-sync

> **Versión en inglés:** [README.md](README.md)

## Sincronizador Multi-Dispositivo de Claude Code

El **contrato de trabajo** que toda sesión de IA debe cumplir, la **política compartida** y el **orquestador** que mantiene todos los equipos sincronizados.

**Principio de diseño:** las instrucciones son tinta (el modelo las sigue de forma
probabilística); los gates son cemento (los ejecuta el programa). Este repo aporta
las dos capas: el contrato como tinta versionada, los hooks y el CI como cemento.

## Anatomía

| Fichero | Qué es | Quién lo lee | Quién lo escribe |
|---|---|---|---|
| `CLAUDE.md` | El contrato de trabajo (cómo trabajo, autoría, git, comunicación) | Claude Code al arrancar cada sesión, desde la copia en `~/.claude/CLAUDE.md` | Solo yo, vía PR |
| `settings.shared.json` | Política compartida: atribución vacía + hook de sync. **Nunca** contiene estado por máquina (`model`, `effortLevel`) — el CI lo impide | `merge_settings.py` | Solo yo, vía PR |
| `sync.sh` | Orquestador: corre en cada arranque de sesión (hook `SessionStart`). Trae `origin/main`, sincroniza la rama local main y materializa de ahí el contrato y la política. Habla siempre, por los dos canales — nunca muere en silencio | El hook de SessionStart | Solo yo, vía PR |
| `merge_settings.py` | La lógica de fusión: el repo GANA en las claves que gestiona, lo local no gestionado se conserva. Fusión superficial a propósito. Lee la política del historial (`git show origin/main:…`) y no acepta rutas por argumento | `sync.sh` | Solo yo, vía PR |
| `install.sh` | Bootstrap de máquina: ejecuta el sync una vez, que materializa el contrato y registra el hook. Idempotente | Yo, una vez por equipo | Solo yo, vía PR |
| `tests/` | UT de la fusión (la única lógica real del repo) | CI y pre-PR | Junto al código que tocan |

### Lo que rige es lo APROBADO, no lo que haya en la carpeta

`~/.claude/CLAUDE.md` es una **copia gestionada por el sync**, extraída de `origin/main`
con `git show`. No es un enlace al árbol de trabajo, y por eso:

- Da igual en qué rama esté esta copia del repo, o si tiene cambios sin commitear:
  **lo que rige tu sesión es siempre lo que se mergeó a main**. Un borrador en una rama
  nunca gobierna nada.
- No hace falta ninguna disciplina ("acuérdate de volver a main"): la máquina donde se
  desarrolla la configuración se comporta igual que las demás.
- **No lo edites a mano**: el siguiente arranque lo sobrescribe. El contrato se cambia
  por PR.

`~/.claude/settings.json`, en cambio, es **estado vivo** que Claude Code escribe (modelo,
nivel de esfuerzo, flags). Por eso no se sustituye entero, sino que se fusiona: el repo
gana en las claves que gestiona y el estado por máquina no viaja jamás entre equipos.

## Onboarding

### Máquina nueva (o existente — el repo gana en lo que gestiona)

```bash
git clone git@github.com:colomr-cc/claude-sync.git ~/dev/claude-sync
~/dev/claude-sync/install.sh
```

Listo. La siguiente sesión de Claude Code en esa máquina ya arranca con el contrato
cargado y el sync automático activo. Si había un `~/.claude/CLAUDE.md` previo,
se sustituye por la copia aprobada; las claves locales no gestionadas de `settings.json` se conservan.

**Requisito:** la ruta debe ser `~/dev/claude-sync` (el hook la referencia).

### Actualizar el contrato o la política

Nunca a mano en main. Flujo E2E estándar:

1. Rama feature → cambio → PR (lo puede crear Claude; lo apruebo y mergeo **yo**).
2. El CI valida: shellcheck, ruff, pytest, JSON de política, y cero atribución de IA.
3. Tras el merge, cada máquina se actualiza sola en su siguiente arranque de sesión.

### Diagnóstico

El sync **siempre habla**. Detalle importante del harness: el evento `SessionStart` solo
honra `additionalContext`, que va al contexto del modelo y **no se muestra en pantalla**
(se emite también `systemMessage`, pero este evento lo ignora). Por eso la regla 11 del
contrato obliga a Claude a reproducir esa línea al inicio de su primera respuesta: es la
única forma de que el estado llegue a mis ojos. El silencio sería indistinguible de "el
hook no llegó a ejecutarse":

- **Éxito:** `✅ claude-sync · contrato en vigor: <commit> (<fecha>)`. El commit
  identifica qué versión rige en esa máquina: útil al volver a un equipo que llevaba
  tiempo sin usarse.
- **Contrato actualizado:** el mensaje lo añade explícitamente, con el comando para ver
  el diff — `git -C ~/dev/claude-sync log -p -1 origin/main -- CLAUDE.md`. Ningún
  cambio del contrato se aplica en silencio.
- **Problema:** `⚠️ claude-sync: ...` con la causa (sin acceso a `origin`, referencia
  inexistente, política ilegible). El sync no rompe el arranque de la sesión: informa y
  sigue con la última configuración válida.
- **Ningún mensaje:** el hook no se ejecutó → revisar la instalación en esa máquina.

## Quality Gate

CI en GitHub Actions (obligatorio vía branch protection) + SonarCloud Automatic
Analysis. El mismo estándar que cualquier otro repo: nada llega a main sin verde.

### Dónde vive la configuración de Sonar

En la **UI de SonarCloud, dentro del proyecto** (`Administration → …`), no en el repo:
el Automatic Analysis **ignora los ficheros `sonar-project.properties`** — esos solo
los lee el scanner cuando el análisis corre desde el CI. Comprobado en la práctica:
con el fichero presente, los avisos seguían apareciendo.

Ajustes actuales, todos a nivel de proyecto (no heredados de la organización):

| Ajuste | Valor | Dónde en la UI |
|---|---|---|
| `sonar.python.version` | `3.12` | General Settings → Languages → Python |
| `sonar.test.inclusions` | `tests/**` | Analysis Scope → **Test** File Inclusions |

⚠️ Cuidado con el alcance: `sonar.inclusions` (Source File Inclusions) significa
"analiza **solo** esto" — poner ahí `tests/**` deja fuera todo el código de producción
y el gate se queda ciego en verde. El campo correcto para marcar tests es
`sonar.test.inclusions`.
