import { useState, useEffect } from 'react';
import { apiClient } from '../services/api';

export const useCurrentUser = () => {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    const fetchCurrentUser = async () => {
      try {
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

  const isAdmin = user?.role_id === 3;

  return { user, loading, error, isAdmin };
};
