import os
import json
from functools import lru_cache
from sqlmodel import Session, select, func
from datetime import datetime, timedelta, timezone

from ..models.analytics import AnalyticsResponse, Metric, ChartData, ChartDataset, Suggestion, ChatMessage


# ─── OpenAI integration (optional) ─────────────────────────────
try:
    from openai import OpenAI
    _openai_available = True
except ImportError:
    _openai_available = False


def _openai_insights(page: str, context: dict) -> AnalyticsResponse:
    try:
        if not _openai_available:
            return _fallback_insights(page, context)
        client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))
        prompt = _build_prompt(page, context)
        resp = client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[
                {"role": "system", "content": "Jy is 'n fasiliteitbestuur-analis. Gee insigte en aksie-voorstelle in Afrikaans. Antwoord altyd met geldige JSON."},
                {"role": "user", "content": prompt},
            ],
            response_format={"type": "json_object"},
            temperature=0.3,
        )
        raw = resp.choices[0].message.content
        data = json.loads(raw)
        suggestions = []
        for s in data.get("suggestions", []):
            suggestions.append(Suggestion(**s))
        return AnalyticsResponse(
            summary=data.get("summary", ""),
            metrics=[Metric(**m) for m in data.get("metrics", [])],
            insights=data.get("insights", []),
            suggestions=suggestions,
            chart=ChartData(**data["chart"]) if data.get("chart") else None,
        )
    except Exception:
        return _fallback_insights(page, context, session=None)


_FEW_SHOT = """
Voorbeeld van verwagte JSON-formaat (insluitend suggestions):
{
  "summary": "Daar is tans 45 bates in die stelsel, waarvan 12 in instandhouding is.",
  "metrics": [{"label": "Totale Bates", "value": "45"}, {"label": "Instandhouding", "value": "12"}],
  "insights": ["4 IT-bates is ouer as 5 jaar en benodig aandag.", "Bate 'Dell R740' wag al 45 dae vir instandhouding."],
  "suggestions": [
    {"type": "create_work_order", "label": "Skep werksopdrag vir Dell R740", "description": "Hierdie bate is al 45 dae in instandhouding.", "params": {"job_desc": "Instandhouding: Dell R740", "asset_id": 1, "job_priority": "Dringend"}},
    {"type": "reorder_stock", "label": "Hervul Toiletpapier", "description": "Toiletpapier voorraad is 2, minimum is 10.", "params": {"stock_id": 1, "amount": 15}}
  ],
  "chart": {"type": "bar", "labels": ["Elektries", "Meganies", "IT"], "datasets": [{"label": "Bates", "data": [20, 15, 10], "backgroundColor": ["#935e28"]}]}
}
"""


def _build_prompt(page: str, context: dict) -> str:
    base = f"Page: {page}\nData: {json.dumps(context, default=str)}\n\n{_FEW_SHOT}\n"
    prompts = {
        "assets": base + "Gee dinamiese insigte oor bates. Verwys na spesifieke bates by naam. Sluit 'n staafgrafiek in van bates per tipe. Stel aksies voor soos om werksopdragte te skep vir bates wat lank in instandhouding is.",
        "stock": base + "Gee dinamiese insigte oor voorraad. Verwys na spesifieke items by naam. Stel aksies voor om lae voorraad te hervul. Staafgrafiek van voorraadvlakke per item.",
        "rooms": base + "Gee dinamiese insigte oor lokale. Verwys na spesifieke lokale by naam. Stel inspeksies voor vir lokale met foute. Staafgrafiek van lokale per gebou.",
        "buildings": base + "Gee dinamiese insigte oor geboue, per kampus. Stel voor waar aandag nodig is. Staafgrafiek van geboue per kampus.",
        "terrains": base + "Gee dinamiese insigte oor terreine/kampuste. Stel voor waar uitbreiding of aandag nodig is. Staafgrafiek.",
        "fault-tickets": base + "Gee dinamiese insigte oor foutkaartjies. Verwys na spesifieke foute. Stel aksies voor soos om werksopdragte te skep vir hoë-prioriteit foute of ou foute te sluit. Staafgrafiek van foute per prioriteit.",
        "work-orders": base + "Gee dinamiese insigte oor werksopdragte. Verwys na spesifieke werksopdragte. Stel aksies voor soos om ontoegewysde werksopdragte aan te wys of agterstallige werk te herprioritiseer. Staafgrafiek van werksopdragte per status.",
        "dashboard": base + "Gee 'n hoëvlak samevatting van die fasiliteit. Stel oorkoepelende aksies voor. Staafgrafiek van maandelikse aktiwiteit.",
        "users": base + "Gee insigte oor gebruikers: aantal per rol, onlangse aktiwiteit.",
        "calendar": base + "Gee insigte oor die kalender: komende gebeurtenisse, besige dae.",
    }
    return prompts.get(page, base + "Gee 'n dinamiese opsomming van die bladsy se data met insigte en aksie-voorstelle.")


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
        if j.get("job_status") in ("Oop", "oop", "Pending", "pending") and not j.get("assigned_to"):
            suggestions.append(Suggestion(
                type="assign_job",
                label=f"Ken werksopdrag #{j.get('jobcard_id')} toe",
                description=f"{str(j.get('job_desc', ''))[:80]} het geen toewysing nie",
                params={"jobcard_id": j.get("jobcard_id")},
            ))

    maintenance_assets = [a for a in raw_assets if a.get("asset_status") == "Instandhouding"]
    if len(maintenance_assets) >= 2:
        suggestions.append(Suggestion(
            type="create_work_order",
            label="Skeduleer instandhouding",
            description=f"{len(maintenance_assets)} bates wag vir instandhouding",
            params={},
        ))

    fault_rooms = [r for r in raw_rooms if r.get("room_status") in ("Fout Aangemeld", "Instandhouding")]
    if len(fault_rooms) >= 2:
        suggestions.append(Suggestion(
            type="create_work_order",
            label="Inspekteer foutiewe lokale",
            description=f"{len(fault_rooms)} lokale het foute aangemeld",
            params={},
        ))

    return suggestions


def _fallback_insights(page: str, context: dict, session=None) -> AnalyticsResponse:
    raw_assets = context.get("raw_assets", [])
    raw_stock = context.get("raw_stock", [])
    raw_faults = context.get("raw_faults", [])
    raw_jobs = context.get("raw_jobs", [])
    raw_rooms = context.get("raw_rooms", [])
    raw_buildings = context.get("raw_buildings", [])
    raw_users = context.get("raw_users", [])
    raw_events = context.get("raw_events", [])
    raw_terrains = context.get("raw_terrains", [])

    if page == "assets":
        total = len(raw_assets)
        active = context.get("active", 0)
        maintenance = context.get("maintenance", 0)
        insights = []
        if total:
            insights.append(f"{total} bates in die stelsel ({active} aktief, {maintenance} in instandhouding).")
        if maintenance:
            names = [a.get("asset_name") for a in raw_assets if a.get("asset_status") == "Instandhouding"]
            if names:
                insights.append(f"In standhouding: {', '.join(names[:3])}{' en meer' if len(names) > 3 else ''}.")
        return AnalyticsResponse(
            summary=f"Daar is tans {total} bates, waarvan {active} aktief en {maintenance} in instandhouding." if total else "Geen bates nie.",
            metrics=[
                Metric(label="Totale Bates", value=str(total)),
                Metric(label="Aktief", value=str(active)),
                Metric(label="Tipes", value=str(context.get("types", 0))),
            ],
            insights=insights,
            suggestions=_fallback_suggestions(page, context),
            chart=ChartData(
                type="bar",
                labels=list(context.get("type_labels", [])),
                datasets=[ChartDataset(label="Bates", data=context.get("type_counts", []), backgroundColor=["#935e28"])],
            ) if context.get("type_labels") else None,
        )

    elif page == "stock":
        total = len(raw_stock)
        low_items = [s for s in raw_stock if s.get("stock_amount", 0) < s.get("stock_minimum", 0)]
        insights = []
        if total:
            insights.append(f"{total} voorraaditems, waarvan {len(low_items)} onder minimum is.")
        for s in low_items[:3]:
            insights.append(f"{s.get('stock_name')} — {s.get('stock_amount')}/{s.get('stock_minimum')}")
        return AnalyticsResponse(
            summary=f"{len(low_items)} items benodig herbestelling." if low_items else "Voorraadvlakke is normaal.",
            metrics=[
                Metric(label="Items", value=str(total)),
                Metric(label="Onder Minimum", value=str(len(low_items))),
                Metric(label="Tot. Hoeveelheid", value=str(context.get("total_amount", 0))),
            ],
            insights=insights,
            suggestions=_fallback_suggestions(page, context),
            chart=ChartData(
                type="bar",
                labels=list(context.get("item_labels", [])),
                datasets=[ChartDataset(label="Voorraad", data=context.get("item_counts", []), backgroundColor=["#935e28"])],
            ) if context.get("item_labels") else None,
        )

    elif page == "fault-tickets":
        open_tickets = context.get("open", 0)
        closed = context.get("closed", 0)
        total = open_tickets + closed
        pct_open = round(open_tickets / total * 100, 1) if total else 0
        insights = []
        if total:
            insights.append(f"{open_tickets} oop foutkaartjies ({pct_open}% van {total}).")
        high_prio = [f for f in raw_faults if f.get("fault_priority") in ("Hoog", "Dringend")]
        if high_prio:
            insights.append(f"{len(high_prio)} hoë-prioriteit foute wag vir aandag.")
        return AnalyticsResponse(
            summary=f"{open_tickets} oop foutkaartjies ({pct_open}%).",
            metrics=[
                Metric(label="Oop", value=str(open_tickets)),
                Metric(label="Gesluit", value=str(closed)),
                Metric(label="Totaal", value=str(total)),
            ],
            insights=insights,
            suggestions=_fallback_suggestions(page, context),
            chart=ChartData(
                type="bar",
                labels=list(context.get("priority_labels", [])),
                datasets=[ChartDataset(label="Foute", data=context.get("priority_counts", []), backgroundColor=["#935e28"])],
            ) if context.get("priority_labels") else None,
        )

    elif page == "work-orders":
        pending = context.get("pending", 0)
        completed = context.get("completed", 0)
        total = pending + completed
        insights = []
        if total:
            insights.append(f"{pending} hangende, {completed} voltooide werksopdragte.")
        unassigned = [j for j in raw_jobs if j.get("job_status") in ("Oop", "oop", "Pending", "pending") and not j.get("assigned_to")]
        if unassigned:
            insights.append(f"{len(unassigned)} werksopdragte het geen toewysing nie.")
        return AnalyticsResponse(
            summary=f"{pending} werksopdragte is tans hangend." if pending else "Alle werksopdragte is op skedule.",
            metrics=[
                Metric(label="Hangend", value=str(pending)),
                Metric(label="Voltooi", value=str(completed)),
                Metric(label="Totaal", value=str(total)),
            ],
            insights=insights,
            suggestions=_fallback_suggestions(page, context),
            chart=ChartData(
                type="bar",
                labels=list(context.get("status_labels", [])),
                datasets=[ChartDataset(label="Werksopdragte", data=context.get("status_counts", []), backgroundColor=["#935e28"])],
            ) if context.get("status_labels") else None,
        )

    elif page == "rooms":
        total = len(raw_rooms)
        fault_rooms = [r for r in raw_rooms if r.get("room_status") in ("Fout Aangemeld", "Instandhouding")]
        insights = []
        if total:
            insights.append(f"{total} lokale, waarvan {len(fault_rooms)} foute aangemeld het.")
            names = [r.get("room_name") for r in fault_rooms[:3]]
            if names:
                insights.append(f"Probleem lokale: {', '.join(names)}.")
        return AnalyticsResponse(
            summary=f"{total} lokale is geregistreer." if total else "Geen lokale nie.",
            metrics=[
                Metric(label="Lokale", value=str(total)),
                Metric(label="Met Foute", value=str(len(fault_rooms))),
            ],
            insights=insights,
            suggestions=_fallback_suggestions(page, context),
            chart=ChartData(
                type="bar",
                labels=list(context.get("type_labels", [])),
                datasets=[ChartDataset(label="Lokale", data=context.get("type_counts", []), backgroundColor=["#935e28"])],
            ) if context.get("type_labels") else None,
        )

    elif page == "buildings":
        total = len(raw_buildings)
        per_location = context.get("per_location", {})
        return AnalyticsResponse(
            summary=f"{total} geboue is geregistreer." if total else "Geen geboue nie.",
            metrics=[
                Metric(label="Geboue", value=str(total)),
                Metric(label="Kampusse", value=str(len(per_location))),
            ],
            insights=[
                f"{total} geboue in die stelsel." if total else "",
                *([f"{k}: {v} geboue." for k, v in per_location.items()]),
            ],
            chart=ChartData(
                type="bar",
                labels=list(per_location.keys()),
                datasets=[ChartDataset(label="Geboue", data=list(per_location.values()), backgroundColor=["#935e28"])],
            ) if per_location else None,
        )

    elif page == "terrains":
        total = len(raw_terrains)
        bpt = context.get("buildings_per_terrain", {})
        return AnalyticsResponse(
            summary=f"{total} terreine is geregistreer." if total else "Geen terreine nie.",
            metrics=[
                Metric(label="Terreine", value=str(total)),
                Metric(label="Geboue Totaal", value=str(sum(bpt.values()))),
            ],
            insights=[
                f"{total} kampusse/terreine." if total else "",
                *([f"{k}: {v} geboue." for k, v in bpt.items()]),
            ],
            chart=ChartData(
                type="bar",
                labels=list(bpt.keys()),
                datasets=[ChartDataset(label="Geboue", data=list(bpt.values()), backgroundColor=["#935e28"])],
            ) if bpt else None,
        )

    elif page == "dashboard":
        assets = context.get("assets", 0)
        open_faults = context.get("open_faults", 0)
        work_orders = context.get("work_orders", 0)
        stock_items = context.get("stock_items", 0)
        rooms = context.get("rooms", 0)
        buildings = context.get("buildings", 0)
        return AnalyticsResponse(
            summary=f"FBS Paneelbord: {assets} bates, {open_faults} oop foute, {work_orders} werksopdragte.",
            metrics=[
                Metric(label="Bates", value=str(assets)),
                Metric(label="Oop Foute", value=str(open_faults)),
                Metric(label="Werksopdragte", value=str(work_orders)),
                Metric(label="Voorraaditems", value=str(stock_items)),
                Metric(label="Lokale", value=str(rooms)),
                Metric(label="Geboue", value=str(buildings)),
            ],
            insights=[
                f"{assets} bates, {open_faults} oop foute, {work_orders} werksopdragte.",
                f"{stock_items} voorraaditems, {rooms} lokale, {buildings} geboue.",
            ],
        )

    elif page == "users":
        total = len(raw_users)
        active = context.get("active_users", 0)
        per_role = context.get("per_role", {})
        return AnalyticsResponse(
            summary=f"{total} gebruikers in die stelsel, waarvan {active} aktief." if total else "Geen gebruikers nie.",
            metrics=[
                Metric(label="Gebruikers", value=str(total)),
                Metric(label="Aktief", value=str(active)),
                Metric(label="Rolle", value=str(len(per_role))),
            ],
            insights=[
                f"{total} gebruikers geregistreer." if total else "",
                *([f"Rol '{r}': {c}" for r, c in per_role.items()]),
            ],
        )

    elif page == "calendar":
        total = len(raw_events)
        upcoming = context.get("upcoming", 0)
        return AnalyticsResponse(
            summary=f"{total} kalendergebeurtenisse, waarvan {upcoming} in die toekoms is." if total else "Geen gebeurtenisse nie.",
            metrics=[
                Metric(label="Gebeure", value=str(total)),
                Metric(label="Komend", value=str(upcoming)),
            ],
            insights=[
                f"{total} gebeurtenisse" if total else "",
                f"{upcoming} komend" if upcoming else "Geen komende gebeurtenisse nie.",
            ],
        )

    return AnalyticsResponse(
        summary="Kies 'n bladsy om insigte te sien.",
        metrics=[],
        insights=[],
    )


# ─── Public entry point (cached) ──────────────────────────────

@lru_cache(maxsize=20)
def _cached_insights(key: str) -> str:
    return key  # placeholder; actual cache logic in generate_insights


def generate_insights(page: str, session: Session, date_from: datetime = None, date_to: datetime = None) -> AnalyticsResponse:
    context = _gather_context(page, session, date_from, date_to)

    if os.getenv("OPENAI_API_KEY"):
        result = _openai_insights(page, context)
    else:
        result = _fallback_insights(page, context, session)

    return result


def answer_chat_query(page: str, query: str, history: list[ChatMessage], session: Session) -> str:
    context = _gather_context(page, session)

    context_block = json.dumps(context, default=str, indent=2)

    messages = [
        {"role": "system", "content": (
            "Jy is 'n fasiliteitbestuur-analis vir die FBS stelsel. "
            "Beantwoord die gebruiker se vraag in Afrikaans, gebaseer op die verskafde data-konteks. "
            "Wees bondig, spesifiek, en noem name/gettalle waar moontlik. "
            "As jy nie die antwoord uit die konteks kan gee nie, sê dit eerlik."
        )},
        {"role": "user", "content": f"Hier is die huidige data vir die '{page}' bladsy:\n\n{context_block}"},
    ]

    for msg in history:
        messages.append({"role": msg.role, "content": msg.content})

    messages.append({"role": "user", "content": query})

    if os.getenv("OPENAI_API_KEY") and _openai_available:
        try:
            client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))
            resp = client.chat.completions.create(
                model="gpt-4o-mini",
                messages=messages,
                temperature=0.3,
            )
            return resp.choices[0].message.content
        except Exception:
            pass

    total = len(context.get("raw_assets", [])) + len(context.get("raw_stock", []))
    return f"Ek het data vir {total} items op die '{page}' bladsy. Stel 'n OPENAI_API_KEY om die KI-gesprek te aktiveer."


def _count_by(session: Session, model, group_field: str, label_field: str = None,
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
    """Serialize SQLModel records to plain dicts for AI context."""
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


def _execute_suggestion(suggestion: Suggestion, session: Session, user_id: int) -> dict:
    from ..models.job import Jobcard
    from ..models.fault import Faultcard
    from ..models.stock import Stock
    from ..models.asset import Asset, AssetStatus
    from ..models.job import JobStatus

    typ = suggestion.type
    params = suggestion.params

    if typ == "create_work_order":
        job = Jobcard(
            job_desc=params.get("job_desc", ""),
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

    if typ == "close_fault":
        fault = session.get(Faultcard, params.get("fault_id"))
        if fault:
            try:
                from ..models.fault import FaultStatus
                fault.fault_status = FaultStatus.CLOSED
            except Exception:
                fault.fault_status = "Gesluit"
            session.add(fault)
            session.commit()
            return {"success": True, "message": "Foutkaartjie gesluit"}
        return {"success": False, "message": "Foutkaartjie nie gevind nie"}

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
            job.assigned_to = params.get("assigned_to")
            session.add(job)
            session.commit()
            return {"success": True, "message": "Werksopdrag toegewys"}
        return {"success": False, "message": "Werksopdrag nie gevind nie"}

    return {"success": False, "message": f"Onbekende suggestion tipe: {typ}"}


def _gather_context(page: str, session: Session,
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
            if s in ("Oop", "oop", "Pending", "pending"):
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

    return ctx