#!/usr/bin/env python3
"""Normalizes the raw introspected OpenAPI spec for
swagger_dart_code_generator 4.1.1's known limitations, before codegen runs.

Full regeneration pipeline (documented here since it spans two repos):

  1. From Cerebro 2.0/services/api, using that project's own venv:

       ./.venv/Scripts/python.exe -c "
       import json, sys
       sys.path.insert(0, '.')
       from app.main import app
       json.dump(app.openapi(), open('/tmp/raw_openapi.json', 'w'), indent=2)
       "

  2. From this repo (Cerebro Flutter), using any Python 3 (stdlib only):

       python3 scripts/normalize_openapi_spec.py /tmp/raw_openapi.json

  3. From this repo, with Flutter on PATH:

       flutter pub run build_runner build --delete-conflicting-outputs

Known limitations this script works around (input normalization, not
hand-patched *generated* output — safe to re-run every time):

  - UpdateTodoBody.priority uses the `anyOf: [enum, null]` shape FastAPI/
    Pydantic emits for `Optional[Literal[...]] = None`. The generator
    references an enum type it never actually defines for this shape,
    breaking the whole generated file. Flattened here to a plain nullable
    enum, which it handles correctly. Confirmed (2026-09-22) this is the
    only field in the spec with this shape — check again if this script
    starts silently under-normalizing after a backend schema change.
"""

import json
import sys
from pathlib import Path

OUTPUT_PATH = Path(__file__).parent.parent / "lib" / "api_spec" / "cerebro_api.swagger.json"


def normalize(spec: dict) -> dict:
    schemas = spec.get("components", {}).get("schemas", {})

    priority = schemas.get("UpdateTodoBody", {}).get("properties", {}).get("priority")
    if priority and "anyOf" in priority:
        enum_variant = next((v for v in priority["anyOf"] if "enum" in v), None)
        if enum_variant:
            schemas["UpdateTodoBody"]["properties"]["priority"] = {
                "type": enum_variant["type"],
                "enum": enum_variant["enum"],
                "title": priority.get("title", "Priority"),
                "nullable": True,
            }

    return spec


def main() -> None:
    if len(sys.argv) != 2:
        print(f"usage: {sys.argv[0]} <raw-openapi-spec.json>", file=sys.stderr)
        sys.exit(1)

    raw = json.loads(Path(sys.argv[1]).read_text())
    normalized = normalize(raw)

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(normalized, indent=2))
    print(f"wrote {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
