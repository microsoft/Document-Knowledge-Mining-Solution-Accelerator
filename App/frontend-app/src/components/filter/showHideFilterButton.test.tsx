// src/components/filter/showHideFilterButton.test.tsx
import React from 'react';
import { render, fireEvent, screen } from '@testing-library/react';
import {FilterButton} from './showHideFilterButton';

describe('FilterButton component', () => {
  it('renders the button with the correct text', () => {
    render(<FilterButton />);
    expect(screen.getByRole('button')).toHaveTextContent('components.filter.title'); // Note: This will be the key, not the actual translation
  });

  it('calls the onFilterPress callback when clicked', () => {
    const onFilterPress = jest.fn();
    const { getByRole } = render(<FilterButton onFilterPress={onFilterPress} />);
    const button = getByRole('button');
    fireEvent.click(button);
    expect(onFilterPress).toHaveBeenCalledTimes(1);
  });

  it('renders the button with the correct icon', () => {
    render(<FilterButton />);
    const button = screen.getByRole('button');
    expect(button).toContainElement(button.querySelector('svg'));
  });


  it('renders the button with the correct class name', () => {
    render(<FilterButton />);
    expect(screen.getByRole('button')).toHaveClass('h-full');
  });
});
