from ..models.mappoint import Mappoint, MappointCreate, MappointUpdate
from .base_service import BaseService


class MappointService(BaseService[Mappoint, MappointCreate, MappointUpdate]):
    def create_or_update(self, session, obj, latitude, longitude):
        """Koppel 'n Mappoint aan 'n entiteit (foutkaartjie/werksopdrag).

        As die entiteit reeds 'n mappoint het word dit opgedateer; anders
        word 'n nuwe Mappoint geskep en die mappoint_id gekoppel. Moet voor
        session.commit() geroep word.
        """
        from ..models.mappoint import Mappoint as MP

        if obj.mappoint_id:
            point = session.get(MP, obj.mappoint_id)
            if point:
                point.latitude = latitude
                point.longitude = longitude
                session.add(point)
                return point
        point = MP(latitude=latitude, longitude=longitude)
        session.add(point)
        session.flush()
        obj.mappoint_id = point.mappoint_id
        return point

    create_or_update_for_fault = create_or_update


mappoint_service = MappointService(Mappoint)
