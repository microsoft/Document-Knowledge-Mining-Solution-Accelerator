import React from 'react';
import { render, screen, fireEvent } from '@testing-library/react';
import '@testing-library/jest-dom';
import { PagesTab } from './PagesTab';
import { Document } from '../../api/apiTypes/embedded';
import { useTranslation } from 'react-i18next';

// Mock the useTranslation hook
jest.mock('react-i18next', () => ({
  useTranslation: () => ({
    t: (key: string) => key,
  }),
}));

describe('PagesTab Component', () => {
  const mockHandlePageClick = jest.fn();

  const mockPageMetadata: Document[] = [
    { 
      id: 'doc-001', 
      page_number: 1, 
      documentId: '1', 
      fileName: 'doc1.pdf', 
      keywords: { topic: 'test' }, 
      importedTime: new Date().toISOString(), 
      processingTime: '3s', 
      mimeType: 'application/pdf', 
      summary: 'Test document', 
      __partitionkey: 'partition-1', 
      document_url: 'https://example.com/doc1.pdf' 
    },
    { 
      id: 'doc-002', 
      page_number: 2, 
      documentId: '2', 
      fileName: 'doc2.pdf', 
      keywords: { topic: 'sample' }, 
      importedTime: new Date().toISOString(), 
      processingTime: '4s', 
      mimeType: 'application/pdf', 
      summary: 'Sample document', 
      __partitionkey: 'partition-2', 
      document_url: 'https://example.com/doc2.pdf' 
    },
  ];

  it('renders the component with page metadata', () => {
    render(<PagesTab className="test-class" pageMetadata={mockPageMetadata} handlePageClick={mockHandlePageClick} />);

    // Check that the correct number of pages is rendered
    const pageItems = screen.getAllByText(/components.pages-tab.page/i);
    expect(pageItems).toHaveLength(mockPageMetadata.length);

    // Check that page numbers are displayed correctly
    expect(screen.getByText('components.pages-tab.page 1')).toBeInTheDocument();
    expect(screen.getByText('components.pages-tab.page 2')).toBeInTheDocument();
  });

  it('renders nothing when pageMetadata is null', () => {
    render(<PagesTab className="test-class" pageMetadata={null} handlePageClick={mockHandlePageClick} />);
    
    // Ensure no page items are rendered
    expect(screen.queryByText(/components.pages-tab.page/i)).not.toBeInTheDocument();
  });

  it('calls handlePageClick when a page is clicked', () => {
    render(<PagesTab className="test-class" pageMetadata={mockPageMetadata} handlePageClick={mockHandlePageClick} />);

    // Simulate clicking on the first page
    const firstPageDiv = screen.getByText('components.pages-tab.page 1').closest('div');
    if (firstPageDiv) {
      fireEvent.click(firstPageDiv);
      expect(mockHandlePageClick).toHaveBeenCalledWith(mockPageMetadata[0]);
    }

    // Simulate clicking on the second page
    const secondPageDiv = screen.getByText('components.pages-tab.page 2').closest('div');
    if (secondPageDiv) {
      fireEvent.click(secondPageDiv);
      expect(mockHandlePageClick).toHaveBeenCalledWith(mockPageMetadata[1]);
    }
  });
});