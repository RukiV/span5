import React from 'react';
import DetailSection from './DetailSection';
import DetailCard from './DetailCard';
import DetailRow from './DetailRow';
import { IoLocationOutline } from 'react-icons/io5';

function CampusDetailView({ campus, buildings, onNavigateToBuilding }) {
  const campusBuildings = buildings.filter(b => b.location_id === campus.location_id);

  return (
    <div>
      <DetailSection title="Besonderhede">
        <DetailCard>
          <DetailRow label="Naam">{campus.location_name}</DetailRow>
          <DetailRow label="Tipe">{campus.location_type || '-'}</DetailRow>
          <DetailRow label="Straatnommer">{campus.location_streetnum || '-'}</DetailRow>
          <DetailRow label="Straatnaam">{campus.location_streetname || '-'}</DetailRow>
          <DetailRow label="Voorstad">{campus.location_suburb || '-'}</DetailRow>
          <DetailRow label="Stad">{campus.location_city || '-'}</DetailRow>
          <DetailRow label="Provinsie">{campus.location_province || '-'}</DetailRow>
          <DetailRow label="Land">{campus.location_country || '-'}</DetailRow>
        </DetailCard>
      </DetailSection>

      <DetailSection title="Geboue">
        <DetailCard>
          {campusBuildings.length === 0 ? (
            <div className="detail-empty-children">Geen geboue op hierdie terrein.</div>
          ) : (
            <ul className="detail-children-list">
              {campusBuildings.map(b => (
                <li
                  key={b.building_id}
                  className="detail-children-item"
                  onClick={() => onNavigateToBuilding && onNavigateToBuilding(b)}
                >
                  <div>
                    <div className="detail-children-item-name">{b.building_name}</div>
                    <div className="detail-children-item-meta">{b.building_type || 'Ander'}</div>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </DetailCard>
      </DetailSection>
    </div>
  );
}

export default CampusDetailView;
