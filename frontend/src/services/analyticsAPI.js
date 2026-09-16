import { apiClient } from './api';

export const analyticsAPI = {
  getInsights: (page, dateFrom, dateTo, signal) =>
    apiClient.post('/analytics/insights', { page, date_from: dateFrom, date_to: dateTo }, { signal }),
  executeSuggestion: (suggestion) =>
    apiClient.post('/analytics/suggestions/execute', suggestion),
};