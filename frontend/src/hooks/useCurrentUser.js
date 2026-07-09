/**
 * useCurrentUser - Haal huidige gebruiker en admin-status
 * 
 * Custom hook wat huidige ingelogde gebruiker se inligting op haal
 * en bepaal of hulle 'n Administrateur is (role_id=3).
 * 
 * Gebruik:
 *  const { user, isAdmin, loading, error } = useCurrentUser();
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
    const fetchCurrentUser = async () => {
      try {
        // Stuur GET-versoek na /auth/me met Bearer-token
        const response = await apiClient.get('/auth/me');
        setUser(response.data);
      } catch (err) {
        console.error('Error fetching current user:', err);
        setError(err);
      } finally {
        setLoading(false);
      }
    };

    fetchCurrentUser();
  }, []);

  // Bereken of gebruiker 'n Administrator is (role_id=3)
  const isAdmin = user?.role_id === 3;

  return { user, loading, error, isAdmin };
};
