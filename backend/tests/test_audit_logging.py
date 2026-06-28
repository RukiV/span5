import os
import sys
import unittest
from pathlib import Path

from sqlmodel import Session, SQLModel, create_engine, select

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.models.asset import Asset, AssetCreate, AssetUpdate, Assettype
from app.models.audit import Auditlog
from app.models.role import Role
from app.models.user import User
from app.services.base_service import BaseService


class AuditLoggingTests(unittest.TestCase):
    def test_audit_payload_contains_previous_and_new_values(self):
        database_url = 'postgresql+psycopg2://postgres:password@localhost:5432/facility_db'
        engine = create_engine(database_url)
        SQLModel.metadata.drop_all(engine)
        SQLModel.metadata.create_all(engine)

        with Session(engine) as session:
            assettype = Assettype(assettype_name='Test Type', assettype_avg_lifespan=5)
            session.add(assettype)
            session.commit()
            session.refresh(assettype)

            role = Role(role_name='Test Role')
            session.add(role)
            session.commit()
            session.refresh(role)

            user = User(
                user_name='Tester',
                user_surname='Audit',
                user_email='tester@example.com',
                user_password='secret',
                user_status='active',
                role_id=role.role_id,
            )
            session.add(user)
            session.commit()
            session.refresh(user)

            service = BaseService(Asset)
            created = service.create(session, AssetCreate(asset_name='Test Asset', assettype_id=assettype.assettype_id))
            updated = service.update(session, created.asset_id, AssetUpdate(asset_name='Updated Asset'), user_id=user.user_id)

            audit_logs = session.exec(select(Auditlog)).all()
            self.assertEqual(len(audit_logs), 2)

            update_log = audit_logs[1]
            self.assertEqual(update_log.action, 'update')
            self.assertEqual(update_log.affectedcolumn, 'asset_name')
            self.assertEqual(update_log.user_id, user.user_id)
            self.assertEqual(update_log.previous_value['asset_name'], 'Test Asset')
            self.assertEqual(update_log.new_value['asset_name'], 'Updated Asset')
            self.assertEqual(updated.asset_name, 'Updated Asset')


if __name__ == '__main__':
    unittest.main()
