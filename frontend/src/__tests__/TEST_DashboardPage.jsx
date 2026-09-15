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
    workOrdersAPI: { getAll: jest.fn().mockResolvedValue({ data: [] }), getRecent: jest.fn(), update: jest.fn() },
    assetsAPI: { getAll: jest.fn().mockResolvedValue({ data: [] }), getStatusSummary: jest.fn().mockResolvedValue({ data: [] }) },
    ticketsAPI: { getAll: jest.fn().mockResolvedValue({ data: [] }) },
    authAPI: { me: jest.fn().mockResolvedValue({}) },
    calendarEventsAPI: {
      getRange: jest.fn().mockResolvedValue({ data: [] }),
      create: jest.fn().mockResolvedValue({ data: {} }),
      update: jest.fn().mockResolvedValue({ data: {} }),
      delete: jest.fn().mockResolvedValue({}),
    },
    apiClient: { get: mockGet, post: jest.fn(), defaults: { baseURL: '' },
                 assets: { getStatusSummary: jest.fn().mockResolvedValue({ data: [] }) } },
  };
});

jest.mock('@azure/msal-react', () => ({
  useMsal: () => ({ instance: { getActiveAccount: () => null, acquireTokenSilent: jest.fn() } }),
}));
jest.mock('../services/msalConfig', () => ({ loginRequest: {} }));

jest.mock('../hooks/useCurrentUser', () => ({
  useCurrentUser: () => ({ user: { user_name: 'Admin', role_id: 3 }, rights: ['jobs.manage','stock.manage','predictions.view','faults.view','analytics.view','calendar.view'], hasRight: (r) => ['jobs.manage','stock.manage','predictions.view','faults.view','analytics.view','calendar.view'].includes(r), isAdmin: true, loading: false, error: null }),
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

test('renders activity log', async () => {
  const DashboardPage = require('../pages/DashboardPage').default;
  render(<MemoryRouter><DashboardPage /></MemoryRouter>);
  await waitFor(() => {
    expect(screen.getByText('Aktiwiteit Log')).toBeInTheDocument();
  });
});

test('shows empty state for activity log', async () => {
  const DashboardPage = require('../pages/DashboardPage').default;
  render(<MemoryRouter><DashboardPage /></MemoryRouter>);
  await waitFor(() => {
    expect(screen.getByText(/Geen aktiwiteite om te vertoon nie/i)).toBeInTheDocument();
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

test('renders calendar section for users with calendar.view', async () => {
  const DashboardPage = require('../pages/DashboardPage').default;
  render(<MemoryRouter><DashboardPage /></MemoryRouter>);
  await waitFor(() => {
    expect(screen.getByText('Kalender')).toBeInTheDocument();
  });
});

describe('parseTimeFromText', () => {
  const { parseTimeFromText } = require('../pages/DashboardPage');

  test('parses start time only', () => {
    expect(parseTimeFromText('E-pos bestuurder om 18:00')).toEqual({
      cleanTitle: 'E-pos bestuurder',
      hours: 18,
      minutes: 0,
      endHours: null,
      endMinutes: null,
    });
  });

  test('parses start and end time with "tot"', () => {
    expect(parseTimeFromText('Vergadering om 9:00 tot 11:00')).toEqual({
      cleanTitle: 'Vergadering',
      hours: 9,
      minutes: 0,
      endHours: 11,
      endMinutes: 0,
    });
  });

  test('parses end time only with "tot"', () => {
    expect(parseTimeFromText('Taak tot 12:00')).toEqual({
      cleanTitle: 'Taak',
      hours: 8,
      minutes: 0,
      endHours: 12,
      endMinutes: 0,
    });
  });

  test('parses dash form', () => {
    expect(parseTimeFromText('Om 10:30 - 13:45 vergadering')).toEqual({
      cleanTitle: 'vergadering',
      hours: 10,
      minutes: 30,
      endHours: 13,
      endMinutes: 45,
    });
  });

  test('parses pm/nm suffix on both start and end', () => {
    expect(parseTimeFromText('Besoek om 2nm tot 4nm')).toEqual({
      cleanTitle: 'Besoek',
      hours: 14,
      minutes: 0,
      endHours: 16,
      endMinutes: 0,
    });
  });
});