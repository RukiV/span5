import '@testing-library/jest-dom';
import { render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import React from 'react';

jest.mock('../services/api', () => ({
  __esModule: true,
  default: { get: jest.fn().mockResolvedValue({ data: {} }) },
  apiClient: { get: jest.fn().mockResolvedValue({ data: {} }), defaults: { baseURL: '' } },
}));
jest.mock('../components/Notifications/NotificationBell', () => () => <div />);
jest.mock('../components/UserProfileHeader', () => () => <div />);

let mockRights = [];
jest.mock('../hooks/useCurrentUser', () => ({
  useCurrentUser: () => ({
    user: { user_name: 'Test', user_email: 'test@test.com' },
    rights: mockRights,
    isAdmin: false,
    loading: false,
    error: null,
    hasRight: (r) => mockRights.includes(r),
  }),
}));

const RIGHTS_MAP = {
  'assets.manage':       { sidebar: 'Bates',            route: '/assets',            group: 'Fasiliteite' },
  'stock.manage':        { sidebar: 'Voorraad',         route: '/stock',             group: 'Fasiliteite' },
  'rooms.manage':        { sidebar: 'Lokale',           route: '/rooms',             group: 'Fasiliteite' },
  'buildings.manage':    { sidebar: 'Geboue',           route: '/buildings',         group: 'Fasiliteite' },
  'locations.manage':    { sidebar: 'Terreine',         route: '/terrains',          group: 'Fasiliteite' },
  'faults.view':         { sidebar: 'Foutkaartjies',    route: '/fault-tickets' },
  'room_checks.manage':  { sidebar: 'Lokaal Kontrole', route: '/room-checks-schedules' },
  'jobs.manage':         { sidebar: 'Werksopdragte',    route: '/work-orders' },
  'predictions.view':    { sidebar: 'Voorspellings',    route: '/predictions' },
  'users.manage':        { sidebar: 'Gebruikers',       route: '/users' },
};

const renderSidebar = () => {
  const Sidebar = require('../components/Sidebar').default;
  return render(
    <MemoryRouter initialEntries={['/dashboard']}>
      <Sidebar currentPath="/dashboard" onLogout={jest.fn()} />
    </MemoryRouter>
  );
};

describe('Reg-per-reg Sidebar-verifikasie', () => {
  Object.entries(RIGHTS_MAP).forEach(([right, expected]) => {
    test(`${right} → "${expected.sidebar}" verskyn NIE sonder reg`, () => {
      mockRights = Object.keys(RIGHTS_MAP).filter(r => r !== right);
      renderSidebar();
      expect(screen.queryByText(expected.sidebar)).not.toBeInTheDocument();
    });

    test(`${right} → "${expected.sidebar}" verskyn MET reg`, () => {
      mockRights = [right];
      renderSidebar();
      expect(screen.getAllByText(expected.sidebar).length).toBeGreaterThanOrEqual(1);
    });
  });

  test('Geen regte → slegs Paneelbord en Teken Uit', () => {
    mockRights = [];
    renderSidebar();
    expect(screen.getByText('Paneelbord')).toBeInTheDocument();
    expect(screen.getByText('Teken Uit')).toBeInTheDocument();
    expect(screen.queryByText('Fasiliteite')).not.toBeInTheDocument();
    expect(screen.queryByText('Foutkaartjies')).not.toBeInTheDocument();
    expect(screen.queryByText('Werksopdragte')).not.toBeInTheDocument();
    expect(screen.queryByText('Kalender')).not.toBeInTheDocument();
    expect(screen.queryByText('Voorspellings')).not.toBeInTheDocument();
    expect(screen.queryByText('Gebruikers')).not.toBeInTheDocument();
    expect(screen.queryByText('Lokaal Kontrole')).not.toBeInTheDocument();
  });

  test('Fasiliteite dropdown verskyn met ENIGE facility-reg', () => {
    mockRights = ['assets.manage'];
    renderSidebar();
    expect(screen.getByText('Fasiliteite')).toBeInTheDocument();
  });

  test('Fasiliteite dropdown verdwyn sonder alle facility-regte', () => {
    mockRights = ['faults.view', 'jobs.manage', 'calendar.view'];
    renderSidebar();
    expect(screen.queryByText('Fasiliteite')).not.toBeInTheDocument();
  });

  test('Alle regte → alle sidebar-items sigbaar', () => {
    mockRights = Object.keys(RIGHTS_MAP);
    renderSidebar();
    expect(screen.getByText('Paneelbord')).toBeInTheDocument();
    expect(screen.getByText('Fasiliteite')).toBeInTheDocument();
    expect(screen.getByText('Foutkaartjies')).toBeInTheDocument();
    expect(screen.getByText('Lokaal Kontrole')).toBeInTheDocument();
    expect(screen.getByText('Werksopdragte')).toBeInTheDocument();
    expect(screen.getByText('Voorspellings')).toBeInTheDocument();
    expect(screen.getAllByText('Gebruikers').length).toBeGreaterThanOrEqual(1);
  });
});
