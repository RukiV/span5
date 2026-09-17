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
    ai: { getStatus: jest.fn() },
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
  apiClient.ai.getStatus.mockResolvedValue({ data: { ai_enabled: true } });
});

test('renders AI draft queue with Afrikaans title and draft rows', async () => {
  const AIDraftQueuePage = require('../pages/AIDraftQueuePage').default;
  render(<MemoryRouter><AIDraftQueuePage /></MemoryRouter>);
  await waitFor(() => {
    expect(screen.getByText('+ Nuwe Voorgestelde Werksopdrag')).toBeInTheDocument();
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
    expect(screen.getByText('+ Nuwe Voorgestelde Werksopdrag')).toBeInTheDocument();
    // Should still render the page controls even when data fetch fails
    // (default filter is "Konsepte", i.e. draft status)
    expect(screen.getByText('Konsepte')).toBeInTheDocument();
  });
});

test('calls getAll with draft status filter by default', async () => {
  const AIDraftQueuePage = require('../pages/AIDraftQueuePage').default;
  render(<MemoryRouter><AIDraftQueuePage /></MemoryRouter>);
  await waitFor(() => {
    expect(apiClient.jobDrafts.getAll).toHaveBeenCalledWith({ status_filter: 'draft', source_filter: '' });
  });
});

test('renders AI status indicator (Aktief)', async () => {
  const AIDraftQueuePage = require('../pages/AIDraftQueuePage').default;
  render(<MemoryRouter><AIDraftQueuePage /></MemoryRouter>);
  await waitFor(() => {
    expect(screen.getByText('AI: Aktief')).toBeInTheDocument();
  });
  expect(apiClient.ai.getStatus).toHaveBeenCalled();
});

test('AI indicator is absent while loading', async () => {
  apiClient.ai.getStatus.mockImplementationOnce(() => new Promise(() => {})); // never resolves
  const AIDraftQueuePage = require('../pages/AIDraftQueuePage').default;
  render(<MemoryRouter><AIDraftQueuePage /></MemoryRouter>);
  expect(screen.queryByText('AI: Aktief')).not.toBeInTheDocument();
  expect(screen.queryByText('AI: Inaktief')).not.toBeInTheDocument();
});

test('initialises source filter from URL (?source=auto) and fetches with source_filter=auto', async () => {
  const AIDraftQueuePage = require('../pages/AIDraftQueuePage').default;
  render(<MemoryRouter initialEntries={['/ai-drafts?source=auto']}><AIDraftQueuePage /></MemoryRouter>);
  await waitFor(() => {
    expect(apiClient.jobDrafts.getAll).toHaveBeenCalledWith({ status_filter: 'draft', source_filter: 'auto' });
  });
  expect(await screen.findByText('Gefiltreer: Outomaties')).toBeInTheDocument();
});

test('Bron dropdown sets source filter and refetches with source_filter=auto', async () => {
  const AIDraftQueuePage = require('../pages/AIDraftQueuePage').default;
  render(<MemoryRouter><AIDraftQueuePage /></MemoryRouter>);
  await screen.findByText('+ Nuwe Voorgestelde Werksopdrag');

  // Maak die Bron-keuselys oop (laaste react-select op die blad)
  const selects = document.querySelectorAll('.react-select-container');
  const bronControl = selects[selects.length - 1].querySelector('.react-select__control');
  fireEvent.mouseDown(bronControl);

  // Kies "Outomaties" uit die oop keuselys (slegs in die opgeskorte menu, nie die tabel nie)
  await waitFor(() => {
    expect(document.querySelector('.react-select__menu')).toBeInTheDocument();
  });
  const option = Array.from(document.querySelectorAll('.react-select__option'))
    .find((el) => el.textContent.trim() === 'Outomaties');
  fireEvent.click(option);

  await waitFor(() => {
    expect(apiClient.jobDrafts.getAll).toHaveBeenCalledWith({ status_filter: 'draft', source_filter: 'auto' });
  });
  expect(await screen.findByText('Gefiltreer: Outomaties')).toBeInTheDocument();
});
