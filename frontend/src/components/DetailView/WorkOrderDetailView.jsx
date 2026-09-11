import React, { useState } from 'react';
import DetailSection from './DetailSection';
import DetailCard from './DetailCard';
import DetailRow from './DetailRow';
import StatusBadge from './StatusBadge';
import LocationBreadcrumb from './LocationBreadcrumb';

const TYPE_LABELS = {
  'Onderhoud': 'Onderhoud',
  'Herstel': 'Herstel',
  'Inspeksie': 'Inspeksie',
  'Installasie': 'Installasie',
};

const NATURE_LABELS = {
  'Elektries': 'Elektries',
  'Meganies': 'Meganies',
  'Siviel': 'Siviel',
  'Buite': 'Buite',
  'Algemeen': 'Algemeen',
};

function formatDate(dt) {
  if (!dt) return null;
  return new Date(dt).toLocaleString('af-ZA', {
    day: '2-digit', month: '2-digit', year: 'numeric',
    hour: '2-digit', minute: '2-digit',
  });
}

function WorkOrderDetailView({
  order, assignedName, contractorName,
  terrainName, buildingName, roomName, assetName,
  faultId, ticketTitle,
  ticketImages, jobImages, onImageClick,
}) {
  const [activeTab, setActiveTab] = useState('besonderhede');

  const tabs = [
    { key: 'besonderhede', label: 'Besonderhede' },
    { key: 'werknotas', label: 'Kontrakteur Werknotas' },
  ];

  return (
    <div>
      <div className="detail-tabs">
        {tabs.map(tab => (
          <div
            key={tab.key}
            className={`detail-tab ${activeTab === tab.key ? 'active' : ''}`}
            onClick={() => setActiveTab(tab.key)}
          >
            {tab.label}
          </div>
        ))}
      </div>

      {activeTab === 'besonderhede' && (
        <div>
          <DetailSection title="Besonderhede">
            <DetailCard>
              <div className="detail-header-row">
                <span className="detail-id-badge">#{order.jobcard_id}</span>
                <StatusBadge status={order.job_status} />
              </div>
              <DetailRow label="Beskrywing">{order.job_desc || '-'}</DetailRow>
              <DetailRow label="Tipe">{TYPE_LABELS[order.job_type] || order.job_type || '-'}</DetailRow>
              <DetailRow label="Prioriteit">{order.job_priority || '-'}</DetailRow>
              <DetailRow label="Natuur">{NATURE_LABELS[order.nature] || order.nature || '-'}</DetailRow>
              <DetailRow label="Geskep">{formatDate(order.job_createddatetime) || '-'}</DetailRow>
              {order.job_scheduled_datetime && (
                <DetailRow label="Begin datum en tyd">{formatDate(order.job_scheduled_datetime)}</DetailRow>
              )}
              {order.job_scheduled_end_datetime && (
                <DetailRow label="Einddatum en tyd">{formatDate(order.job_scheduled_end_datetime)}</DetailRow>
              )}
              {order.job_finisheddatetime && (
                <DetailRow label="Voltooi op">{formatDate(order.job_finisheddatetime)}</DetailRow>
              )}
              <DetailRow label="Verantwoordelike personeellid">{assignedName || '-'}</DetailRow>
              {contractorName && (
                <DetailRow label="Kontrakteur">{contractorName}</DetailRow>
              )}
            </DetailCard>
          </DetailSection>

          <DetailSection title="Ligging">
            <DetailCard>
              <LocationBreadcrumb parts={[terrainName, buildingName, roomName, assetName]} />
            </DetailCard>
          </DetailSection>

          {faultId && (
            <DetailSection title="Gekoppel aan Foutkaartjie">
              <DetailCard>
                <span
                  style={{ color: '#935e28', fontWeight: 600, cursor: 'pointer' }}
                >
                  #{faultId}{ticketTitle ? ` - ${ticketTitle}` : ''}
                </span>
              </DetailCard>
            </DetailSection>
          )}
        </div>
      )}

      {activeTab === 'werknotas' && (
        <div>
          {ticketImages && ticketImages.length > 0 && (
            <DetailSection title="Foto van Fout">
              <DetailCard>
                <div className="detail-images-grid">
                  {ticketImages.map(img => (
                    <img
                      key={img.image_id}
                      className="detail-image-thumb"
                      src={img.url}
                      alt={img.filename || 'Fout beeld'}
                      onClick={() => onImageClick && onImageClick(img.url)}
                    />
                  ))}
                </div>
              </DetailCard>
            </DetailSection>
          )}

          <DetailSection title="Werknotas">
            <DetailCard>
              {order.job_notes ? (
                <div className="detail-notes">{order.job_notes}</div>
              ) : (
                <div className="detail-empty">Geen werknotas nie.</div>
              )}
            </DetailCard>
          </DetailSection>

          {jobImages && jobImages.length > 0 && (
            <DetailSection title="Beelde">
              <DetailCard>
                <div className="detail-images-grid">
                  {jobImages.map(img => (
                    <img
                      key={img.image_id}
                      className="detail-image-thumb"
                      src={img.url}
                      alt={img.filename || 'Beeld'}
                      onClick={() => onImageClick && onImageClick(img.url)}
                    />
                  ))}
                </div>
              </DetailCard>
            </DetailSection>
          )}
        </div>
      )}
    </div>
  );
}

export default WorkOrderDetailView;
