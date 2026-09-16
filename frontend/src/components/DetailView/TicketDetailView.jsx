import React, { useState } from 'react';
import DetailSection from './DetailSection';
import DetailCard from './DetailCard';
import DetailRow from './DetailRow';
import StatusBadge from './StatusBadge';
import LocationBreadcrumb from './LocationBreadcrumb';

function extractTitle(description) {
  if (!description) return '-';
  const idx = description.indexOf(':');
  return idx > 0 ? description.substring(0, idx).trim() : description.trim();
}

function extractDescription(description) {
  if (!description) return '';
  const idx = description.indexOf(':');
  return idx > 0 ? description.substring(idx + 1).trim() : '';
}

const PRIORITY_COLORS = {
  'Laag': '#16a34a',
  'Medium': '#ca8a04',
  'Hoog': '#ea580c',
  'Dringend': '#dc2626',
};

function TicketDetailView({ ticket, images, assetName, roomName, buildingName, terrainName, onViewWorkOrder }) {
  const [activeImage, setActiveImage] = useState(null);
  const title = extractTitle(ticket.fault_description);
  const description = extractDescription(ticket.fault_description);

  return (
    <div>
      <DetailSection title="Besonderhede">
        <DetailCard>
          <div className="detail-header-row">
            <span className="detail-id-badge">#{ticket.fault_id}</span>
            <StatusBadge status={ticket.fault_status} />
          </div>
          <DetailRow label="Titel">{title}</DetailRow>
          <DetailRow label="Kategorie">{ticket.fault_type || '-'}</DetailRow>
          <DetailRow label="Prioriteit">
            {ticket.fault_priority ? (
              <span style={{ color: PRIORITY_COLORS[ticket.fault_priority] || '#333', fontWeight: 600 }}>
                {ticket.fault_priority}
              </span>
            ) : '-'}
          </DetailRow>
          {description && (
            <DetailRow label="Beskrywing">
              <span style={{ whiteSpace: 'pre-wrap' }}>{description}</span>
            </DetailRow>
          )}
          <DetailRow label="Gerapporteer">
            {ticket.fault_reportdatetime
              ? new Date(ticket.fault_reportdatetime).toLocaleDateString('af-ZA')
              : '-'}
          </DetailRow>
          <DetailRow label="Opgedateer">
            {ticket.fault_updatedatetime
              ? new Date(ticket.fault_updatedatetime).toLocaleDateString('af-ZA')
              : '-'}
          </DetailRow>
        </DetailCard>
      </DetailSection>

      <DetailSection title="Ligging">
        <DetailCard>
          <LocationBreadcrumb parts={[terrainName, buildingName, roomName, assetName]} />
        </DetailCard>
      </DetailSection>

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
                  onClick={() => setActiveImage(img.url)}
                />
              ))}
            </div>
          </DetailCard>
        </DetailSection>
      )}

      {activeImage && (
        <div
          style={{
            position: 'fixed', top: 0, left: 0, right: 0, bottom: 0,
            background: 'rgba(0,0,0,0.8)', zIndex: 1100, display: 'flex',
            justifyContent: 'center', alignItems: 'center', cursor: 'pointer',
          }}
          onClick={() => setActiveImage(null)}
        >
          <img
            src={activeImage}
            alt="Volgrootte beeld"
            style={{ maxWidth: '90%', maxHeight: '90%', borderRadius: 8 }}
            onClick={e => e.stopPropagation()}
          />
        </div>
      )}
    </div>
  );
}

export default TicketDetailView;
