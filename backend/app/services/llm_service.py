"""LLM client for the AI fault-draft pipeline (Ollama / Gemma 4 E2B, local).

The service makes exactly two structured calls per draft:
  1. ``extract``        — free text -> cleaned description, title, asset/room
                          mention, failure category, work instruction, language.
  2. ``disambiguate``   — (only when multiple candidates resolve) pick the best
                          asset/room + flag a duplicate open fault.

Entity ids are never produced by the model: ``disambiguate`` may only reference
ids that were handed to it in the prompt (from the backend's own resolution),
and the endpoint validates the result. Any failure raises ``LlmUnavailable`` so
the caller can degrade to the rules-only path instead of failing the request.
"""

import json
import os
from typing import Any, Optional

import httpx

DEFAULT_OLLAMA_URL = os.environ.get("OLLAMA_URL", "http://localhost:11434/api/generate")
DEFAULT_MODEL = os.environ.get("OLLAMA_MODEL", "gemma4:e2b-text")
DEFAULT_TIMEOUT = int(os.environ.get("OLLAMA_TIMEOUT", "180"))

CATEGORIES = ["electrical", "plumbing", "it", "hvac", "furniture", "structural", "other"]

EXTRACT_SCHEMA = {
    "type": "object",
    "properties": {
        "cleaned_description": {"type": "string"},
        "title": {"type": "string"},
        "asset_mention": {"type": "string"},
        "room_mention": {"type": "string"},
        "failure_category": {"type": "string", "enum": CATEGORIES},
        "work_instruction": {"type": "string"},
        "language": {"type": "string", "enum": ["af", "en"]},
    },
    "required": [
        "cleaned_description", "title", "asset_mention", "room_mention",
        "failure_category", "work_instruction", "language",
    ],
}

SYSTEM_PROMPT = (
    "Jy is 'n fasiliteitsbestuur-assistent. Lees die foutbeskrywing en haal die "
    "inligting daaruit uit. Reëls: "
    "1) cleaned_description: skryf die beskrywing netjies oor (spelfoute, herhaling "
    "en rommel regmaak) sonder om inligting by te voeg of te versin; "
    "2) title: een reël wat die fout opsom; "
    "3) asset_mention: die generiese naam van die toestel (bv. 'Projektor' of "
    "'Stoel'); leë string as geen toestel genoem word nie; "
    "4) room_mention: die kamer/gebou wat genoem word (bv. 'Kombuis' of "
    "'Lesinglokaal A'); leë string as niks genoem word nie; "
    "5) failure_category: een van electrical/plumbing/it/hvac/furniture/structural/other; "
    "6) work_instruction: een kort sin oor wat gedoen moet word; "
    "7) language: 'af' of 'en' na gelang van die taal van die beskrywing. "
    "Antwoord in die taal van die beskrywing. Gee slegs geldige JSON terug."
)

FEWSHOT = [
    (
        "Projektor lens is gekraak",
        {
            "cleaned_description": "Die projektorlens is gekraak.",
            "title": "Projektorlens gekraak",
            "asset_mention": "Projektor",
            "room_mention": "",
            "failure_category": "it",
            "work_instruction": "Vervang die projektorlens of diens die projektor in.",
            "language": "af",
        },
    ),
    (
        "Kraan lek in kombuis",
        {
            "cleaned_description": "Die kraan in die kombuis lek.",
            "title": "Kraan lek in kombuis",
            "asset_mention": "",
            "room_mention": "Kombuis",
            "failure_category": "plumbing",
            "work_instruction": "Herstel of vervang die kraan se seël in die kombuis.",
            "language": "af",
        },
    ),
]


class LlmUnavailable(Exception):
    """Raised when Ollama cannot be reached or returns garbage — the caller
    degrades to the rules-only path rather than failing the request."""


class LlmService:
    def __init__(self, url: str = DEFAULT_OLLAMA_URL, model: str = DEFAULT_MODEL,
                 timeout: int = DEFAULT_TIMEOUT):
        self.url = url
        self.model = model
        self.timeout = timeout

    def _enabled(self) -> bool:
        return os.environ.get("AI_ENABLED", "true").lower() not in ("false", "0", "no")

    def _generate(self, system: str, prompt: str, schema: Optional[dict],
                  options: Optional[dict] = None) -> dict:
        body = {
            "model": self.model,
            "system": system,
            "prompt": prompt,
            "stream": False,
            "options": {"temperature": 0, "num_ctx": 8192, "num_predict": 512, **(options or {})},
        }
        if schema:
            body["format"] = schema
        else:
            body["format"] = "json"
        with httpx.Client(timeout=self.timeout) as client:
            resp = client.post(self.url, json=body)
            resp.raise_for_status()
            return resp.json()

    # --- public API ---------------------------------------------------------

    def extract(self, description: str) -> dict:
        """Free text -> structured draft fields (schema-enforced)."""
        if not self._enabled():
            raise LlmUnavailable("AI disabled via AI_ENABLED")
        parts = []
        for text, out in FEWSHOT:
            parts.append(f"Beskrywing: {text}\nAntwoord: {json.dumps(out, ensure_ascii=False)}")
        parts.append(f"Beskrywing: {description}\nAntwoord:")
        raw = self._generate(SYSTEM_PROMPT, "\n\n".join(parts), EXTRACT_SCHEMA)
        text = (raw.get("response") or "").strip()
        data = self._parse_json(text)
        if not isinstance(data, dict):
            raise LlmUnavailable(f"Unparseable LLM output: {text[:200]}")
        if data.get("failure_category") not in CATEGORIES:
            data["failure_category"] = "other"
        if data.get("language") not in ("af", "en"):
            data["language"] = "af"
        return data

    def disambiguate(self, description: str, asset_candidates: list[dict],
                     room_candidates: list[dict], open_jobs: list[dict]) -> dict:
        """Pick the best asset/room among candidates + flag a duplicate.

        ``open_jobs`` is a short list of {id, description} of open jobcards.
        The model may only reference ids that were provided here.
        """
        if not self._enabled():
            raise LlmUnavailable("AI disabled via AI_ENABLED")

        def _fmt(items):
            return "; ".join(
                f"{it['id']}: {it['name']}" + (f" ({it['detail']})" if it.get("detail") else "")
                for it in items
            ) or "(geen)"

        prompt = (
            "Jy kry 'n foutbeskrywing en 'n lys moontlike bates en kamers. "
            "Kies die mees waarskynlike een vir ELK, of gebruik null as die teks "
            "nie genoeg inligting gee om te kies nie. Moenie 'n id kies wat nie in "
            "die lys is nie. Dui ook duplicate_of aan as hierdie beskrywing "
            "duidelik dieselfde fout is as een van die oop werkskaartjies (anders null).\n\n"
            f"Beskrywing: {description}\n"
            f"Moontlike bates: {_fmt(asset_candidates)}\n"
            f"Moontlike kamers: {_fmt(room_candidates)}\n"
            f"Oop werkskaartjies: {_fmt(open_jobs)}\n"
            "Antwoord (slegs JSON): "
            '{"asset_id": <int|null>, "room_id": <int|null>, "duplicate_of": <int|null>}'
        )
        raw = self._generate(SYSTEM_PROMPT, prompt, schema=None)
        text = (raw.get("response") or "").strip()
        data = self._parse_json(text)
        if not isinstance(data, dict):
            return {"asset_id": None, "room_id": None, "duplicate_of": None}
        known_asset = {it["id"] for it in asset_candidates}
        known_room = {it["id"] for it in room_candidates}
        known_job = {it["id"] for it in open_jobs}
        return {
            "asset_id": data.get("asset_id") if data.get("asset_id") in known_asset else None,
            "room_id": data.get("room_id") if data.get("room_id") in known_room else None,
            "duplicate_of": data.get("duplicate_of") if data.get("duplicate_of") in known_job else None,
        }

    @staticmethod
    def _parse_json(text: str) -> Optional[Any]:
        text = text.strip()
        # strip markdown fences if present
        if text.startswith("```"):
            text = text.split("\n", 1)[-1].rsplit("```", 1)[0]
        start = text.find("{")
        end = text.rfind("}")
        if start == -1 or end == -1 or end <= start:
            return None
        try:
            return json.loads(text[start:end + 1])
        except json.JSONDecodeError:
            return None


llm_service = LlmService()
