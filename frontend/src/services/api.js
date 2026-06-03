import axios from 'axios';
import authService from './AuthService';

const API_PATH = '/api/v1';
const rawApiUrl = process.env.REACT_APP_API_URL || 'http://localhost:8000';
const normalizedApiUrl = rawApiUrl.replace(/\/+$/, '');
const baseURL = normalizedApiUrl.endsWith(API_PATH)
  ? normalizedApiUrl
  : `${normalizedApiUrl}${API_PATH}`;

const apiClient = axios.create({
  baseURL,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Add request interceptor for authentication
apiClient.interceptors.request.use(
  (config) => {
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

// Assets API
export const assetsAPI = {
  getAll: () => apiClient.get('/assets'),
  getById: (id) => apiClient.get(`/assets/${id}`),
  create: (data) => apiClient.post('/assets', data),
  update: (id, data) => apiClient.patch(`/assets/${id}`, data),
  delete: (id) => apiClient.delete(`/assets/${id}`),
};

// Stock API
export const stockAPI = {
  getAll: () => apiClient.get('/stock'),
  getById: (id) => apiClient.get(`/stock/${id}`),
  create: (data) => apiClient.post('/stock', data),
  update: (id, data) => apiClient.patch(`/stock/${id}`, data),
  delete: (id) => apiClient.delete(`/stock/${id}`),
};

// Rooms API
export const roomsAPI = {
  getAll: () => apiClient.get('/rooms'),
  getById: (id) => apiClient.get(`/rooms/${id}`),
  create: (data) => apiClient.post('/rooms', data),
  update: (id, data) => apiClient.patch(`/rooms/${id}`, data),
  delete: (id) => apiClient.delete(`/rooms/${id}`),
};

// Location API
export const locationAPI = {
  getAll: () => apiClient.get('/location'),
  getById: (id) => apiClient.get(`/location/${id}`),
  create: (data) => apiClient.post('/location', data),
  update: (id, data) => apiClient.patch(`/location/${id}`, data),
  delete: (id) => apiClient.delete(`/location/${id}`),
};

// Tickets API
export const ticketsAPI = {
  getAll: () => apiClient.get('/fault'),
  getById: (id) => apiClient.get(`/fault/${id}`),
  create: (data) => apiClient.post('/fault', data),
  update: (id, data) => apiClient.patch(`/fault/${id}`, data),
  delete: (id) => apiClient.delete(`/fault/${id}`),
};

// Work Orders API
export const workOrdersAPI = {
  getAll: () => apiClient.get('/job'),
  getById: (id) => apiClient.get(`/job/${id}`),
  create: (data) => apiClient.post('/job', data),
  update: (id, data) => apiClient.patch(`/job/${id}`, data),
  delete: (id) => apiClient.delete(`/job/${id}`),
};

// Auth API
export const authAPI = {
  login: (username, password) => apiClient.post('/auth/login', { username, password }),
  me: () => apiClient.get('/auth/me'),
  logout: () => apiClient.post('/auth/logout')
};

// Users API
export const usersAPI = {
  getAll: () => apiClient.get('/users'),
  getById: (id) => apiClient.get(`/users/${id}`),
  create: (data) => apiClient.post('/users', data),
  update: (id, data) => apiClient.put(`/users/${id}`, data),
  delete: (id) => apiClient.delete(`/users/${id}`),
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

export { apiClient };
