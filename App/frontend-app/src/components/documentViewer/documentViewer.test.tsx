
import React from 'react';
import { render, screen, fireEvent, act } from '@testing-library/react';
import { DocDialog } from './documentViewer';
import { Document } from '../../api/apiTypes/embedded';
// import { useTranslation } from 'react-i18next';
// import { PagesTab } from './PagesTab';
import {PostFeedback} from '../../api/chatService';

jest.mock('react-i18next', () => ({
  useTranslation: () => ({
    t: (key: any) => key,
  }),
}));
jest.mock("react-tiff", () => ({
    TIFFViewer: () => <div>Tiff</div>,
}));
jest.mock('react-i18next', () => ({
    useTranslation: () => ({
      t: (key: any) => key, // Returns the key as the translated string
    }),
    // Trans: ({ children }) => children, // Support for <Trans> component
    initReactI18next: {
      type: '3rdParty',
      init: jest.fn(),
    },
    i18n: {
      use: jest.fn(),
      init: jest.fn(),
      t: (key: any) => key,
    },
  }));
  
describe('DocDialog Component', () => {
  const mockOnClose = jest.fn();

  const metadataMock: Document = {
    document_url : 'http://example.com/document',
    documentId: '123',
    fileName: 'test.pdf',
    page_number: 1,
    keywords: {
                field1: "value1",
                field2: "value2",
            },
    importedTime: "string",
    processingTime: "string",
    mimeType: "string",
    summary: "string",
    id: "string",                    
    __partitionkey: "string"
  };

  Object.defineProperty(global, "import.meta", {
    value: {
      env: {
        VITE_API_ENDPOINT: "http://mock-api-endpoint.com",
        },
        },
    });
  const defaultProps = {
    metadata: metadataMock,
    isOpen: true,
    allChunkTexts: ['Chunk 1', 'Chunk 2'],
    clearChatFlag: false,
    onClose: mockOnClose,
  };
  jest.mock('react-tiff', () => ({
    TIFFViewer: jest.fn(() => <div data-testid="mock-tiff-viewer">Mocked TIFF Viewer</div>),
  }));
  
jest.mock("./iFrameComponent", () => ({
    IFrameComponent: () => <div>IFrameComponent</div>,
}));

jest.mock("./dialogContentComponent", () => ({
    DialogContentComponent: () => <div>DialogContentComponent</div>,
}));

jest.mock("./PagesTab", () => ({
    PagesTab: () => <div>PagesTab</div>,
}));

jest.mock("./PageNumberTab", () => ({
    PageNumberTab: () => <div>PageNumberTab</div>,
}));

jest.mock("./MetadataTable", () => ({
    MetadataTable: () => <div>MetadataTable</div>,
}));

jest.mock("./dialogTitleBar", () => ({
    DialogTitleBar: () => <div>DialogTitleBar</div>,
}));

jest.mock("./aIKnowledgeTab", () => ({
    AIKnowledgeTab: () => <div>AIKnowledgeTab</div>,
}));

jest.mock("../../api/chatService", () => ({
  PostFeedback: jest.fn(),
}));

  it('renders correctly with initial props', () => {
    render(<DocDialog {...defaultProps} />);

    expect(screen.getByText('Document')).toBeInTheDocument();
    expect(screen.getByText('AI Knowledge')).toBeInTheDocument();
  });

  it('handles tab selection', () => {
    render(<DocDialog {...defaultProps} />);

    // Simulate clicking the "Pages" tab
    const pagesTab = screen.getByText('Pages');
    fireEvent.click(pagesTab);

    expect(screen.getByText('Pages')).toBeInTheDocument();
  });

  it('calls onClose when dialog is closed', () => {
    render(<DocDialog {...defaultProps} />);

    const closeButton = screen.getByRole('button', { name: /close/i }); // Assuming close button exists in DialogTitleBar
    fireEvent.click(closeButton);

    expect(mockOnClose).toHaveBeenCalledTimes(1);
  });

  it('handles download functionality', () => {
    window.open = jest.fn();
    render(<DocDialog {...defaultProps} />);

    const downloadButton = screen.getByRole('button', { name: /download/i }); // Assuming download button exists in DialogTitleBar
    fireEvent.click(downloadButton);

    expect(window.open).toHaveBeenCalledWith(metadataMock.document_url, '_blank');
  });

  it('handles iframe key updates on tab changes', () => {
    render(<DocDialog {...defaultProps} />);

    act(() => {
      fireEvent.click(screen.getByText('Document'));
    });

    expect(screen.getByText('Document')).toBeInTheDocument();
  });

  it('displays AI Knowledge tab correctly', () => {
    render(<DocDialog {...defaultProps} />);

    fireEvent.click(screen.getByText('AI Knowledge'));

    expect(screen.getByText('key1')).toBeInTheDocument();
    expect(screen.getByText('value1')).toBeInTheDocument();
    expect(screen.getByText('value2')).toBeInTheDocument();
  });

  it('handles page click and updates tab', () => {
    render(<DocDialog {...defaultProps} />);

    const mockPageMetadata = [{ page_number: 2 }];

    act(() => {
      fireEvent.click(screen.getByText('Pages'));
    });

    expect(screen.getByText('Pages')).toBeInTheDocument();
  });

  it('does not break when metadata is null', () => {
    render(
      <DocDialog
        {...defaultProps}
        metadata={null}
      />
    );

    expect(screen.getByText('Document')).toBeInTheDocument();
  });

  it('updates selected page correctly', () => {
    render(<DocDialog {...defaultProps} />);

    act(() => {
      fireEvent.click(screen.getByText('Page Number'));
    });

    expect(screen.getByText('Page Number')).toBeInTheDocument();
  });

  it('handles null page metadata gracefully', () => {
    render(<DocDialog {...defaultProps} />);

    fireEvent.click(screen.getByText('Page Metadata'));

    expect(screen.getByText('Page Metadata')).toBeInTheDocument();
  });

  it('handles document URL undefined scenario', () => {
    render(
      <DocDialog
        {...defaultProps}
        metadata={{ ...metadataMock, document_url: undefined }}
      />
    );

    expect(screen.getByText('Document')).toBeInTheDocument();
  });
});
