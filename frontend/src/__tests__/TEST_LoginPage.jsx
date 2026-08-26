import '@testing-library/jest-dom';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { BrowserRouter } from 'react-router-dom';
import LoginPage from '../pages/LoginPage';

jest.mock('../services/api', () => ({
  __esModule: true,
  default: { post: jest.fn(), get: jest.fn() },
  authAPI: { login: jest.fn(), me: jest.fn(), logout: jest.fn(), validateMicrosoftToken: jest.fn() },
  apiClient: { post: jest.fn(), get: jest.fn(), defaults: { baseURL: '' } },
}));

jest.mock('@azure/msal-react', () => ({
  useMsal: () => ({ instance: { loginPopup: jest.fn(), acquireTokenSilent: jest.fn(), acquireTokenPopup: jest.fn() } }),
}));

jest.mock('../authSession', () => ({
  clearAuthSession: jest.fn(), markUserActivity: jest.fn(),
}));

beforeEach(() => {
  sessionStorage.clear();
  jest.clearAllMocks();
});

test('renders username and password fields', () => {
  render(<BrowserRouter><LoginPage /></BrowserRouter>);
  expect(screen.getByLabelText('Gebruikersnaam:')).toBeInTheDocument();
  expect(screen.getByLabelText('Wagwoord:')).toBeInTheDocument();
});

test('renders submit button and MS button', () => {
  render(<BrowserRouter><LoginPage /></BrowserRouter>);
  expect(screen.getByRole('button', { name: /Teken In$/ })).toBeInTheDocument();
  expect(screen.getByText('Teken in met Microsoft')).toBeInTheDocument();
});

test('shows error message on failed login', async () => {
  const { authAPI } = require('../services/api');
  authAPI.login.mockRejectedValue({ response: { status: 401, data: { detail: 'Invalid credentials' } } });
  render(<BrowserRouter><LoginPage /></BrowserRouter>);
  fireEvent.change(screen.getByLabelText('Gebruikersnaam:'), { target: { value: 'test@test.com' } });
  fireEvent.change(screen.getByLabelText('Wagwoord:'), { target: { value: 'wrong' } });
  fireEvent.click(screen.getByRole('button', { name: /Teken In$/ }));
  await waitFor(() => {
    expect(screen.getByText(/Invalid credentials/i)).toBeInTheDocument();
  });
});
