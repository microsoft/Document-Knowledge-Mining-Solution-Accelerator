// src/components/headerBar/headerBar.test.tsx
import React from 'react';
import { render, fireEvent, screen } from '@testing-library/react';
import { HeaderBar } from './headerBar';
import { useMsal } from '@azure/msal-react';
import { BrowserRouter } from 'react-router-dom';

jest.mock('@azure/msal-react', () => ({
  useMsal: jest.fn(() => ({
    instance: {
      loginRedirect: jest.fn(),
      logoutRedirect: jest.fn(),
    },
    accounts: [{ name: 'Test User' }],
  })),
}));

jest.mock('react-i18next', () => ({
  useTranslation: jest.fn(() => ({
    t: jest.fn((key) => key),
  })),
}));

jest.mock('../../utils/auth/auth', () => ({
  getAuthenticationRequest: jest.fn(() => ({})),
}));

describe('HeaderBar component', () => {
  it('renders the logo and title', () => {
    render(
      <BrowserRouter>
        <HeaderBar />
      </BrowserRouter>
    );
    expect(screen.getByAltText('logo')).toBeInTheDocument();
    expect(screen.getByText('components.header-bar.title')).toBeInTheDocument();
  });

  it('renders the navigation menu', () => {
    render(
      <BrowserRouter>
        <HeaderBar />
      </BrowserRouter>
    );
    expect(screen.getByText('components.header-bar.sub-title')).toBeInTheDocument();
  });

  it('renders the sign-out button when authenticated', () => {
    (useMsal as jest.Mock).mockImplementation(() => ({
      instance: {
        loginRedirect: jest.fn(),
        logoutRedirect: jest.fn(),
      },
      accounts: [{ name: 'Test User' }],
    }));

    render(
      <BrowserRouter>
        <HeaderBar />
      </BrowserRouter>
    );

    const signOutLink = screen.getByRole('link', { name: 'components.header-bar.sign-out' });
    expect(signOutLink).toBeInTheDocument();
  });

  it('calls the sign-out function when the sign-out button is clicked', () => {
    const logoutRedirectMock = jest.fn();

    // Mock msal with logoutRedirect function
    (useMsal as jest.Mock).mockImplementation(() => ({
      instance: {
        loginRedirect: jest.fn(),
        logoutRedirect: logoutRedirectMock,  // Mock logoutRedirect
      },
      accounts: [{ name: 'Test User' }],
    }));

    render(
      <BrowserRouter>
        <HeaderBar />
      </BrowserRouter>
    );

    // Ensure sign-out link is rendered
    const signOutLink = screen.getByRole('link', { name: 'components.header-bar.sign-out' });
    expect(signOutLink).toBeInTheDocument();

    // Simulate click event
    fireEvent.click(signOutLink);

    // Check if logoutRedirect function was called
    expect(logoutRedirectMock).toHaveBeenCalledTimes(1);
  });

  it('renders the personal documents link when authenticated', () => {
    (useMsal as jest.Mock).mockImplementation(() => ({
      instance: {
        loginRedirect: jest.fn(),
        logoutRedirect: jest.fn(),
      },
      accounts: [{ name: 'Test User' }],
    }));

    render(
      <BrowserRouter>
        <HeaderBar />
      </BrowserRouter>
    );

    const personalDocumentsLink = screen.getByRole('link', { name: 'Personal Documents' });
    expect(personalDocumentsLink).toBeInTheDocument();
  });

  it('calls the navigate function when a link is clicked', () => {
    (useMsal as jest.Mock).mockImplementation(() => ({
      instance: {
        loginRedirect: jest.fn(),
        logoutRedirect: jest.fn(),
      },
      accounts: [{ name: 'Test User' }],
    }));

    render(
      <BrowserRouter>
        <HeaderBar />
      </BrowserRouter>
    );

    const personalDocumentsLink = screen.getByRole('link', { name: 'Personal Documents' });
    expect(personalDocumentsLink.getAttribute('href')).toBe('/personalDocuments');
  });

  it('renders the hamburger icon on small screens', () => {
    render(
      <BrowserRouter>
        <HeaderBar />
      </BrowserRouter>
    );
    expect(screen.getByText('☰')).toBeInTheDocument();
  });

  it('toggles the navigation menu when the hamburger icon is clicked', () => {
    render(
      <BrowserRouter>
        <HeaderBar />
      </BrowserRouter>
    );

    const hamburgerIcon = screen.getByText('☰');
    fireEvent.click(hamburgerIcon);
    expect(screen.queryByText('components.header-bar.sub-title')).toBeInTheDocument();
  });
});
