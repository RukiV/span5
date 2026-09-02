import '@testing-library/jest-dom';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';

jest.mock('../services/api', () => ({
  __esModule: true,
  default: { get: jest.fn(), post: jest.fn(), patch: jest.fn(), delete: jest.fn(), defaults: { baseURL: '' } },
  apiClient: { get: jest.fn(), post: jest.fn(), defaults: { baseURL: '' },
    users: { getAll: jest.fn().mockResolvedValue({ data: [] }), getById: jest.fn(), create: jest.fn(), update: jest.fn(), delete: jest.fn() },
    roles: { getAll: jest.fn().mockResolvedValue({ data: [{ role_id: 1, role_name: 'Student' }, { role_id: 2, role_name: 'FK' }, { role_id: 3, role_name: 'Admin' }] }) },
  },
  locationAPI: { getAll: jest.fn().mockResolvedValue({ data: [] }) },
  usersAPI: { getAll: jest.fn().mockResolvedValue({ data: [] }), create: jest.fn(), update: jest.fn(), delete: jest.fn() },
}));
jest.mock('../components/Toast/useToast', () => ({ useToast: () => ({ showToast: jest.fn() }) }));
jest.mock('../components/Modal/useConfirmDialog', () => ({ useConfirmDialog: () => ({ confirm: jest.fn(), dialog: null }) }));

test('renders search, filter, sort controls and add button', async () => {
  const UsersPage = require('../pages/UsersPage').default;
  render(<MemoryRouter><UsersPage /></MemoryRouter>);
  await waitFor(() => {
    expect(screen.getByPlaceholderText('Soek op Naam of E-pos...')).toBeInTheDocument();
    expect(screen.getByText('+ Nuwe Gebruiker')).toBeInTheDocument();
  });
});

test('renders user table headers', async () => {
  const UsersPage = require('../pages/UsersPage').default;
  render(<MemoryRouter><UsersPage /></MemoryRouter>);
  await waitFor(() => {
    const names = screen.getAllByText('Naam');
    expect(names.length).toBeGreaterThanOrEqual(1);
    const epos = screen.getAllByText('E-pos');
    expect(epos.length).toBeGreaterThanOrEqual(1);
    const rol = screen.getAllByText('Rol');
    expect(rol.length).toBeGreaterThanOrEqual(1);
    const statusses = screen.getAllByText('Status');
    expect(statusses.length).toBeGreaterThanOrEqual(1);
  });
});

test('clicking Nuwe Gebruiker opens modal with all fields', async () => {
  const UsersPage = require('../pages/UsersPage').default;
  render(<MemoryRouter><UsersPage /></MemoryRouter>);
  fireEvent.click(await screen.findByText('+ Nuwe Gebruiker'));
  await waitFor(() => {
    expect(screen.getByText('Kanselleer')).toBeInTheDocument();
    expect(screen.getByText('Stoor')).toBeInTheDocument();
  });
});

test('shows loading state', async () => {
  const UsersPage = require('../pages/UsersPage').default;
  render(<MemoryRouter><UsersPage /></MemoryRouter>);
  await waitFor(() => { expect(screen.getByText(/Besig om gebruikers te laai/i)).toBeInTheDocument(); });
});
