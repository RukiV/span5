import json
import logging as _lg
from collections import Counter
from sqlmodel import Session, select, func
from datetime import datetime, timezone

from ..models.analytics import AnalyticsResponse, Metric, ChartData, ChartDataset, Suggestion


def _llm_ops_digest(response: AnalyticsResponse, page: str) -> str | None:
    """Optional AI prose layer: short Afrikaans ops summary from computed aggregates.

    Numbers in, prose out — the prompt only carries the already-computed
    metrics/insights, so the hallucination surface is near-zero. When the LLM
    is unavailable (AI_ENABLED=false / Ollama down / garbage output) returns
    None so the caller keeps the rule-based summary.
    """
    try:
        from ..services.llm_service import llm_service, LlmUnavailable  # local import (lazy)

        if not llm_service._enabled():
            return None

        metrics_block = "\n".join(
            f"- {m.label}: {m.value}" for m in (response.metrics or [])
        )
        insights_block = "\n".join(response.insights or [])
        prompt = (
            f"Page: {page}\n"
            f"Metrics:\n{metrics_block or '(none)'}\n"
            f"Rule insights:\n{insights_block or '(none)'}\n"
            "Skryf 'n bondige maar insiggewende Afrikaans-bedryfsopsomming van "
            "2-3 sinne as JSON {\"digest\": \"<string>\"} — noem die belangrikste "
            "syfers en status-afbrekings; gebruik slegs die gegewe getalle, moenie "
            "getalle versin nie."
        )
        raw = llm_service._generate(
            "Jy is 'n fasiliteitsbestuur-assistent. Gee slegs 'n kort Afrikaans opsaamfasering van die cijfers.",
            prompt,
            {"type": "object", "properties": {"digest": {"type": "string"}}, "required": ["digest"]},
            {"temperature": 0.3, "num_predict": 220},
        )
        text = (raw.get("response") or "").strip()
        parsed = llm_service._parse_json(text)
        if isinstance(parsed, dict) and isinstance(parsed.get("digest"), str) and parsed["digest"].strip():
            return parsed["digest"].strip()[:400]
    except LlmUnavailable:
        _lg.debug("Ops digest skipped (LLM unavailable): %s", page)
    except Exception as e:
        _lg.debug("Ops digest failed: %s", e)
    return None





# ─── Fallback (rule-based, no AI) ─────────────────────────────

def _dynamic_insight_items(raw_list, name_field, status_field, status_filter, action_label):
    """Generate dynamic item-specific insights and suggestions from raw records."""
    insights = []
    suggestions = []
    filtered = [r for r in raw_list if r.get(status_field) in (status_filter if isinstance(status_filter, (list, tuple)) else [status_filter])]
    for item in filtered[:3]:
        name = item.get(name_field, f"Item #{item.get(list(item.keys())[0], '')}")
        insights.append(f"{name} is tans {status_filter}")
        suggestions.append(action_label.format(name=name))
    return insights, suggestions


def _fallback_suggestions(page: str, context: dict) -> list[Suggestion]:
    suggestions = []

    raw_stock = context.get("raw_stock", [])
    raw_faults = context.get("raw_faults", [])
    raw_jobs = context.get("raw_jobs", [])
    raw_assets = context.get("raw_assets", [])
    raw_rooms = context.get("raw_rooms", [])

    for item in raw_stock:
        amt = item.get("stock_amount", 0)
        minimum = item.get("stock_minimum", 0)
        if amt < minimum:
            suggestions.append(Suggestion(
                type="reorder_stock",
                label=f"Hervul {item.get('stock_name', 'item')}",
                description=f"{item.get('stock_name')} is krities laag ({amt}/{minimum})",
                params={"stock_id": item.get("stock_id"), "name": item.get("stock_name"), "amount": minimum * 2},
            ))

    for f in raw_faults:
        if f.get("fault_status") in ("Oop", "oop", "WAIT") and f.get("fault_priority") in ("Hoog", "Dringend", "HIGH", "high"):
            suggestions.append(Suggestion(
                type="create_work_order",
                label=f"Werksopdrag vir fout #{f.get('fault_id')}",
                description=f"Hoë-prioriteit: {str(f.get('fault_description', ''))[:80]}",
                params={
                    "fault_id": f.get("fault_id"),
                    "job_desc": str(f.get("fault_description", "")),
                    "room_id": f.get("room_id"),
                    "building_id": f.get("building_id"),
                    "location_id": f.get("location_id"),
                    "job_priority": "Dringend",
                },
            ))

    for j in raw_jobs:
        if j.get("job_status") in ("Oop", "oop", "Pending", "pending", "Geskeduleer", "geskeduleer", "SCHEDULED", "scheduled") and not j.get("assigned_to"):
            suggestions.append(Suggestion(
                type="assign_job",
                label=f"Ken werksopdrag #{j.get('jobcard_id')} aan my toe",
                description=f"{str(j.get('job_desc', ''))[:80]} het geen toewysing nie",
                params={"jobcard_id": j.get("jobcard_id")},
            ))

    maintenance_assets = [a for a in raw_assets if a.get("asset_status") == "Instandhouding"]
    if len(maintenance_assets) >= 2:
        suggestions.append(Suggestion(
            type="create_work_order",
            label=f"Werksopdrag vir {maintenance_assets[0].get('asset_name', 'bate')}",
            description=f"{maintenance_assets[0].get('asset_name', 'Bate')} is al in instandhouding",
            params={
                "asset_id": maintenance_assets[0].get("asset_id"),
                "job_desc": f"Instandhouding: {maintenance_assets[0].get('asset_name', 'onbekend')}",
                "room_id": maintenance_assets[0].get("room_id"),
                "job_priority": "Normaal",
            },
        ))

    return suggestions


def _fallback_insights(page: str, context: dict, session=None, user=None) -> AnalyticsResponse:
    if page == "dashboard":
        total = context.get("assets", 0)
        active_faults = context.get("active_faults", 0)
        active_jobs = context.get("active_jobs", 0)
        stock_items = context.get("stock_items", 0)
        rooms = context.get("rooms", 0)
        buildings = context.get("buildings", 0)
        faults_by_status = context.get("faults_by_status", {})
        jobs_by_status = context.get("jobs_by_status", {})
        open_faults = context.get("open_faults", active_faults)
        high_priority_faults = context.get("high_priority_faults", 0)
        high_priority_jobs = context.get("high_priority_jobs", 0)
        auto_drafts = context.get("auto_drafts", 0)
        is_fk_scoped = context.get("is_fk_scoped", False)
        location_name = context.get("location_name", "")

        suggestions = _fallback_suggestions(page, context)
        all_insights = [
            f"Daar is {total} bates, {active_faults} onopgeloste foutkaartjies, en {active_jobs} aktiewe werksopdragte.",
        ]
        if active_faults > 0 and faults_by_status:
            fault_breakdown = ", ".join(f"{c} {s}" for s, c in faults_by_status.items() if s != "Gesluit")
            all_insights.append(f"Onopgeloste foute per status: {fault_breakdown}.")
        if active_jobs > 0 and jobs_by_status:
            job_breakdown = ", ".join(f"{c} {s}" for s, c in jobs_by_status.items() if s not in ("Voltooid", "Gekanselleer"))
            all_insights.append(f"Aktiewe werksopdragte per status: {job_breakdown}.")
        if stock_items > 0:
            all_insights.append(f"{stock_items} voorraaditems word tans bestuur.")
        all_insights.append(f"Die fasiliteit het {rooms} lokale oor {buildings} geboue.")
        if open_faults + high_priority_faults + high_priority_jobs + auto_drafts > 0:
            all_insights.append(
                f"{open_faults} oop foutkaartjies, {high_priority_faults} hoë-prioriteit, "
                f"{high_priority_jobs} hoë-prioriteit werksopdragte aktief, {auto_drafts} Gemma-auto-konsepte."
            )

        if is_fk_scoped and location_name:
            summary = (
                f"Oorsig vir {location_name}: {total} bates, {active_faults} onopgeloste foute, "
                f"{active_jobs} aktiewe werksopdragte."
            )
        else:
            summary = f"Oorsig van {total} bates, {active_faults} onopgeloste foute, {active_jobs} aktiewe werksopdragte."

        return AnalyticsResponse(
            summary=summary,
            metrics=[
                Metric(label="Totale Bates", value=str(total)),
                Metric(label="Onopgeloste Foute", value=str(active_faults)),
                Metric(label="Aktiewe Werksopdragte", value=str(active_jobs)),
                Metric(label="Voorraaditems", value=str(stock_items)),
                Metric(label="Oop Foutkaartjies", value=str(open_faults)),
                Metric(label="Hoë-prioriteit Foute", value=str(high_priority_faults)),
                Metric(label="Hoë-prioriteit Werksopdragte", value=str(high_priority_jobs)),
                Metric(label="Gemma Auto-konsepte", value=str(auto_drafts)),
            ],
            insights=all_insights,
            suggestions=suggestions,
            chart=ChartData(
                type="bar",
                labels=["Bates", "Onopgeloste Foute", "Aktiewe Werksopdragte", "Voorraad"],
                datasets=[ChartDataset(label="Aantal", data=[total, active_faults, active_jobs, stock_items], backgroundColor=["#935e28", "#b8863c", "#d4a357", "#e8c49a"])],
            ),
        )

    elif page == "assets":
        total = context.get("total", 0)
        active = context.get("active", 0)
        maintenance = context.get("maintenance", 0)
        type_labels = context.get("type_labels", [])
        type_counts = context.get("type_counts", [])
        asset_list = context.get("raw_assets", [])

        insights = [f"{total} bates in die stelsel, waarvan {active} aktief is en {maintenance} in instandhouding."]
        suggestions = _fallback_suggestions(page, context)

        in_maint = [a for a in asset_list if a.get("asset_status") == "Instandhouding"]
        if in_maint:
            names = ", ".join(a.get("asset_name", f"ID {a['asset_id']}") for a in in_maint[:3])
            insights.append(f"Instandhouding: {names}")

        return AnalyticsResponse(
            summary=f"{total} bates: {active} aktief, {maintenance} in instandhouding.",
            metrics=[
                Metric(label="Totaal", value=str(total)),
                Metric(label="Aktief", value=str(active)),
                Metric(label="Instandhouding", value=str(maintenance)),
            ],
            insights=insights,
            suggestions=suggestions,
            chart=ChartData(
                type="bar",
                labels=type_labels or ["Bates"],
                datasets=[ChartDataset(label="Bates per tipe", data=type_counts or [total], backgroundColor=["#935e28", "#b8863c", "#d4a357", "#e8c49a", "#f0dcc8"])],
            ),
        )

    elif page == "stock":
        total = context.get("total", 0)
        low = context.get("low_stock", 0)
        total_amount = context.get("total_amount", 0)
        item_labels = context.get("item_labels", [])
        item_counts = context.get("item_counts", [])
        stock_list = context.get("raw_stock", [])

        insights = [f"{total} voorraaditems, waarvan {low} laag is."]
        suggestions = _fallback_suggestions(page, context)

        low_items = [s for s in stock_list if s.get("stock_amount", 0) < s.get("stock_minimum", 0)]
        if low_items:
            low_names = ", ".join(s.get("stock_name", f"ID {s['stock_id']}") for s in low_items[:3])
            insights.append(f"Lae voorraad: {low_names}")

        return AnalyticsResponse(
            summary=f"{total} voorraaditems, {low} benodig hervulling.",
            metrics=[
                Metric(label="Totaal", value=str(total)),
                Metric(label="Lae Voorraad", value=str(low)),
                Metric(label="Totale Hoeveelheid", value=str(total_amount)),
            ],
            insights=insights,
            suggestions=suggestions,
            chart=ChartData(
                type="bar",
                labels=item_labels or ["Voorraad"],
                datasets=[ChartDataset(label="Voorraadvlak", data=item_counts or [0], backgroundColor=["#935e28"] * len(item_counts))],
            ),
        )

    elif page == "fault-tickets":
        total = context.get("open", 0) + context.get("closed", 0)
        op = context.get("open", 0)
        closed = context.get("closed", 0)
        pri_labels = context.get("priority_labels", [])
        pri_counts = context.get("priority_counts", [])
        fault_list = context.get("raw_faults", [])

        insights = [f"{total} foutkaartjies: {op} oop, {closed} gesluit."]
        suggestions = _fallback_suggestions(page, context)

        high_pri = [f for f in fault_list if f.get("fault_priority") in ("Hoog", "Dringend")]
        if high_pri:
            insights.append(f"{len(high_pri)} hoë-prioriteit foute wag vir aandag.")

        return AnalyticsResponse(
            summary=f"{total} foutkaartjies — {op} nog oop.",
            metrics=[
                Metric(label="Totaal", value=str(total)),
                Metric(label="Oop", value=str(op)),
                Metric(label="Gesluit", value=str(closed)),
            ],
            insights=insights,
            suggestions=suggestions,
            chart=ChartData(
                type="bar",
                labels=pri_labels or ["Foute"],
                datasets=[ChartDataset(label="Foute per prioriteit", data=pri_counts or [total], backgroundColor=["#b91c1c", "#c97c3c", "#935e28", "#d4a357"])],
            ),
        )

    elif page == "work-orders":
        total = context.get("pending", 0) + context.get("completed", 0)
        pend = context.get("pending", 0)
        comp = context.get("completed", 0)
        status_labels = context.get("status_labels", [])
        status_counts = context.get("status_counts", [])
        job_list = context.get("raw_jobs", [])

        suggestions = _fallback_suggestions(page, context)
        unassigned = [j for j in job_list if not j.get("assigned_to")]
        insights = [f"{total} werksopdragte: {pend} hangende, {comp} voltooid."]
        if unassigned:
            insights.append(f"{len(unassigned)} werksopdragte het geen toewysing nie.")

        return AnalyticsResponse(
            summary=f"{total} werksopdragte — {pend} nog aan die gang.",
            metrics=[
                Metric(label="Totaal", value=str(total)),
                Metric(label="Hangend", value=str(pend)),
                Metric(label="Voltooid", value=str(comp)),
            ],
            insights=insights,
            suggestions=suggestions,
            chart=ChartData(
                type="bar",
                labels=status_labels or ["Werksopdragte"],
                datasets=[ChartDataset(label="Werksopdragte per status", data=status_counts or [total], backgroundColor=["#935e28", "#10b981", "#d4a357", "#6b7280"])],
            ),
        )

    elif page == "rooms":
        total = context.get("total", 0)
        type_labels = context.get("type_labels", [])
        type_counts = context.get("type_counts", [])

        return AnalyticsResponse(
            summary=f"{total} lokale in die stelsel.",
            metrics=[Metric(label="Totale Lokale", value=str(total))],
            insights=[f"{total} lokale in die fasiliteit."],
            suggestions=[],
            chart=ChartData(
                type="bar",
                labels=type_labels or ["Lokale"],
                datasets=[ChartDataset(label="Lokale per tipe", data=type_counts or [total], backgroundColor=["#935e28", "#b8863c", "#d4a357"])],
            ),
        )

    elif page == "buildings":
        total = context.get("total", 0)
        per_location = context.get("per_location", {})
        loc_name = context.get("location_name", "Kampus")

        count_text = ", ".join(f"{k}: {v}" for k, v in per_location.items())
        insights = [f"{total} geboue oor {len(per_location)} terreine."]
        if per_location:
            insights.append(count_text)

        return AnalyticsResponse(
            summary=f"{total} geboue in die stelsel.",
            metrics=[Metric(label="Totale Geboue", value=str(total))],
            insights=insights,
            suggestions=[],
            chart=ChartData(
                type="bar",
                labels=list(per_location.keys()) or ["Geboue"],
                datasets=[ChartDataset(label="Geboue per kampus", data=list(per_location.values()) or [total], backgroundColor=["#935e28", "#b8863c", "#d4a357"])],
            ),
        )

    elif page == "terrains":
        total = context.get("total", 0)
        buildings_per = context.get("buildings_per_terrain", {})

        insights = [f"{total} terreine in die stelsel."]
        if buildings_per:
            top = sorted(buildings_per.items(), key=lambda x: -x[1])[:3]
            insights.append("Meeste geboue: " + ", ".join(f"{k} ({v})" for k, v in top))

        return AnalyticsResponse(
            summary=f"{total} terreine in die stelsel.",
            metrics=[Metric(label="Totale Terreine", value=str(total))],
            insights=insights,
            suggestions=[],
            chart=ChartData(
                type="bar",
                labels=list(buildings_per.keys()) or ["Terreine"],
                datasets=[ChartDataset(label="Geboue per terrein", data=list(buildings_per.values()) or [total], backgroundColor=["#935e28", "#b8863c", "#d4a357"])],
            ),
        )

    elif page == "users":
        total = context.get("total", 0)
        active = context.get("active_users", 0)
        per_role = context.get("per_role", {})

        role_text = ", ".join(f"{r}: {c}" for r, c in per_role.items())
        insights = [f"{total} gebruikers ({active} aktief)."]
        if per_role:
            insights.append(f"Rolle: {role_text}")

        return AnalyticsResponse(
            summary=f"{total} gebruikers: {active} aktief.",
            metrics=[
                Metric(label="Totaal", value=str(total)),
                Metric(label="Aktief", value=str(active)),
            ],
            insights=insights,
            suggestions=[],
        )

    elif page == "calendar":
        total = context.get("total", 0)
        upcoming = context.get("upcoming", 0)

        return AnalyticsResponse(
            summary=f"{total} kalendergebeurtenisse ({upcoming} komende).",
            metrics=[
                Metric(label="Totaal", value=str(total)),
                Metric(label="Komend", value=str(upcoming)),
            ],
            insights=[f"{total} gebeurtenisse, waarvan {upcoming} nog komende is."],
            suggestions=[],
        )

    elif page == "predictions":
        total = context.get("total", 0)
        replacement_suggested = context.get("replacement_suggested", 0)
        maintenance_overdue = context.get("maintenance_overdue", 0)
        high_risk = context.get("high_risk", 0)
        model_available = context.get("model_available", False)
        top_risk = context.get("top_risk", [])

        if model_available:
            summary = f"Survival-model aktief: {high_risk} bates met hoë ML-risiko uit {total}."
        else:
            summary = f"{total} bates ontleed. Survival-model nie beskikbaar nie (benodig genoeg data) — reëls-gebaseerde voorspellings word gebruik."

        insights = []
        if model_available:
            insights.append(f"{high_risk} bates het ≥50% faalkans binne 12 maande per ML-model.")
            if top_risk:
                insights.append("Hoogste risiko: " + ", ".join(f"{t['asset_name']} ({t['prob_pct']}%)" for t in top_risk))
        else:
            insights.append("Die ML-survival-model verg ≥50 bates en ≥80 foutgebeurtenisse; sodra daar genoeg data is, verskyn ML-risiko hier.")

        return AnalyticsResponse(
            summary=summary,
            metrics=[
                Metric(label="Totale Bates", value=str(total)),
                Metric(label="Vervanging Voorgestel", value=str(replacement_suggested)),
                Metric(label="Onderhoud Agterstallig", value=str(maintenance_overdue)),
                Metric(label="ML Hoë Risiko", value=str(high_risk) if model_available else "—"),
            ],
            insights=insights,
            suggestions=[],
            chart=None,
        )

    elif page == "ai-drafts":
        total = context.get("total", 0)
        pending = context.get("pending", 0)
        approved = context.get("approved", 0)
        rejected = context.get("rejected", 0)
        auto = context.get("auto", 0)

        insights = []
        if pending > 0:
            insights.append(f"{pending} konsepte wag vir FK/Admin-goedkeuring.")
        insights.append(f"{auto} konsepte is outomaties gegenereer deur die skandeerder.")

        return AnalyticsResponse(
            summary=f"{pending} AI-werkskonsepte wag op goedkeuring ({approved} goedgekeur, {rejected} verwerp) van {total} totaal.",
            metrics=[
                Metric(label="Wag op goedkeuring", value=str(pending)),
                Metric(label="Goedgekeur", value=str(approved)),
                Metric(label="Verwerp", value=str(rejected)),
                Metric(label="Outo-geskep", value=str(auto)),
            ],
            insights=insights,
            suggestions=[],
            chart=None,
        )

    return AnalyticsResponse(
        summary="Kies 'n bladsy om insigte te sien.",
        metrics=[],
        insights=[],
    )


# ─── Public entry point ──────────────────────────────────────


def generate_insights(page: str, session, date_from: datetime = None, date_to: datetime = None, user=None) -> AnalyticsResponse:
    context = _gather_context(page, session, date_from, date_to, user=user)
    response = _fallback_insights(page, context, session, user=user)
    digest = _llm_ops_digest(response, page)
    if digest is not None:
        response.digest = digest
    return response


# ─── Suggestion execution ────────────────────────────────────


def _execute_suggestion(suggestion: Suggestion, session, user_id: int) -> dict:
    from ..models.job import Jobcard
    from ..models.stock import Stock

    typ = suggestion.type
    params = suggestion.params
    now = datetime.now(timezone.utc).replace(tzinfo=None)

    if typ == "create_work_order":
        job = Jobcard(
            job_desc=params.get("job_desc", ""),
            job_createddatetime=now,
            room_id=params.get("room_id"),
            building_id=params.get("building_id"),
            location_id=params.get("location_id"),
            fault_id=params.get("fault_id"),
            asset_id=params.get("asset_id"),
            job_priority=params.get("job_priority", "Normal"),
            user_id=user_id,
        )
        session.add(job)
        session.commit()
        return {"success": True, "message": "Werksopdrag geskep", "jobcard_id": job.jobcard_id}

    if typ == "reorder_stock":
        stock = session.get(Stock, params.get("stock_id"))
        if stock:
            amount = params.get("amount", stock.stock_minimum or 10)
            stock.stock_amount = (stock.stock_amount or 0) + amount
            session.add(stock)
            session.commit()
            return {"success": True, "message": f"Voorraad hervul met {amount} eenhede"}
        return {"success": False, "message": "Voorraad item nie gevind nie"}

    if typ == "assign_job":
        job = session.get(Jobcard, params.get("jobcard_id"))
        if job:
            job.assigned_to = user_id
            session.add(job)
            session.commit()
            return {"success": True, "message": "Werksopdrag toegewys aan uitvoerder"}
        return {"success": False, "message": "Werksopdrag nie gevind nie"}

    return {"success": False, "message": f"Onbekende suggestion tipe: {typ}"}


# ─── FK kampus scoping (single source of truth) ──────────────


def _build_fk_scope(session, user) -> dict:
    """Compute the FK campus scope for a user — one definition used by both
    ``get_dashboard_summary`` and ``_gather_context``.

    Returns a dict with ``is_fk_scoped`` (True only for an FK whose
    ``location_id`` is set), ``allowed_building_ids``, ``allowed_room_ids``
    (None = unscoped) and ``user_location_id``.
    """
    from ..models.location import Building, Room
    from ..auth.rights_catalog import ROLE_FK

    user_location_id = getattr(user, "location_id", None) if user else None
    is_fk_scoped = bool(user and getattr(user, "role_id", None) == ROLE_FK and user_location_id)
    allowed_building_ids = None
    allowed_room_ids = None
    if is_fk_scoped:
        buildings = session.exec(select(Building).where(Building.location_id == user_location_id)).all()
        allowed_building_ids = {b.building_id for b in buildings}
        rooms = session.exec(select(Room)).all()
        allowed_room_ids = {r.room_id for r in rooms if r.building_id in allowed_building_ids}

    return {
        "is_fk_scoped": is_fk_scoped,
        "allowed_building_ids": allowed_building_ids,
        "allowed_room_ids": allowed_room_ids,
        "user_location_id": user_location_id,
    }


def _in_scope_fault(session, scope: dict, f) -> bool:
    """True when a faultcard belongs to the (possibly FK-scoped) campus."""
    if not scope["is_fk_scoped"]:
        return True
    user_location_id = scope["user_location_id"]
    allowed_building_ids = scope["allowed_building_ids"]
    allowed_room_ids = scope["allowed_room_ids"]
    if getattr(f, "location_id", None) == user_location_id:
        return True
    if getattr(f, "building_id", None) in allowed_building_ids:
        return True
    if getattr(f, "room_id", None) in allowed_room_ids:
        return True
    if getattr(f, "asset_id", None):
        from ..models.asset import Asset

        asset = session.get(Asset, f.asset_id)
        if asset and asset.room_id in allowed_room_ids:
            return True
    return False


def _in_scope_job(session, scope: dict, j) -> bool:
    """True when a jobcard belongs to the (possibly FK-scoped) campus."""
    if not scope["is_fk_scoped"]:
        return True
    user_location_id = scope["user_location_id"]
    allowed_building_ids = scope["allowed_building_ids"]
    allowed_room_ids = scope["allowed_room_ids"]
    if getattr(j, "location_id", None) == user_location_id:
        return True
    if getattr(j, "building_id", None) in allowed_building_ids:
        return True
    if getattr(j, "room_id", None) in allowed_room_ids:
        return True
    if getattr(j, "asset_id", None):
        from ..models.asset import Asset

        asset = session.get(Asset, j.asset_id)
        if asset and asset.room_id in allowed_room_ids:
            return True
    return False


def _in_scope_asset(session, scope: dict, a) -> bool:
    """True when an asset belongs to the (possibly FK-scoped) campus."""
    if not scope["is_fk_scoped"]:
        return True
    return a.room_id in scope["allowed_room_ids"]


def _in_scope_stock(session, scope: dict, s) -> bool:
    """True when a stock item belongs to the (possibly FK-scoped) campus."""
    if not scope["is_fk_scoped"]:
        return True
    return s.room_id in scope["allowed_room_ids"]


def _in_scope_draft(session, scope: dict, draft) -> bool:
    """True when a JobDraft targets the (possibly FK-scoped) campus.

    Campus resolution mirrors ``_in_scope_fault``: direct ``location_id`` /
    ``building_id`` / ``room_id`` fields when present, else via the resolved
    asset/room or the raw candidate id JSON lists.
    """
    if not scope["is_fk_scoped"]:
        return True
    user_location_id = scope["user_location_id"]
    allowed_building_ids = scope["allowed_building_ids"]
    allowed_room_ids = scope["allowed_room_ids"]
    if getattr(draft, "location_id", None) == user_location_id:
        return True
    if getattr(draft, "building_id", None) in allowed_building_ids:
        return True
    if getattr(draft, "room_id", None) in allowed_room_ids:
        return True

    from ..models.asset import Asset

    resolved_asset_id = getattr(draft, "resolved_asset_id", None)
    if resolved_asset_id:
        asset = session.get(Asset, resolved_asset_id)
        if asset and asset.room_id in allowed_room_ids:
            return True

    resolved_room_id = getattr(draft, "resolved_room_id", None)
    if resolved_room_id and resolved_room_id in allowed_room_ids:
        return True

    try:
        asset_ids = json.loads(getattr(draft, "asset_ids", "[]") or "[]")
        for aid in asset_ids:
            asset = session.get(Asset, int(aid))
            if asset and asset.room_id in allowed_room_ids:
                return True
    except (ValueError, TypeError):
        pass

    try:
        room_ids = json.loads(getattr(draft, "room_ids", "[]") or "[]")
        for rid in room_ids:
            if int(rid) in allowed_room_ids:
                return True
    except (ValueError, TypeError):
        pass
    return False


# ─── Context gathering ───────────────────────────────────────


def _gather_context(page: str, session,
                    date_from: datetime = None, date_to: datetime = None, user=None) -> dict:
    from ..models.asset import Asset
    from ..models.stock import Stock
    from ..models.fault import Faultcard
    from ..models.job import Jobcard
    from ..models.location import Room, Building, Location
    from ..models.user import User
    from ..models.calendar_event import CalendarEvent

    ctx: dict = {}

    if page == "assets":
        assets = session.exec(select(Asset)).all()
        from ..models.asset import Assettype
        types = session.exec(select(Assettype)).all()
        type_map = {at.assettype_id: at.assettype_name for at in types}
        ctx["total"] = len(assets)
        status_counts = {}
        type_counts = {}
        ctx["active"] = 0
        ctx["maintenance"] = 0
        for a in assets:
            t = type_map.get(a.assettype_id, "Onbekend")
            type_counts[t] = type_counts.get(t, 0) + 1
            s = _enum_val(a.asset_status)
            status_counts[s] = status_counts.get(s, 0) + 1
            if s == "Aktief":
                ctx["active"] += 1
            elif s == "Instandhouding":
                ctx["maintenance"] += 1
        ctx["type_labels"] = list(type_counts.keys())
        ctx["type_counts"] = list(type_counts.values())
        ctx["types"] = len(type_counts)
        ctx["raw_assets"] = _serialize_records(assets)
        ctx["raw_types"] = _serialize_records(types)

    elif page == "stock":
        items = session.exec(select(Stock)).all()
        ctx["total"] = len(items)
        low = [i for i in items if i.stock_amount is not None and i.stock_minimum is not None and i.stock_amount < i.stock_minimum]
        ctx["low_stock"] = len(low)
        ctx["total_amount"] = sum(i.stock_amount or 0 for i in items)
        ctx["item_labels"] = [i.stock_name or f"Item {i.stock_id}" for i in items[:10]]
        ctx["item_counts"] = [i.stock_amount or 0 for i in items[:10]]
        ctx["raw_stock"] = _serialize_records(items)

    elif page == "fault-tickets":
        faults = session.exec(select(Faultcard)).all()
        ctx["open"] = 0
        ctx["closed"] = 0
        pri_counts = {}
        for f in faults:
            s = _enum_val(f.fault_status)
            if s in ("Oop", "oop"):
                ctx["open"] += 1
            elif s in ("Gesluit", "gesluit", "Closed", "closed"):
                ctx["closed"] += 1
            p = _enum_val(f.fault_priority)
            pri_counts[p] = pri_counts.get(p, 0) + 1
        ctx["priority_labels"] = list(pri_counts.keys())
        ctx["priority_counts"] = list(pri_counts.values())
        ctx["raw_faults"] = _serialize_records(faults)

    elif page == "work-orders":
        jobs = session.exec(select(Jobcard)).all()
        status_counts = {}
        ctx["pending"] = 0
        ctx["completed"] = 0
        for j in jobs:
            s = _enum_val(j.job_status)
            status_counts[s] = status_counts.get(s, 0) + 1
            if s in ("Oop", "oop", "Pending", "pending", "Geskeduleer", "geskeduleer", "SCHEDULED", "scheduled"):
                ctx["pending"] += 1
            elif s in ("Voltooid", "Voltooi", "voltooi", "Completed", "completed"):
                ctx["completed"] += 1
        ctx["status_labels"] = list(status_counts.keys())
        ctx["status_counts"] = list(status_counts.values())
        ctx["raw_jobs"] = _serialize_records(jobs)

    elif page == "rooms":
        rooms = session.exec(select(Room)).all()
        ctx["total"] = len(rooms)
        type_counts = {}
        for r in rooms:
            t = _enum_val(r.room_type)
            type_counts[t] = type_counts.get(t, 0) + 1
        ctx["type_labels"] = list(type_counts.keys())
        ctx["type_counts"] = list(type_counts.values())
        ctx["raw_rooms"] = _serialize_records(rooms)

    elif page == "buildings":
        locs = {l.location_id: l.location_name for l in session.exec(select(Location)).all()}
        buildings = session.exec(select(Building)).all()
        ctx["total"] = len(buildings)
        per_location = {}
        for b in buildings:
            loc_name = locs.get(b.location_id) or f"Kampus {b.location_id}" if b.location_id else "Onbekend"
            per_location[loc_name] = per_location.get(loc_name, 0) + 1
        ctx["per_location"] = per_location
        first_loc_name = locs.get(buildings[0].location_id) if buildings else ""
        ctx["location_name"] = first_loc_name or ""
        ctx["raw_buildings"] = _serialize_records(buildings)

    elif page == "terrains":
        locs = {l.location_id: l.location_name for l in session.exec(select(Location)).all()}
        terrains = session.exec(select(Location)).all()
        ctx["total"] = len(terrains)
        buildings = session.exec(select(Building)).all()
        bp = {}
        for b in buildings:
            loc_name = locs.get(b.location_id) or f"Kampus {b.location_id}" if b.location_id else "Onbekend"
            bp[loc_name] = bp.get(loc_name, 0) + 1
        ctx["buildings_per_terrain"] = bp
        ctx["raw_terrains"] = _serialize_records(terrains)

    elif page == "dashboard":
        scope = _build_fk_scope(session, user)
        all_assets = session.exec(select(Asset)).all()
        all_assets = [a for a in all_assets if _in_scope_asset(session, scope, a)]
        ctx["assets"] = len(all_assets)
        all_faults = session.exec(select(Faultcard)).all()
        faults = [f for f in all_faults if _in_scope_fault(session, scope, f)]
        # "Onopgelos" = enigiets behalwe Gesluit; geslote foute is afgehandel.
        ctx["active_faults"] = sum(1 for f in faults if _enum_val(f.fault_status) != "Gesluit")
        ctx["faults_by_status"] = dict(sorted(Counter(_enum_val(f.fault_status) for f in faults).items(), key=lambda kv: (-kv[1], kv[0])))
        all_jobs = session.exec(select(Jobcard)).all()
        jobs = [j for j in all_jobs if _in_scope_job(session, scope, j)]
        # "Aktief" = enigiets behalwe Voltooid/Gekanselleer.
        ctx["active_jobs"] = sum(1 for j in jobs if _enum_val(j.job_status) not in ("Voltooid", "Gekanselleer"))
        ctx["jobs_by_status"] = dict(sorted(Counter(_enum_val(j.job_status) for j in jobs).items(), key=lambda kv: (-kv[1], kv[0])))
        all_stocks = session.exec(select(Stock)).all()
        stocks = [s for s in all_stocks if _in_scope_stock(session, scope, s)]
        ctx["stock_items"] = len(stocks)
        all_rooms = session.exec(select(Room)).all()
        if scope["is_fk_scoped"]:
            all_rooms = [r for r in all_rooms if r.room_id in scope["allowed_room_ids"]]
        ctx["rooms"] = len(all_rooms)
        all_buildings = session.exec(select(Building)).all()
        if scope["is_fk_scoped"]:
            all_buildings = [b for b in all_buildings if b.building_id in scope["allowed_building_ids"]]
        ctx["buildings"] = len(all_buildings)
        ctx["raw_assets"] = _serialize_records(all_assets, limit=10)
        ctx["raw_faults"] = _serialize_records(faults, limit=10)
        ctx["raw_jobs"] = _serialize_records(jobs, limit=10)
        ctx["raw_stock"] = _serialize_records(stocks, limit=10)
        # ── Nuwe FK-scoped KPIs (dieselde definisies as get_dashboard_summary) ──
        ctx["open_faults"] = sum(1 for f in faults if _enum_val(f.fault_status) != "Gesluit")
        ctx["high_priority_faults"] = sum(
            1 for f in faults
            if _enum_val(f.fault_status) != "Gesluit"
            and _enum_val(f.fault_priority).upper() in ("HOOG", "HIGH")
        )
        high_job_priorities = ("HOOG", "DRINGEND", "HIGH", "URGENT")
        ctx["high_priority_jobs"] = sum(
            1 for j in jobs
            if _enum_val(j.job_status) not in ("Voltooid", "Gekanselleer")
            and _enum_val(j.job_priority).upper() in high_job_priorities
        )
        from ..models.jobdraft import JobDraft

        all_drafts = session.exec(select(JobDraft)).all()
        drafts = [d for d in all_drafts if _in_scope_draft(session, scope, d)]
        ctx["auto_drafts"] = sum(1 for d in drafts if d.source == "auto")
        ctx["raw_drafts"] = _serialize_records(drafts, limit=10)
        ctx["is_fk_scoped"] = scope["is_fk_scoped"]
        if scope["is_fk_scoped"] and scope["user_location_id"]:
            loc = session.get(Location, scope["user_location_id"])
            ctx["location_name"] = loc.location_name if loc else ""
        else:
            ctx["location_name"] = ""

    elif page == "users":
        users = session.exec(select(User)).all()
        ctx["total"] = len(users)
        ctx["active_users"] = sum(1 for u in users if getattr(u, "user_status", "") in ("Aktief", "aktief", "Active", "active"))
        role_counts = {}
        for u in users:
            r = f"Rol {u.role_id}" if u.role_id else "Onbekend"
            role_counts[r] = role_counts.get(r, 0) + 1
        ctx["per_role"] = role_counts
        ctx["raw_users"] = _serialize_records(users, exclude_fields=["user_password"])

    elif page == "calendar":
        events = session.exec(select(CalendarEvent)).all()
        ctx["total"] = len(events)
        now = datetime.now(timezone.utc).replace(tzinfo=None)
        ctx["upcoming"] = sum(1 for e in events if e.start_datetime and e.start_datetime > now)
        ctx["raw_events"] = _serialize_records(events)

    elif page == "predictions":
        from ..services.prediction_service import PredictionService

        preds = PredictionService().getPredictions(session)
        ctx["total"] = len(preds)
        ctx["replacement_suggested"] = sum(1 for p in preds if p.replacement_suggested)
        ctx["maintenance_overdue"] = sum(1 for p in preds if p.maintenance_overdue)
        ctx["model_available"] = any(p.survival_model_available for p in preds)
        ctx["high_risk"] = sum(1 for p in preds if p.survival_high_risk)
        risk_sorted = sorted(
            (p for p in preds if p.survival_failure_prob_12mo is not None),
            key=lambda p: p.survival_failure_prob_12mo,
            reverse=True,
        )
        ctx["top_risk"] = [
            {
                "asset_name": p.asset_name,
                "serial": p.asset_serial,
                "prob_pct": round(p.survival_failure_prob_12mo * 100) if p.survival_failure_prob_12mo is not None else None,
            }
            for p in risk_sorted[:3]
        ]
        ctx["raw_predictions"] = [
            {
                "asset_name": p.asset_name,
                "asset_serial": p.asset_serial,
                "survival_high_risk": p.survival_high_risk,
                "survival_failure_prob_12mo": p.survival_failure_prob_12mo,
            }
            for p in risk_sorted[:10]
        ]
        # Module-level model stats — identical on every prediction.
        first_with_events = next((p for p in preds if p.survival_events_count is not None), None)
        ctx["survival_events"] = first_with_events.survival_events_count if first_with_events else None
        ctx["survival_assets"] = None
        if first_with_events is not None:
            from ..services import survival_service

            ctx["survival_assets"] = survival_service.get_status().get("assets")

    elif page == "ai-drafts":
        from ..models.jobdraft import JobDraft

        drafts = session.exec(select(JobDraft)).all()
        ctx["total"] = len(drafts)
        ctx["pending"] = sum(1 for d in drafts if d.status == "draft")
        ctx["approved"] = sum(1 for d in drafts if d.status == "approved")
        ctx["rejected"] = sum(1 for d in drafts if d.status == "rejected")
        ctx["auto"] = sum(1 for d in drafts if d.source == "auto")
        ctx["raw_drafts"] = _serialize_records(drafts, limit=10)

    return ctx


def get_dashboard_summary(session, user=None, include_ai_charts: bool = False) -> dict:
    """Usable dashboard metrics for FK/Admin — replaces vanity Totale Bates."""
    from datetime import timedelta
    from collections import Counter, defaultdict
    from ..models.asset import Asset
    from ..models.stock import Stock
    from ..models.fault import Faultcard
    from ..models.job import Jobcard
    from ..models.location import Room, Building, Location
    from ..services.prediction_service import PredictionService
    from ..auth.rights_catalog import ROLE_FK

    now = datetime.now(timezone.utc).replace(tzinfo=None)
    two_days_ago = now - timedelta(days=2)
    thirty_days_ago = now - timedelta(days=30)

    # ── FK scoping (gedeelde definisie met _gather_context) ──
    scope = _build_fk_scope(session, user)
    is_fk_scoped = scope["is_fk_scoped"]
    user_location_id = scope["user_location_id"]
    allowed_room_ids = scope["allowed_room_ids"]
    if is_fk_scoped:
        buildings = session.exec(select(Building).where(Building.location_id == user_location_id)).all()
        rooms = session.exec(select(Room)).all()
    else:
        buildings = session.exec(select(Building)).all()
        rooms = session.exec(select(Room)).all()

    building_map = {b.building_id: b.building_name for b in buildings}
    room_map = {r.room_id: (r.room_name, r.building_id) for r in rooms}

    # ── Predictions (rules + ML) ──
    try:
        preds = PredictionService().getPredictions(session)
        if is_fk_scoped:
            filtered = []
            for p in preds:
                a = session.get(Asset, p.asset_id)
                if a and _in_scope_asset(session, scope, a):
                    filtered.append(p)
            preds = filtered
    except Exception:
        preds = []

    overdue_maintenance = sum(1 for p in preds if p.maintenance_overdue)
    replacement_suggested = sum(1 for p in preds if p.replacement_suggested)
    high_risk = sum(1 for p in preds if getattr(p, "survival_high_risk", False))
    # Risk distribution
    veilig = 0
    monitor = 0
    vervang = 0
    for p in preds:
        pct = getattr(p, "lifespan_pct_used", None)
        is_high = getattr(p, "survival_high_risk", False) or p.replacement_suggested or p.lifespan_exceeded
        if is_high or (pct is not None and pct >= 100):
            vervang += 1
        elif pct is not None and pct >= 80:
            monitor += 1
        else:
            veilig += 1

    # Top risk
    def _risk_score(p):
        prob = getattr(p, "survival_failure_prob_12mo", 0) or 0
        pct = getattr(p, "lifespan_pct_used", 0) or 0
        return (prob * 100) + (pct / 2) + (10 if p.replacement_suggested else 0)
    top_risk = sorted(preds, key=_risk_score, reverse=True)[:5]
    top_risk_list = [
        {
            "asset_id": p.asset_id,
            "asset_name": p.asset_name,
            "asset_serial": p.asset_serial,
            "building": building_map.get(room_map.get(session.get(Asset, p.asset_id).room_id, (None, None))[1], "") if session.get(Asset, p.asset_id) and session.get(Asset, p.asset_id).room_id in room_map else "",
            "lifespan_pct_used": getattr(p, "lifespan_pct_used", None),
            "failure_prob": getattr(p, "survival_failure_prob_12mo", None),
            "reason": (p.replacement_reason or "")[:120],
            "replacement_suggested": p.replacement_suggested,
            "maintenance_overdue": p.maintenance_overdue,
        }
        for p in top_risk
    ]

    # ── Faults actionable ──
    faults = session.exec(select(Faultcard)).all()
    faults = [f for f in faults if _in_scope_fault(session, scope, f)]
    # unassigned high priority >2 days old and still open
    open_statuses = {"Oop", "Wag", "Bevestig", "Besig"}
    unassigned_high = 0
    for f in faults:
        s = _enum_val(f.fault_status)
        p = _enum_val(f.fault_priority)
        if s in open_statuses and p == "Hoog":
            rd = f.fault_reportdatetime
            if rd and rd < two_days_ago:
                unassigned_high += 1
            elif not rd:
                unassigned_high += 1

    # faults per building last 30 days
    recent_faults = [f for f in faults if f.fault_reportdatetime and f.fault_reportdatetime >= thirty_days_ago]
    # try to resolve building for each fault (direct building_id else via room/asset)
    def _fault_building_name(f):
        if f.building_id and f.building_id in building_map:
            return building_map[f.building_id]
        if f.room_id and f.room_id in room_map:
            bid = room_map[f.room_id][1]
            return building_map.get(bid, "Onbekend")
        if f.asset_id:
            a = session.get(Asset, f.asset_id)
            if a and a.room_id in room_map:
                bid = room_map[a.room_id][1]
                return building_map.get(bid, "Onbekend")
        if f.location_id:
            # fallback to location
            loc = session.get(Location, f.location_id)
            return loc.location_name if loc else "Onbekend"
        return "Onbekend"
    per_building = Counter(_fault_building_name(f) for f in recent_faults)
    faults_per_building = [{"building": k, "count": v} for k, v in per_building.most_common(6)]

    # trend last 8 weeks: faults created per week, jobs completed per week
    jobs = session.exec(select(Jobcard)).all()
    jobs = [j for j in jobs if _in_scope_job(session, scope, j)]
    # overdue jobs
    overdue_jobs = 0
    for j in jobs:
        s = _enum_val(j.job_status)
        if s not in ("Voltooid", "Gekanselleer"):
            if j.job_scheduled_end_datetime and j.job_scheduled_end_datetime < now:
                overdue_jobs += 1

    # weekly buckets last 8 weeks
    weeks = []
    week_labels = []
    for i in range(7, -1, -1):
        ws = now - timedelta(weeks=i, days=now.weekday())
        ws = ws.replace(hour=0, minute=0, second=0, microsecond=0)
        we = ws + timedelta(days=7)
        weeks.append((ws, we))
        week_labels.append(ws.strftime("%d %b"))

    faults_per_week = []
    jobs_completed_per_week = []
    for ws, we in weeks:
        fc = sum(1 for f in faults if f.fault_reportdatetime and ws <= f.fault_reportdatetime < we)
        jc = sum(1 for j in jobs if j.job_finisheddatetime and ws <= j.job_finisheddatetime < we and _enum_val(j.job_status) == "Voltooid")
        faults_per_week.append(fc)
        jobs_completed_per_week.append(jc)

    # stock critical
    stocks = session.exec(select(Stock)).all()
    stocks = [s for s in stocks if _in_scope_stock(session, scope, s)]
    critical_stock = sum(1 for s in stocks if s.stock_amount is not None and s.stock_minimum is not None and s.stock_amount < s.stock_minimum)
    # top low stock
    low_sorted = sorted(
        [s for s in stocks if s.stock_amount is not None and s.stock_minimum is not None],
        key=lambda s: (s.stock_amount - s.stock_minimum)
    )[:5]
    critical_stock_list = [
        {"stock_id": s.stock_id, "stock_name": s.stock_name, "amount": s.stock_amount, "minimum": s.stock_minimum, "room_id": s.room_id}
        for s in low_sorted if s.stock_amount < s.stock_minimum
    ]
    # fallback if none critical, show lowest ratio
    if not critical_stock_list:
        critical_stock_list = [
            {"stock_id": s.stock_id, "stock_name": s.stock_name, "amount": s.stock_amount, "minimum": s.stock_minimum, "room_id": s.room_id}
            for s in low_sorted[:5]
        ]

    # jobs per status last 8 weeks (for stacked bar alternative) - also overall pending vs completed
    status_counts = Counter(_enum_val(j.job_status) for j in jobs)
    pending = sum(status_counts.get(s, 0) for s in ("Oop", "Wag", "Geskeduleer", "Besig"))
    completed = status_counts.get("Voltooid", 0)

    # ── 9 AI visuals — gegenereer elke keer as AI-statistiek run (via chart_ai_service, LLM waar beskikbaar) ──
    ai_charts = {}
    try:
        from .chart_ai_service import generate_all_charts

        ai_charts = generate_all_charts(session, user)
    except Exception as e:
        import logging as _lg

        _lg.getLogger(__name__).warning("AI charts generering misluk, gaan voort sonder: %s", e)
        ai_charts = {}
    # ── 9 AI visuals — only generated on the voorspellings page (via ?include_ai_charts=true) ──
    ai_charts = {}
    if include_ai_charts:
        try:
            from .chart_ai_service import generate_all_charts

            ai_charts = generate_all_charts(session, user)
        except Exception as e:
            import logging as _lg

            _lg.getLogger(__name__).warning("AI charts generering misluk, gaan voort sonder: %s", e)
            ai_charts = {}

    # ── Nuwe FK-scoped KPIs (dieselde definisies as _gather_context dashboard) ──
    open_faults = sum(1 for f in faults if _enum_val(f.fault_status) != "Gesluit")
    high_priority_faults = sum(
        1 for f in faults
        if _enum_val(f.fault_status) != "Gesluit"
        and _enum_val(f.fault_priority).upper() in ("HOOG", "HIGH")
    )
    high_priority_jobs = sum(
        1 for j in jobs
        if _enum_val(j.job_status) not in ("Voltooid", "Gekanselleer")
        and _enum_val(j.job_priority).upper() in ("HOOG", "DRINGEND", "HIGH", "URGENT")
    )
    from ..models.jobdraft import JobDraft

    all_drafts = session.exec(select(JobDraft)).all()
    auto_drafts = sum(1 for d in all_drafts if d.source == "auto" and _in_scope_draft(session, scope, d))

    return {
        "kpis": {
            "overdue_maintenance": overdue_maintenance,
            "unassigned_high_faults": unassigned_high,
            "overdue_jobs": overdue_jobs,
            "critical_stock": critical_stock,
            "replacement_suggested": replacement_suggested,
            "high_risk": high_risk,
            "pending_jobs": pending,
            "completed_jobs": completed,
            "open_faults": open_faults,
            "high_priority_faults": high_priority_faults,
            "high_priority_jobs": high_priority_jobs,
            "auto_drafts": auto_drafts,
        },
        "risk_distribution": {"veilig": veilig, "monitor": monitor, "vervang": vervang},
        "faults_per_building": faults_per_building,
        "trend": {"labels": week_labels, "faults_per_week": faults_per_week, "jobs_completed_per_week": jobs_completed_per_week},
        "top_risk_assets": top_risk_list,
        "critical_stock_list": critical_stock_list,
        "ai_charts": ai_charts,
        "scope": "fk" if is_fk_scoped else "all",
        "location_name": session.get(Location, user_location_id).location_name if is_fk_scoped and user_location_id else None,
    }


def _count_by(session, model, group_field: str, label_field: str = None,
              date_field: str = None, date_from: datetime = None, date_to: datetime = None) -> dict:
    query = select(model)
    if date_from and date_field:
        query = query.where(getattr(model, date_field) >= date_from)
    if date_to and date_field:
        query = query.where(getattr(model, date_field) <= date_to)
    rows = session.exec(query).all()
    counts = {}
    for r in rows:
        key = str(getattr(r, group_field, "Onbekend") or "Onbekend")
        counts[key] = counts.get(key, 0) + 1
    return counts


def _enum_val(v):
    """Return .value if v is an Enum, otherwise v (as string fallback)."""
    if v is None:
        return "Onbekend"
    if hasattr(v, 'value'):
        return v.value
    return str(v)


def _serialize_records(records, exclude_fields=None, limit=500):
    """Serialize SQLModel records to plain dicts."""
    exclude = set(exclude_fields or [])
    result = []
    for r in records:
        d = {}
        for col in r.__table__.columns:
            if col.name in exclude:
                continue
            val = getattr(r, col.name)
            if hasattr(val, 'value'):
                val = val.value
            elif isinstance(val, datetime):
                val = val.isoformat()
            d[col.name] = val
        result.append(d)
    if limit and len(result) > limit:
        result = result[:limit]
    return result
