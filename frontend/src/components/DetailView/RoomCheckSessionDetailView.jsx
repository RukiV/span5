import React from 'react';
import DetailSection from './DetailSection';
import DetailCard from './DetailCard';
import DetailRow from './DetailRow';
import StatusBadge from './StatusBadge';
import LocationBreadcrumb from './LocationBreadcrumb';

const STATUS_LABELS = {
  scheduled: 'Geskeduleer',
  completed: 'Voltooi',
  cancelled: 'Gekanselleer',
};

function RoomCheckSessionDetailView({ session, roomName, buildingName, terrainName, userName }) {
  return (
    <div>
      <DetailSection title="Besonderhede">
        <DetailCard>
          <div className="detail-header-row">
            <span className="detail-id-badge">#{session.session_id}</span>
            <StatusBadge status={session.status} />
          </div>
          <DetailRow label="Lokaal">{roomName || `Lokaal #${session.room_id}`}</DetailRow>
          <DetailRow label="Toegewese Gebruiker">{userName || `Gebruiker #${session.assigned_user_id}`}</DetailRow>
          <DetailRow label="Datum en Tyd">
            {session.scheduled_datetime
              ? new Date(session.scheduled_datetime).toLocaleString('af-ZA', {
                  day: '2-digit', month: '2-digit', year: 'numeric',
                  hour: '2-digit', minute: '2-digit',
                })
              : '-'}
          </DetailRow>
        </DetailCard>
      </DetailSection>

      <DetailSection title="Ligging">
        <DetailCard>
          <LocationBreadcrumb parts={[terrainName, buildingName, roomName]} />
        </DetailCard>
      </DetailSection>
    </div>
  );
}

export default RoomCheckSessionDetailView;
