"""Kaskade-verwydering vir die fisiese hiërargie.

Die API se skema het geen `ondelete=CASCADE` nie (tabelle word via
`metadata.create_all` geskep en FKs is almal `NO ACTION`). Om 'n ouer én sy
kinders permanent te verwyder, doen ons die opruiming eksplisiet in die
toepassingslaag — binne die transaksie van die ouer se `delete()`.

Rekursie volg die hiërargie:
    Terrein (Location) -> Geboue (Building) -> Lokale (Room)
        -> Bates (Asset), Voorraad (Stock), Lokale-kontroles (RoomCheck),
           Lokaal-kontroles (RoomCheckSession), Foutkaartjies (Faultcard),
           Werksopdragte (Jobcard), AI-konsepte (JobDraft)

Elke rekord wat beelde/kaartliggings het, word skoongemaak voordat dit
verwyder word. 'n Mappoint/Quotum wat deur meer as een rekord gedeel word,
word nie verwyder nie tensy dit die laaste verwysing is.
"""
from sqlmodel import Session, select

from ..models.asset import Asset, Assettype
from ..models.document import QuoteDocument
from ..models.fault import Faultcard
from ..models.image import ImageAsset, ImageAssetLink
from ..models.job import Jobcard, Jobrecurring
from ..models.jobdraft import JobDraft
from ..models.location import Building, BuildingTypeLink, Location, Room
from ..models.mappoint import Mappoint
from ..models.quote import Quote
from ..models.room_check import RoomCheck
from ..models.room_check_session import RoomCheckSession
from ..models.stock import Stock


# --------------------------------------------------------------------------
# Beelde
# --------------------------------------------------------------------------

def delete_images_for_parent(session: Session, parent_id: int, parent_type: str) -> None:
    """Verwyder alle beeld-skakels vir 'n ouer en enige wekebare beelde.

    Beelde woon in die universele `image`-tafel en word via `image_link`
    (parent_type/parent_id) aan ouers gekoppel. 'n beeld word eers verwyder
    wanneer dit geen ander skakels meer het nie (symbierbei met die ouer se
    skakel, en die wees word dan self verwyder).
    """
    links = session.exec(
        select(ImageAssetLink).where(
            ImageAssetLink.parent_id == parent_id,
            ImageAssetLink.parent_type == parent_type.lower(),
        )
    ).all()
    for link in links:
        image = session.get(ImageAsset, link.image_id)
        session.delete(link)
        session.flush()
        if image is not None:
            remaining = session.exec(
                select(ImageAssetLink).where(ImageAssetLink.image_id == image.image_id)
            ).first()
            if remaining is None:
                session.delete(image)


# --------------------------------------------------------------------------
# Kaartliggings (Mappoint) en kwotas
# --------------------------------------------------------------------------

def _mappoint_still_used(session: Session, mappoint_id: int) -> bool:
    if session.exec(select(Faultcard).where(Faultcard.mappoint_id == mappoint_id)).first():
        return True
    if session.exec(select(Jobcard).where(Jobcard.mappoint_id == mappoint_id)).first():
        return True
    return False


def _delete_mappoint(session: Session, mappoint_id) -> None:
    if mappoint_id is None:
        return
    if _mappoint_still_used(session, mappoint_id):
        return
    mp = session.get(Mappoint, mappoint_id)
    if mp is not None:
        session.delete(mp)


def _quote_still_used(session: Session, quote_id: int) -> bool:
    if session.exec(select(Jobcard).where(Jobcard.quote_id == quote_id)).first():
        return True
    return False


def _delete_quote(session: Session, quote_id) -> None:
    if quote_id is None:
        return
    if _quote_still_used(session, quote_id):
        return
    for doc in session.exec(select(QuoteDocument).where(QuoteDocument.quote_id == quote_id)).all():
        session.delete(doc)
    quote = session.get(Quote, quote_id)
    if quote is not None:
        session.delete(quote)


# --------------------------------------------------------------------------
# Rekord-vlak opruimers
# --------------------------------------------------------------------------

def _delete_single_jobcard(session: Session, job_id: int) -> None:
    job = session.get(Jobcard, job_id)
    if job is None:
        return
    delete_images_for_parent(session, job.jobcard_id, "job")
    recurr_id = job.jobrecurr_id
    mappoint_id = job.mappoint_id
    quote_id = job.quote_id
    session.delete(job)
    session.flush()
    if recurr_id is not None:
        rec = session.get(Jobrecurring, recurr_id)
        if rec is not None:
            session.delete(rec)
    _delete_mappoint(session, mappoint_id)
    _delete_quote(session, quote_id)


def _delete_single_faultcard(session: Session, fault_id: int) -> None:
    fault = session.get(Faultcard, fault_id)
    if fault is None:
        return
    # Eers al die werkopdragte wat uit hierdie foutkaartjie geskep is.
    for job in session.exec(select(Jobcard).where(Jobcard.fault_id == fault_id)).all():
        _delete_single_jobcard(session, job.jobcard_id)
    # Enige foutkaartjies wat duplikate van hierdie een is.
    for dup in session.exec(select(Faultcard).where(Faultcard.duplicate_of == fault_id)).all():
        _delete_single_faultcard(session, dup.fault_id)
    delete_images_for_parent(session, fault.fault_id, "ticket")
    mappoint_id = fault.mappoint_id
    session.delete(fault)
    session.flush()
    _delete_mappoint(session, mappoint_id)


def _delete_single_asset(session: Session, asset_id: int) -> None:
    asset = session.get(Asset, asset_id)
    if asset is None:
        return
    for fault in session.exec(select(Faultcard).where(Faultcard.asset_id == asset_id)).all():
        _delete_single_faultcard(session, fault.fault_id)
    for job in session.exec(select(Jobcard).where(Jobcard.asset_id == asset_id)).all():
        _delete_single_jobcard(session, job.jobcard_id)
    for draft in session.exec(select(JobDraft).where(JobDraft.resolved_asset_id == asset_id)).all():
        session.delete(draft)
    delete_images_for_parent(session, asset.asset_id, "asset")
    session.delete(asset)


def _delete_single_stock(session: Session, stock_id: int) -> None:
    stock = session.get(Stock, stock_id)
    if stock is None:
        return
    delete_images_for_parent(session, stock.stock_id, "stock")
    session.delete(stock)


def _delete_single_room(session: Session, room_id: int) -> None:
    room = session.get(Room, room_id)
    if room is None:
        return
    for asset in session.exec(select(Asset).where(Asset.room_id == room_id)).all():
        _delete_single_asset(session, asset.asset_id)
    for stock in session.exec(select(Stock).where(Stock.room_id == room_id)).all():
        _delete_single_stock(session, stock.stock_id)
    for check in session.exec(select(RoomCheck).where(RoomCheck.room_id == room_id)).all():
        session.delete(check)
    for sess in session.exec(select(RoomCheckSession).where(RoomCheckSession.room_id == room_id)).all():
        session.delete(sess)
    for fault in session.exec(select(Faultcard).where(Faultcard.room_id == room_id)).all():
        _delete_single_faultcard(session, fault.fault_id)
    for job in session.exec(select(Jobcard).where(Jobcard.room_id == room_id)).all():
        _delete_single_jobcard(session, job.jobcard_id)
    for draft in session.exec(select(JobDraft).where(JobDraft.resolved_room_id == room_id)).all():
        session.delete(draft)
    delete_images_for_parent(session, room.room_id, "room")
    session.delete(room)


def _delete_single_building(session: Session, building_id: int) -> None:
    building = session.get(Building, building_id)
    if building is None:
        return
    for row in session.exec(select(BuildingTypeLink).where(BuildingTypeLink.building_id == building_id)).all():
        session.delete(row)
    for room in session.exec(select(Room).where(Room.building_id == building_id)).all():
        _delete_single_room(session, room.room_id)
    for fault in session.exec(select(Faultcard).where(Faultcard.building_id == building_id)).all():
        _delete_single_faultcard(session, fault.fault_id)
    for job in session.exec(select(Jobcard).where(Jobcard.building_id == building_id)).all():
        _delete_single_jobcard(session, job.jobcard_id)
    for link in session.exec(select(BuildingTypeLink).where(BuildingTypeLink.building_id == building_id)).all():
        session.delete(link)
    delete_images_for_parent(session, building.building_id, "building")
    session.delete(building)


def _delete_single_location(session: Session, location_id: int) -> None:
    location = session.get(Location, location_id)
    if location is None:
        return
    for building in session.exec(select(Building).where(Building.location_id == location_id)).all():
        _delete_single_building(session, building.building_id)
    # Direkte verwysings na die terrein self (foute/werkopdragte sonder 'n gebou).
    for fault in session.exec(select(Faultcard).where(Faultcard.location_id == location_id)).all():
        _delete_single_faultcard(session, fault.fault_id)
    for job in session.exec(select(Jobcard).where(Jobcard.location_id == location_id)).all():
        _delete_single_jobcard(session, job.jobcard_id)
    session.delete(location)


# --------------------------------------------------------------------------
# Publieke inskrypings
# --------------------------------------------------------------------------

def cascade_delete_location(session: Session, location_id: int) -> None:
    _delete_single_location(session, location_id)


def cascade_delete_building(session: Session, building_id: int) -> None:
    _delete_single_building(session, building_id)


def cascade_delete_room(session: Session, room_id: int) -> None:
    _delete_single_room(session, room_id)


def cascade_delete_asset(session: Session, asset_id: int) -> None:
    _delete_single_asset(session, asset_id)


def cascade_delete_stock(session: Session, stock_id: int) -> None:
    _delete_single_stock(session, stock_id)


def cascade_delete_fault(session: Session, fault_id: int) -> None:
    _delete_single_faultcard(session, fault_id)


def cascade_delete_job(session: Session, job_id: int) -> None:
    _delete_single_jobcard(session, job_id)
