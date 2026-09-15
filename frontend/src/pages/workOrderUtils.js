export const normalizeWorkOrdersPayload = (payload) => {
  if (!payload) return [];

  if (Array.isArray(payload)) {
    return payload;
  }

  if (typeof payload === 'object') {
    if (Array.isArray(payload.items)) return payload.items;
    if (Array.isArray(payload.data)) return payload.data;
    if (Array.isArray(payload.work_orders)) return payload.work_orders;
    if (Array.isArray(payload.jobs)) return payload.jobs;
    if (Array.isArray(payload.results)) return payload.results;
  }

  return [];
};
