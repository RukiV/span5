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
    const headers = Array.from(document.querySelectorAll('th')).map((th) => th.textContent);
    expect(headers).not.toContain('ID');
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

test('filters out Gesluit tickets when ?status=open is in the URL', async () => {
  const TicketPage = require('../pages/TicketPage').default;
  const { apiClient } = require('../services/api');
  apiClient.tickets.getAll.mockResolvedValue({
    data: [
      { fault_id: 1, fault_description: 'Oop fout lekkasie', fault_priority: 'Hoog', fault_status: 'Oop', fault_type: 'Herstel', fault_reportdatetime: '2025-01-01T08:00:00' },
      { fault_id: 2, fault_description: 'Gesluit fout klaargehandel', fault_priority: 'Laag', fault_status: 'Gesluit', fault_type: 'Herstel', fault_reportdatetime: '2025-01-02T08:00:00' },
    ],
  });
  render(<MemoryRouter initialEntries={['/fault-tickets?status=open']}><TicketPage /></MemoryRouter>);
  await waitFor(() => {
    expect(screen.getByText('Oop fout lekkasie')).toBeInTheDocument();
    expect(screen.queryByText('Gesluit fout klaargehandel')).not.toBeInTheDocument();
    expect(screen.getByText('Gefiltreer: Oop foute')).toBeInTheDocument();
  });
});

test('keeps only Hoog/HIGH priority tickets when ?priority=Hoog is in the URL', async () => {
  const TicketPage = require('../pages/TicketPage').default;
  const { apiClient } = require('../services/api');
  apiClient.tickets.getAll.mockResolvedValue({
    data: [
      { fault_id: 1, fault_description: 'Hoog prio fout een', fault_priority: 'Hoog', fault_status: 'Oop', fault_type: 'Herstel', fault_reportdatetime: '2025-01-01T08:00:00' },
      { fault_id: 2, fault_description: 'HIGH prio fout twee', fault_priority: 'HIGH', fault_status: 'Oop', fault_type: 'Herstel', fault_reportdatetime: '2025-01-02T08:00:00' },
      { fault_id: 3, fault_description: 'Laag prio fout drie', fault_priority: 'Laag', fault_status: 'Oop', fault_type: 'Herstel', fault_reportdatetime: '2025-01-03T08:00:00' },
    ],
  });
  render(<MemoryRouter initialEntries={['/fault-tickets?priority=Hoog']}><TicketPage /></MemoryRouter>);
  await waitFor(() => {
    expect(screen.getByText('Hoog prio fout een')).toBeInTheDocument();
    expect(screen.getByText('HIGH prio fout twee')).toBeInTheDocument();
    expect(screen.queryByText('Laag prio fout drie')).not.toBeInTheDocument();
    expect(screen.getByText('Gefiltreer: Hoë-prioriteit foute')).toBeInTheDocument();
  });
});

test('chip clears the URL filter when × is clicked', async () => {
  const TicketPage = require('../pages/TicketPage').default;
  const { apiClient } = require('../services/api');
  apiClient.tickets.getAll.mockResolvedValue({
    data: [
      { fault_id: 3, fault_description: 'Laag prio fout drie', fault_priority: 'Laag', fault_status: 'Oop', fault_type: 'Herstel', fault_reportdatetime: '2025-01-03T08:00:00' },
    ],
  });
  render(<MemoryRouter initialEntries={['/fault-tickets?priority=Hoog']}><TicketPage /></MemoryRouter>);
  await screen.findByText('Gefiltreer: Hoë-prioriteit foute');
  // Laag-prioriteit fout bly weggesteek solank die filter aktief is
  expect(screen.queryByText('Laag prio fout drie')).not.toBeInTheDocument();
  fireEvent.click(screen.getByRole('button', { name: 'Verwyder filter' }));
  await waitFor(() => {
    expect(screen.queryByText('Gefiltreer: Hoë-prioriteit foute')).not.toBeInTheDocument();
    expect(screen.getByText('Laag prio fout drie')).toBeInTheDocument();
  });
});
