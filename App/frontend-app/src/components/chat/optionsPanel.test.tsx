// src/components/chat/optionsPanel.test.tsx

import React from 'react';
import { render, fireEvent, screen } from '@testing-library/react';
import '@testing-library/jest-dom';
import { OptionsPanel } from './optionsPanel';
import { useTranslation } from 'react-i18next';

jest.mock('react-i18next', () => ({
    useTranslation: () => ({ t: (key: string) => key }), // Mock translation function
}));

describe('OptionsPanel Component', () => {
    const mockOnSourceChange = jest.fn();
    const mockOnModelChange = jest.fn(); // Add mock for onModelChange

    const defaultProps = {
        className: 'test-class',
        onSourceChange: mockOnSourceChange,
        onModelChange: mockOnModelChange, // Add onModelChange to defaultProps
        disabled: false,
        selectedDocuments: [],
        isSticky: false,
    };

    afterEach(() => {
        jest.clearAllMocks();
    });

    // Test 1: Basic rendering
    it('renders without crashing', () => {
        render(<OptionsPanel {...defaultProps} />);
        expect(screen.getByText('Chat with documents')).toBeInTheDocument();
    });

    // Test 2: Sticky class
    it('should render with sticky class when isSticky is true', () => {
        const { container } = render(<OptionsPanel {...defaultProps} isSticky={true} />);
        expect(container.firstChild).toHaveClass('sticky');
    });

    // Test 3: Source change for "All Documents"
    it('should call onSourceChange when "All Documents" button is clicked', () => {
        render(<OptionsPanel {...defaultProps} />);
        const allDocumentsButton = screen.getByText('All Documents');
        fireEvent.click(allDocumentsButton);
        expect(mockOnSourceChange).toHaveBeenCalledWith('All Documents', 'All Documents');
    });

    // Test 4: Source change for "Selected" button with documents selected
    it('should call onSourceChange when "Selected" button is clicked', () => {
        render(<OptionsPanel {...defaultProps} selectedDocuments={[{ id: 1 }]} />);
        const selectedButton = screen.getByText(/Selected/);
        fireEvent.click(selectedButton);
        expect(mockOnSourceChange).toHaveBeenCalledWith('Selected', 'Selected');
    });

    // Test 5: Disable "Selected" button when no documents are selected
    it('should disable "Selected" button when no documents are selected', () => {
        render(<OptionsPanel {...defaultProps} />);
        const selectedButton = screen.getByText(/Selected/);
        expect(selectedButton).toBeDisabled();
    });

    // Test 6: Enable "Selected" button when documents are selected
    it('should enable "Selected" button when documents are selected', () => {
        render(<OptionsPanel {...defaultProps} selectedDocuments={[{ id: 1 }]} />);
        const selectedButton = screen.getByText(/Selected/);
        expect(selectedButton).not.toBeDisabled();
    });

    // Test 7: Button text update based on the number of selected documents
    it('should update button text based on the number of selected documents', () => {
        const { rerender } = render(<OptionsPanel {...defaultProps} selectedDocuments={[{ id: 1 }]} />);
        expect(screen.getByText('1 Selected')).toBeInTheDocument();

        rerender(<OptionsPanel {...defaultProps} selectedDocuments={[{ id: 1 }, { id: 2 }]} />);
        expect(screen.getByText('2 Selected')).toBeInTheDocument();
    });

    // Test 8: Toggle active class on button click
    it('should toggle selectedButton state on button click', () => {
        render(<OptionsPanel {...defaultProps} />);
        const allDocumentsButton = screen.getByText('All Documents');
        fireEvent.click(allDocumentsButton);
        expect(allDocumentsButton).toHaveClass('active');
    });
});