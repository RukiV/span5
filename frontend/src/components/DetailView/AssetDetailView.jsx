import React from 'react';
import Barcode from 'react-barcode';
import DetailSection from './DetailSection';
import DetailCard from './DetailCard';
import DetailRow from './DetailRow';
import StatusBadge from './StatusBadge';
import LocationBreadcrumb from './LocationBreadcrumb';

function AssetDetailView({ asset, assetTypeName, roomName, buildingName, terrainName, images, onViewHistory }) {
  return (
    <div>
      <DetailSection title="Besonderhede">
        <DetailCard>
          <DetailRow label="Naam">{asset.asset_name}</DetailRow>
          <DetailRow label="Handelsmerk">{asset.asset_brand || '-'}</DetailRow>
          <DetailRow label="Kategorie">{assetTypeName || '-'}</DetailRow>
          <DetailRow label="Plasing">{asset.asset_isoutdoor ? 'Buite' : 'Binne'}</DetailRow>
          <DetailRow label="Status"><StatusBadge status={asset.asset_status} /></DetailRow>
          <DetailRow label="Geskep">
            {asset.asset_created_datetime
              ? new Date(asset.asset_created_datetime).toLocaleDateString('af-ZA')
              : '-'}
          </DetailRow>
        </DetailCard>
      </DetailSection>

      <DetailSection title="Ligging">
        <DetailCard>
          <LocationBreadcrumb parts={[terrainName, buildingName, roomName]} />
        </DetailCard>
      </DetailSection>

      {asset.asset_serial && (
        <DetailSection title="Streepkode">
          <DetailCard>
            <div className="detail-barcode-card">
              <Barcode value={asset.asset_serial} width={1.5} height={60} displayValue={true} fontSize={14} />
            </div>
          </DetailCard>
        </DetailSection>
      )}

      {images && images.length > 0 && (
        <DetailSection title="Beelde">
          <DetailCard>
            <div className="detail-images-grid">
              {images.map(img => (
                <img
                  key={img.image_id}
                  className="detail-image-thumb"
                  src={img.url}
                  alt={img.filename || 'Beeld'}
                />
              ))}
            </div>
          </DetailCard>
        </DetailSection>
      )}

      {onViewHistory && (
        <div style={{ marginTop: 12 }}>
          <button
            className="btn-view"
            onClick={onViewHistory}
            style={{ fontSize: 13 }}
          >
            Bekyk Geskiedenis
          </button>
        </div>
      )}
    </div>
  );
}

export default AssetDetailView;
