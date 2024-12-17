import React from 'react';
import { render, fireEvent, screen } from '@testing-library/react';
import { OrderBy } from './orderBy';
import '@testing-library/jest-dom';

jest.mock('react-i18next', () => ({
  useTranslation: () => ({
    t: (key: string) => {
      const translations: {[key: string]: string} = {
        'components.order-by.sort-by': 'Sort by...',
        'components.order-by.title': 'Title',
        'components.order-by.creation-date': 'Creation Date',
        'components.order-by.last-modified': 'Last Modified',
        'components.order-by.processing-date': 'Processing Date',
        'components.order-by.source-processing-date': 'Source Processing Date',
        'components.order-by.source-last-modified': 'Source Last Modified'
      };
      return translations[key] || key;
    },
  }),
}));

describe('OrderBy component', () => {
  const onSortSelected = jest.fn();

  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('renders the select component with all options', () => {
    render(<OrderBy onSortSelected={onSortSelected} />);
    expect(screen.getByText('Sort by...')).toBeInTheDocument();
    expect(screen.getByText('Title')).toBeInTheDocument();
    expect(screen.getByText('Creation Date')).toBeInTheDocument();
    expect(screen.getByText('Last Modified')).toBeInTheDocument();
    expect(screen.getByText('Processing Date')).toBeInTheDocument();
    expect(screen.getByText('Source Processing Date')).toBeInTheDocument();
    expect(screen.getByText('Source Last Modified')).toBeInTheDocument();
  });

  const testCases = [
    { displayText: 'Title', expectedValue: 'title' },
    { displayText: 'Creation Date', expectedValue: 'creation_date' },
    { displayText: 'Last Modified', expectedValue: 'last_modified' },
    { displayText: 'Processing Date', expectedValue: 'processing_date' },
    { displayText: 'Source Processing Date', expectedValue: 'source_processing_date' },
    { displayText: 'Source Last Modified', expectedValue: 'source_last_modified' },
  ];

  testCases.forEach(({ displayText, expectedValue }) => {
    it(`calls onSortSelected with ${expectedValue} when ${displayText} is selected`, () => {
      render(<OrderBy onSortSelected={onSortSelected} />);
      const selectElement = screen.getByRole('combobox');
      
      fireEvent.change(selectElement, { 
        target: { value: displayText }
      });
      
      expect(onSortSelected).toHaveBeenCalledWith(expectedValue);
    });

    it(`updates view value to ${displayText} when selected`, () => {
      render(<OrderBy onSortSelected={onSortSelected} />);
      const selectElement = screen.getByRole('combobox');
      
      fireEvent.change(selectElement, { 
        target: { value: displayText }
      });
      
      expect(screen.getByText(displayText)).toBeInTheDocument();
    });
  });

  it('resets to default state when invalid option is selected', () => {
    render(<OrderBy onSortSelected={onSortSelected} />);
    const selectElement = screen.getByRole('combobox');
    
    fireEvent.change(selectElement, { 
      target: { value: '' }
    });
    
    expect(screen.getByText('Sort by...')).toBeInTheDocument();
    expect(onSortSelected).toHaveBeenCalledWith('');
  });

  it('has correct initial state', () => {
    render(<OrderBy onSortSelected={onSortSelected} />);
    
    expect(screen.getByText('Sort by...')).toBeInTheDocument();
    expect(onSortSelected).toHaveBeenCalledWith('');
  });
});