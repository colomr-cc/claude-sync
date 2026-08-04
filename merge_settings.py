#!/usr/bin/env python3
"""Fusiona la política compartida (settings.shared.json) en el settings.json local.

Regla: el repo GANA en las claves que gestiona; el resto de claves locales
(model, effortLevel, flags de onboarding...) se conservan intactas.
La fusión es superficial a propósito: cada clave gestionada se sustituye
completa — la política compartida nunca se mezcla a medias con estado local.

Las rutas son fijas y se derivan de la ubicación del propio script: no se
aceptan por línea de comandos para que nadie pueda apuntarlo a otros ficheros.
"""

import json
import sys
from pathlib import Path

REPO_DIR = Path(__file__).resolve().parent
SHARED_PATH = REPO_DIR / "settings.shared.json"
LOCAL_PATH = Path.home() / ".claude" / "settings.json"


def merge(shared: dict, local: dict) -> dict:
    """Las claves de shared pisan a las de local; las demás se conservan."""
    return local | shared


def load_local(path: Path) -> dict:
    """Settings local, o {} si no existe o está corrupto (se reconstruye)."""
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (FileNotFoundError, json.JSONDecodeError):
        return {}


def sync(shared_path: Path = SHARED_PATH, local_path: Path = LOCAL_PATH) -> bool:
    """Aplica la política compartida al settings local. True si hubo cambios."""
    shared = json.loads(shared_path.read_text(encoding="utf-8"))
    local = load_local(local_path)

    merged = merge(shared, local)
    if merged == local:
        return False

    local_path.parent.mkdir(parents=True, exist_ok=True)
    local_path.write_text(
        json.dumps(merged, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    return True


def main() -> int:
    sync()
    return 0


if __name__ == "__main__":
    sys.exit(main())
