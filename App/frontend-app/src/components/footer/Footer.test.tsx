import { render, screen } from '@testing-library/react';
import { Footer } from './footer';  // Adjust the import according to your project structure
import { useTranslation } from 'react-i18next';
 
// Mock the useTranslation hook
jest.mock('react-i18next', () => ({
  useTranslation: jest.fn(),
}));
 
describe('Footer Component', () => {
  it('renders the footer with the correct copyright and current year', () => {
    // Creating a mock implementation for the `useTranslation` hook
    const mockT = (key: string, options: { year: number }) => {
      if (key === 'components.footer.copyright') {
        return `© ${options.year} My Company`;
      }
      return key;
    };
 
    // Assign the mock translation function to the mocked `useTranslation` hook
    (useTranslation as jest.Mock).mockReturnValue({ t: mockT });
 
    render(<Footer />);
 
    // Get the current year
    const currentYear = new Date().getFullYear();
 
    // Check if the translated text contains the correct copyright message with the year
    expect(screen.getByText(`© ${currentYear} My Company`)).toBeInTheDocument();
  });
});
 