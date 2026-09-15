"""Rules-based fault classifier — the deterministic heart of the AI pipeline.

Phase 0 benchmark (19 real faultcards) proved rules beat the LLM decisively on
the domain taxonomy: 100% type / 78.9% priority vs 47.4% / 57.9%. So the LLM
never gets a vote on type/priority; this module always owns it.

The Afrikaans/English signal-word sets are finite and stable; extend them here
when a new symptom word shows up in real reports.
"""

import re
import unicodedata


def normalize(text: str) -> str:
    """Lowercase, strip accents, drop non-alphanumerics, collapse spaces."""
    text = unicodedata.normalize("NFKD", text or "")
    text = "".join(ch for ch in text if not unicodedata.combining(ch))
    text = text.lower()
    text = re.sub(r"[^a-z0-9 ]+", " ", text)
    return re.sub(r"\s+", " ", text).strip()


REPAIR_SIGNALS = [
    "gebreek", "gebreuk", "lek", "gekraak", "stukkend", "oorloop", "oorverhit",
    "flikker", "skakel nie aan", "skakel nie", "werk nie", "warm lug",
    "oorstroming", "breek", "breek", "barst", "stuk", "defek", "fout",
]
MAINT_SIGNALS = [
    "vries", "papierstoor", "druk laag", "onstabiel", "onderhoud", "diens",
    "toets", "vervang", "skoon", "battery", "geraas", "kalibreer",
    "instandhouding", "opdatering", "smeer",
]
HIGH_SIGNALS = [
    "oorloop", "oorstroming", "brand", "nood", "dringend", "warm lug",
    "oorverhit", "skakel nie aan", "druk laag", "rook", "water skade",
]
LOW_SIGNALS = ["gering", "klein", "ligte", "papierstoor", "geraas", "minimaal"]

DEFAULT_TYPE = "REPAIR"
DEFAULT_PRIORITY = "MEDIUM"


def classify_type(text: str) -> str:
    """REPAIR when the thing is broken and needs fixing, MAINTENANCE for
    routine upkeep-style symptoms (paper jam, low pressure, freezing, noise…).
    """
    norm = normalize(text)
    if any(s in norm for s in MAINT_SIGNALS):
        return "MAINTENANCE"
    if any(s in norm for s in REPAIR_SIGNALS):
        return "REPAIR"
    return DEFAULT_TYPE


def classify_priority(text: str) -> str:
    """HIGH for safety/water/fire/life-safety symptoms, LOW for cosmetic ones,
    MEDIUM as the default."""
    norm = normalize(text)
    if any(s in norm for s in HIGH_SIGNALS):
        return "HIGH"
    if any(s in norm for s in LOW_SIGNALS):
        return "LOW"
    return DEFAULT_PRIORITY
