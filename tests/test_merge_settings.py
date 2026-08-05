"""Tests de la lógica de fusión: el repo gana en sus claves, lo local se conserva."""

import json
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import merge_settings
from merge_settings import approved_shared, load_local, merge, sync

SHARED = {"attribution": {"commit": "", "pr": ""}, "hooks": {"SessionStart": []}}


def _escribir(path: Path, data: dict) -> Path:
    path.write_text(json.dumps(data), encoding="utf-8")
    return path


def test_merge_el_repo_gana_en_sus_claves():
    local = {"attribution": {"commit": "algo viejo"}, "model": "claude-opus-5"}
    merged = merge(SHARED, local)
    assert merged["attribution"] == {"commit": "", "pr": ""}


def test_merge_conserva_las_claves_locales_no_gestionadas():
    local = {"model": "claude-opus-5", "effortLevel": "high"}
    merged = merge(SHARED, local)
    assert merged["model"] == "claude-opus-5"
    assert merged["effortLevel"] == "high"
    assert merged["hooks"] == SHARED["hooks"]


def test_load_local_sin_fichero_devuelve_vacio(tmp_path):
    assert load_local(tmp_path / "no-existe.json") == {}


def test_load_local_corrupto_devuelve_vacio(tmp_path):
    roto = tmp_path / "roto.json"
    roto.write_text("{esto no es json", encoding="utf-8")
    assert load_local(roto) == {}


def test_sync_escribe_el_resultado_fusionado(tmp_path):
    local_f = _escribir(tmp_path / "settings.json", {"model": "claude-sonnet-5"})

    assert sync(SHARED, local_f) is True

    resultado = json.loads(local_f.read_text(encoding="utf-8"))
    assert resultado["model"] == "claude-sonnet-5"
    assert resultado["attribution"] == {"commit": "", "pr": ""}


def test_sync_no_reescribe_si_no_hay_cambios(tmp_path):
    local_f = _escribir(tmp_path / "settings.json", {"model": "x"} | SHARED)

    antes = local_f.stat().st_mtime_ns
    assert sync(SHARED, local_f) is False
    assert local_f.stat().st_mtime_ns == antes


def test_sync_crea_el_settings_si_no_existe(tmp_path):
    local_f = tmp_path / "nuevo" / "settings.json"

    assert sync(SHARED, local_f) is True
    assert json.loads(local_f.read_text(encoding="utf-8")) == SHARED


def test_approved_shared_lee_del_historial_no_del_arbol(monkeypatch):
    """La política debe salir de `git show <ref>:...`, nunca del fichero local."""
    llamada = {}

    def fake_run(cmd, **kwargs):
        llamada["cmd"] = cmd
        return subprocess.CompletedProcess(cmd, 0, stdout=json.dumps(SHARED), stderr="")

    monkeypatch.setattr(merge_settings.subprocess, "run", fake_run)

    assert approved_shared(ref="origin/main") == SHARED
    assert llamada["cmd"][:3] == ["git", "-C", str(merge_settings.REPO_DIR)]
    assert llamada["cmd"][3:] == ["show", "origin/main:settings.shared.json"]
