import '@testing-library/jest-dom';
import { render, screen, waitFor, fireEvent } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';

jest.mock('../services/api', () => {
  const mockGet = jest.fn();
  return {
    __esModule: true,
    mockGet,
    authAPI: { me: jest.fn() },
    apiClient: { get: mockGet, post: jest.fn(), defaults: { baseURL: '' } },
    predictionsAPI: {
      getAll: jest.fn(),
      getByAsset: jest.fn(),
      getModelStatus: jest.fn(),
      retrainModel: jest.fn(),
      setModelEnabled: jest.fn(),
    },
    assetsAPI: { getAll: jest.fn() },
    locationAPI: { getAll: jest.fn() },
    buildingsAPI: { getAll: jest.fn() },
    roomsAPI: { getAll: jest.fn() },
    workOrdersAPI: { getAll: jest.fn() },
    ticketsAPI: { getAll: jest.fn() },
  };
});

jest.mock('../hooks/useCurrentUser', () => ({
  useCurrentUser: () => ({
    user: { user_name: 'Admin', role_id: 3 },
    rights: ['predictions.view', 'predictions.manage', 'jobs.manage', 'stock.manage'],
    hasRight: (r) => ['predictions.view', 'predictions.manage', 'jobs.manage', 'stock.manage'].includes(r),
    isAdmin: true,
    loading: false,
    error: null,
  }),
}));

// Chart.js resizes canvases on re-render and crashes in jsdom (getComputedStyle
// on a detached node). The charts aren't what we assert on, so stub them out.
jest.mock('react-chartjs-2', () => ({
  Line: () => <div data-testid="chart-line" />,
  Bar: () => <div data-testid="chart-bar" />,
  Doughnut: () => <div data-testid="chart-doughnut" />,
}));

jest.mock('../components/Toast/useToast', () => ({ useToast: () => ({ showToast: jest.fn() }) }));
jest.mock('../components/Modal/useConfirmDialog', () => ({ useConfirmDialog: () => ({ confirm: jest.fn(() => Promise.resolve(false)), dialog: null }) }));
jest.mock('../services/analyticsAPI', () => ({ analyticsAPI: { executeSuggestion: jest.fn(() => Promise.resolve({ data: { message: 'Aksie uitgevoer' } })) } }));

const { apiClient, authAPI, predictionsAPI, assetsAPI, locationAPI, buildingsAPI, roomsAPI, workOrdersAPI, ticketsAPI } = require('../services/api');

// 2 monsters: een gesonde bate, een met replacement_suggested + survival-velde
const MOCK_PREDICTIONS = [
  {
    asset_id: 11,
    asset_name: 'Lugversorger LV-3',
    asset_serial: 'AC-99120',
    assettype_name: 'HVAK',
    lifespan_pct_used: 62,
    lifespan_exceeded: false,
    next_maintenance_date: '2026-09-15',
    maintenance_overdue: false,
    fault_count_12mo: 1,
    replacement_threshold: 3,
    survival_model_available: true,
    survival_failure_prob_12mo: 0.18,
    survival_high_risk: false,
    survival_events_count: 120,
    survival_trained_at: '2026-07-01T10:00:00',
    replacement_suggested: false,
  },
  {
    asset_id: 12,
    asset_name: 'Boiler B-7',
    asset_serial: 'BL-40231',
    assettype_name: 'HVAK',
    lifespan_pct_used: 95,
    lifespan_exceeded: true,
    next_maintenance_date: '2026-01-10',
    maintenance_overdue: true,
    fault_count_12mo: 4,
    replacement_threshold: 3,
    survival_model_available: true,
    survival_failure_prob_12mo: 0.81,
    survival_high_risk: true,
    survival_events_count: 120,
    survival_trained_at: '2026-07-01T10:00:00',
    replacement_suggested: true,
    replacement_reason: 'Lewensduur oorskry en herhalende foute in die afgelope jaar',
  },
];

const MOCK_MODEL_STATUS = {
  available: false,
  enabled: true,
  trained_at: '2026-07-01T10:00:00',
  assets: 2,
  events: 5,
};

const EMPTY_SUMMARY = {
  kpis: { overdue_maintenance: 0, unassigned_high_faults: 0, overdue_jobs: 0, critical_stock: 0, replacement_suggested: 0, high_risk: 0 },
  risk_distribution: { veilig: 0, monitor: 0, vervang: 0 },
  faults_per_building: [],
  trend: { labels: ['Geen data'], faults_per_week: [0], jobs_completed_per_week: [0] },
  top_risk_assets: [],
  critical_stock_list: [],
  scope: 'all',
};

beforeEach(() => {
  jest.clearAllMocks();
  localStorage.clear();
  authAPI.me.mockResolvedValue({ data: { user_id: 1 } });
  apiClient.get.mockImplementation((url) => {
    if (url === '/predictions') return Promise.resolve({ data: MOCK_PREDICTIONS });
    if (url.includes('/analytics/dashboard-summary')) return Promise.resolve({ data: EMPTY_SUMMARY });
    return Promise.resolve({ data: [] });
  });
  apiClient.post.mockResolvedValue({ data: {} });
  predictionsAPI.getModelStatus.mockResolvedValue({ data: { ...MOCK_MODEL_STATUS } });
  predictionsAPI.retrainModel.mockResolvedValue({ data: {} });
  predictionsAPI.setModelEnabled.mockResolvedValue({ data: {} });
  assetsAPI.getAll.mockResolvedValue({ data: [] });
  locationAPI.getAll.mockResolvedValue({ data: [] });
  buildingsAPI.getAll.mockResolvedValue({ data: [] });
  roomsAPI.getAll.mockResolvedValue({ data: [] });
  workOrdersAPI.getAll.mockResolvedValue({ data: [] });
  ticketsAPI.getAll.mockResolvedValue({ data: [] });
});

const renderPage = () => {
  const PredictionsPage = require('../pages/PredictionsPage').default;
  return render(<MemoryRouter><PredictionsPage /></MemoryRouter>);
};

test('wys die standaard kolomkoppe en rye-data met lewensduur-persentasie', async () => {
  renderPage();
  await waitFor(() => expect(screen.getByText('Lugversorger LV-3')).toBeInTheDocument());
  expect(screen.getByText('Boiler B-7')).toBeInTheDocument();
  expect(screen.getByText('Bate')).toBeInTheDocument();
  expect(screen.getByText('Serienommer')).toBeInTheDocument();
  expect(screen.getByText('Tipe')).toBeInTheDocument();
  expect(screen.getByText('Lewensduur')).toBeInTheDocument();
  // lewensduur-persentasies in die selle
  expect(screen.getByText('62%')).toBeInTheDocument();
  expect(screen.getByText('95%')).toBeInTheDocument();
  // onderhoud-badges
  expect(screen.getByText('Op skedule')).toBeInTheDocument();
  expect(screen.getByText('Agterstallig')).toBeInTheDocument();
});

test('wys status-skyfie "Te min data" wanneer model beskikbaar maar nie genoeg data het nie', async () => {
  renderPage();
  await waitFor(() => expect(screen.getByText('Lugversorger LV-3')).toBeInTheDocument());
  await waitFor(() => expect(screen.getByText('Te min data')).toBeInTheDocument());
  // Ondertitel toon trained_at + bates/gebeurtenisse
  expect(screen.getByText(/2 bates \/ 5 gebeurtenisse/)).toBeInTheDocument();
});

test('"Herlaai model"-knop roep retrain-eindpunt aan', async () => {
  renderPage();
  await waitFor(() => expect(screen.getByText('Herlaai model')).toBeInTheDocument());
  fireEvent.click(screen.getByText('Herlaai model'));
  await waitFor(() => expect(predictionsAPI.retrainModel).toHaveBeenCalledTimes(1));
});

test('"Deaktiveer"-knop roep enabled-eindpunt aan met enabled=false', async () => {
  renderPage();
  await waitFor(() => expect(screen.getByText('Deaktiveer')).toBeInTheDocument());
  fireEvent.click(screen.getByText('Deaktiveer'));
  await waitFor(() => expect(predictionsAPI.setModelEnabled).toHaveBeenCalledWith(false));
});