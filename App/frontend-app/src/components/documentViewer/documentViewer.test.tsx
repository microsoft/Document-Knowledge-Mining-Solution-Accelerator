import React from 'react';
import { render, screen, fireEvent, act, waitFor } from '@testing-library/react';
import { DocDialog } from './documentViewer';
import { MetadataTable } from './metadataTable';
import { IFrameComponent } from './iFrameComponent';
import { DialogContentComponent } from './dialogContentComponent';
import { PagesTab } from './PagesTab';
import { PageNumberTab } from './pageNumberTab';
import { AIKnowledgeTab } from './aIKnowledgeTab';
import { DialogTitleBar } from './dialogTitleBar';

import { Document } from '../../api/apiTypes/embedded';
import { defaultCalendarStrings } from '@fluentui/react';

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

Object.defineProperty(global, "import.meta", {
  value: {
    env: {
      VITE_API_ENDPOINT: "http://mock-api-endpoint.com",
    },
  },
});


// Mock Fluent UI Components
jest.mock('@fluentui/react-components', () => ({
  ...jest.requireActual("@fluentui/react-components"),
  Dialog: jest.fn(({ children }) => <div data-testid="Dialog">{children}</div>),
  DialogSurface: jest.fn(({ children }) => <div data-testid="DialogSurface">{children}</div>),
  DialogBody: jest.fn(({ children }) => <div data-testid="DialogBody">{children}</div>),
}));

// Mock External Components
jest.mock('./metadataTable', () => ({
  MetadataTable: jest.fn(() => <div data-testid="MetadataTable">MetadataTable</div>),
}));

jest.mock('./iFrameComponent', () => ({
  IFrameComponent: jest.fn(() => <div data-testid="IFrameComponent">IFrameComponent</div>),
}));

jest.mock('./dialogContentComponent', () => ({
  DialogContentComponent: jest.fn(() => <div data-testid="DialogContentComponent">DialogContentComponent</div>),
}));

jest.mock('./pageNumberTab', () => ({
  pageNumberTab: jest.fn(() => <div data-testid="pageNumberTab">pageNumberTab</div>),
}));

jest.mock('./PagesTab', () => ({
  PagesTab: jest.fn((props: any) => {
    const mockMetadata: Document = {
      document_url: 'http://example.com/document',
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
    return (<div data-testid="PagesTab">
      PagesTab
      <button onClick={props.handlePageClick(mockMetadata)}>PageNumber</button>
    </div>)
  }),
}));



jest.mock('./aIKnowledgeTab', () => ({
  AIKnowledgeTab: jest.fn(() => <div data-testid="AIKnowledgeTab">AIKnowledgeTab</div>),
}));

jest.mock('./dialogTitleBar', () => ({
  DialogTitleBar: jest.fn((props: any) => <div data-testid="DialogTitleBar">
    DialogTitleBar
    <span data-testid="selectedPage" >{props.selectedPage}</span>
    <span data-testid="selectedTab">{props.selectedTab}</span>
    <button onClick={(e) => props.onTabSelect(e, { value: 'Pages' })}>PagesTab</button>
    <button onClick={(e) => props.onTabSelect(e, { value: 'AI Knowledge' })}>AI Knowledge</button>
    <button onClick={(e) => props.onTabSelect(e, { value: 'Page Number' })}>Page Number</button>
    <button onClick={(e) => props.onTabSelect(e, { value: 'PageMetadata' })}>PageMetadata</button>
    <button data-testid="return-to-document-tab" onClick={props.handleReturnToDocumentTab}>Return</button>
    <button onClick={props.handleDialogClose}>Close</button>
    <button onClick={props.downloadFile}>Download</button>
  </div>),
}));

// Mock API Calls
jest.mock('../../api/documentsService', () => ({
  downloadDocument: jest.fn(),
  getEmbedded: jest.fn(),
}));



describe('DocDialog Component', () => {

  beforeEach(() => {
    // Mock window.open
    jest.spyOn(window, 'open').mockImplementation(() => null);
  });

  afterEach(() => {
    // Restore original implementation of window.open
    jest.restoreAllMocks();
  });

  const mockMetadata: Document = {
    document_url: 'http://example.com/document',
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

  const defaultProps = {
    metadata: mockMetadata,
    isOpen: true,
    allChunkTexts: [],
    clearChatFlag: false,
    onClose: jest.fn(),
  };

  it('renders the Dialog and DialogSurface components', () => {
    render(<DocDialog {...defaultProps} />);
    expect(screen.getByTestId('Dialog')).toBeInTheDocument();
    expect(screen.getByTestId('DialogSurface')).toBeInTheDocument();
  });

  it('renders the IFrameComponent when the "Document" tab is selected', () => {
    render(<DocDialog {...defaultProps} />);
    expect(screen.getByTestId('IFrameComponent')).toBeInTheDocument();
  });

  it('renders the PagesTab when the "Pages" tab is selected', () => {
    const { rerender } = render(<DocDialog {...defaultProps} />);
    rerender(<DocDialog {...defaultProps} />);
    const button = screen.getByRole('button', { name: 'PagesTab' });
    fireEvent.click(button);
    expect(screen.getByTestId('PagesTab')).toBeInTheDocument();
  });

  it('renders the AI Knowledge when the "AI Knowledge" tab is selected', () => {
    const { rerender } = render(<DocDialog {...defaultProps} />);
    rerender(<DocDialog {...defaultProps} />);
    const button = screen.getByRole('button', { name: 'AI Knowledge' });
    fireEvent.click(button);
    expect(screen.getByTestId('AIKnowledgeTab')).toBeInTheDocument();
  });


  it('renders the PageMetadata when the "PageMetadata" tab is selected', async () => {
    const { rerender } = render(<DocDialog {...defaultProps} />);
    rerender(<DocDialog {...defaultProps} />);
    const button = screen.getByRole('button', { name: 'PageMetadata' });
    act(() => {
      fireEvent.click(button);
    });

    const selectedTab = screen.getByTestId('selectedTab');
    expect(selectedTab).toHaveTextContent('PageMetadata');

  });


  it('renders the Page Number  when a Page Number Tab is selected and Click on PageNumber', async () => {
    const { rerender } = render(<DocDialog {...defaultProps} />);
    rerender(<DocDialog {...defaultProps} />);
    const button = screen.getByRole('button', { name: 'PagesTab' });
    fireEvent.click(button);
    expect(screen.getByTestId('PagesTab')).toBeInTheDocument();

    const buttonPageNumber = screen.getByRole('button', { name: 'PageNumber' });
    act(() => {
      fireEvent.click(buttonPageNumber);
    })

    const selectedPage = screen.getByTestId('selectedPage');
    expect(selectedPage).toHaveTextContent('1');
  });

  it('calls onClose when the dialog close button is clicked', () => {
    render(<DocDialog {...defaultProps} />);
    const button = screen.getByRole('button', { name: 'Close' });
    fireEvent.click(button);
    expect(defaultProps.onClose).toHaveBeenCalled();
  });

  it('downloads the document when the download button is clicked', () => {
    render(<DocDialog {...defaultProps} />);
    const button = screen.getByRole('button', { name: 'Download' });
    fireEvent.click(button);
    expect(window.open).toHaveBeenCalledTimes(1);
    expect(window.open).toHaveBeenCalledWith("https://mock-api-endpoint.com/Documents/123/test.pdf", '_blank');
  });

  it('Retrun to Iframe Component after navigate to other tab', async () => {
    const { rerender } = render(<DocDialog {...defaultProps} />);
    rerender(<DocDialog {...defaultProps} />);
    const button = screen.getByRole('button', { name: 'PagesTab' });
    fireEvent.click(button);
    expect(screen.getByTestId('PagesTab')).toBeInTheDocument();


    const buttonReturn = screen.getByRole('button', { name: 'Return' });
    act(() => {
      fireEvent.click(buttonReturn);
    });
    expect(screen.getByTestId('IFrameComponent')).toBeInTheDocument();

  });


  it('Should not downloads the document when the metaData emtpy or null', () => {
    const compProps = { ...defaultProps, metadata: null };
    render(<DocDialog {...compProps} />);
    const button = screen.getByRole('button', { name: 'Download' });
    fireEvent.click(button);
    expect(window.open).toHaveBeenCalledTimes(0);
  });

});