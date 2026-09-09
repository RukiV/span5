import '@testing-library/jest-dom';
import { render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import React from 'react';

jest.mock('../services/api', () => ({
  __esModule: true,
  default: { get: jest.fn().mockResolvedValue({ data: {} }) },
  apiClient: { get: jest.fn().mockResolvedValue({ data: {} }), defaults: { baseURL: '' } },
}));

const fullRights = ['assets.manage', 'stock.manage', 'rooms.manage', 'buildings.manage',
  'locations.manage', 'faults.view', 'jobs.manage',
  'room_checks.manage', 'ai.use', 'ai.approve',
  'calendar.view', 'predictions.view', 'users.manage',
  'roles.manage', 'rights.manage'];

jest.mock('../hooks/useCurrentUser', () => ({
  useCurrentUser: () => ({
    user: { user_name: 'Admin', user_email: 'admin@test.com' },
    rights: fullRights,
    isAdmin: true, loading: false, error: null, hasRight: (r) => fullRights.includes(r),
  }),
}));

jest.mock('../components/Notifications/NotificationBell', () => () => <div data-testid="notification-bell">Bell</div>);
jest.mock('../components/UserProfileHeader', () => () => <div data-testid="user-profile">Profile</div>);

const renderSidebar = (path = '/dashboard') => {
  const Sidebar = require('../components/Sidebar').default;
  return render(
    <MemoryRouter initialEntries={[path]}>
      <Sidebar currentPath={path} onLogout={jest.fn()} />
    </MemoryRouter>
  );
};

const renderNavbar = (path = '/dashboard') => {
  const Navbar = require('../components/Navbar').default;
  return render(
    <MemoryRouter initialEntries={[path]}>
      <Navbar />
    </MemoryRouter>
  );
};

describe('Sidebar', () => {
  test('renders FBS title and main navigation links', () => {
    renderSidebar('/dashboard');
    expect(screen.getByText('FBS')).toBeInTheDocument();
    expect(screen.getByText('Paneelbord')).toBeInTheDocument();
    expect(screen.getByText('Fasiliteite')).toBeInTheDocument();
    expect(screen.getByText('Foutkaartjies')).toBeInTheDocument();
    expect(screen.getByText('Werksopdragte')).toBeInTheDocument();
    expect(screen.getByText('Voorspellings')).toBeInTheDocument();
    expect(screen.getByText('Teken Uit')).toBeInTheDocument();
  });

  test('renders all facility dropdown items', () => {
    renderSidebar('/dashboard');
    expect(screen.getByText('Bates')).toBeInTheDocument();
    expect(screen.getByText('Voorraad')).toBeInTheDocument();
    expect(screen.getByText('Lokale')).toBeInTheDocument();
    expect(screen.getByText('Geboue')).toBeInTheDocument();
    expect(screen.getByText('Terreine')).toBeInTheDocument();
  });

  test('renders all user management items', () => {
    renderSidebar('/dashboard');
    const gebr = screen.getAllByText('Gebruikers');
    expect(gebr.length).toBeGreaterThanOrEqual(1);
    expect(screen.getByText('Rolle')).toBeInTheDocument();
    expect(screen.getByText('Regte')).toBeInTheDocument();
  });

  test('highlights active link', () => {
    renderSidebar('/fault-tickets');
    expect(screen.getByText('Foutkaartjies').closest('a')).toHaveClass('active-link');
  });
});

describe('Navbar', () => {
  test('renders page title and profile elements', () => {
    renderNavbar('/dashboard');
    expect(screen.getByText('Paneelbord')).toBeInTheDocument();
    expect(screen.getByTestId('notification-bell')).toBeInTheDocument();
    expect(screen.getByTestId('user-profile')).toBeInTheDocument();
  });

  test('displays correct title per route', () => {
    const Navbar = require('../components/Navbar').default;
    const { rerender } = render(<MemoryRouter initialEntries={['/assets']}><Navbar /></MemoryRouter>);
    expect(screen.getByText('Bestuur Bates')).toBeInTheDocument();
  });
});
