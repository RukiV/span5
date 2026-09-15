"""AI chart generation for 9 dashboard visuals.

Each time AI statistics is run (POST /analytics/insights or GET /dashboard-summary)
this service is called to (re)generate the 9 charts. It first tries the local
LLM (Gemma via llm_service) to choose titles/insights, but the numeric data is
always rule-based from the DB so hallucination is impossible. If the LLM is
unavailable the numeric chart is still returned and the frontend shows the
chart with a rule-based title.

Charts ( #3 Depreciation removed per user):
 1. lifecycle_age - Stacked column age vs expected lifespan
 2. failure_pareto - Pareto bar+line per asset class
 4. health_status - Donut operational status
 5. criticality_matrix - Heatmap risk vs impact (Option A mapping)
 6. ticket_volume_backlog - Multi-line log volume / WIP / resolution
 7. sla_compliance - Stacked bar per priority (Hoog 4h, Medium 48h, Laag 168h)
 8. mttr_mtbf - Cards + trend lines
 9. strategy_mix - Donut reactive/preventive/predictive
10. technician_load - Grouped bar assigned vs completed per tech

FK filtering: if user.role_id==2 and user.location_id, only buildings/rooms/assets
on that campus are counted (same helper as get_dashboard_summary).
"""

import json
import logging
from collections import Counter, defaultdict
from datetime import datetime, timezone, timedelta
from typing import Optional

from sqlmodel import Session, select

from ..models.asset import Asset, Assettype
from ..models.fault import Faultcard
from ..models.job import Jobcard
from ..models.location import Building, Room
from ..models.user import User

logger = logging.getLogger(__name__)

# SLA windows in hours
SLA_HOURS = {"Hoog": 4, "Medium": 48, "Laag": 168}
# Building/room impact mapping Option A
IMPACT_MAP_BUILDING = {
    "Laboratorium": 5,
    "Onderwys": 4,
    "Klas": 4,
    "Kantoorgebou": 3,
    "Kantoor": 3,
    "Koshuis": 2,
    "Badkamer": 2,
    "Pakhuis": 1,
    "warehouse": 1,
    "Ander": 1,
    "Kafeteria": 2,
}
IMPACT_MAP_ROOM = {
    "Laboratorium": 5,
    "Klaskamer": 4,
    "Konferensiekamer": 3,
    "Kantoor": 3,
    "Badkamer": 2,
    "Pakhuis": 1,
    "Ander": 1,
}


def _enum_val(v):
    if v is None:
        return "Onbekend"
    if hasattr(v, "value"):
        return v.value
    return str(v)


def _fk_scope(session: Session, user: Optional[User]):
    """Return (allowed_building_ids, allowed_room_ids, is_fk) for FK filtering."""
    from ..auth.rights_catalog import ROLE_FK

    if user and getattr(user, "role_id", None) == ROLE_FK and getattr(user, "location_id", None) is not None:
        loc_id = user.location_id
        buildings = session.exec(select(Building).where(Building.location_id == loc_id)).all()
        b_ids = {b.building_id for b in buildings}
        rooms = session.exec(select(Room)).all()
        r_ids = {r.room_id for r in rooms if r.building_id in b_ids}
        return b_ids, r_ids, True
    return None, None, False


def _in_scope_asset(a: Asset, b_ids, r_ids, is_fk: bool) -> bool:
    if not is_fk:
        return True
    return a.room_id in r_ids if a.room_id else False


def _in_scope_fault(f: Faultcard, session: Session, b_ids, r_ids, is_fk: bool, loc_id) -> bool:
    if not is_fk:
        return True
    if f.location_id == loc_id:
        return True
    if f.building_id in b_ids:
        return True
    if f.room_id in r_ids:
        return True
    if f.asset_id:
        a = session.get(Asset, f.asset_id)
        if a and a.room_id in r_ids:
            return True
    return False


def _in_scope_job(j: Jobcard, session: Session, b_ids, r_ids, is_fk: bool, loc_id) -> bool:
    if not is_fk:
        return True
    if j.location_id == loc_id:
        return True
    if j.building_id in b_ids:
        return True
    if j.room_id in r_ids:
        return True
    if j.asset_id:
        a = session.get(Asset, j.asset_id)
        if a and a.room_id in r_ids:
            return True
    return False


def _impact_for_asset(session: Session, asset: Asset) -> int:
    if not asset or not asset.room_id:
        return 1
    room = session.get(Room, asset.room_id)
    if not room:
        return 1
    b = session.get(Building, room.building_id) if room.building_id else None
    r_score = IMPACT_MAP_ROOM.get(_enum_val(room.room_type), 1)
    building_types = getattr(b, "building_types", None) if b else None
    if building_types:
        b_score = max(IMPACT_MAP_BUILDING.get(_enum_val(t), 1) for t in building_types)
    else:
        b_score = IMPACT_MAP_BUILDING.get(_enum_val(getattr(b, "building_type", None)) if b else "Ander", 1)
    return max(r_score, b_score)


def generate_all_charts(session: Session, user: Optional[User] = None) -> dict:
    """Generate all 9 AI visuals. Called each time AI statistics is run.

    Returns dict with keys for each visual, each value is a ChartData-like
    dict {type, title, labels, datasets, insights?} plus two scalar cards for
    MTTR/MTBF.
    """
    b_ids, r_ids, is_fk = _fk_scope(session, user)
    loc_id = getattr(user, "location_id", None) if is_fk else None
    now = datetime.now(timezone.utc).replace(tzinfo=None)

    # Preload for FK filtering
    assets = session.exec(select(Asset)).all()
    if is_fk:
        assets = [a for a in assets if _in_scope_asset(a, b_ids, r_ids, is_fk)]
    asset_map = {a.asset_id: a for a in assets}
    assettype_map = {at.assettype_id: at for at in session.exec(select(Assettype)).all()}

    faults = session.exec(select(Faultcard)).all()
    if is_fk:
        faults = [f for f in faults if _in_scope_fault(f, session, b_ids, r_ids, is_fk, loc_id)]
    jobs = session.exec(select(Jobcard)).all()
    if is_fk:
        jobs = [j for j in jobs if _in_scope_job(j, session, b_ids, r_ids, is_fk, loc_id)]

    # Try to enrich titles via LLM, but never fail the numeric data
    llm_title_overrides = {}
    try:
        from .llm_service import llm_service, LlmUnavailable

        if llm_service._enabled():
            # Simple prompt to get insight titles for the 9 charts
            ctx = {
                "total_assets": len(assets),
                "total_faults": len(faults),
                "total_jobs": len(jobs),
                "faults_last_30d": sum(1 for f in faults if f.fault_reportdatetime and f.fault_reportdatetime >= now - timedelta(days=30)),
                "scope": "fk" if is_fk else "all",
            }
            # We ask LLM for a short Afrikaans insight per chart; if it fails we keep rule titles
            # Use a tiny schema to avoid hallucinated numbers
            prompt = (
                "Konteks: " + json.dumps(ctx, ensure_ascii=False) + "\n"
                "Gee vir elk van die 9 grafieke 'n kort Afrikaans titel (max 6 woorde) as JSON "
                '{"lifecycle":"..","pareto":"..","health":"..","criticality":"..","volume":"..","sla":"..","mttr":"..","strategy":"..","load":".."}'
            )
            # Use a generic system prompt
            raw = llm_service._generate(
                "Jy is 'n fasiliteitsbestuur assistent. Gee slegs geldige JSON terug.",
                prompt,
                {"type": "object", "properties": {k: {"type": "string"} for k in ["lifecycle","pareto","health","criticality","volume","sla","mttr","strategy","load"]}, "required": []},
                {"temperature": 0.3, "num_predict": 256},
            )
            txt = (raw.get("response") or "").strip()
            parsed = llm_service._parse_json(txt)
            if isinstance(parsed, dict):
                llm_title_overrides = {k: v for k, v in parsed.items() if isinstance(v, str) and v.strip()}
    except Exception as e:
        logger.debug("LLM title enrichment failed, using rule titles: %s", e)

    def _title(key: str, fallback: str) -> str:
        return llm_title_overrides.get(key, fallback)

    charts = {}

    # 1. Lifecycle & Age Distribution - stacked column age vs expected lifespan
    # Buckets: 0-2, 2-5, 5-8, 8+ years
    buckets = ["0-2j", "2-5j", "5-8j", "8+j"]
    # Group by assettype
    per_type_bucket = defaultdict(lambda: [0, 0, 0, 0])
    for a in assets:
        if not a.asset_created_datetime:
            continue
        age_years = (now - a.asset_created_datetime).days / 365.25
        if age_years < 2:
            idx = 0
        elif age_years < 5:
            idx = 1
        elif age_years < 8:
            idx = 2
        else:
            idx = 3
        at = assettype_map.get(a.assettype_id)
        tname = at.assettype_name if at else "Onbekend"
        # Normalize demo names: Stoel/Tafel/Bureau -> keep separate per user 5y
        per_type_bucket[tname][idx] += 1
    # Build stacked datasets
    # Limit to top 5 types by count
    sorted_types = sorted(per_type_bucket.items(), key=lambda x: sum(x[1]), reverse=True)[:5]
    charts["lifecycle_age"] = {
        "type": "bar",
        "title": _title("lifecycle", "Bate Lewensiklus & Ouderdomsverspreiding"),
        "labels": buckets,
        "datasets": [
            {"label": tname, "data": counts} for tname, counts in sorted_types
        ] if sorted_types else [{"label": "Bates", "data": [0, 0, 0, 0]}],
        "insights": [f"{tname}: {sum(c)} bates" for tname, c in sorted_types[:3]] if sorted_types else [],
    }

    # 2. Failure Pareto - bar+line sorted by fault count per asset class
    per_type_faults = Counter()
    for f in faults:
        if f.duplicate_of:
            continue
        if not f.asset_id or f.asset_id not in asset_map:
            continue
        a = asset_map[f.asset_id]
        at = assettype_map.get(a.assettype_id)
        tname = at.assettype_name if at else "Onbekend"
        per_type_faults[tname] += 1
    sorted_pareto = per_type_faults.most_common(8)
    total_faults = sum(per_type_faults.values()) or 1
    cum = 0
    pareto_line = []
    for _, cnt in sorted_pareto:
        cum += cnt
        pareto_line.append(round(cum / total_faults * 100, 1))
    charts["failure_pareto"] = {
        "type": "bar",
        "title": _title("pareto", "Faling Frekwensie Pareto — Top Bate Klasse"),
        "labels": [k for k, _ in sorted_pareto] if sorted_pareto else ["Geen foute"],
        "datasets": [
            {"label": "Foute", "data": [v for _, v in sorted_pareto] if sorted_pareto else [0]},
            {"label": "Kumulatief %", "data": pareto_line if pareto_line else [0]},
        ],
        "insights": [f"Top {sorted_pareto[0][0]}: {sorted_pareto[0][1]} foute ({pareto_line[0]}% kumulatief)" ] if sorted_pareto else [],
    }

    # 4. Health & Status - donut
    status_counts = Counter(_enum_val(a.asset_status) for a in assets)
    # Map to requested labels: Operational (Aktief), Degraded (Instandhouding), Under Repair (Besig?), Out of Service (Afgedank/Onaktief)
    # Use asset_status directly, but group for donut
    health_labels = list(status_counts.keys()) if status_counts else ["Geen data"]
    health_data = list(status_counts.values()) if status_counts else [0]
    charts["health_status"] = {
        "type": "doughnut",
        "title": _title("health", "Bate Gesondheid & Status Verspreiding"),
        "labels": health_labels,
        "datasets": [{"label": "Bates", "data": health_data}],
    }

    # 5. Criticality Matrix - heatmap approximated as stacked bar of 4 quadrants
    # X risk: high if survival_high_risk or lifespan_pct>=100 or fault_count>=threshold, else monitor if pct>=80 else low
    # Y impact: via building/room mapping 1-5, high if >=4, low if <=2
    try:
        from .prediction_service import PredictionService
        preds = PredictionService().getPredictions(session)
        if is_fk:
            preds = [p for p in preds if p.asset_id in asset_map]
    except Exception:
        preds = []
    quadrants = Counter()
    for p in preds:
        a = asset_map.get(p.asset_id)
        if not a:
            continue
        # risk
        pct = getattr(p, "lifespan_pct_used", 0) or 0
        is_high_risk = getattr(p, "survival_high_risk", False) or p.replacement_suggested or pct >= 100
        is_med = pct >= 80 and not is_high_risk
        risk_label = "Hoog" if is_high_risk else ("Medium" if is_med else "Laag")
        impact = _impact_for_asset(session, a)
        impact_label = "Hoog" if impact >= 4 else ("Medium" if impact == 3 else "Laag")
        key = f"{risk_label} Risiko / {impact_label} Impak"
        quadrants[key] += 1
    # Ensure 4 quadrants present
    all_keys = ["Hoog Risiko / Hoog Impak", "Hoog Risiko / Laag Impak", "Laag Risiko / Hoog Impak", "Laag Risiko / Laag Impak"]
    # Map our detailed keys to 4 quadrants
    quad_data = []
    for k in all_keys:
        # Sum any matching
        cnt = sum(v for kk, v in quadrants.items() if k.split(" / ")[0].split()[0] in kk and k.split(" / ")[1].split()[0] in kk)
        quad_data.append(cnt)
    # If no preds, fallback to empty
    if not preds:
        quadrants = Counter()
        quad_data = [0, 0, 0, 0]
    charts["criticality_matrix"] = {
        "type": "bar",
        "title": _title("criticality", "Kritieke Matrix — Risiko vs Impak"),
        "labels": all_keys,
        "datasets": [{"label": "Bates", "data": quad_data}],
        "insights": [f"Prioriteit 1 (Hoog/Hoog): {quad_data[0]} bates" ] if quad_data[0] else [],
    }

    # 6. Ticket Volume & Backlog Trend - multi-line last 8 weeks
    weeks = []
    week_labels = []
    for i in range(7, -1, -1):
        ws = now - timedelta(weeks=i, days=now.weekday())
        ws = ws.replace(hour=0, minute=0, second=0, microsecond=0)
        we = ws + timedelta(days=7)
        weeks.append((ws, we))
        week_labels.append(ws.strftime("%d %b"))
    log_volume = []
    wip = []
    resolution = []
    for ws, we in weeks:
        lv = sum(1 for f in faults if f.fault_reportdatetime and ws <= f.fault_reportdatetime < we)
        # WIP = open at end of week: faults created <= we and not closed by we (approx via status not Gesluit/Opgelos and report < we)
        open_statuses = {"Oop", "Wag", "Bevestig", "Besig"}
        wip_count = sum(1 for f in faults if f.fault_reportdatetime and f.fault_reportdatetime < we and _enum_val(f.fault_status) in open_statuses)
        # resolution = closed that week
        res = sum(1 for f in faults if f.fault_updatedatetime and ws <= f.fault_updatedatetime < we and _enum_val(f.fault_status) in ("Gesluit", "Opgelos"))
        log_volume.append(lv)
        wip.append(wip_count)
        resolution.append(res)
    charts["ticket_volume_backlog"] = {
        "type": "line",
        "title": _title("volume", "Foutkaartjie Volume & Agterstand Tendens (8 weke)"),
        "labels": week_labels,
        "datasets": [
            {"label": "Log Volume", "data": log_volume},
            {"label": "WIP", "data": wip},
            {"label": "Opgelos", "data": resolution},
        ],
    }

    # 7. SLA Compliance Rate - stacked bar per priority
    sla_labels = ["Hoog (4h)", "Medium (2d)", "Laag (1w)"]
    sla_total = []
    sla_compliant = []
    sla_breach = []
    for prio, hours in [("Hoog", 4), ("Medium", 48), ("Laag", 168)]:
        prio_faults = [f for f in faults if _enum_val(f.fault_priority) == prio]
        total = len(prio_faults)
        comp = 0
        for f in prio_faults:
            if not f.fault_reportdatetime:
                continue
            deadline = f.fault_reportdatetime + timedelta(hours=hours)
            # Find linked job finish or fault close
            finish = None
            # Try linked job
            linked_jobs = [j for j in jobs if j.fault_id == f.fault_id and j.job_finisheddatetime]
            if linked_jobs:
                finish = min(j.job_finisheddatetime for j in linked_jobs)
            elif f.fault_updatedatetime and _enum_val(f.fault_status) in ("Gesluit", "Opgelos"):
                finish = f.fault_updatedatetime
            else:
                # Still open: check if now > deadline -> breach, else not yet counted as breach
                if now > deadline:
                    # breach
                    continue
                else:
                    # not yet due, count as compliant for now
                    comp += 1
                    continue
            if finish and finish <= deadline:
                comp += 1
        sla_total.append(total)
        sla_compliant.append(comp)
        sla_breach.append(total - comp)
    charts["sla_compliance"] = {
        "type": "bar",
        "title": _title("sla", "SLA Nakoming per Prioriteit"),
        "labels": sla_labels,
        "datasets": [
            {"label": "Nakoming", "data": sla_compliant},
            {"label": "Oortreding", "data": sla_breach},
        ],
        "insights": [f"Hoog: {round(sla_compliant[0]/sla_total[0]*100) if sla_total[0] else 0}% betyds"] if sla_total[0] else [],
    }

    # 8. MTTR & MTBF - cards + trend
    # MTTR per week last 8 weeks
    mttr_per_week = []
    for ws, we in weeks:
        durations = []
        for j in jobs:
            if j.job_createddatetime and j.job_finisheddatetime and ws <= j.job_finisheddatetime < we and _enum_val(j.job_status) == "Voltooid":
                dur = (j.job_finisheddatetime - j.job_createddatetime).total_seconds() / 3600  # hours
                if 0 < dur < 24 * 90:  # filter outliers >90d
                    durations.append(dur)
        avg = round(sum(durations) / len(durations), 1) if durations else 0
        mttr_per_week.append(avg)
    # MTBF per asset: avg gap between faults per asset, system avg
    mtbf_gaps = []
    faults_by_asset = defaultdict(list)
    for f in faults:
        if f.asset_id and f.fault_reportdatetime:
            faults_by_asset[f.asset_id].append(f.fault_reportdatetime)
    for aid, dates in faults_by_asset.items():
        dates.sort()
        for i in range(1, len(dates)):
            gap = (dates[i] - dates[i-1]).total_seconds() / 3600 / 24  # days
            if 0 < gap < 365 * 3:
                mtbf_gaps.append(gap)
    mtbf_avg = round(sum(mtbf_gaps) / len(mtbf_gaps), 1) if mtbf_gaps else 0
    mttr_avg = round(sum(mttr_per_week) / len([x for x in mttr_per_week if x]) , 1) if any(mttr_per_week) else 0
    charts["mttr_mtbf"] = {
        "type": "line",
        "title": _title("mttr", "MTTR & MTBF — Tendense"),
        "labels": week_labels,
        "datasets": [
            {"label": "MTTR (ure)", "data": mttr_per_week},
        ],
        "cards": {"mttr": mttr_avg, "mtbf_days": mtbf_avg},
        "insights": [f"MTTR gem: {mttr_avg}h, MTBF gem: {mtbf_avg}d"] if mttr_avg or mtbf_avg else [],
    }

    # 9. Maintenance Strategy Mix - donut
    # Map job_type free text to 3 buckets
    def _norm_strategy(t):
        s = str(t or "").strip().lower()
        if s in ("maintenance", "onderhoud", "preventive", "preventief", "inspection", "inspeksie"):
            return "Preventief"
        if s in ("repair", "herstel", "emergency", "noodgeval"):
            return "Reaktief"
        if "predict" in s or s in ("predictive", "voorspellend"):
            return "Voorspellend"
        # fallback: check fault_type mapping
        return "Reaktief" if s in ("repair", "herstel") else "Preventief"
    strat_counts = Counter(_norm_strategy(j.job_type) for j in jobs if j.job_type)
    # Ensure 3 buckets present
    for k in ["Reaktief", "Preventief", "Voorspellend"]:
        strat_counts.setdefault(k, 0)
    charts["strategy_mix"] = {
        "type": "doughnut",
        "title": _title("strategy", "Onderhoud Strategie Mengsel"),
        "labels": ["Reaktief", "Preventief", "Voorspellend"],
        "datasets": [{"label": "Werksopdragte", "data": [strat_counts["Reaktief"], strat_counts["Preventief"], strat_counts["Voorspellend"]]}],
    }

    # 10. Technician & Contractor Load - grouped bar
    # assigned_to vs contractor_id, counts pending vs completed
    from ..models.user import User as UserModel

    user_map = {u.user_id: f"{u.user_name} {u.user_surname}".strip() for u in session.exec(select(UserModel)).all()}
    load = defaultdict(lambda: {"assigned": 0, "completed": 0})
    for j in jobs:
        key = None
        name = None
        if j.assigned_to:
            key = f"a_{j.assigned_to}"
            name = user_map.get(j.assigned_to, f"Gebruiker {j.assigned_to}")
        elif j.contractor_id:
            key = f"c_{j.contractor_id}"
            name = user_map.get(j.contractor_id, f"Kontrakteur {j.contractor_id}")
        else:
            key = "unassigned"
            name = "Ontoegewys"
        # Use name as key for grouping, but keep id for dedup
        # Aggregate by name
        if _enum_val(j.job_status) == "Voltooid":
            load[name]["completed"] += 1
        else:
            load[name]["assigned"] += 1
    # Top 6 by total
    sorted_load = sorted(load.items(), key=lambda x: x[1]["assigned"] + x[1]["completed"], reverse=True)[:6]
    charts["technician_load"] = {
        "type": "bar",
        "title": _title("load", "Tegnikus & Kontrakteur Lading"),
        "labels": [k for k, _ in sorted_load] if sorted_load else ["Geen data"],
        "datasets": [
            {"label": "Toegewys", "data": [v["assigned"] for _, v in sorted_load] if sorted_load else [0]},
            {"label": "Voltooi", "data": [v["completed"] for _, v in sorted_load] if sorted_load else [0]},
        ],
    }

    return charts
