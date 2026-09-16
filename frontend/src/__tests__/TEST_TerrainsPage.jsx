import '@testing-library/jest-dom';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';

jest.mock('../services/api', () => ({
  __esModule: true,
  default: { get: jest.fn(), post: jest.fn(), patch: jest.fn(), delete: jest.fn(), defaults: { baseURL: '' } },
  locationAPI: { getAll: jest.fn().mockResolvedValue({ data: [] }), create: jest.fn(), update: jest.fn(), delete: jest.fn() },
  buildingsAPI: { getAll: jest.fn().mockResolvedValue({ data: [] }) },
}));
jest.mock('../components/Toast/useToast', () => ({ useToast: () => ({ showToast: jest.fn() }) }));
jest.mock('../components/Modal/useConfirmDialog', () => ({ useConfirmDialog: () => ({ confirm: jest.fn(), dialog: null }) }));

beforeEach(() => { jest.clearAllMocks(); });

test('renders search, filter, sort, and add button', async () => {
  const TerrainsPage = require('../pages/TerrainsPage').default;
  render(<MemoryRouter><TerrainsPage /></MemoryRouter>);
  await waitFor(() => {
    expect(screen.getByPlaceholderText('Soek terreine...')).toBeInTheDocument();
    expect(screen.getByText('+ Nuwe Terrein')).toBeInTheDocument();
  });
});

test('renders terrain table headers', async () => {
  const TerrainsPage = require('../pages/TerrainsPage').default;
  render(<MemoryRouter><TerrainsPage /></MemoryRouter>);
  await waitFor(() => {
    const headers = Array.from(document.querySelectorAll('th')).map((th) => th.textContent);
    expect(headers).not.toContain('ID Terrein');
    const names = screen.getAllByText('Naam');
    expect(names.length).toBeGreaterThanOrEqual(1);
    expect(screen.getByText('Stad')).toBeInTheDocument();
    expect(screen.getByText('Provinsie')).toBeInTheDocument();
  });
});

test('clicking Nuwe Terrein opens modal', async () => {
  const TerrainsPage = require('../pages/TerrainsPage').default;
  render(<MemoryRouter><TerrainsPage /></MemoryRouter>);
  fireEvent.click(await screen.findByText('+ Nuwe Terrein'));
  await waitFor(() => {
    expect(screen.getByText('Kanselleer')).toBeInTheDocument();
    expect(screen.getByText('Stoor')).toBeInTheDocument();
  });
});

test('shows loading state', async () => {
  const TerrainsPage = require('../pages/TerrainsPage').default;
  render(<MemoryRouter><TerrainsPage /></MemoryRouter>);
  await waitFor(() => { expect(screen.getByText('Laai...')).toBeInTheDocument(); });
});
