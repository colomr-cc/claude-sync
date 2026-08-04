#!/usr/bin/env python3
"""Fusiona la política compartida (settings.shared.json) en el settings.json local.

Regla: el repo GANA en las claves que gestiona; el resto de claves locales
(model, effortLevel, flags de onboarding...) se conservan intactas.
La fusión es superficial a propósito: cada clave gestionada se sustituye
completa — la política compartida nunca se mezcla a medias con estado local.
"""

import json
import sys
from pathlib import Path


def merge(shared: dict, local: dict) -> dict:
    """Las claves de shared pisan a las de local; las demás se conservan."""
    return local | shared


def load_local(path: Path) -> dict:
    """Settings local, o {} si no existe o está corrupto (se reconstruye)."""
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (FileNotFoundError, json.JSONDecodeError):
        return {}


def main(shared_path: str, local_path: str) -> int:
    shared = json.loads(Path(shared_path).read_text(encoding="utf-8"))
    local_file = Path(local_path)
    local = load_local(local_file)

    merged = merge(shared, local)
    if merged != local:
        local_file.write_text(
            json.dumps(merged, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
        )
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1], sys.argv[2]))
