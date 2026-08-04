import '@testing-library/jest-dom';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { BrowserRouter } from 'react-router-dom';
import ForgotPasswordPage from '../pages/ForgotPasswordPage';

jest.mock('../services/api', () => ({
  __esModule: true,
  default: { post: jest.fn(), get: jest.fn() },
}));

beforeEach(() => {
  jest.clearAllMocks();
});

test('renders email input, submit button, and back link', () => {
  render(<BrowserRouter><ForgotPasswordPage /></BrowserRouter>);
  expect(screen.getByPlaceholderText('E-pos adres')).toBeInTheDocument();
  expect(screen.getByText('Stuur Herstel Skakel')).toBeInTheDocument();
  expect(screen.getByText('Terug na aanmelding')).toBeInTheDocument();
});

test('shows success message on submit', async () => {
  const api = require('../services/api').default;
  api.post.mockResolvedValue({});
  render(<BrowserRouter><ForgotPasswordPage /></BrowserRouter>);
  fireEvent.change(screen.getByPlaceholderText('E-pos adres'), { target: { value: 'test@test.com' } });
  fireEvent.click(screen.getByText('Stuur Herstel Skakel'));
  await waitFor(() => {
    expect(screen.getByText(/herstel skakel gestuur/i)).toBeInTheDocument();
  });
});

test('shows error message on API failure', async () => {
  const api = require('../services/api').default;
  api.post.mockRejectedValue(new Error('Network error'));
  render(<BrowserRouter><ForgotPasswordPage /></BrowserRouter>);
  fireEvent.change(screen.getByPlaceholderText('E-pos adres'), { target: { value: 'test@test.com' } });
  fireEvent.click(screen.getByText('Stuur Herstel Skakel'));
  await waitFor(() => {
    expect(screen.getByText(/Kon nie versoek verwerk nie/i)).toBeInTheDocument();
  });
});

test('back link navigates to /login', () => {
  render(<BrowserRouter><ForgotPasswordPage /></BrowserRouter>);
  expect(screen.getByText('Terug na aanmelding').closest('a')).toHaveAttribute('href', '/login');
});
