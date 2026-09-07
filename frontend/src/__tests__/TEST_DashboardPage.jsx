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
  Bar: () => <div data-testid="bar-chart">Bar Chart</div>,
}));

jest.mock('chart.js', () => ({
  Chart: { register: jest.fn() },
  CategoryScale: jest.fn(),
  LinearScale: jest.fn(),
  PointElement: jest.fn(),
  LineElement: jest.fn(),
  BarElement: jest.fn(),
  Title: jest.fn(),
  Tooltip: jest.fn(),
  Legend: jest.fn(),
  ArcElement: jest.fn(),
}));

jest.mock('../hooks/useCurrentUser', () => ({
  useCurrentUser: () => ({ user: { user_name: 'Admin', role_id: 3 }, rights: ['jobs.manage','stock.manage','predictions.view','faults.view','analytics.view'], hasRight: (r) => ['jobs.manage','stock.manage','predictions.view','faults.view','analytics.view'].includes(r), isAdmin: true, loading: false, error: null }),
}));

jest.mock('../components/Toast/useToast', () => ({ useToast: () => ({ showToast: jest.fn() }) }));
jest.mock('../components/Modal/useConfirmDialog', () => ({ useConfirmDialog: () => ({ confirm: jest.fn(() => Promise.resolve(false)), dialog: null }) }));
jest.mock('../services/analyticsAPI', () => ({ analyticsAPI: { getInsights: jest.fn(() => Promise.resolve({ data: {} })), executeSuggestion: jest.fn(() => Promise.resolve({ data: { message: 'Aksie uitgevoer' } })) } }));

beforeEach(() => {
  jest.clearAllMocks();
  mockGet.mockImplementation((url) => {
    if (typeof url === 'string' && url.includes('dashboard-summary')) {
      return Promise.resolve({
        data: {
          kpis: { overdue_maintenance: 2, unassigned_high_faults: 1, overdue_jobs: 3, critical_stock: 1, replacement_suggested: 4, high_risk: 2, pending_jobs: 5, completed_jobs: 10 },
          risk_distribution: { veilig: 10, monitor: 5, vervang: 3 },
          faults_per_building: [{ building: 'Gebou A', count: 2 }],
          trend: { labels: ['01 Jan', '08 Jan'], faults_per_week: [1, 2], jobs_completed_per_week: [2, 3] },
          top_risk_assets: [],
          critical_stock_list: [],
          scope: 'all',
        },
      });
    }
    return Promise.resolve({ data: [] });
  });
});

test('renders dashboard with all KPI cards', async () => {
  const DashboardPage = require('../pages/DashboardPage').default;
  render(<MemoryRouter><DashboardPage /></MemoryRouter>);
  await waitFor(() => {
    expect(screen.getByText('Onderhoud Agterstallig')).toBeInTheDocument();
    expect(screen.getByText(/Hoë-prioriteit Foute/)).toBeInTheDocument();
    expect(screen.getByText('Werksopdragte Oortyd')).toBeInTheDocument();
    expect(screen.getByText('Kritieke Voorraad')).toBeInTheDocument();
    expect(screen.getByText('Vervanging Voorgestel')).toBeInTheDocument();
    expect(screen.getByText(/ML Hoë Risiko/)).toBeInTheDocument();
  });
});

test('renders charts', async () => {
  const DashboardPage = require('../pages/DashboardPage').default;
  render(<MemoryRouter><DashboardPage /></MemoryRouter>);
  await waitFor(() => {
    expect(screen.getByText('Foute per Gebou (30 dae)')).toBeInTheDocument();
    expect(screen.getByText('Bate Risiko-verdeling')).toBeInTheDocument();
    expect(screen.getByText(/Tendens 8 Weke/)).toBeInTheDocument();
    // Charts are mocked as bar/line
    expect(screen.getAllByTestId('bar-chart').length).toBeGreaterThan(0);
    expect(screen.getByTestId('line-chart')).toBeInTheDocument();
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
    const links = screen.getAllByText(/Bekyk.*voorspellings/i);
    expect(links.length).toBeGreaterThan(0);
    links.forEach(l => expect(l.closest('a')).toHaveAttribute('href', '/predictions'));
  });
});
