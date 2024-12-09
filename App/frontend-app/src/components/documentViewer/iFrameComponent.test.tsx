import React from 'react';
import { render, screen, waitFor } from '@testing-library/react';
import { IFrameComponent } from './iFrameComponent';
import { useTranslation } from 'react-i18next';

// Mock translation function
jest.mock('react-i18next', () => ({
    useTranslation: () => ({
        t: jest.fn().mockImplementation((key) => key),
    }),
}));

describe('IFrameComponent', () => {
    const mockUrlWithSasToken = 'https://example.com/file.pdf';
    const mockIframeKey = 1;

    const renderComponent = (metadata: any, urlWithSasToken: string | undefined) => {
        render(<IFrameComponent metadata={metadata} urlWithSasToken={urlWithSasToken} iframeKey={mockIframeKey} />);
    };

    it('should render an error message when metadata or urlWithSasToken is missing', () => {
        renderComponent(null, undefined);
        expect(screen.getByText('components.iframe.error')).toBeInTheDocument();
    });

    it('should render an Excel file in iframe when mimeType is application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', () => {
        const metadata = { mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' };
        renderComponent(metadata, mockUrlWithSasToken);
        const iframe = screen.getByTitle('Excel viewer');
        expect(iframe).toBeInTheDocument();
        expect(iframe).toHaveAttribute('src', `https://view.officeapps.live.com/op/embed.aspx?src=${encodeURIComponent(mockUrlWithSasToken)}`);
    });

    it('should render a Word file in iframe when mimeType is application/vnd.openxmlformats-officedocument.wordprocessingml.document', () => {
        const metadata = { mimeType: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document' };
        renderComponent(metadata, mockUrlWithSasToken);
        const iframe = screen.getByTitle('Word viewer');
        expect(iframe).toBeInTheDocument();
    });

    it('should render a PowerPoint file in iframe when mimeType is application/vnd.openxmlformats-officedocument.presentationml.presentation', () => {
        const metadata = { mimeType: 'application/vnd.openxmlformats-officedocument.presentationml.presentation' };
        renderComponent(metadata, mockUrlWithSasToken);
        const iframe = screen.getByTitle('PowerPoint viewer');
        expect(iframe).toBeInTheDocument();
    });

    it('should render a PDF file in iframe when mimeType is application/pdf', () => {
        const metadata = { mimeType: 'application/pdf' };
        renderComponent(metadata, mockUrlWithSasToken);
        const iframe = screen.getByTitle('PDF Viewer');
        expect(iframe).toBeInTheDocument();
        expect(iframe).toHaveAttribute('src', expect.stringContaining('embed=True'));
    });

    it('should render an image when mimeType is image/jpeg, image/png, image/gif, or image/svg+xml', () => {
        const imageTypes = ['image/jpeg', 'image/png', 'image/gif', 'image/svg+xml'];
        imageTypes.forEach((mimeType) => {
            const metadata = { mimeType };
            renderComponent(metadata, mockUrlWithSasToken);
            screen.debug();
            const img = screen.findAllByAltText('Document');
            waitFor(()=>{expect(img).toBeInTheDocument()});
        });
    });

    it('should render the default iframe for unknown mimeType', () => {
        const metadata = { mimeType: 'application/unknown' };
        renderComponent(metadata, mockUrlWithSasToken);
        const iframe = screen.getByTitle('Doc visualizer');
        expect(iframe).toBeInTheDocument();
        expect(iframe).toHaveAttribute('src', mockUrlWithSasToken);
    });
});
