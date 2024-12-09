import React from 'react';
import { render, screen } from '@testing-library/react';
import '@testing-library/jest-dom';
import { TableTab } from './tableTab';

// Define types here since they are not exported from the component file
interface TableData {
  row_count: number;
  column_count: number;
  cells: Cell[];
}

interface Cell {
  colIndex: number;
  colSpan: number;
  is_header: boolean;
  rowIndex: number;
  rowSpan: number;
  text: string;
}

describe('TableTab Component', () => {
  const mockTableData: TableData = {
    row_count: 3,
    column_count: 3,
    cells: [
      { rowIndex: 0, colIndex: 0, colSpan: 1, rowSpan: 1, is_header: false, text: 'Cell 1' },
      { rowIndex: 0, colIndex: 1, colSpan: 1, rowSpan: 1, is_header: false, text: 'Cell 2' },
      { rowIndex: 0, colIndex: 2, colSpan: 1, rowSpan: 1, is_header: false, text: 'Cell 3' },
      { rowIndex: 1, colIndex: 0, colSpan: 1, rowSpan: 1, is_header: false, text: 'Cell 4' },
      { rowIndex: 1, colIndex: 1, colSpan: 1, rowSpan: 1, is_header: false, text: 'Cell 5' },
      { rowIndex: 1, colIndex: 2, colSpan: 1, rowSpan: 1, is_header: false, text: 'Cell 6' },
      { rowIndex: 2, colIndex: 0, colSpan: 1, rowSpan: 1, is_header: false, text: 'Cell 7' },
      { rowIndex: 2, colIndex: 1, colSpan: 1, rowSpan: 1, is_header: false, text: 'Cell 8' },
      { rowIndex: 2, colIndex: 2, colSpan: 1, rowSpan: 1, is_header: false, text: 'Cell 9' },
    ],
  };

  it('renders the table with the correct number of rows and cells', () => {
    render(<TableTab tableValues={mockTableData} />);

    // Check the number of rows
    const rows = screen.getAllByRole('row');
    expect(rows).toHaveLength(mockTableData.row_count);

    // Check the number of cells
    const cells = screen.getAllByRole('cell');
    expect(cells).toHaveLength(mockTableData.row_count * mockTableData.column_count);

    // Verify cell content
    expect(screen.getByText('Cell 1')).toBeInTheDocument();
    expect(screen.getByText('Cell 5')).toBeInTheDocument();
    expect(screen.getByText('Cell 9')).toBeInTheDocument();
  });

  it('renders empty cells if no text is provided', () => {
    const emptyTableData: TableData = {
      row_count: 2,
      column_count: 2,
      cells: [],
    };

    render(<TableTab tableValues={emptyTableData} />);

    // Check that cells are rendered but are empty
    const cells = screen.getAllByRole('cell');
    expect(cells).toHaveLength(4);
    cells.forEach((cell) => {
      expect(cell).toHaveTextContent('');
    });
  });
});
