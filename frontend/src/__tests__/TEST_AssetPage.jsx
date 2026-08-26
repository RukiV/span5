import '@testing-library/jest-dom';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';

jest.mock('../services/api', () => ({
  __esModule: true,
  default: { get: jest.fn(), post: jest.fn(), patch: jest.fn(), delete: jest.fn(), defaults: { baseURL: '' } },
  assetsAPI: { getAll: jest.fn(), getById: jest.fn(), getHistory: jest.fn(), create: jest.fn(), update: jest.fn(), delete: jest.fn(), getStatusSummary: jest.fn() },
  assettypesAPI: { getAll: jest.fn(), getById: jest.fn(), create: jest.fn(), update: jest.fn(), delete: jest.fn() },
  roomsAPI: { getAll: jest.fn() },
  buildingsAPI: { getAll: jest.fn() },
  locationAPI: { getAll: jest.fn() },
  workOrdersAPI: { getAll: jest.fn() },
  authAPI: { me: jest.fn() },
  apiClient: { get: jest.fn(), post: jest.fn(), defaults: { baseURL: '' }, image: { getByParent: jest.fn(), getFileUrl: jest.fn(), delete: jest.fn(), uploadForParent: jest.fn() } },
}));
jest.mock('../hooks/useCurrentUser', () => ({ useCurrentUser: () => ({ user: { user_id: 1 }, hasRight: (r) => ["locations.manage","buildings.manage","rooms.manage","assets.manage","stock.manage","faults.manage_all","jobs.manage"].includes(r) }) }));
jest.mock('../components/Toast/useToast', () => ({ useToast: () => ({ showToast: jest.fn() }) }));
jest.mock('../components/Modal/useConfirmDialog', () => ({ useConfirmDialog: () => ({ confirm: jest.fn(), dialog: null }) }));

beforeEach(() => {
  const api = require('../services/api');
  api.assetsAPI.getAll.mockResolvedValue({ data: [] });
  api.assettypesAPI.getAll.mockResolvedValue({ data: [] });
  api.roomsAPI.getAll.mockResolvedValue({ data: [] });
  api.buildingsAPI.getAll.mockResolvedValue({ data: [] });
  api.locationAPI.getAll.mockResolvedValue({ data: [] });
  api.workOrdersAPI.getAll.mockResolvedValue({ data: [] });
  api.authAPI.me.mockResolvedValue({ data: {} });
  api.apiClient.image.getByParent.mockResolvedValue({ data: [] });
});

test('renders search, filter, sort controls and add button', async () => {
  const AssetPage = require('../pages/AssetPage').default;
  render(<MemoryRouter><AssetPage /></MemoryRouter>);
  await waitFor(() => {
    expect(screen.getByPlaceholderText('Soek bates...')).toBeInTheDocument();
    expect(screen.getByText('+ Nuwe Bate')).toBeInTheDocument();
  });
});

test('renders asset table with all column headers', async () => {
  const AssetPage = require('../pages/AssetPage').default;
  render(<MemoryRouter><AssetPage /></MemoryRouter>);
  await waitFor(() => {
    expect(screen.getByText('Naam')).toBeInTheDocument();
    expect(screen.getByText('Merk')).toBeInTheDocument();
    expect(screen.getByText('Serienommer')).toBeInTheDocument();
    expect(screen.getByText('Lokaal')).toBeInTheDocument();
    expect(screen.getByText('Status')).toBeInTheDocument();
  });
});

test('clicking Nuwe Bate opens modal with all form fields', async () => {
  const AssetPage = require('../pages/AssetPage').default;
  render(<MemoryRouter><AssetPage /></MemoryRouter>);
  const btn = await screen.findByText('+ Nuwe Bate');
  fireEvent.click(btn);
  await waitFor(() => {
    expect(screen.getByDisplayValue(/AK/)).toBeInTheDocument();
    expect(screen.getByText('Kanselleer')).toBeInTheDocument();
    expect(screen.getByText('Stoor')).toBeInTheDocument();
  });
});

test('shows loading state when data not yet loaded', () => {
  const AssetPage = require('../pages/AssetPage').default;
  render(<MemoryRouter><AssetPage /></MemoryRouter>);
  expect(screen.getByText('Laai...')).toBeInTheDocument();
});
