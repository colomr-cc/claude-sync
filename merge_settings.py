#!/usr/bin/env python3
"""Aplica al settings.json local la política APROBADA (la de origin/main).

Regla: el repo GANA en las claves que gestiona; el resto de claves locales
(model, effortLevel, flags de onboarding...) se conservan intactas.
La fusión es superficial a propósito: cada clave gestionada se sustituye
completa — la política compartida nunca se mezcla a medias con estado local.

La política se lee del historial (`git show origin/main:...`), no del árbol de
trabajo: así el estado de la copia local (rama, cambios sin commitear) no influye
en lo que rige. Las rutas son fijas y no se aceptan por línea de comandos.
"""

import json
import subprocess
import sys
from pathlib import Path

REPO_DIR = Path(__file__).resolve().parent
LOCAL_PATH = Path.home() / ".claude" / "settings.json"
APPROVED_REF = "origin/main"
SHARED_FILE = "settings.shared.json"


def merge(shared: dict, local: dict) -> dict:
    """Las claves de shared pisan a las de local; las demás se conservan."""
    return local | shared


def load_local(path: Path) -> dict:
    """Settings local, o {} si no existe o está corrupto (se reconstruye)."""
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (FileNotFoundError, json.JSONDecodeError):
        return {}


def approved_shared(ref: str = APPROVED_REF, repo_dir: Path = REPO_DIR) -> dict:
    """Política aprobada, leída del historial en lugar del árbol de trabajo."""
    salida = subprocess.run(
        ["git", "-C", str(repo_dir), "show", f"{ref}:{SHARED_FILE}"],
        capture_output=True,
        text=True,
        check=True,
    )
    return json.loads(salida.stdout)


def sync(shared: dict, local_path: Path = LOCAL_PATH) -> bool:
    """Aplica la política al settings local. True si hubo cambios."""
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
    sync(approved_shared())
    return 0


if __name__ == "__main__":
    sys.exit(main())
