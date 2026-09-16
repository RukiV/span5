import '@testing-library/jest-dom';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';

jest.mock('../services/api', () => ({
  __esModule: true,
  default: { get: jest.fn(), post: jest.fn(), patch: jest.fn(), delete: jest.fn(), defaults: { baseURL: '' } },
  buildingsAPI: { getAll: jest.fn().mockResolvedValue({ data: [] }), create: jest.fn(), update: jest.fn(), delete: jest.fn() },
  locationAPI: { getAll: jest.fn().mockResolvedValue({ data: [] }) },
  roomsAPI: { getAll: jest.fn().mockResolvedValue({ data: [] }) },
}));
jest.mock('../hooks/useCurrentUser', () => ({ useCurrentUser: () => ({ user: { user_id: 1 }, hasRight: (r) => ["locations.manage","buildings.manage","rooms.manage","assets.manage","stock.manage","faults.view","jobs.manage"].includes(r) }) }));
jest.mock('../components/Toast/useToast', () => ({ useToast: () => ({ showToast: jest.fn() }) }));
jest.mock('../components/Modal/useConfirmDialog', () => ({ useConfirmDialog: () => ({ confirm: jest.fn(), dialog: null }) }));

beforeEach(() => { jest.clearAllMocks(); });

test('renders search, filter, sort, and add button', async () => {
  const BuildingsPage = require('../pages/BuildingsPage').default;
  render(<MemoryRouter><BuildingsPage /></MemoryRouter>);
  await waitFor(() => {
    expect(screen.getByPlaceholderText('Soek geboue...')).toBeInTheDocument();
    expect(screen.getByText('+ Nuwe Gebou')).toBeInTheDocument();
  });
});

test('renders building table headers', async () => {
  const BuildingsPage = require('../pages/BuildingsPage').default;
  render(<MemoryRouter><BuildingsPage /></MemoryRouter>);
  await waitFor(() => {
    expect(screen.getByText('Naam')).toBeInTheDocument();
    expect(screen.getByText('Tipe')).toBeInTheDocument();
    expect(screen.getByText('Terrein')).toBeInTheDocument();
  });
});

test('clicking Nuwe Gebou opens modal', async () => {
  const BuildingsPage = require('../pages/BuildingsPage').default;
  render(<MemoryRouter><BuildingsPage /></MemoryRouter>);
  fireEvent.click(await screen.findByText('+ Nuwe Gebou'));
  await waitFor(() => {
    expect(screen.getByText('Kanselleer')).toBeInTheDocument();
    expect(screen.getByText('Stoor')).toBeInTheDocument();
  });
});

test('shows loading state', async () => {
  const BuildingsPage = require('../pages/BuildingsPage').default;
  render(<MemoryRouter><BuildingsPage /></MemoryRouter>);
  await waitFor(() => { expect(screen.getByText('Laai...')).toBeInTheDocument(); });
});
