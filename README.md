# claude-config

Configuración global de Claude Code para todos mis equipos: el **contrato de trabajo**
que toda sesión de IA debe cumplir, la **política compartida** y el **orquestador**
que mantiene las tres máquinas sincronizadas.

**Principio de diseño:** las instrucciones son tinta (el modelo las sigue de forma
probabilística); los gates son cemento (los ejecuta el programa). Este repo aporta
las dos capas: el contrato como tinta versionada, los hooks y el CI como cemento.

## Anatomía

| Fichero | Qué es | Quién lo lee | Quién lo escribe |
|---|---|---|---|
| `CLAUDE.md` | El contrato de trabajo (cómo trabajo, autoría, git, comunicación) | Claude Code al arrancar cada sesión, vía symlink `~/.claude/CLAUDE.md` | Solo yo, vía PR |
| `settings.shared.json` | Política compartida: atribución vacía + hook de sync. **Nunca** contiene estado por máquina (`model`, `effortLevel`) — el CI lo impide | `merge_settings.py` | Solo yo, vía PR |
| `sync.sh` | Orquestador: corre en cada arranque de sesión (hook `SessionStart`). Hace `git pull` de este repo y re-fusiona la política en el settings local. Todo fallo se comunica en voz alta dentro de la sesión — nunca muere en silencio | El hook de SessionStart | Solo yo, vía PR |
| `merge_settings.py` | La lógica de fusión: el repo GANA en las claves que gestiona, lo local no gestionado se conserva. Fusión superficial a propósito. Rutas fijas (no acepta argumentos): nadie puede apuntarlo a otros ficheros | `sync.sh` e `install.sh` | Solo yo, vía PR |
| `install.sh` | Bootstrap de máquina: symlink del contrato + primera fusión (que además registra el hook). Idempotente | Yo, una vez por equipo | Solo yo, vía PR |
| `tests/` | UT de la fusión (la única lógica real del repo) | CI y pre-PR | Junto al código que tocan |

### Por qué el settings local NO se symlinka

`~/.claude/settings.json` es **estado vivo**: Claude Code escribe en él (elección de
modelo, nivel de esfuerzo, flags). Compartirlo entero habría propagado el modelo de
una máquina a las demás y ensuciado este repo hasta romper el `git pull --ff-only`
en silencio. Por eso: el contrato (estático) va por symlink; la política (pocas
claves) va por fusión; el estado por máquina no viaja jamás.

## Onboarding

### Máquina nueva (o existente — el repo gana en lo que gestiona)

```bash
git clone git@github.com:colomr-cc/claude-config.git ~/dev/claude-config
~/dev/claude-config/install.sh
```

Listo. La siguiente sesión de Claude Code en esa máquina ya arranca con el contrato
cargado y el sync automático activo. Si había un `~/.claude/CLAUDE.md` previo, se
sustituye; las claves locales no gestionadas de `settings.json` se conservan.

**Requisito:** la ruta debe ser `~/dev/claude-config` (el hook la referencia).

### Actualizar el contrato o la política

Nunca a mano en main. Flujo E2E estándar:

1. Rama feature → cambio → PR (lo puede crear Claude; lo apruebo y mergeo **yo**).
2. El CI valida: shellcheck, ruff, pytest, JSON de política, y cero atribución de IA.
3. Tras el merge, cada máquina se actualiza sola en su siguiente arranque de sesión.

### Diagnóstico

El sync **siempre habla** al inicio de la sesión de Claude Code — el silencio sería
indistinguible de "el hook no llegó a ejecutarse":

- **Éxito:** `✅ claude-config sincronizado · contrato en vigor: <commit> (<fecha>)`.
  El commit identifica qué versión del contrato rige en esa máquina: útil para ver
  de un vistazo si un equipo se quedó atrás.
- **Problema:** `⚠️ claude-config: ...` con la causa (repo sucio, rama a medias, sin
  red, JSON roto). El sync no rompe el arranque de la sesión: informa y sigue con la
  última configuración local válida.
- **Ningún mensaje:** el hook no se ejecutó → revisar la instalación en esa máquina.

## Quality Gate

CI en GitHub Actions (obligatorio vía branch protection) + SonarCloud Automatic
Analysis. El mismo estándar que cualquier otro repo: nada llega a main sin verde.
