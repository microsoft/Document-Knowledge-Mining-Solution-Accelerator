import React from 'react';
import { render, screen, fireEvent } from '@testing-library/react';
import { DialogContentComponent } from './dialogContentComponent';
import { Document } from '../../api/apiTypes/embedded';

jest.mock('react-i18next', () => ({
  useTranslation: () => ({
    t: (key: string) => key, // Return the key as the translated string
  }),
}));
describe('DialogContentComponent', () => {
  const metadata: Document = {
    documentId: 'doc1',
    fileName: 'example.pdf',
    keywords: { topic: 'test' },
    importedTime: '2024-11-28T10:00:00Z',
    processingTime: '10s',
    mimeType: 'application/pdf',
    summary: 'This is a test summary.\nSecond line of summary.',
    id: '1',
    __partitionkey: 'key1',
    document_url: 'https://example.com/doc1',
    page_number: null,
  };
  const allChunkTexts = [
    'This is chunk 1.',
    'This is chunk 2.',
    'This is chunk 3.',
  ];
  it('renders metadata summary when available', () => {
    render(
      <DialogContentComponent
        className="test-class"
        metadata={metadata}
        allChunkTexts={[]}
        isExpanded={false}
        setIsExpanded={jest.fn()}
      />
    );
    expect(screen.getByText('components.dialog-content.extractive-summary')).toBeInTheDocument();
    expect(screen.getByText('This is a test summary.')).toBeInTheDocument();
    expect(screen.getByText('Second line of summary.')).toBeInTheDocument();
  });
  it('renders chunk texts when available', () => {
    render(
      <DialogContentComponent
        className="test-class"
        metadata={metadata}
        allChunkTexts={allChunkTexts}
        isExpanded={false}
        setIsExpanded={jest.fn()}
      />
    );
    expect(screen.getByText('components.dialog-content.chunk-texts')).toBeInTheDocument();
    allChunkTexts.forEach((chunk) => {
      expect(screen.getByText(chunk.substring(0, 200) + '...')).toBeInTheDocument();
    });
  });
  it('renders full chunk text when isExpanded is true', () => {
    const mockSetIsExpanded = jest.fn();
    render(
      <DialogContentComponent
        className="test-class"
        metadata={metadata}
        allChunkTexts={allChunkTexts}
        isExpanded={true}
        setIsExpanded={mockSetIsExpanded}
      />
    );
  
    allChunkTexts.forEach((chunk) => {
      expect(screen.getByText(chunk)).toBeInTheDocument(); // Full text, no truncation
      expect(screen.queryByText(chunk.substring(0, 200) + '...')).not.toBeInTheDocument();
    });
  });
  it('expands chunk text on click', () => {
    const mockSetIsExpanded = jest.fn();
    render(
      <DialogContentComponent
        className="test-class"
        metadata={metadata}
        allChunkTexts={allChunkTexts}
        isExpanded={false}
        setIsExpanded={mockSetIsExpanded}
      />
    );
    const chunkElement = screen.getByText(allChunkTexts[0].substring(0, 200) + '...');
    fireEvent.click(chunkElement);
    expect(mockSetIsExpanded).toHaveBeenCalledWith(true);
  });

  it('calls setIsExpanded with correct value when clicked', () => {
    const mockSetIsExpanded = jest.fn();
  
    render(
      <DialogContentComponent
        className="test-class"
        metadata={metadata}
        allChunkTexts={allChunkTexts}
        isExpanded={false}
        setIsExpanded={mockSetIsExpanded}
      />
    );
  
    const clickableElement = screen.getByText(allChunkTexts[0].substring(0, 200) + '...');
    fireEvent.click(clickableElement);
  
    expect(mockSetIsExpanded).toHaveBeenCalledWith(true); // Ensure it toggles
  });
});