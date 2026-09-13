import React from 'react';
import DetailSection from './DetailSection';
import DetailCard from './DetailCard';
import DetailRow from './DetailRow';
import StatusBadge from './StatusBadge';
import LocationBreadcrumb from './LocationBreadcrumb';

function StockDetailView({ stock, roomName, buildingName, terrainName }) {
  return (
    <div>
      <DetailSection title="Besonderhede">
        <DetailCard>
          <DetailRow label="Naam">{stock.stock_name}</DetailRow>
          <DetailRow label="Handelsmerk">{stock.stock_brand || '-'}</DetailRow>
          <DetailRow label="Tipe">{stock.stock_type || '-'}</DetailRow>
          <DetailRow label="Hoeveelheid">{stock.stock_amount ?? 0}</DetailRow>
          <DetailRow label="Minimum Voorraad">{stock.stock_minimum ?? '-'}</DetailRow>
          <DetailRow label="Boks Totaal">{stock.stock_boxTotal ?? '-'}</DetailRow>
          {stock.stock_desc && (
            <DetailRow label="Beskrywing">
              <span style={{ whiteSpace: 'pre-wrap' }}>{stock.stock_desc}</span>
            </DetailRow>
          )}
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

export default StockDetailView;
