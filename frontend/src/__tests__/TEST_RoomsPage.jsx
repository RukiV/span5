import '@testing-library/jest-dom';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';

const mockGet = jest.fn();
jest.mock('../services/api', () => ({
  __esModule: true,
  default: { get: mockGet, post: jest.fn(), patch: jest.fn(), delete: jest.fn(), defaults: { baseURL: '' } },
  roomsAPI: { getAll: jest.fn().mockResolvedValue({ data: [] }), create: jest.fn(), update: jest.fn(), delete: jest.fn() },
  buildingsAPI: { getAll: jest.fn().mockResolvedValue({ data: [] }) },
  locationAPI: { getAll: jest.fn().mockResolvedValue({ data: [] }) },
  assetsAPI: { getAll: jest.fn().mockResolvedValue({ data: [] }) },
  apiClient: { get: mockGet, post: jest.fn(), defaults: { baseURL: '' } },
}));
jest.mock('../hooks/useCurrentUser', () => ({ useCurrentUser: () => ({ user: { user_id: 1 }, hasRight: (r) => ["locations.manage","buildings.manage","rooms.manage","assets.manage","stock.manage","faults.view","room_checks.manage","jobs.manage"].includes(r) }) }));
jest.mock('../components/Toast/useToast', () => ({ useToast: () => ({ showToast: jest.fn() }) }));
jest.mock('../components/Modal/useConfirmDialog', () => ({ useConfirmDialog: () => ({ confirm: jest.fn(), dialog: null }) }));

beforeEach(() => { jest.clearAllMocks(); });

test('renders search, filter, sort controls and add button', async () => {
  const RoomsPage = require('../pages/RoomsPage').default;
  render(<MemoryRouter><RoomsPage /></MemoryRouter>);
  await waitFor(() => {
    expect(screen.getByPlaceholderText('Soek lokale...')).toBeInTheDocument();
    expect(screen.getByText('+ Nuwe Lokaal')).toBeInTheDocument();
  });
});

test('renders room table headers', async () => {
  const RoomsPage = require('../pages/RoomsPage').default;
  render(<MemoryRouter><RoomsPage /></MemoryRouter>);
  await waitFor(() => {
    expect(screen.getByText('Naam')).toBeInTheDocument();
    expect(screen.getByText('Kode')).toBeInTheDocument();
    expect(screen.getByText('Tipe')).toBeInTheDocument();
    expect(screen.getByText('Status')).toBeInTheDocument();
    expect(screen.getByText('Gebou')).toBeInTheDocument();
    expect(screen.getByText('Kapasiteit')).toBeInTheDocument();
  });
});

test('clicking Nuwe Lokaal opens modal with form fields', async () => {
  const RoomsPage = require('../pages/RoomsPage').default;
  render(<MemoryRouter><RoomsPage /></MemoryRouter>);
  fireEvent.click(await screen.findByText('+ Nuwe Lokaal'));
  await waitFor(() => {
    expect(screen.getByText('Kanselleer')).toBeInTheDocument();
    expect(screen.getByText('Stoor')).toBeInTheDocument();
  });
});

test('shows loading state', async () => {
  const RoomsPage = require('../pages/RoomsPage').default;
  render(<MemoryRouter><RoomsPage /></MemoryRouter>);
  await waitFor(() => { expect(screen.getByText('Laai...')).toBeInTheDocument(); });
});
