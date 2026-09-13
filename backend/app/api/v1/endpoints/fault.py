from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session, select
from typing import List, Optional

from ....auth.permissions import get_current_user, require_right, user_has_right
from ....db.database import getSession
from ....models.fault import Faultcard, FaultcardRead, FaultcardCreate, FaultcardUpdate, WRONG_ROOM_FAULT_PREFIX
from ....models.asset import Asset
from ....models.user import User
from ....models.enums import FaultStatus
from ....services.fault_service import fault_service
from ....services.notification_service import NotificationService

router = APIRouter()


def _fault_summary(session: Session, fault: Faultcard, max_desc_len: int = 60) -> str:
    parts = [f"Fout #{fault.fault_id}"]
    if fault.fault_description:
        desc = fault.fault_description.strip()
        if len(desc) > max_desc_len:
            desc = desc[:max_desc_len].rsplit(" ", 1)[0] + "…"
        parts.append(desc)
    if fault.asset_id:
        asset = session.get(Asset, fault.asset_id)
        if asset:
            parts.append(f"({asset.asset_name})")
    return " — ".join(parts)


def notify_fault_status_change(session: Session, fault: Faultcard, old_status, actor: User,
                               exclude_user_ids: Optional[set[int]] = None):
    """Stuur die kennisgewings wat 'n foutkaartjie-statusverandering vergesel.

    Gedeel deur PATCH /fault en die werksopdrag-kaskade (Wanneer 'n werksopdrag
    voltooi word, word die gekoppelde foutkaartjie opgelos). Doen niks as die
    status nie eintlik verander het nie. `exclude_user_ids` laat die kaskade toe
    om gebruikers oor te slaan wat reeds 'n kennisgewing vir dieselfde gebeurtenis
    ontvang het (bv. die werksopdrag se statusverandering).
    """
    if old_status == fault.fault_status:
        return
    notif_svc = NotificationService(session)
    summary = _fault_summary(session, fault)
    notified = set(exclude_user_ids or ())
    if fault.user_id and fault.user_id not in notified:
        notified.add(fault.user_id)
        notif_svc.create_notification(
            user_id=fault.user_id,
            notification_type="fault.status_changed",
            title="Fout status verander",
            message=f"{summary} status verander na {fault.fault_status.value}",
            actor_id=actor.user_id,
            reference_type="fault",
            reference_id=fault.fault_id,
        )
    if fault.location_id:
        notified |= notif_svc.notify_location_users(
            location_id=fault.location_id,
            notification_type="fault.status_changed",
            title="Fout status verander",
            message=f"{summary} status verander na {fault.fault_status.value}",
            actor_id=actor.user_id,
            reference_type="fault",
            reference_id=fault.fault_id,
            exclude_user_ids=notified,
        )
    if fault.fault_status == FaultStatus.RESOLVED:
        notified |= notif_svc.notify_admins(
            notification_type="fault.resolved",
            title="Fout opgelos",
            message=f"{summary} opgelos deur {actor.user_name}",
            actor_id=actor.user_id,
            reference_type="fault",
            reference_id=fault.fault_id,
            exclude_user_ids=notified,
        )
        _move_asset_back_if_wrong_room(session, fault)


def _move_asset_back_if_wrong_room(session: Session, fault: Faultcard):
    """Veiligheidsnet wat loop wanneer 'n 'gevind in verkeerde lokaal'-
    foutkaartjie opgelos word.

    Die bate se `room_id` word nie verskuif wanneer dit 'as vermis' gemerk
    word nie, so normaalweg is hier niks om te doen nie. Slegs as die bate
    fisies na die "gevind"-lokaal verskuif is, word dit teruggeskuif na die
    lokaal van die oorspronklike (vermis) foutkaartjie.
    """
    desc = (fault.fault_description or "").strip()
    if not desc.startswith(WRONG_ROOM_FAULT_PREFIX):
        return
    if not fault.asset_id:
        return
    asset = session.get(Asset, fault.asset_id)
    if not asset:
        return
    # Die bate se `room_id` word nie verskuif wanneer dit 'as vermis' gemerk
    # word nie — dit bly op sy toegewese lokaal. Hier is niks om te doen as die
    # bate nie in die "gevind"-lokaal staan nie. Slegs as die bate per ongeluk
    # na die gevind-lokaal beweeg is, word dit teruggeskuif na die lokaal van
    # die oorspronklike (vermis) foutkaartjie.
    if asset.room_id != fault.room_id:
        return
    target_room = None
    if fault.duplicate_of:
        original = session.get(Faultcard, fault.duplicate_of)
        if original and original.room_id:
            target_room = original.room_id
    if target_room is not None:
        asset.room_id = target_room
        session.add(asset)
        session.commit()
        session.refresh(asset)

# Authorization is driven entirely by the rights system now (see
# auth/permissions.py), not by raw role_id comparisons:
#   - faults.view   : Admin/FK — see every fault card.
#   - faults.manage : Admin/FK — update/delete every fault card.
#   - faults.create : Admin/FK/Student — create a fault card.
#   - faults.view_own : Student — see only fault cards you created.
# The own-fault-card ownership scoping (fault.user_id == user.user_id) is
# preserved exactly as before; only its trigger condition changed. Students are
# read-only after submitting: PATCH requires faults.manage.


@router.get("", response_model=List[FaultcardRead])
def readFaults(session: Session = Depends(getSession), user: User = Depends(get_current_user)):
    """Fetch faults. faults.view sees all; faults.view_own sees only own."""
    if user_has_right(session, user.role_id, "faults.view"):
        return fault_service.getAll(session)
    if user_has_right(session, user.role_id, "faults.view_own"):
        return session.exec(
            select(Faultcard).where(Faultcard.user_id == user.user_id)
        ).all()
    raise HTTPException(status_code=403, detail="Insufficient permissions")


@router.get("/{faultID}", response_model=FaultcardRead)
def readFault(faultID: int, session: Session = Depends(getSession), user: User = Depends(get_current_user)):
    """Fetch single fault. Without faults.view, only own fault cards are visible."""
    manage_all = user_has_right(session, user.role_id, "faults.view")
    if not (manage_all or user_has_right(session, user.role_id, "faults.view_own")):
        raise HTTPException(status_code=403, detail="Insufficient permissions")
    fault = fault_service.getByID(session, faultID)
    if not fault:
        raise HTTPException(status_code=404, detail="Fault not found")
    if not manage_all and fault.user_id != user.user_id:
        raise HTTPException(status_code=403, detail="Access denied")
    return fault


@router.post("", response_model=FaultcardRead, status_code=status.HTTP_201_CREATED)
def addFault(faultIn: FaultcardCreate, session: Session = Depends(getSession), user: User = Depends(require_right("faults.create"))):
    """Create a new fault report. Requires faults.create (Admin/FK/Student)."""
    fault = fault_service.create(session, faultIn, user_id=user.user_id)
    notif_svc = NotificationService(session)
    summary = _fault_summary(session, fault)
    notif_svc.notify_admins(
        notification_type="fault.created",
        title="Nuwe foutkaartjie",
        message=f"{summary} aangeteken deur {user.user_name}",
        actor_id=user.user_id,
        reference_type="fault",
        reference_id=fault.fault_id,
    )
    if fault.location_id:
        notif_svc.notify_location_users(
            location_id=fault.location_id,
            notification_type="fault.created",
            title="Nuwe foutkaartjie",
            message=f"{summary} by jou terrein",
            actor_id=user.user_id,
            reference_type="fault",
            reference_id=fault.fault_id,
        )
    return fault


@router.patch("/{faultID}", response_model=FaultcardRead)
def patchFault(faultID: int, faultIn: FaultcardUpdate, session: Session = Depends(getSession), user: User = Depends(require_right("faults.manage"))):
    """Update existing fault. Requires faults.manage (Admin/FK).

    Students are read-only after submitting — they may create and view their own
    fault cards but not edit them afterwards.
    """
    old = fault_service.getByID(session, faultID)
    old_status = old.fault_status if old else None
    fault = fault_service.update(session, faultID, faultIn, user_id=user.user_id)
    if not fault:
        raise HTTPException(status_code=404, detail="Fault not found")

    if faultIn.fault_status is not None and old:
        notify_fault_status_change(session, fault, old_status, user)

    return fault


@router.delete("/{faultID}", status_code=status.HTTP_204_NO_CONTENT)
def removeFault(faultID: int, session: Session = Depends(getSession), user: User = Depends(require_right("faults.manage"))):
    """Delete fault. Requires faults.manage (Admin/FK)."""
    if not fault_service.delete(session, faultID, user_id=user.user_id):
        raise HTTPException(status_code=404, detail="Fault not found")
    return None
