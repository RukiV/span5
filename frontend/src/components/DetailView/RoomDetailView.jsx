import React from 'react';
import { QRCodeSVG } from 'qrcode.react';
import DetailSection from './DetailSection';
import DetailCard from './DetailCard';
import DetailRow from './DetailRow';
import StatusBadge from './StatusBadge';

const ROOM_TYPE_LABELS = {
  'Klaskamer': 'Klaskamer',
  'Laboratorium': 'Laboratorium',
  'Kantoor': 'Kantoor',
  'Konferensiekamer': 'Konferensiekamer',
  'Pakhuis': 'Pakhuis',
  'Badkamer': 'Badkamer',
  'Ander': 'Ander',
};

function RoomDetailView({ room, buildingName, terrainName }) {
  return (
    <div>
      <DetailSection title="Besonderhede">
        <DetailCard>
          <DetailRow label="Naam">{room.room_name}</DetailRow>
          <DetailRow label="Tipe">{ROOM_TYPE_LABELS[room.room_type] || room.room_type || '-'}</DetailRow>
          <DetailRow label="Gebou">{buildingName || '-'}</DetailRow>
          <DetailRow label="Terrein">{terrainName || '-'}</DetailRow>
          <DetailRow label="Kapasiteit">{room.room_capacity ?? '-'}</DetailRow>
          <DetailRow label="Status"><StatusBadge status={room.room_status} /></DetailRow>
        </DetailCard>
      </DetailSection>

      {room.room_code && (
        <DetailSection title="QR Kode">
          <DetailCard>
            <div className="detail-qr-card">
              <div className="detail-qr-code">{room.room_code}</div>
              <QRCodeSVG value={room.room_code} size={160} />
            </div>
          </DetailCard>
        </DetailSection>
      )}
    </div>
  );
}

export default RoomDetailView;
