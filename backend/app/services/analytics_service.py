import json
from sqlmodel import Session, select, func
from datetime import datetime, timezone

from ..models.analytics import AnalyticsResponse, Metric, ChartData, ChartDataset, Suggestion


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


def _fallback_insights(page: str, context: dict, session=None) -> AnalyticsResponse:
    if page == "dashboard":
        total = context.get("assets", 0)
        open_faults = context.get("open_faults", 0)
        work_orders = context.get("work_orders", 0)
        stock_items = context.get("stock_items", 0)
        rooms = context.get("rooms", 0)
        buildings = context.get("buildings", 0)

        suggestions = _fallback_suggestions(page, context)
        all_insights = [
            f"Daar is {total} bates, {open_faults} oop foutkaartjies, en {work_orders} werksopdragte.",
        ]
        if open_faults > 0:
            all_insights.append(f"{open_faults} foutkaartjies wag nog vir aandag.")
        if stock_items > 0:
            all_insights.append(f"{stock_items} voorraaditems word tans bestuur.")
        all_insights.append(f"Die fasiliteit het {rooms} lokale oor {buildings} geboue.")

        return AnalyticsResponse(
            summary=f"Oorsig van {total} bates, {open_faults} oop foute, {work_orders} werksopdragte.",
            metrics=[
                Metric(label="Totale Bates", value=str(total)),
                Metric(label="Oop Foute", value=str(open_faults)),
                Metric(label="Werksopdragte", value=str(work_orders)),
                Metric(label="Voorraaditems", value=str(stock_items)),
            ],
            insights=all_insights,
            suggestions=suggestions,
            chart=ChartData(
                type="bar",
                labels=["Bates", "Oop Foute", "Werksopdragte", "Voorraad"],
                datasets=[ChartDataset(label="Aantal", data=[total, open_faults, work_orders, stock_items], backgroundColor=["#935e28", "#b8863c", "#d4a357", "#e8c49a"])],
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
            summary=f"{pending} AI-foutkonsepte wag op goedkeuring ({approved} goedgekeur, {rejected} verwerp) van {total} totaal.",
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


def generate_insights(page: str, session, date_from: datetime = None, date_to: datetime = None) -> AnalyticsResponse:
    context = _gather_context(page, session, date_from, date_to)
    return _fallback_insights(page, context, session)


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


# ─── Context gathering ───────────────────────────────────────


def _gather_context(page: str, session,
                    date_from: datetime = None, date_to: datetime = None) -> dict:
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
        all_assets = session.exec(select(Asset)).all()
        ctx["assets"] = len(all_assets)
        faults = session.exec(select(Faultcard)).all()
        ctx["open_faults"] = sum(1 for f in faults if _enum_val(f.fault_status) in ("Oop", "oop"))
        ctx["work_orders"] = len(session.exec(select(Jobcard)).all())
        ctx["stock_items"] = len(session.exec(select(Stock)).all())
        ctx["rooms"] = len(session.exec(select(Room)).all())
        ctx["buildings"] = len(session.exec(select(Building)).all())
        ctx["raw_assets"] = _serialize_records(all_assets, limit=10)
        ctx["raw_faults"] = _serialize_records(faults, limit=10)

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
