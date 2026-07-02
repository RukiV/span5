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

// Voeg versoek-interceptor vir outentikasie-token en client-type by
apiClient.interceptors.request.use(
  (config) => {
    // Haal token uit sessionStorage en voeg by Authorization-header
    const token = sessionStorage.getItem('token');
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    // Voeg X-Client-Type header by om as web-klien te identifiseer
    // Backend kontroleer hierdie vir rol-gebaseerde toegang (Students slegs mobile)
    config.headers['X-Client-Type'] = 'web';
    return config;
  },
  (error) => { 
    return Promise.reject(error);
  }
);

//Voeg antwoord-interceptor by vir stelsel-foute (Verval/Server Down) =====
apiClient.interceptors.response.use(
  (response) => {
    return response;
  },
  (error) => {
    // 401 beteken die token het verval of die backend het herbegin en ken nie die sessie nie
    if (error.response && error.response.status === 401) {
      console.warn('Sessie het verval of token is ongeldig. Meld tans af...');
      
      // Maak die sessionStorage skoon
      sessionStorage.clear();
      
      // Dwing die blaaier om terug te gaan na die Login-skerm
      window.location.href = '/login';
    }
    return Promise.reject(error);
  }
);

// ===== BATES-API =====
export const assetsAPI = {
  getAll: () => apiClient.get('/assets'),
  getById: (id) => apiClient.get(`/assets/${id}`),
  getStatusSummary: () => apiClient.get('/assets/status-summary'),
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
  // create: Ondersteun multipart form data vir image uploads (mobiele app)
  create: (data) => {
    // As data bevat FormData, gebruik multipart form data header
    if (data instanceof FormData) {
      return apiClient.post('/fault', data, {
        headers: { 'Content-Type': 'multipart/form-data' }
      });
    }
    // Anders stuur as JSON
    return apiClient.post('/fault', data);
  },
  update: (id, data) => apiClient.patch(`/fault/${id}`, data),
  delete: (id) => apiClient.delete(`/fault/${id}`),
};

// ===== WERKSOPDRAGTE-API =====
export const workOrdersAPI = {
  getAll: () => apiClient.get('/job'),
  getRecent: (limit = 5) => apiClient.get('/job/recent', { params: { limit } }),
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

export const contractorsAPI = {
  getAll: () => apiClient.get('/contractors'),
  getById: (id) => apiClient.get(`/contractors/${id}`),
  create: (data) => apiClient.post('/contractors', data),
  update: (id, data) => apiClient.patch(`/contractors/${id}`, data),
  delete: (id) => apiClient.delete(`/contractors/${id}`),
};

export const quotesAPI = {
  getAll: () => apiClient.get('/quotes'),
  getById: (id) => apiClient.get(`/quotes/${id}`),
  create: (data) => apiClient.post('/quotes', data),
  update: (id, data) => apiClient.patch(`/quotes/${id}`, data),
  delete: (id) => apiClient.delete(`/quotes/${id}`),
};

// Attach all API collections to apiClient
apiClient.assets = assetsAPI;
apiClient.stock = stockAPI;
apiClient.rooms = roomsAPI;
apiClient.location = locationAPI;
apiClient.tickets = ticketsAPI;
apiClient.workOrders = workOrdersAPI;
apiClient.auth = authAPI;
apiClient.users = usersAPI;
apiClient.contractors = contractorsAPI;
apiClient.quotes = quotesAPI;

// Voer apiClient uit vir gebruik in komponente
export { apiClient };
