import React from 'react';
import { useCurrentUser } from '../hooks/useCurrentUser';

function UserProfileHeader() {
  const { user, loading } = useCurrentUser();

  return (
    <div className="user-profile-box" style={{ textAlign: 'right', fontSize: '14px', lineHeight: '1.3' }}>
      {loading ? (
        <div className="user-loading" style={{ color: '#999' }}>Laai profiel...</div>
      ) : user ? (
        <>
          <div className="user-name" style={{ fontWeight: 'bold' }}>
            {user.user_name} {user.user_surname}
          </div>
          <div className="user-role" style={{ fontSize: '12px', color: '#935e28', fontWeight: '600' }}>
            {user.role_id === 3 ? 'Administrateur' : user.role_id === 2 ? 'Personeel' : 'Student'}
          </div>
          <div className="user-email" style={{ fontSize: '11px', color: '#666' }}>
            {user.user_email}
          </div>
        </>
      ) : (
        <div className="user-loading" style={{ color: '#999' }}>Geen profiel beskikbaar nie</div>
      )}
    </div>
  );
}

export default UserProfileHeader;
