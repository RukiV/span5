import axios from 'axios';

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
  getAll: () => apiClient.get('/assets/'),
  getById: (id) => apiClient.get(`/assets/${id}/`),
  create: (data) => apiClient.post('/assets/', data),
  update: (id, data) => apiClient.patch(`/assets/${id}/`, data),
  delete: (id) => apiClient.delete(`/assets/${id}/`),
};

// Rooms API
export const roomsAPI = {
  getAll: () => apiClient.get('/rooms/'),
  getById: (id) => apiClient.get(`/rooms/${id}/`),
  create: (data) => apiClient.post('/rooms/', data),
  update: (id, data) => apiClient.patch(`/rooms/${id}/`, data),
  delete: (id) => apiClient.delete(`/rooms/${id}/`),
};

// Tickets API
export const ticketsAPI = {
  getAll: () => apiClient.get('/tickets'),
  getById: (id) => apiClient.get(`/tickets/${id}`),
  create: (data) => apiClient.post('/tickets', data),
  update: (id, data) => apiClient.put(`/tickets/${id}`, data),
  delete: (id) => apiClient.delete(`/tickets/${id}`),
};

// Work Orders API
export const workOrdersAPI = {
  getAll: () => apiClient.get('/work-orders'),
  getById: (id) => apiClient.get(`/work-orders/${id}`),
  create: (data) => apiClient.post('/work-orders', data),
  update: (id, data) => apiClient.put(`/work-orders/${id}`, data),
  delete: (id) => apiClient.delete(`/work-orders/${id}`),
};

// Auth API
export const authAPI = {
  login: (username, password) => {
    const formData = new URLSearchParams();
    formData.append('username', username);
    formData.append('password', password);
    return apiClient.post('/auth/login', formData, {
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
    });
  },
  register: (data) => apiClient.post('/auth/register', data),
  me: () => apiClient.get('/auth/me'),
  getCurrentUser: () => apiClient.get('/auth/me'),
};

// Users API
export const usersAPI = {
  getAll: () => apiClient.get('/users'),
  getById: (id) => apiClient.get(`/users/${id}`),
  create: (data) => apiClient.post('/users', data),
  update: (id, data) => apiClient.put(`/users/${id}`, data),
  delete: (id) => apiClient.delete(`/users/${id}`),
};

export { apiClient };