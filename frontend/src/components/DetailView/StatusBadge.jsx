import React from 'react';

const STATUS_MAP = {
  'Aktief': 'active',
  'active': 'active',
  'Onaktief': 'inactive',
  'inactive': 'inactive',
  'Instandhouding': 'maintenance',
  'Afgedank': 'inactive',
  'Geskeduleer': 'scheduled',
  'scheduled': 'scheduled',
  'Voltooi': 'completed',
  'completed': 'completed',
  'Gekanselleer': 'cancelled',
  'cancelled': 'cancelled',
  'Oop': 'open',
  'open': 'open',
  'Wag': 'wait',
  'wait': 'wait',
  'Besig': 'progress',
  'progress': 'progress',
  'Opgelos': 'resolved',
  'resolved': 'resolved',
  'Gesluit': 'closed',
  'closed': 'closed',
  'Bevestig': 'confirmed',
  'confirmed': 'confirmed',
  'Fout Aangemeld': 'maintenance',
  'Buite Werking': 'inactive',
  'Operasioneel': 'active',
};

const LABEL_MAP = {
  'active': 'Aktief',
  'inactive': 'Onaktief',
  'maintenance': 'Instandhouding',
  'scheduled': 'Geskeduleer',
  'completed': 'Voltooi',
  'cancelled': 'Gekanselleer',
  'open': 'Oop',
  'wait': 'Wag',
  'progress': 'Besig',
  'resolved': 'Opgelos',
  'closed': 'Gesluit',
  'confirmed': 'Bevestig',
  'default': '-',
};

function StatusBadge({ status }) {
  if (!status) return <span className="detail-empty">-</span>;
  const variant = STATUS_MAP[status] || 'default';
  const label = LABEL_MAP[variant] || status;
  return (
    <span className={`detail-badge detail-badge-${variant}`}>
      {label}
    </span>
  );
}

export default StatusBadge;
