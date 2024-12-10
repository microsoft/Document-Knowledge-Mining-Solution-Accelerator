import React from 'react';
import { render, screen } from '@testing-library/react';
import { IFrameComponent } from './tempIframe';
import { Document } from '../../api/apiTypes/embedded';
import '@testing-library/jest-dom';
import { useTranslation } from 'react-i18next';
import * as pdfjs from 'pdfjs-dist';

jest.mock('react-i18next', () => ({
  useTranslation: () => ({
    t: (key: string) => key,
  }),
}));

jest.mock('@react-pdf-viewer/core', () => ({
  Worker: ({ children }: { children: React.ReactNode }) => <div>{children}</div>,
  Viewer: ({ fileUrl }: { fileUrl: string }) => <div>PDF Viewer for {fileUrl}</div>,
}));

jest.mock('@react-pdf-viewer/default-layout', () => ({
  defaultLayoutPlugin: () => ({}),
}));

pdfjs.GlobalWorkerOptions.workerSrc = `//cdnjs.cloudflare.com/ajax/libs/pdf.js/${pdfjs.version}/pdf.worker.min.js`;

const mockMetadata: Document = {
  page_number: 1,
  documentId: 'doc-001',
  fileName: 'test-document.pdf',
  keywords: { topic: 'test, sample' },
  importedTime: new Date().toISOString(),
  processingTime: '5s',
  mimeType: 'application/pdf',
  summary: 'This is a test document.',
  id: 'unique-id-123',
  __partitionkey: 'partition-key-001',
  document_url: 'https://example.com/document.pdf',
};

describe('IFrameComponent', () => {
  const urlWithSasToken = mockMetadata.document_url;
  const iframeKey = 1;

  it('renders an error message when metadata is null', () => {
    render(<IFrameComponent metadata={null} urlWithSasToken={urlWithSasToken} iframeKey={iframeKey} />);
    expect(screen.getByText('components.iframe.error')).toBeInTheDocument();
  });

  it('renders an error message when urlWithSasToken is undefined', () => {
    render(<IFrameComponent metadata={mockMetadata} urlWithSasToken={undefined} iframeKey={iframeKey} />);
    expect(screen.getByText('components.iframe.error')).toBeInTheDocument();
  });

  it('renders an Excel viewer for Excel MIME type', () => {
    render(
      <IFrameComponent
        metadata={{ ...mockMetadata, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' }}
        urlWithSasToken={urlWithSasToken}
        iframeKey={iframeKey}
      />
    );
    expect(screen.getByTitle('Excel viewer')).toBeInTheDocument();
  });

  it('renders a Word viewer for Word MIME type', () => {
    render(
      <IFrameComponent
        metadata={{ ...mockMetadata, mimeType: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document' }}
        urlWithSasToken={urlWithSasToken}
        iframeKey={iframeKey}
      />
    );
    expect(screen.getByTitle('Word viewer')).toBeInTheDocument();
  });

  it('renders a PowerPoint viewer for PowerPoint MIME type', () => {
    render(
      <IFrameComponent
        metadata={{ ...mockMetadata, mimeType: 'application/vnd.openxmlformats-officedocument.presentationml.presentation' }}
        urlWithSasToken={urlWithSasToken}
        iframeKey={iframeKey}
      />
    );
    expect(screen.getByTitle('PowerPoint viewer')).toBeInTheDocument();
  });

  it('renders a PDF viewer for PDF MIME type', () => {
    render(
      <IFrameComponent
        metadata={{ ...mockMetadata, mimeType: 'application/pdf' }}
        urlWithSasToken={urlWithSasToken}
        iframeKey={iframeKey}
      />
    );
    expect(screen.getByText(`PDF Viewer for ${urlWithSasToken}`)).toBeInTheDocument();
  });

  it('renders an image viewer for image MIME type', () => {
    render(
      <IFrameComponent
        metadata={{ ...mockMetadata, mimeType: 'image/jpeg' }}
        urlWithSasToken={urlWithSasToken}
        iframeKey={iframeKey}
      />
    );
    const image = screen.getByAltText('Document image');
    expect(image).toBeInTheDocument();
    expect(image).toHaveAttribute('src', urlWithSasToken);
  });

  it('renders a default viewer for unsupported MIME type', () => {
    render(
      <IFrameComponent
        metadata={{ ...mockMetadata, mimeType: 'text/plain' }}
        urlWithSasToken={urlWithSasToken}
        iframeKey={iframeKey}
      />
    );
    expect(screen.getByTitle('Doc visualizer')).toBeInTheDocument();
  });
});
