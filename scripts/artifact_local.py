"""Load optional machine-local paths for artifact helper scripts."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Dict


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
LOCAL_CONFIG_PATH = REPOSITORY_ROOT / ".artifact-local.json"


def load_local_config() -> Dict[str, str]:
    """Return path overrides from the ignored repository-local config file."""

    if not LOCAL_CONFIG_PATH.is_file():
        return {}
    try:
        values = json.loads(LOCAL_CONFIG_PATH.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise ValueError(f"invalid local artifact config {LOCAL_CONFIG_PATH}: {error}") from error
    if not isinstance(values, dict):
        raise ValueError(f"local artifact config must be a JSON object: {LOCAL_CONFIG_PATH}")
    invalid = sorted(
        key
        for key, value in values.items()
        if not isinstance(key, str) or not isinstance(value, str) or not value.strip()
    )
    if invalid:
        raise ValueError(
            f"local artifact config has invalid path value(s): {', '.join(invalid)}"
        )
    return values


def configured_path(key: str, fallback: Path) -> Path:
    """Resolve a configured path, with relative values based at the repository root."""

    value = load_local_config().get(key)
    if value is None:
        return fallback
    path = Path(value).expanduser()
    return path if path.is_absolute() else REPOSITORY_ROOT / path
