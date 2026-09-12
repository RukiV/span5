import React from 'react';
import DetailSection from './DetailSection';
import DetailCard from './DetailCard';
import DetailRow from './DetailRow';
import StatusBadge from './StatusBadge';

const ROLE_LABELS = {
  1: 'Gebruiker',
  2: 'Fasiliteit Koordineerder',
  3: 'Administrateur',
  4: 'Kontrakteur',
};

const ROLE_CLASSES = {
  1: 'role-user',
  2: 'role-coordinator',
  3: 'role-admin',
  4: 'role-contractor',
};

function UserDetailView({ user, terrainName }) {
  return (
    <div>
      <DetailSection title="Besonderhede">
        <DetailCard>
          <DetailRow label="Voornaam">{user.user_name}</DetailRow>
          <DetailRow label="Van">{user.user_surname || '-'}</DetailRow>
          <DetailRow label="E-pos">{user.user_email}</DetailRow>
          <DetailRow label="Rol">
            <span className={`role-badge ${ROLE_CLASSES[user.role_id] || ''}`}>
              {ROLE_LABELS[user.role_id] || `Rol ${user.role_id}`}
            </span>
          </DetailRow>
          <DetailRow label="Terrein">{terrainName || '-'}</DetailRow>
          <DetailRow label="Status">
            <StatusBadge status={user.user_status === 'active' ? 'Aktief' : 'Onaktief'} />
          </DetailRow>
          <DetailRow label="Laaste Teken-In">
            {user.user_lastlogintime
              ? new Date(user.user_lastlogintime).toLocaleDateString('af-ZA')
              : '-'}
          </DetailRow>
        </DetailCard>
      </DetailSection>
    </div>
  );
}

export default UserDetailView;
