import '@testing-library/jest-dom';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';

jest.mock('../services/api', () => ({
  __esModule: true,
  default: { get: jest.fn(), post: jest.fn(), patch: jest.fn(), delete: jest.fn(), defaults: { baseURL: '' } },
  stockAPI: { getAll: jest.fn().mockResolvedValue({ data: [] }), getById: jest.fn(), create: jest.fn(), update: jest.fn(), delete: jest.fn() },
  roomsAPI: { getAll: jest.fn().mockResolvedValue({ data: [] }) },
  buildingsAPI: { getAll: jest.fn().mockResolvedValue({ data: [] }) },
  locationAPI: { getAll: jest.fn().mockResolvedValue({ data: [] }) },
  apiClient: { get: jest.fn(), post: jest.fn(), defaults: { baseURL: '' },
    image: { getByParent: jest.fn().mockResolvedValue({ data: [] }), getFileUrl: jest.fn(), delete: jest.fn(), uploadForParent: jest.fn() },
  },
}));
jest.mock('../hooks/useCurrentUser', () => ({ useCurrentUser: () => ({ user: { user_id: 1 }, hasRight: (r) => ["locations.manage","buildings.manage","rooms.manage","assets.manage","stock.manage","faults.manage_all","jobs.manage"].includes(r) }) }));
jest.mock('../components/Toast/useToast', () => ({ useToast: () => ({ showToast: jest.fn() }) }));
jest.mock('../components/Modal/useConfirmDialog', () => ({ useConfirmDialog: () => ({ confirm: jest.fn(), dialog: null }) }));

test('renders search, filter, sort, and add button', async () => {
  const StockPage = require('../pages/StockPage').default;
  render(<MemoryRouter><StockPage /></MemoryRouter>);
  await waitFor(() => {
    expect(screen.getByPlaceholderText('Soek voorraad...')).toBeInTheDocument();
    expect(screen.getByText('+ Nuwe Voorraad')).toBeInTheDocument();
  });
});

test('renders stock table headers', async () => {
  const StockPage = require('../pages/StockPage').default;
  render(<MemoryRouter><StockPage /></MemoryRouter>);
  await waitFor(() => {
    expect(screen.getByText('ID Voorraad')).toBeInTheDocument();
    const names = screen.getAllByText('Naam');
    expect(names.length).toBeGreaterThanOrEqual(1);
    const merke = screen.getAllByText('Merk');
    expect(merke.length).toBeGreaterThanOrEqual(1);
    const hoeveelhede = screen.getAllByText('Hoeveelheid');
    expect(hoeveelhede.length).toBeGreaterThanOrEqual(1);
    const lokale = screen.getAllByText('Lokaal');
    expect(lokale.length).toBeGreaterThanOrEqual(1);
  });
});

test('clicking Nuwe Voorraad opens modal', async () => {
  const StockPage = require('../pages/StockPage').default;
  render(<MemoryRouter><StockPage /></MemoryRouter>);
  fireEvent.click(await screen.findByText('+ Nuwe Voorraad'));
  await waitFor(() => {
    expect(screen.getByText('Kanselleer')).toBeInTheDocument();
    expect(screen.getByText('Stoor')).toBeInTheDocument();
  });
});
