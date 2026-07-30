import { apiClient } from './api';

export const analyticsAPI = {
  getInsights: (page, dateFrom, dateTo) =>
    apiClient.post('/analytics/insights', { page, date_from: dateFrom, date_to: dateTo }),
  executeSuggestion: (suggestion) =>
    apiClient.post('/analytics/suggestions/execute', suggestion),
  chat: (page, query, history) =>
    apiClient.post('/analytics/chat', { page, query, history }),
};