import '@testing-library/jest-dom';
import { render, screen, waitFor } from '@testing-library/react';
import React from 'react';

jest.mock('../services/api', () => ({
  __esModule: true,
  default: { get: jest.fn() },
  apiClient: { get: jest.fn(), defaults: { baseURL: '' } },
}));

jest.mock('../components/Toast/useToast', () => ({
  useToast: () => ({ showToast: mockShowToast }),
}));

const mockShowToast = jest.fn();

const { apiClient } = require('../services/api');
const { NotificationProvider, useNotificationContext } = require('../components/Notifications/NotificationContext');

function Consumer() {
  const { unreadCount } = useNotificationContext();
  return <div data-testid="count">{unreadCount}</div>;
}

describe('NotificationContext polling', () => {
  beforeEach(() => {
    sessionStorage.setItem('token', 'test-token');
    apiClient.get.mockReset();
    apiClient.get.mockResolvedValue({ data: { unread_count: 2, latest: [{ notification_id: 1 }] } });
  });

  afterEach(() => {
    sessionStorage.clear();
    jest.useRealTimers();
  });

  test("peil net een keer per monteer en loop nie op 'n herlaai-lus nie", async () => {
    render(
      <NotificationProvider>
        <Consumer />
      </NotificationProvider>
    );

    await waitFor(() => expect(screen.getByTestId('count')).toHaveTextContent('2'));

    // Gee die (foutiewe) effek-ketting kans om 'n tweede aanvanklike peiling te skiet
    await new Promise(r => setTimeout(r, 100));

    const unreadCalls = apiClient.get.mock.calls.filter(([url]) => url === '/notifications/unread');
    expect(unreadCalls.length).toBe(1);
  });

  test('laai nie wanneer daar geen token is nie', async () => {
    sessionStorage.clear();
    render(
      <NotificationProvider>
        <Consumer />
      </NotificationProvider>
    );

    await new Promise(r => setTimeout(r, 50));
    expect(apiClient.get).not.toHaveBeenCalled();
  });
});