import { render, screen, waitFor } from '@testing-library/react';
import { ImageCarousel } from './imageCarousel';
import { GetImage } from '../../api/storageService'; 
import { Spinner, Image } from '@fluentui/react-components';
import { useTranslation } from 'react-i18next';

// Mock dependencies
jest.mock('../../api/storageService');
jest.mock('react-i18next', () => ({
    useTranslation: jest.fn().mockReturnValue({ t: (key: string) => key }),
}));

describe('ImageCarousel', () => {
    const mockPageMetadata = [
        {
            document_url: 'url1',
            documentId: 'doc1',
            fileName: 'file1',
            importedTime: '2024-11-01',
            processingTime: '5s',
            mimeType: 'image/png',
            summary: 'summary1',
            id: '1',
            __partitionkey: '1',
            page_number: 1,
            keywords: { keyword1: 'value1', keyword2: 'value2' }, // Adjusted to match { [key: string]: string }
        },
        {
            document_url: 'url2',
            documentId: 'doc2',
            fileName: 'file2',
            importedTime: '2024-11-02',
            processingTime: '6s',
            mimeType: 'image/jpg',
            summary: 'summary2',
            id: '2',
            __partitionkey: '2',
            page_number: 2,
            keywords: { keyword1: 'value3', keyword2: 'value4' }, // Adjusted to match { [key: string]: string }
        }
    ];

    beforeAll(() => {
        global.URL.createObjectURL = jest.fn().mockReturnValue('mocked-url');
    });

    it('should render a loading spinner when images are being loaded', () => {
        (GetImage as jest.Mock).mockResolvedValueOnce(new Blob());

        render(<ImageCarousel pageMetadata={mockPageMetadata} currentImageIndex={0} />);

        expect(screen.getByRole('progressbar')).toBeInTheDocument(); // Spinner should be displayed
    });

    it('should render the image once loading is complete', async () => {
        const mockImageUrl = 'mockImageUrl';
        (GetImage as jest.Mock).mockResolvedValueOnce(new Blob());

        render(<ImageCarousel pageMetadata={mockPageMetadata} currentImageIndex={0} />);

        // Wait for the images to be fetched and rendered
        await waitFor(() => expect(screen.getByRole('img')).toHaveAttribute('src', 'mocked-url'));
    });


    it('should render the correct image based on the currentImageIndex', async () => {
        const mockImageUrl1 = 'mockImageUrl1';
        const mockImageUrl2 = 'mockImageUrl2';

        (GetImage as jest.Mock)
            .mockResolvedValueOnce(new Blob())  // Mock first image
            .mockResolvedValueOnce(new Blob()); // Mock second image

        render(<ImageCarousel pageMetadata={mockPageMetadata} currentImageIndex={0} />);

        // Wait for first image to be loaded
        await waitFor(() => expect(screen.getByRole('img')).toHaveAttribute('src', 'mocked-url'));

        render(<ImageCarousel pageMetadata={mockPageMetadata} currentImageIndex={1} />);

        // Wait for second image to be loaded
        await waitFor(() => expect(screen.getByRole('img')).toHaveAttribute('src', 'mocked-url'));
    });

   
});
