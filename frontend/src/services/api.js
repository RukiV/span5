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

// ===== BATE TIPES-API =====
export const assettypesAPI = {
  getAll: () => apiClient.get('/assettypes'),
  getById: (id) => apiClient.get(`/assettypes/${id}`),
  create: (data) => apiClient.post('/assettypes', data),
  update: (id, data) => apiClient.patch(`/assettypes/${id}`, data),
  delete: (id) => apiClient.delete(`/assettypes/${id}`),
};

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
};

// ===== ROLLE-API (admin: bestuur rolle en hul regte) =====
export const rolesAPI = {
  getAll: () => apiClient.get('/roles'),
  getById: (id) => apiClient.get(`/roles/${id}`),
  create: (data) => apiClient.post('/roles', data),
  update: (id, data) => apiClient.patch(`/roles/${id}`, data),
  delete: (id) => apiClient.delete(`/roles/${id}`),
  getRights: (id) => apiClient.get(`/roles/${id}/rights`),
  setRights: (id, rightIds) => apiClient.put(`/roles/${id}/rights`, { right_ids: rightIds }),
};

// ===== REGTE-API (admin: bestuur regte-katalogus) =====
export const rightsAPI = {
  getAll: () => apiClient.get('/rights'),
  getById: (id) => apiClient.get(`/rights/${id}`),
  create: (data) => apiClient.post('/rights', data),
  update: (id, data) => apiClient.patch(`/rights/${id}`, data),
  delete: (id) => apiClient.delete(`/rights/${id}`),
};

export const quotesAPI = {
  getAll: () => apiClient.get('/quotes'),
  getById: (id) => apiClient.get(`/quotes/${id}`),
  create: (data) => apiClient.post('/quotes', data),
  update: (id, data) => apiClient.patch(`/quotes/${id}`, data),
  delete: (id) => apiClient.delete(`/quotes/${id}`),
};

// ===== VOORSPELLINGS-API =====
export const predictionsAPI = {
  getAll: () => apiClient.get('/predictions'),
  getByAsset: (id) => apiClient.get(`/predictions/${id}`),
};

// Die audit-log is doelbewus LEES-ALLEEN aan die agterkant: audit-rye word net
// intern geskep as 'n newe-effek van werklike data-veranderinge. Die vorige
// create/update/delete client-metodes is verwyder saam met hul roetes.
export const auditsAPI = {
  getAllUnsorted: () => apiClient.get('/audit'),
  getAll: () => apiClient.get('/audit'),
  getById: (id) => apiClient.get(`/audit/${id}`),
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
  upload: (formData, params = {}) => apiClient.post('/image/', formData, {
    params,
    headers: { 'Content-Type': 'multipart/form-data' }
  }),
  uploadForParent: (parentId, parentType, formData) => apiClient.post('/image/', formData, {
    params: { parent_id: parentId, parent_type: parentType },
    headers: { 'Content-Type': 'multipart/form-data' }
  }),
  getAll: (skip = 0, limit = 100) => apiClient.get('/image/', { params: { skip, limit } }),
  getById: (id) => apiClient.get(`/image/${id}`),
  getByParent: (parentType, parentId) => apiClient.get(`/image/parent/${parentType}/${parentId}`),
  getFileUrl: (id) => `${apiClient.defaults.baseURL}/image/${id}/file`,
  update: (id, data) => apiClient.patch(`/image/${id}`, data),
  delete: (id) => apiClient.delete(`/image/${id}`),
};

// ===== KWOTASIE DOKUMENTE-API (PDF) =====
export const documentsAPI = {
  getByQuote: (quoteId) => apiClient.get(`/quotes/${quoteId}/documents`),
  create: (quoteId, formData) => apiClient.post(`/quotes/${quoteId}/documents`, formData, {
    headers: { 'Content-Type': 'multipart/form-data' }
  }),
  getFileUrl: (documentId) => `${apiClient.defaults.baseURL}/documents/${documentId}/file`,
  delete: (documentId) => apiClient.delete(`/documents/${documentId}`),
};

// ===== LOKAAL KONTROLE-API =====
export const roomChecksAPI = {
  getByRoom: (roomId) => apiClient.get('/room-checks', { params: { room_id: roomId } }),
  getById: (id) => apiClient.get(`/room-checks/${id}`),
  create: (data) => apiClient.post('/room-checks', data),
};

// ===== KALENDER EVENTS-API =====
export const calendarEventsAPI = {
  getRange: (start, end) => apiClient.get('/calendar/events', { params: { start, end } }),
  getById: (id) => apiClient.get(`/calendar/events/${id}`),
  create: (data) => apiClient.post('/calendar/events', data),
  update: (id, data) => apiClient.patch(`/calendar/events/${id}`, data),
  delete: (id) => apiClient.delete(`/calendar/events/${id}`),
};

// Attach all API collections to apiClient
apiClient.assets = assetsAPI;
apiClient.assettypes = assettypesAPI;
apiClient.stock = stockAPI;
apiClient.rooms = roomsAPI;
apiClient.buildings = buildingsAPI;
apiClient.location = locationAPI;
apiClient.tickets = ticketsAPI;
apiClient.workOrders = workOrdersAPI;
apiClient.auth = authAPI;
apiClient.users = usersAPI;
apiClient.roles = rolesAPI;
apiClient.rights = rightsAPI;
apiClient.quotes = quotesAPI;
apiClient.predictions = predictionsAPI;
apiClient.image = imageAPI;
apiClient.documents = documentsAPI;
apiClient.calendarEvents = calendarEventsAPI;
apiClient.roomChecks = roomChecksAPI;

// Voer apiClient uit vir gebruik in komponente
export { apiClient };
export default apiClient;