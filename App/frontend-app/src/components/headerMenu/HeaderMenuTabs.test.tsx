import { render, screen, fireEvent, within } from "@testing-library/react";
import { HeaderMenuTabs } from "./HeaderMenuTabs";
import { BrowserRouter } from "react-router-dom";
import { Document, Tokens } from "../../api/apiTypes/documentResults";

// Define TestDocument type for handling nullable fields
type TestDocument = Omit<Document, 'summary' | 'keywords' | 'document_url'> & {
  summary?: string | null;
  keywords?: { [key: string]: string } | null;
  document_url?: string | null;
};

// Declare the import.meta type globally
declare global {
  interface Window {
    import: {
      meta: {
        env: {
          VITE_API_ENDPOINT: string;
        };
      };
    };
  }
}

// Mock import.meta.env
window.import = {
  meta: {
    env: {
      VITE_API_ENDPOINT: 'http://test-api-endpoint'
    }
  }
};

// Mock DocDialog component
jest.mock('../documentViewer/documentViewer', () => ({
  DocDialog: ({ onClose, document, onDocumentView }: { 
    open: boolean; 
    onClose: () => void;
    onDocumentView?: (document: Document) => void;
    document?: Document;
  }) => (
    <div 
      role="dialog" 
      aria-modal="true" 
      data-testid="doc-dialog"
    >
      <button 
        onClick={() => {
          // Simulate document view if onDocumentView is provided
          if (onDocumentView && document) {
            onDocumentView(document);
          }
          onClose();
        }}
        aria-label="View Document"
      >
        {document ? document.fileName : 'No Document'}
      </button>
    </div>
  ),
}));

// Mock react-i18next
jest.mock("react-i18next", () => ({
  useTranslation: () => ({
    t: (str: string) => str,
  }),
}));

// Mock navigate function
const mockNavigate = jest.fn();
jest.mock("react-router-dom", () => ({
  ...jest.requireActual("react-router-dom"),
  useNavigate: () => mockNavigate,
  useLocation: () => ({
    pathname: "/search",
  }),
}));

describe("HeaderMenuTabs Component", () => {
  const mockSelectedDocuments: TestDocument[] = [
    {
      documentId: "doc1",
      fileName: "test-document-1.pdf",
      keywords: {},
      importedTime: "2024-01-01T00:00:00Z",
      processingTime: "1.5",
      mimeType: "application/pdf",
      summary: "Test document 1 summary",
      id: "id1",
      __partitionkey: "partition1",
      page_number: 1,
      document_url: "https://test.com/doc1",
    },
    {
      documentId: "doc2",
      fileName: "test-document-with-very-long-name-that-should-be-truncated.pdf",
      keywords: {},
      importedTime: "2024-01-01T00:00:00Z",
      processingTime: "1.5",
      mimeType: "application/pdf",
      summary: "Test document 2 summary",
      id: "id2",
      __partitionkey: "partition2",
      page_number: 1,
      document_url: "https://test.com/doc2",
    },
  ];

  const mockTokens: Tokens = {
    documents: "doc-token",
    images: "image-token",
    translation: "translation-token",
  };

  const mockUpdateSelectedDocuments = jest.fn();

  const defaultProps = {
    selectedDocuments: mockSelectedDocuments as Document[],
    updateSelectedDocuments: mockUpdateSelectedDocuments,
    tokens: mockTokens,
  };

  const renderComponent = (props = {}) => {
    return render(
      <BrowserRouter>
        <HeaderMenuTabs {...defaultProps} {...props} />
      </BrowserRouter>
    );
  };

  beforeEach(() => {
    jest.clearAllMocks();
  });

  afterEach(() => {
    jest.resetAllMocks();
  });

  // Original Tests
  test("shows selected documents count", () => {
    renderComponent();
    expect(screen.getByText("components.header-menu.selected-documents (2)")).toBeInTheDocument();
  });

  test("opens document menu when clicking selected documents button", () => {
    renderComponent();
    fireEvent.click(screen.getByText("components.header-menu.selected-documents (2)"));
    expect(screen.getByText("test-document-1.pdf")).toBeInTheDocument();
  });

  test("truncates long document names in menu", () => {
    renderComponent();
    fireEvent.click(screen.getByText("components.header-menu.selected-documents (2)"));
    
    // Check for truncated name
    const truncatedFileName = screen.getByText(/test-document-with-very-long-name/);
    expect(truncatedFileName.textContent).toContain("...");
  });

  test("does not render selected documents menu when no documents are selected", () => {
    renderComponent({ selectedDocuments: [] });
    
    // Ensure the menu is not rendered
    expect(screen.queryByText("components.header-menu.selected-documents")).not.toBeInTheDocument();
  });

  test("handles maximum document name length", () => {
    // Test with an extremely long file name
    const documentsWithLongName: TestDocument[] = [
      {
        ...mockSelectedDocuments[0],
        fileName: "a-very-long-document-name-that-is-extremely-long-and-should-definitely-be-truncated-beyond-the-usual-truncation-limit.pdf"
      }
    ];

    renderComponent({ selectedDocuments: documentsWithLongName as Document[] });
    
    // Click on selected documents to open menu
    fireEvent.click(screen.getByText("components.header-menu.selected-documents (1)"));
    
    // Check that the filename is truncated
    const truncatedFileName = screen.getByText(/a-very-long-document-name.*/);
    expect(truncatedFileName.textContent).toContain("...");
  });

  test("handles different mime types", () => {
    const documentsWithDifferentTypes: TestDocument[] = [
      {
        ...mockSelectedDocuments[0],
        mimeType: "image/jpeg"
      },
      {
        ...mockSelectedDocuments[1],
        mimeType: "application/docx"
      }
    ];

    renderComponent({ selectedDocuments: documentsWithDifferentTypes as Document[] });
    
    // Verify the count is correct
    expect(screen.getByText("components.header-menu.selected-documents (2)")).toBeInTheDocument();
  });

  test("handles tokens being undefined", () => {
    renderComponent({ tokens: undefined });
    
    // Ensure the component doesn't crash with undefined tokens
    expect(screen.getByText("components.header-menu.selected-documents (2)")).toBeInTheDocument();
  });

  test("opens document viewer when clicking on document", () => {
    renderComponent();
    fireEvent.click(screen.getByText("components.header-menu.selected-documents (2)"));
    
    // Click on the first document
    fireEvent.click(screen.getByText("test-document-1.pdf"));
    
    // Verify document viewer dialog is opened
    expect(screen.getByTestId("doc-dialog")).toBeInTheDocument();
  });

  test("handles document view callback", () => {
    renderComponent();
    
    // Open the menu and click a document
    fireEvent.click(screen.getByText("components.header-menu.selected-documents (2)"));
    fireEvent.click(screen.getByText("test-document-1.pdf"));
    
    // Simulate document view in dialog
    const dialog = screen.getByTestId("doc-dialog");
    const viewButton = within(dialog).getByRole("button", { name: "View Document" });
    fireEvent.click(viewButton);
    
    // Verify dialog is closed after viewing
    expect(screen.queryByTestId("doc-dialog")).not.toBeInTheDocument();
  });

  test("handles error state when tokens are invalid", () => {
    const invalidTokens: Tokens = {
      documents: "",
      images: "",
      translation: "",
    };
    
    renderComponent({ tokens: invalidTokens });
    
    // Verify component still renders without crashing
    expect(screen.getByText("components.header-menu.selected-documents (2)")).toBeInTheDocument();
  });

  test("updates UI when selectedDocuments prop changes", () => {
    const { rerender } = renderComponent();
    
    // Verify initial count
    expect(screen.getByText("components.header-menu.selected-documents (2)")).toBeInTheDocument();
    
    // Update selected documents
    const updatedDocs = [mockSelectedDocuments[0]];
    rerender(
      <BrowserRouter>
        <HeaderMenuTabs
          {...defaultProps}
          selectedDocuments={updatedDocs as Document[]}
        />
      </BrowserRouter>
    );
    
    // Verify updated count
    expect(screen.getByText("components.header-menu.selected-documents (1)")).toBeInTheDocument();
  });

  test("closes document viewer when clicking close button", () => {
    renderComponent();
    
    // Open the menu and select a document
    fireEvent.click(screen.getByText("components.header-menu.selected-documents (2)"));
    fireEvent.click(screen.getByText("test-document-1.pdf"));
    
    // Verify dialog is open
    expect(screen.getByTestId("doc-dialog")).toBeInTheDocument();
    
    // Click close button
    fireEvent.click(screen.getByRole("button", { name: "View Document" }));
    
    // Verify dialog is closed
    expect(screen.queryByTestId("doc-dialog")).not.toBeInTheDocument();
  });

  // New Additional Tests with TypeScript fixes
  test("handles document selection with null or undefined properties", () => {
    const documentsWithNullProps: TestDocument[] = [
      {
        ...mockSelectedDocuments[0],
        summary: null,
        keywords: null
      }
    ];
    
    renderComponent({ selectedDocuments: documentsWithNullProps as Document[] });
    
    // Open menu and verify it handles null/undefined props
    fireEvent.click(screen.getByText("components.header-menu.selected-documents (1)"));
    expect(screen.getByText("test-document-1.pdf")).toBeInTheDocument();
  });

  test("handles click on document with missing document_url", () => {
    const documentsWithoutUrl: TestDocument[] = [
      {
        ...mockSelectedDocuments[0],
        document_url: null
      }
    ];
    
    renderComponent({ selectedDocuments: documentsWithoutUrl as Document[] });
    
    // Open menu and click document
    fireEvent.click(screen.getByText("components.header-menu.selected-documents (1)"));
    fireEvent.click(screen.getByText("test-document-1.pdf"));
    
    // Should still open dialog
    expect(screen.getByTestId("doc-dialog")).toBeInTheDocument();
  });
});
