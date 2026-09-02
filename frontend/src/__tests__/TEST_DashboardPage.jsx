import '@testing-library/jest-dom';
import { render, screen, waitFor } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';

const mockData = {
  assets: [],
  orders: [],
  tickets: [],
  audits: [],
  predictions: [],
  statusSummary: [],
};

const mockGet = jest.fn();
jest.mock('../services/api', () => {
  const createMockApi = () => ({
    getAll: mockGet, getById: mockGet, create: jest.fn(), update: jest.fn(), delete: jest.fn(),
    getRecent: jest.fn(), getStatusSummary: jest.fn().mockResolvedValue({ data: [] }),
    getHistory: jest.fn(),
  });
  return {
    __esModule: true,
    default: { get: mockGet, post: jest.fn(), patch: jest.fn(), delete: jest.fn(),
               defaults: { baseURL: '' }, assets: { getStatusSummary: jest.fn().mockResolvedValue({ data: [] }) } },
    auditsAPI: { getAll: jest.fn().mockResolvedValue({ data: [] }) },
    workOrdersAPI: { getAll: jest.fn().mockResolvedValue({ data: [] }), getRecent: jest.fn() },
    assetsAPI: { getAll: jest.fn().mockResolvedValue({ data: [] }), getStatusSummary: jest.fn().mockResolvedValue({ data: [] }) },
    ticketsAPI: { getAll: jest.fn().mockResolvedValue({ data: [] }) },
    apiClient: { get: mockGet, post: jest.fn(), defaults: { baseURL: '' },
                 assets: { getStatusSummary: jest.fn().mockResolvedValue({ data: [] }) } },
  };
});

jest.mock('react-chartjs-2', () => ({
  Line: () => <div data-testid="line-chart">Line Chart</div>,
  Doughnut: () => <div data-testid="doughnut-chart">Doughnut Chart</div>,
}));

jest.mock('chart.js', () => ({
  Chart: { register: jest.fn() },
  CategoryScale: jest.fn(),
  LinearScale: jest.fn(),
  PointElement: jest.fn(),
  LineElement: jest.fn(),
  Title: jest.fn(),
  Tooltip: jest.fn(),
  Legend: jest.fn(),
  ArcElement: jest.fn(),
}));

beforeEach(() => {
  jest.clearAllMocks();
  mockGet.mockResolvedValue({ data: [] });
});

test('renders dashboard with all KPI cards', async () => {
  const DashboardPage = require('../pages/DashboardPage').default;
  render(<MemoryRouter><DashboardPage /></MemoryRouter>);
  await waitFor(() => {
    expect(screen.getByText('Totale Bates')).toBeInTheDocument();
    expect(screen.getByText('Aktiewe Herstelwerk')).toBeInTheDocument();
    expect(screen.getByText('Voltooide Foutkaartjies')).toBeInTheDocument();
    expect(screen.getByText('Nuwe Foutkaartjies')).toBeInTheDocument();
    expect(screen.getByText('Bate Voorspellings')).toBeInTheDocument();
    expect(screen.getByText('Vervanging Voorgestel')).toBeInTheDocument();
    expect(screen.getByText('Onderhoud Agterstallig')).toBeInTheDocument();
  });
});

test('renders charts', async () => {
  const DashboardPage = require('../pages/DashboardPage').default;
  render(<MemoryRouter><DashboardPage /></MemoryRouter>);
  await waitFor(() => {
    expect(screen.getByTestId('line-chart')).toBeInTheDocument();
    expect(screen.getByTestId('doughnut-chart')).toBeInTheDocument();
  });
});

test('renders recent repairs table and activity log', async () => {
  const DashboardPage = require('../pages/DashboardPage').default;
  render(<MemoryRouter><DashboardPage /></MemoryRouter>);
  await waitFor(() => {
    expect(screen.getByText('Onlangse Herstelwerk')).toBeInTheDocument();
    expect(screen.getByText('Aktiwiteit Log')).toBeInTheDocument();
  });
});

test('shows empty state for recent repairs', async () => {
  const DashboardPage = require('../pages/DashboardPage').default;
  render(<MemoryRouter><DashboardPage /></MemoryRouter>);
  await waitFor(() => {
    expect(screen.getByText(/Geen onlangse herstelwerk beskikbaar nie/i)).toBeInTheDocument();
  });
});

test('prediction links point to /predictions', async () => {
  const DashboardPage = require('../pages/DashboardPage').default;
  render(<MemoryRouter><DashboardPage /></MemoryRouter>);
  await waitFor(() => {
    const links = screen.getAllByText(/Bekyk/i);
    expect(links.length).toBeGreaterThan(0);
    links.forEach(l => expect(l.closest('a')).toHaveAttribute('href', '/predictions'));
  });
});
