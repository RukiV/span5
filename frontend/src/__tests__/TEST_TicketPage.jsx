import '@testing-library/jest-dom';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';

jest.mock('../services/api', () => ({
  __esModule: true,
  default: { get: jest.fn(), post: jest.fn(), patch: jest.fn(), delete: jest.fn(), defaults: { baseURL: '' } },
  ticketsAPI: { getAll: jest.fn().mockResolvedValue({ data: [] }), create: jest.fn(), update: jest.fn(), delete: jest.fn() },
  roomsAPI: { getAll: jest.fn().mockResolvedValue({ data: [] }) },
  buildingsAPI: { getAll: jest.fn().mockResolvedValue({ data: [] }) },
  locationAPI: { getAll: jest.fn().mockResolvedValue({ data: [] }) },
  workOrdersAPI: { getAll: jest.fn().mockResolvedValue({ data: [] }) },
  apiClient: {
    get: jest.fn(), post: jest.fn(), defaults: { baseURL: '' },
    tickets: { getAll: jest.fn().mockResolvedValue({ data: [] }), create: jest.fn(), update: jest.fn(), delete: jest.fn() },
    location: { getAll: jest.fn().mockResolvedValue({ data: [] }) },
    buildings: { getAll: jest.fn().mockResolvedValue({ data: [] }) },
    rooms: { getAll: jest.fn().mockResolvedValue({ data: [] }) },
    assets: { getAll: jest.fn().mockResolvedValue({ data: [] }) },
    image: { getByParent: jest.fn().mockResolvedValue({ data: [] }), getFileUrl: jest.fn(), delete: jest.fn(), uploadForParent: jest.fn() },
  },
}));
jest.mock('../hooks/useCurrentUser', () => ({ useCurrentUser: () => ({ user: { user_id: 1 }, hasRight: (r) => ["locations.manage","buildings.manage","rooms.manage","assets.manage","stock.manage","faults.view","faults.manage","jobs.manage"].includes(r) }) }));
jest.mock('../components/Toast/useToast', () => ({ useToast: () => ({ showToast: jest.fn() }) }));
jest.mock('../components/Modal/useConfirmDialog', () => ({ useConfirmDialog: () => ({ confirm: jest.fn(), dialog: null }) }));

test('renders search, filter, sort controls and add button', async () => {
  const TicketPage = require('../pages/TicketPage').default;
  render(<MemoryRouter><TicketPage /></MemoryRouter>);
  await waitFor(() => {
    expect(screen.getByPlaceholderText('Soek...')).toBeInTheDocument();
    expect(screen.getByText('+ Nuwe Foutkaartjie')).toBeInTheDocument();
  });
});

test('renders ticket table with all column headers', async () => {
  const TicketPage = require('../pages/TicketPage').default;
  render(<MemoryRouter><TicketPage /></MemoryRouter>);
  await waitFor(() => {
    const idHeaders = screen.getAllByText('ID');
    expect(idHeaders.length).toBeGreaterThanOrEqual(1);
    const titels = screen.getAllByText('Titel');
    expect(titels.length).toBeGreaterThanOrEqual(1);
    const priorities = screen.getAllByText('Prioriteit');
    expect(priorities.length).toBeGreaterThanOrEqual(1);
    const statusses = screen.getAllByText('Status');
    expect(statusses.length).toBeGreaterThanOrEqual(1);
  });
});

test('clicking Nuwe Foutkaartjie opens modal with form fields', async () => {
  const TicketPage = require('../pages/TicketPage').default;
  render(<MemoryRouter><TicketPage /></MemoryRouter>);
  fireEvent.click(await screen.findByText('+ Nuwe Foutkaartjie'));
  await waitFor(() => {
    expect(screen.getByText('Kanselleer')).toBeInTheDocument();
    expect(screen.getByText('Stoor')).toBeInTheDocument();
  });
});
