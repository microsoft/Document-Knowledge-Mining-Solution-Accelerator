import React from 'react';
import { render, screen } from '@testing-library/react';
import '@testing-library/jest-dom';
import { PageNumberTab } from './pageNumberTab';
import { Document } from '../../api/apiTypes/embedded';
import { Image, Text } from '@fluentui/react-components';

// Mocking window.ENV object
window.ENV = {
  STORAGE_URL: 'https://storage.example.com/'
};

describe('PageNumberTab Component', () => {
  const mockDocument: Document = {
    id: 'doc-001',
    page_number: 1,
    documentId: '1',
    fileName: 'doc1.pdf',
    keywords: { topic: 'test' },
    importedTime: new Date().toISOString(),
    processingTime: '3s',
    mimeType: 'application/pdf',
    summary: 'Test summary of the document',
    __partitionkey: 'partition-1',
    document_url: 'https://example.com/doc1.pdf'
  };
  it('renders the component correctly when selectedTab is "Page Number"', () => {
    render(
      <PageNumberTab
        selectedTab="Page Number"
        selectedPageMetadata={mockDocument}
        documentUrl="https://example.com"
      />
    );
  
    // Check if the Image component is rendered with the correct src
    const imageElement = screen.getByAltText('Image of selected page number');
    expect(imageElement).toBeInTheDocument();
    expect(imageElement).toHaveAttribute(
      'src',
      'https://storage.example.com/doc1.pdf/' // updated expected value
    );
  
    // Check if the summary text is displayed correctly
    const summaryElement = screen.getByText('Test summary of the document');
    expect(summaryElement).toBeInTheDocument();
  });
  



  it('does not render the component if selectedTab is not "Page Number"', () => {
    render(
      <PageNumberTab
        selectedTab="Other Tab"
        selectedPageMetadata={mockDocument}
        documentUrl="https://example.com"
      />
    );

    // The component should return null, so nothing should be rendered
    expect(screen.queryByAltText('Image of selected page number')).not.toBeInTheDocument();
    expect(screen.queryByText('Test summary of the document')).not.toBeInTheDocument();
  });

  it('does not render if selectedPageMetadata is null', () => {
    render(
      <PageNumberTab
        selectedTab="Page Number"
        selectedPageMetadata={null}
        documentUrl="https://example.com"
      />
    );

    // The component should return null, so nothing should be rendered
    expect(screen.queryByAltText('Image of selected page number')).not.toBeInTheDocument();
  });

  it('does not render if documentUrl is undefined', () => {
    render(
      <PageNumberTab
        selectedTab="Page Number"
        selectedPageMetadata={mockDocument}
        documentUrl={undefined}
      />
    );

    // The component should return null, so nothing should be rendered
    expect(screen.queryByAltText('Image of selected page number')).not.toBeInTheDocument();
  });
});
