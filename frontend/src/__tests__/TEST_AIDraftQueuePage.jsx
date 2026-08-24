import '@testing-library/jest-dom';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';

jest.mock('../services/api', () => ({
  __esModule: true,
  default: { get: jest.fn(), post: jest.fn(), defaults: { baseURL: '' } },
  jobDraftsAPI: {
    getAll: jest.fn(),
    getById: jest.fn(),
    create: jest.fn(),
    approve: jest.fn(),
    reject: jest.fn(),
  },
  apiClient: {
    get: jest.fn(), post: jest.fn(), defaults: { baseURL: '' },
    jobDrafts: {
      getAll: jest.fn(), getById: jest.fn(), create: jest.fn(), approve: jest.fn(), reject: jest.fn(),
    },
  },
}));
jest.mock('../hooks/useCurrentUser', () => ({ useCurrentUser: () => ({ user: { user_id: 1 } }) }));
jest.mock('../components/Toast/useToast', () => ({ useToast: () => ({ showToast: jest.fn() }) }));

const { apiClient } = require('../services/api');

beforeEach(() => {
  jest.clearAllMocks();
  apiClient.jobDrafts.getAll.mockResolvedValue({
    data: [
      { draft_id: 1, title: 'Gebroke venster', description: 'Venster in kantoor 3 is stukkend', suggested_type: 'REPAIR', suggested_priority: 'HIGH', ai_status: 'ok', source: 'auto', status: 'draft', created_at: '2025-07-01T10:00:00' },
      { draft_id: 2, title: 'Onderhoud pyp', description: 'Pyp lek in toilet', suggested_type: 'MAINTENANCE', suggested_priority: 'MEDIUM', ai_status: 'degraded', source: 'manual', status: 'draft', created_at: '2025-07-02T14:30:00' },
    ],
  });
});

test('renders AI draft queue with Afrikaans title and draft rows', async () => {
  const AIDraftQueuePage = require('../pages/AIDraftQueuePage').default;
  render(<MemoryRouter><AIDraftQueuePage /></MemoryRouter>);
  await waitFor(() => {
    expect(screen.getByText('+ Nuwe AI Konsep')).toBeInTheDocument();
    expect(screen.getByText('Gebroke venster')).toBeInTheDocument();
    expect(screen.getByText('Onderhoud pyp')).toBeInTheDocument();
    expect(screen.getByText('Outomaties')).toBeInTheDocument();
    expect(screen.getByText('Handmatig')).toBeInTheDocument();
  });
});

test('handles API error without crashing', async () => {
  apiClient.jobDrafts.getAll.mockRejectedValue(new Error('Network error'));
  const AIDraftQueuePage = require('../pages/AIDraftQueuePage').default;
  render(<MemoryRouter><AIDraftQueuePage /></MemoryRouter>);
  await waitFor(() => {
    expect(screen.getByText('+ Nuwe AI Konsep')).toBeInTheDocument();
    // Should still render the page controls even when data fetch fails
    expect(screen.getByText('Alle')).toBeInTheDocument();
  });
});

test('calls getAll with draft status filter by default', async () => {
  const AIDraftQueuePage = require('../pages/AIDraftQueuePage').default;
  render(<MemoryRouter><AIDraftQueuePage /></MemoryRouter>);
  await waitFor(() => {
    expect(apiClient.jobDrafts.getAll).toHaveBeenCalledWith({ status_filter: 'draft' });
  });
});
