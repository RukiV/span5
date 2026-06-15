/**
 * API Service - Sentraliseerde API-klien en eindpunte
 * 
 * Gebruik Axios vir HTTP-versoeke na FastAPI-backend.
 * Token-based authenticatie met Bearer-tokens.
 */

import axios from 'axios';

// API-pad vir alle versoeke
const API_PATH = '/api/v1';

// Haal backend-URL van omgewings-veranderlikes (default localhost:8000)
const rawApiUrl = process.env.REACT_APP_API_URL || 'http://localhost:8000';
const normalizedApiUrl = rawApiUrl.replace(/\/+$/, '');
const baseURL = normalizedApiUrl.endsWith(API_PATH)
  ? normalizedApiUrl
  : `${normalizedApiUrl}${API_PATH}`;

// Skep Axios-klien met basis-konfigurasie
const apiClient = axios.create({
  baseURL,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Voeg versoek-interceptor vir outentikasie-token by
apiClient.interceptors.request.use(
  (config) => {
    // Haal token uit localStorage en voeg by Authorization-header
    const token = localStorage.getItem('token');
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

// ===== BATES-API =====
export const assetsAPI = {
  getAll: () => apiClient.get('/assets'),
  getById: (id) => apiClient.get(`/assets/${id}`),
  create: (data) => apiClient.post('/assets', data),
  update: (id, data) => apiClient.patch(`/assets/${id}`, data),  // Gebruik PATCH nie PUT
  delete: (id) => apiClient.delete(`/assets/${id}`),
};

// ===== VOORRAAD-API =====
export const stockAPI = {
  getAll: () => apiClient.get('/stock'),
  getById: (id) => apiClient.get(`/stock/${id}`),
  create: (data) => apiClient.post('/stock', data),
  update: (id, data) => apiClient.patch(`/stock/${id}`, data),
  delete: (id) => apiClient.delete(`/stock/${id}`),
};

// ===== KAMERS-API =====
export const roomsAPI = {
  getAll: () => apiClient.get('/rooms'),
  getById: (id) => apiClient.get(`/rooms/${id}`),
  create: (data) => apiClient.post('/rooms', data),
  update: (id, data) => apiClient.patch(`/rooms/${id}`, data),
  delete: (id) => apiClient.delete(`/rooms/${id}`),
};

// ===== LOKASIES/TERREINE-API =====
export const locationAPI = {
  getAll: () => apiClient.get('/location'),
  getById: (id) => apiClient.get(`/location/${id}`),
  create: (data) => apiClient.post('/location', data),
  update: (id, data) => apiClient.patch(`/location/${id}`, data),
  delete: (id) => apiClient.delete(`/location/${id}`),
};

// ===== FOUTKAARTJIES-API =====
export const ticketsAPI = {
  getAll: () => apiClient.get('/fault'),
  getById: (id) => apiClient.get(`/fault/${id}`),
  create: (data) => apiClient.post('/fault', data),
  update: (id, data) => apiClient.patch(`/fault/${id}`, data),
  delete: (id) => apiClient.delete(`/fault/${id}`),
};

// ===== WERKSOPDRAGTE-API =====
export const workOrdersAPI = {
  getAll: () => apiClient.get('/job'),
  getById: (id) => apiClient.get(`/job/${id}`),
  create: (data) => apiClient.post('/job', data),
  update: (id, data) => apiClient.patch(`/job/${id}`, data),
  delete: (id) => apiClient.delete(`/job/${id}`),
};

// ===== OUTENTIKASIE-API =====
/**
 * authAPI - Outentikasie-eindpunte
 * 
 * - login: Plaaslike aanmelding met e-pos en wagwoord
 * - me: Haal huidige gebruiker se inligting
 * - logout: Meld af
 * - validateMicrosoftToken: Valideer Microsoft-token en skep app-token
 */
export const authAPI = {
  login: (user_email, user_password) => apiClient.post('/auth/login', { user_email, user_password }),
  me: () => apiClient.get('/auth/me'),
  logout: () => apiClient.post('/auth/logout'),
  validateMicrosoftToken: (token) => apiClient.post('/auth/microsoft', { microsoft_token: token })
};

// ===== GEBRUIKERS-API =====
/**
 * usersAPI - Gebruiker-beheer (admin-alleen)
 * 
 * - getAll: Haal alle gebruikers
 * - getById: Haal spesifieke gebruiker
 * - create: Skep nuwe gebruiker
 * - update: Opdateer gebruiker-data
 * - delete: Verwyder gebruiker
 */
export const usersAPI = {
  getAll: () => apiClient.get('/users'),
  getById: (id) => apiClient.get(`/users/${id}`),
  create: (data) => apiClient.post('/users', data),
  update: (id, data) => apiClient.patch(`/users/${id}`, data),
  delete: (id) => apiClient.delete(`/users/${id}`),
};

// Heg alle API-versamelings aan apiClient vir maklike toegang
apiClient.assets = assetsAPI;
apiClient.stock = stockAPI;
apiClient.rooms = roomsAPI;
apiClient.location = locationAPI;
apiClient.tickets = ticketsAPI;
apiClient.workOrders = workOrdersAPI;
apiClient.auth = authAPI;
apiClient.users = usersAPI;

// Voer apiClient uit vir gebruik in komponente
export { apiClient };
