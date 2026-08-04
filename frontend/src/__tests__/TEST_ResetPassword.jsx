import '@testing-library/jest-dom';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { BrowserRouter } from 'react-router-dom';
import ResetPasswordPage from '../pages/ResetPasswordPage';

jest.mock('../services/api', () => ({
  __esModule: true,
  default: { post: jest.fn(), get: jest.fn() },
}));

const mockNavigate = jest.fn();
jest.mock('react-router-dom', () => ({
  ...jest.requireActual('react-router-dom'),
  useNavigate: () => mockNavigate,
  useSearchParams: () => [new URLSearchParams('token=abc123'), jest.fn()],
}));

beforeEach(() => { jest.clearAllMocks(); });

test('renders password fields and submit button when token present', () => {
  render(<BrowserRouter><ResetPasswordPage /></BrowserRouter>);
  expect(screen.getByPlaceholderText('Nuwe wagwoord')).toBeInTheDocument();
  expect(screen.getByPlaceholderText('Bevestig nuwe wagwoord')).toBeInTheDocument();
  const buttons = screen.getAllByRole('button', { name: /Herstel Wagwoord/i });
  expect(buttons.length).toBeGreaterThanOrEqual(1);
  expect(screen.getByText('Terug na aanmelding')).toBeInTheDocument();
});

test('shows error when passwords do not match', async () => {
  render(<BrowserRouter><ResetPasswordPage /></BrowserRouter>);
  fireEvent.change(screen.getByPlaceholderText('Nuwe wagwoord'), { target: { value: 'Pass@123' } });
  fireEvent.change(screen.getByPlaceholderText('Bevestig nuwe wagwoord'), { target: { value: 'Different@123' } });
  fireEvent.click(screen.getAllByRole('button', { name: /Herstel Wagwoord/i })[0]);
  await waitFor(() => {
    expect(screen.getByText(/Wagwoorde stem nie ooreen nie/i)).toBeInTheDocument();
  });
});

test('shows error when password too short', async () => {
  render(<BrowserRouter><ResetPasswordPage /></BrowserRouter>);
  fireEvent.change(screen.getByPlaceholderText('Nuwe wagwoord'), { target: { value: 'Ab1@' } });
  fireEvent.change(screen.getByPlaceholderText('Bevestig nuwe wagwoord'), { target: { value: 'Ab1@' } });
  fireEvent.click(screen.getAllByRole('button', { name: /Herstel Wagwoord/i })[0]);
  await waitFor(() => {
    expect(screen.getByText(/ten minste 8 karakters/i)).toBeInTheDocument();
  });
});

test('shows success and redirects after reset', async () => {
  const api = require('../services/api').default;
  api.post.mockResolvedValue({});
  jest.useFakeTimers();
  render(<BrowserRouter><ResetPasswordPage /></BrowserRouter>);
  fireEvent.change(screen.getByPlaceholderText('Nuwe wagwoord'), { target: { value: 'Strong@123' } });
  fireEvent.change(screen.getByPlaceholderText('Bevestig nuwe wagwoord'), { target: { value: 'Strong@123' } });
  fireEvent.click(screen.getAllByRole('button', { name: /Herstel Wagwoord/i })[0]);
  await waitFor(() => {
    expect(screen.getByText(/suksesvol herstel/i)).toBeInTheDocument();
  });
  jest.advanceTimersByTime(3000);
  expect(mockNavigate).toHaveBeenCalledWith('/login');
  jest.useRealTimers();
});

test('shows invalid link page when no token', () => {
  jest.spyOn(require('react-router-dom'), 'useSearchParams').mockReturnValue([new URLSearchParams(''), jest.fn()]);
  render(<BrowserRouter><ResetPasswordPage /></BrowserRouter>);
  expect(screen.getByText('Ongeldige Skakel')).toBeInTheDocument();
  expect(screen.getByText('Stuur weer herstel skakel')).toBeInTheDocument();
});
