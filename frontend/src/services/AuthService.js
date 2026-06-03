// Backend API calls
// Uses real backend endpoints for authentication

import { apiClient } from './api';

export const authService = {
  login: (username, password) => 
    apiClient.post('/auth/login', { username, password }),

  me: () => 
    apiClient.get('/auth/me'),

  logout: () => 
    apiClient.post('/auth/logout')
};

export default authService;