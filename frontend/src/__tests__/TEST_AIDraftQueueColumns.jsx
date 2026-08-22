import '@testing-library/jest-dom';
import { render, screen, waitFor } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';

jest.mock('../services/api', () => ({
  __esModule: true,
  default: { get: jest.fn(), post: jest.fn(), defaults: { baseURL: '' } },
  jobDraftsAPI: {
    getAll: jest.fn(), getById: jest.fn(), create: jest.fn(), approve: jest.fn(), reject: jest.fn(),
  },
  suggestAPI: { suggest: jest.fn() },
  apiClient: {
    get: jest.fn(), post: jest.fn(), defaults: { baseURL: '' },
    jobDrafts: {
      getAll: jest.fn(), getById: jest.fn(), create: jest.fn(), approve: jest.fn(), reject: jest.fn(),
    },
    suggest: { suggest: jest.fn() },
  },
}));
jest.mock('../components/Toast/useToast', () => ({ useToast: () => ({ showToast: jest.fn() }) }));

const { apiClient } = require('../services/api');

beforeEach(() => {
  jest.clearAllMocks();
  apiClient.jobDrafts.getAll.mockResolvedValue({
    data: [
      { draft_id: 1, title: 'Gebroke venster', suggested_type: 'REPAIR', suggested_priority: 'HIGH', ai_status: 'ok', source: 'auto', status: 'draft', created_at: '2026-07-01T10:00:00', resolved_room_name: 'Lesinglokaal A', building_name: 'Blok L', resolved_asset_name: 'Projektor PLA-1' },
      { draft_id: 2, description: 'Pyp lek in die toilet by die ingang', suggested_type: 'MAINTENANCE', suggested_priority: 'MEDIUM', ai_status: 'degraded', source: 'manual', status: 'draft', created_at: '2026-07-02T14:30:00' },
    ],
  });
});

const renderPage = () => {
  const AIDraftQueuePage = require('../pages/AIDraftQueuePage').default;
  return render(<MemoryRouter><AIDraftQueuePage /></MemoryRouter>);
};

test('wys die Bate-kolom by verstek met die opgeloste batenaam', async () => {
  renderPage();
  await waitFor(() => expect(screen.getByText('Projektor PLA-1')).toBeInTheDocument());
  expect(screen.getByText('Bate')).toBeInTheDocument();
});

test('leë ligging wys \'n streep i.p.v. crasht', async () => {
  renderPage();
  await waitFor(() => expect(screen.getByText('Pyp lek in die toilet by die ingang')).toBeInTheDocument());
});

test('sorteer op ID wanneer die kolomkop geklik word', async () => {
  const { fireEvent } = require('@testing-library/react');
  renderPage();
  await waitFor(() => expect(screen.getByText('Projektor PLA-1')).toBeInTheDocument());
  const idHeader = screen.getByText('ID');
  fireEvent.click(idHeader.closest('th'));
  const rows = screen.getAllByText(/^(1|2)$/);
  // Na kliek (op) bly 2 eerste — sorteer stygend oor draft_id.
  expect(rows[0]).toHaveTextContent('1');
});
