import React from 'react';
import DetailSection from './DetailSection';
import DetailCard from './DetailCard';
import DetailRow from './DetailRow';

const BUILDING_TYPE_LABELS = {
  'Kantoorgebou': 'Admin',
  'Onderwys': 'Onderwys',
  'Laboratorium': 'Laboratorium',
  'warehouse': 'Pakhuis',
  'Kafeteria': 'Kafeteria',
  'Koshuis': 'Koshuis',
  'Ander': 'Ander',
};

function formatBuildingTypes(building) {
  const types = Array.isArray(building.building_types)
    ? building.building_types
    : building.building_type
      ? [building.building_type]
      : [];

  return types.map(type => BUILDING_TYPE_LABELS[type] || type).join(', ') || '-';
}

function BuildingDetailView({ building, terrainName, rooms, onNavigateToRoom }) {
  const buildingRooms = rooms.filter(r => r.building_id === building.building_id);

  return (
    <div>
      <DetailSection title="Besonderhede">
        <DetailCard>
          <DetailRow label="Naam">{building.building_name}</DetailRow>
          <DetailRow label="Tipe">{formatBuildingTypes(building)}</DetailRow>
          <DetailRow label="Terrein">{terrainName || '-'}</DetailRow>
        </DetailCard>
      </DetailSection>

      <DetailSection title={`Lokale (${buildingRooms.length})`}>
        <DetailCard>
          {buildingRooms.length === 0 ? (
            <div className="detail-empty-children">Geen lokale in hierdie gebou.</div>
          ) : (
            <ul className="detail-children-list">
              {buildingRooms.map(r => (
                <li
                  key={r.room_id}
                  className="detail-children-item"
                  onClick={() => onNavigateToRoom && onNavigateToRoom(r)}
                >
                  <div>
                    <div className="detail-children-item-name">{r.room_name}</div>
                    <div className="detail-children-item-meta">{r.room_type || 'Ander'}</div>
                  </div>
                  {r.room_capacity != null && (
                    <span className="detail-children-item-trailing">{r.room_capacity} plekke</span>
                  )}
                </li>
              ))}
            </ul>
          )}
        </DetailCard>
      </DetailSection>
    </div>
  );
}

export default BuildingDetailView;
