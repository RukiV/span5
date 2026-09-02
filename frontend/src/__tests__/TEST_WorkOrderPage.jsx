import '@testing-library/jest-dom';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';

jest.mock('../services/api', () => ({
  __esModule: true,
  default: { get: jest.fn(), post: jest.fn(), patch: jest.fn(), delete: jest.fn(), defaults: { baseURL: '' } },
  workOrdersAPI: { getAll: jest.fn().mockResolvedValue({ data: [] }), getRecent: jest.fn(), create: jest.fn(), update: jest.fn(), delete: jest.fn() },
  assetsAPI: { getAll: jest.fn().mockResolvedValue({ data: [] }) },
  roomsAPI: { getAll: jest.fn().mockResolvedValue({ data: [] }) },
  buildingsAPI: { getAll: jest.fn().mockResolvedValue({ data: [] }) },
  locationAPI: { getAll: jest.fn().mockResolvedValue({ data: [] }) },
  ticketsAPI: { getAll: jest.fn().mockResolvedValue({ data: [] }) },
  usersAPI: { getAll: jest.fn().mockResolvedValue({ data: [] }) },
  quotesAPI: { getAll: jest.fn().mockResolvedValue({ data: [] }), create: jest.fn(), update: jest.fn(), delete: jest.fn() },
  apiClient: {
    get: jest.fn(), post: jest.fn(), defaults: { baseURL: '' },
    image: { getByParent: jest.fn().mockResolvedValue({ data: [] }), getFileUrl: jest.fn(), delete: jest.fn(), uploadForParent: jest.fn() },
    documents: { getByQuote: jest.fn().mockResolvedValue({ data: [] }), create: jest.fn(), delete: jest.fn() },
  },
}));
jest.mock('../hooks/useCurrentUser', () => ({ useCurrentUser: () => ({ user: { user_id: 1, role_id: 3 }, hasRight: (r) => ["jobs.manage"].includes(r) }) }));
jest.mock('../components/Toast/useToast', () => ({ useToast: () => ({ showToast: jest.fn() }) }));
jest.mock('../components/Modal/useConfirmDialog', () => ({ useConfirmDialog: () => ({ confirm: jest.fn(), dialog: null }) }));
jest.mock('@azure/msal-react', () => ({ useMsal: () => ({ instance: { acquireTokenSilent: jest.fn() } }) }));

test('renders search field and add button', async () => {
  const WorkOrderPage = require('../pages/WorkOrderPage').default;
  render(<MemoryRouter><WorkOrderPage /></MemoryRouter>);
  await waitFor(() => {
    expect(screen.getByPlaceholderText('Soek op ID of Beskrywing...')).toBeInTheDocument();
    expect(screen.getByText('+ Nuwe Werksopdrag')).toBeInTheDocument();
  });
});

test('renders work order table with key columns', async () => {
  const WorkOrderPage = require('../pages/WorkOrderPage').default;
  render(<MemoryRouter><WorkOrderPage /></MemoryRouter>);
  await waitFor(() => {
    const idHeaders = screen.getAllByText('ID');
    expect(idHeaders.length).toBeGreaterThanOrEqual(1);
    const beskrywings = screen.getAllByText('Beskrywing');
    expect(beskrywings.length).toBeGreaterThanOrEqual(1);
    const statusses = screen.getAllByText('Status');
    expect(statusses.length).toBeGreaterThanOrEqual(1);
  });
});

test('shows empty state when no work orders', async () => {
  const WorkOrderPage = require('../pages/WorkOrderPage').default;
  render(<MemoryRouter><WorkOrderPage /></MemoryRouter>);
  await waitFor(() => {
    expect(screen.getByText(/Geen werksopdragte gevind/i)).toBeInTheDocument();
  });
});
