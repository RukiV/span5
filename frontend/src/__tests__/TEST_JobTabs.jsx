import '@testing-library/jest-dom';
import { render, screen, waitFor } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import JobTabs from '../components/JobTabs';

jest.mock('../services/api', () => ({
  __esModule: true,
  default: { get: jest.fn(), post: jest.fn(), defaults: { baseURL: '' } },
  jobDraftsAPI: {
    getAll: jest.fn(), getById: jest.fn(), create: jest.fn(), approve: jest.fn(), reject: jest.fn(),
  },
  apiClient: {
    get: jest.fn(), post: jest.fn(), defaults: { baseURL: '' },
    jobDrafts: {
      getAll: jest.fn(), getById: jest.fn(), create: jest.fn(), approve: jest.fn(), reject: jest.fn(),
    },
  },
}));
jest.mock('../components/Toast/useToast', () => ({ useToast: () => ({ showToast: jest.fn() }) }));

const { apiClient } = require('../services/api');

let mockHasRight;
jest.mock('../hooks/useCurrentUser', () => ({
  useCurrentUser: () => ({ hasRight: (r) => mockHasRight(r), rights: [] }),
}));

const renderWithTabs = (path, children = <div>Inhoud</div>) =>
  render(
    <MemoryRouter initialEntries={[path]}>
      <JobTabs>{children}</JobTabs>
    </MemoryRouter>
  );

beforeEach(() => {
  jest.clearAllMocks();
  mockHasRight = (right) => right === 'ai.approve';
  apiClient.jobDrafts.getAll.mockResolvedValue({
    data: [
      { draft_id: 1, status: 'draft' },
      { draft_id: 2, status: 'draft' },
    ],
  });
});

test('renders both tabs with Werksopdragte active on /work-orders', async () => {
  renderWithTabs('/work-orders');
  const jobs = screen.getByText('Werksopdragte');
  const ai = screen.getByText('AI Konsepte');
  expect(jobs.closest('a')).toHaveClass('active');
  expect(ai.closest('a')).not.toHaveClass('active');
});

test('marks AI Konsepte active on /ai-drafts routes', async () => {
  renderWithTabs('/ai-drafts/42');
  expect(screen.getByText('AI Konsepte').closest('a')).toHaveClass('active');
  expect(screen.getByText('Werksopdragte').closest('a')).not.toHaveClass('active');
});

test('shows pending draft count badge fetched from the API', async () => {
  renderWithTabs('/work-orders');
  await waitFor(() => {
    expect(screen.getByText('2')).toBeInTheDocument();
  });
  expect(apiClient.jobDrafts.getAll).toHaveBeenCalledWith({ status_filter: 'draft' });
});

test('hides the tab bar entirely when the user lacks ai.approve', async () => {
  mockHasRight = () => false;
  renderWithTabs('/work-orders');
  expect(screen.queryByText('Werksopdragte')).not.toBeInTheDocument();
  expect(screen.queryByText('AI Konsepte')).not.toBeInTheDocument();
  // child content still renders
  expect(screen.getByText('Inhoud')).toBeInTheDocument();
});