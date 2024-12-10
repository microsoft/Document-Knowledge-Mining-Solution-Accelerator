import { render, screen, fireEvent } from '@testing-library/react';
import { MetadataTable } from './metadataTable';
import { mapMetadataKeys } from '../../utils/mapper/metadataMapper';
import { useTranslation } from 'react-i18next';

// Mock dependencies
jest.mock('../../utils/mapper/metadataMapper');
jest.mock('react-i18next', () => ({
    useTranslation: jest.fn().mockReturnValue({ t: (key: string) => key }),
}));

describe('MetadataTable', () => {
    const mockMetadata = {
        key1: 'value1',
        key2: ['value2', 'value3'],
        key3: { subKey1: 'subValue1', subKey2: 'subValue2' },
        key4: null,
    };

    const mappedMetadata = {
        key1: 'value1',
        key2: ['value2', 'value3'],
        key3: { subKey1: 'subValue1', subKey2: 'subValue2' },
        key4: '',
    };

    beforeEach(() => {
        (mapMetadataKeys as jest.Mock).mockReturnValue(mappedMetadata);
    });

   

    it('should render expandable rows for object values', () => {
        render(<MetadataTable metadata={mockMetadata} />);

        // Check if the expandable row is rendered
        const row = screen.getByText('key3').closest('tr');
        fireEvent.click(row!); // Simulate clicking to expand

        // Check for the expanded sub-rows
        expect(screen.getByText('subKey1')).toBeInTheDocument();
        expect(screen.getByText('subValue1')).toBeInTheDocument();
        expect(screen.getByText('subKey2')).toBeInTheDocument();
        expect(screen.getByText('subValue2')).toBeInTheDocument();
    });

    it('should toggle the expanded rows when clicking expandable rows', () => {
        render(<MetadataTable metadata={mockMetadata} />);

        const row = screen.getByText('key3').closest('tr');
        fireEvent.click(row!); // First click to expand

        // Check that the sub-values appear
        expect(screen.getByText('subKey1')).toBeInTheDocument();

        fireEvent.click(row!); // Second click to collapse

        // Check that the sub-values disappear
        expect(screen.queryByText('subKey1')).not.toBeInTheDocument();
    });

    it('should not render empty rows for null or empty values', () => {
        render(<MetadataTable metadata={mockMetadata} />);

        // Ensure rows with null or empty values are not rendered
        expect(screen.queryByText('key4')).not.toBeInTheDocument();
    });

    it('should render the correct translation for table headers', () => {
        render(<MetadataTable metadata={mockMetadata} />);

        // Check that the translated headers are rendered correctly
        expect(screen.getByText('components.metadata-table.key')).toBeInTheDocument();
        expect(screen.getByText('components.metadata-table.value')).toBeInTheDocument();
    });
});
