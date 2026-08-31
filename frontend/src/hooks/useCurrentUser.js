/**
<<<<<<< HEAD
 * useCurrentUser - Haal huidige gebruiker, sy regte, en admin-status
 *
 * Custom hook wat die huidige ingelogde gebruiker se inligting op haal vanaf
 * /auth/me. Die backend gee nou 'n `rights`-lys terug (die enkele bron van
 * waarheid vir toegangsbeheer), so komponente kan `hasRight(...)` gebruik in
 * plaas van hardgekodeerde rol-ID kontroles.
 *
 * Gebruik:
 *  const { user, rights, hasRight, isAdmin, loading, error } = useCurrentUser();
=======
 * useCurrentUser - Haal huidige gebruiker en admin-status
 * 
 * Custom hook wat huidige ingelogde gebruiker se inligting op haal
 * en bepaal of hulle 'n Administrateur is (role_id=3).
 * 
 * Gebruik:
 *  const { user, isAdmin, loading, error } = useCurrentUser();
>>>>>>> a6cc9b7400a2a627147078aeed60cfe907bbb8c3
 */

import { useState, useEffect } from 'react';
import { apiClient } from '../services/api';

export const useCurrentUser = () => {
  // State vir gebruiker-data
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  // Haal huidige gebruiker wanneer hook laai
  useEffect(() => {
<<<<<<< HEAD
    let cancelled = false;
=======
>>>>>>> a6cc9b7400a2a627147078aeed60cfe907bbb8c3
    const fetchCurrentUser = async () => {
      try {
        // Stuur GET-versoek na /auth/me met Bearer-token
        const response = await apiClient.get('/auth/me');
<<<<<<< HEAD
        if (!cancelled) setUser(response.data);
      } catch (err) {
        console.error('Error fetching current user:', err);
        if (!cancelled) setError(err);
      } finally {
        if (!cancelled) setLoading(false);
=======
        setUser(response.data);
      } catch (err) {
        console.error('Error fetching current user:', err);
        setError(err);
      } finally {
        setLoading(false);
>>>>>>> a6cc9b7400a2a627147078aeed60cfe907bbb8c3
      }
    };

    fetchCurrentUser();
<<<<<<< HEAD
    return () => { cancelled = true; };
  }, []);

  // Regte-lys vanaf /auth/me (enkele bron van waarheid vir toegang)
  const rights = user?.rights || [];
  const hasRight = (right) => rights.includes(right);

  // Behou vir agteruit-verenigbaarheid; verkies hasRight('users.manage')
  const isAdmin = user?.role_id === 3;

  return { user, loading, error, rights, hasRight, isAdmin };
=======
  }, []);

  // Bereken of gebruiker 'n Administrator is (role_id=3)
  const isAdmin = user?.role_id === 3;

  return { user, loading, error, isAdmin };
>>>>>>> a6cc9b7400a2a627147078aeed60cfe907bbb8c3
};
