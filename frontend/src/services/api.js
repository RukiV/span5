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
  getHistory: (id) => apiClient.get(`/assets/${id}/history`),
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

// ===== GEBOU-BESTUUR-API =====
export const buildingsAPI = {
  getAll: () => apiClient.get('/building'),
  getById: (id) => apiClient.get(`/building/${id}`),
  create: (data) => apiClient.post('/building', data),
  update: (id, data) => apiClient.patch(`/building/${id}`, data),
  delete: (id) => apiClient.delete(`/building/${id}`),
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
  upload: (formData) => apiClient.post('/image/', formData),
  // create: Ondersteun multipart form data vir image uploads (mobiele app)
  create: (data) => {
    // As data bevat FormData, stuur die FormData direk; axios sal die regte header self stel
    if (data instanceof FormData) {
      return apiClient.post('/fault', data);
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
  getScheduled: () => apiClient.get('/job/scheduled/upcoming'),
  create: (data, config) => apiClient.post('/job', data, config),
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
  getAssignable: () => apiClient.get('/users/assignable'),
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

export const auditsAPI = {
  getAllUnsorted: () => apiClient.get('/audit'),
  getAll: () => apiClient.get('/audit'),
  getById: (id) => apiClient.get(`/audit/${id}`),
  create: (data) => apiClient.post('/audit', data),
  update: (id, data) => apiClient.patch(`/audit/${id}`, data),
  delete: (id) => apiClient.delete(`/audit/${id}`),

  getRoomChangesForAsset: (asset_id) => apiClient.get(`/audit/asset/${asset_id}`),
};

// ===== BEELDE-API =====
/**
 * imagesAPI - Beeld-bestuur (gebruik deur foutkaartjies ens.)
 *
 * Let wel: die backend-roete is gemonteer as "/image" (enkelvoud), nie
 * "/images" nie. Die router self definieer sy lys/skep-roetes op "/", dus
 * gebruik ons "/image/" (met skuinsstreep) hier om 'n 307-herleiding op
 * POST te vermy.
 *
 * - upload: Laai 'n nuwe beeld op (multipart form data, veld "file")
 * - getAll: Haal alle beeld-metadata
 * - getById: Haal metadata vir 'n spesifieke beeld
 * - getFileUrl: Bou die URL wat die rou beeld-grepe bedien (vir <img src>)
 * - update: Opdateer beeld-metadata (bv. lêernaam)
 * - delete: Verwyder beeld en sy grepe
 */
export const imageAPI = {
  upload: (formData) => apiClient.post('/image/', formData, {
    headers: { 'Content-Type': 'multipart/form-data' }
  }),
  getAll: (skip = 0, limit = 100) => apiClient.get('/image/', { params: { skip, limit } }),
  getById: (id) => apiClient.get(`/image/${id}`),
  getFileUrl: (id) => `${apiClient.defaults.baseURL}/image/${id}/file`,
  update: (id, data) => apiClient.patch(`/image/${id}`, data),
  delete: (id) => apiClient.delete(`/image/${id}`),
};

<<<<<<< HEAD
// ===== KWOTASIE DOKUMENTE-API (PDF) =====
export const documentsAPI = {
  getByQuote: (quoteId) => apiClient.get(`/quotes/${quoteId}/documents`),
  create: (quoteId, formData) => apiClient.post(`/quotes/${quoteId}/documents`, formData, {
    headers: { 'Content-Type': 'multipart/form-data' }
  }),
  getFileUrl: (documentId) => `${apiClient.defaults.baseURL}/documents/${documentId}/file`,
  delete: (documentId) => apiClient.delete(`/documents/${documentId}`),
};

// ===== AI JOBDRAFTS-API =====
export const jobDraftsAPI = {
  create: (data) => apiClient.post('/ai', data),
  getAll: (params) => apiClient.get('/ai', { params }),
  getById: (id) => apiClient.get(`/ai/${id}`),
  approve: (id, data) => apiClient.post(`/ai/${id}/approve`, data),
  reject: (id, data) => apiClient.post(`/ai/${id}/reject`, data),
};

// ===== DATA-INVOER-API (CSV/XLSX) =====
export const importAPI = {
  schema: () => apiClient.get('/import/schema'),
  preview: (file, hints) => {
    const formData = new FormData();
    formData.append('file', file);
    if (hints && Object.keys(hints).length > 0) {
      formData.append('hints', JSON.stringify(hints));
    }
    return apiClient.post('/import/preview', formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
      timeout: 120000,
    });
  },
  commit: (payload) => apiClient.post('/import/commit', payload, { timeout: 120000 }),
  exportData: (payload) =>
    apiClient.post('/import/export', payload, { responseType: 'blob', timeout: 120000 }),
};


// ===== AI VELDVOORSTELLE-API =====
export const suggestAPI = {
  suggest: (context, fields, config) => apiClient.post('/ai/suggest', { context, fields }, config),
};

// ===== LOKAAL KONTROLE-API =====
export const roomChecksAPI = {
  getByRoom: (roomId) => apiClient.get('/room-checks', { params: { room_id: roomId } }),
  getById: (id) => apiClient.get(`/room-checks/${id}`),
  create: (data) => apiClient.post('/room-checks', data),
  sessions: {
    getAll: (params) => apiClient.get('/room-checks/sessions', { params }),
    create: (data) => apiClient.post('/room-checks/sessions', data),
    update: (id, data) => apiClient.patch(`/room-checks/sessions/${id}`, data),
    delete: (id) => apiClient.delete(`/room-checks/sessions/${id}`),
    complete: (id) => apiClient.post(`/room-checks/sessions/${id}/complete`),
  },
};

// ===== KALENDER EVENTS-API =====
export const calendarEventsAPI = {
  getRange: (start, end) => apiClient.get('/calendar/events', { params: { start, end } }),
  getById: (id) => apiClient.get(`/calendar/events/${id}`),
  create: (data) => apiClient.post('/calendar/events', data),
  update: (id, data) => apiClient.patch(`/calendar/events/${id}`, data),
  delete: (id) => apiClient.delete(`/calendar/events/${id}`),
};

=======
>>>>>>> a6cc9b7400a2a627147078aeed60cfe907bbb8c3
// Attach all API collections to apiClient
apiClient.assets = assetsAPI;
apiClient.stock = stockAPI;
apiClient.rooms = roomsAPI;
apiClient.buildings = buildingsAPI;
apiClient.location = locationAPI;
apiClient.tickets = ticketsAPI;
apiClient.workOrders = workOrdersAPI;
apiClient.auth = authAPI;
apiClient.users = usersAPI;
apiClient.contractors = contractorsAPI;
apiClient.quotes = quotesAPI;
apiClient.image = imageAPI;
<<<<<<< HEAD
apiClient.documents = documentsAPI;
apiClient.calendarEvents = calendarEventsAPI;
apiClient.roomChecks = roomChecksAPI;
apiClient.jobDrafts = jobDraftsAPI;
apiClient.suggest = suggestAPI;
=======
>>>>>>> a6cc9b7400a2a627147078aeed60cfe907bbb8c3

// Voer apiClient uit vir gebruik in komponente
export { apiClient };
export default apiClient;