import React from 'react';
import { render, screen } from '@testing-library/react';
import { AIKnowledgeTab } from './aIKnowledgeTab';
import '@testing-library/jest-dom'; 


describe('AIKnowledgeTab Component', () => {
  it('should render "No AI entities found" when metadata is empty', () => {
    render(<AIKnowledgeTab metadata={{}} />);
    expect(screen.getByText('No AI entities found.')).toBeInTheDocument();
  });

  it('should render metadata keys and values correctly', () => {
    const mockMetadata = {
      key1: ['value1', 'value2'],
      key2: ['value3'],
    };

    render(<AIKnowledgeTab metadata={mockMetadata} />);

    // Check keys
    expect(screen.getByText('key1:')).toBeInTheDocument();
    expect(screen.getByText('key2:')).toBeInTheDocument();

    // Check values
    expect(screen.getByText('value1')).toBeInTheDocument();
    expect(screen.getByText('value2')).toBeInTheDocument();
    expect(screen.getByText('value3')).toBeInTheDocument();
  });

  it('should render an empty list if the metadata key has no values', () => {
    const mockMetadata = {
      key1: [],
    };

    render(<AIKnowledgeTab metadata={mockMetadata} />);

    expect(screen.getByText('key1:')).toBeInTheDocument();
    expect(screen.queryByText('value1')).not.toBeInTheDocument();
  });
});
