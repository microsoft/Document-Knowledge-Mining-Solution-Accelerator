import React from "react";
import { render, screen, fireEvent } from "@testing-library/react";
import { SearchResultCard } from "./searchResultCard";
import { Document } from "../../api/apiTypes/documentResults";

import { getFileTypeIconProps } from '@fluentui/react-file-type-icons';
jest.mock("@fluentui/react-components", () => ({
  Button: ({ children, onClick }: { children: React.ReactNode; onClick: () => void }) => (
    <button onClick={onClick}>{children}</button>
  ),
  Checkbox: ({ checked, onChange }: { checked: boolean; onChange: () => void }) => (
    <input type="checkbox" checked={checked} onChange={onChange} />
  ),
  Text: ({ children }: { children: React.ReactNode }) => <span>{children}</span>,
}));

jest.mock("@fluentui/react-tags-preview", () => ({
  Tag: ({ children }: { children: React.ReactNode }) => <div>{children}</div>,
  TagGroup: ({ children }: { children: React.ReactNode }) => <div>{children}</div>,
}));

jest.mock("@fluentui/react-icons", () => ({
  Document48Regular: () => <span>Document Icon</span>,
}));

jest.mock("@fluentui/react-file-type-icons", () => ({
  getFileTypeIconProps: jest.fn(() => ({})),
}));

jest.mock("../documentViewer/documentViewer", () => ({
  DocDialog: ({ isOpen, onClose }: { isOpen: boolean; onClose: () => void }) =>
    isOpen ? (
      <div data-testid="doc-dialog">
        <button onClick={onClose}>Close</button>
      </div>
    ) : null,
}));

  
const mockDocument: Document = {
  documentId: "1",
  fileName: "Test Document.pdf",
  mimeType: "application/pdf",
  summary: "This is a test document used for verifying the SearchResultCard component.",
  keywords: {
    Category1: "keyword1, keyword2",
    Category2: "keyword3, keyword4",
  },
  importedTime: "2024-12-02T12:00:00Z",
  processingTime: "120",
  id: "doc-1",
  __partitionkey: "partition-1",
  page_number: 10,
  document_url: "http://example.com/test-document.pdf",
};

describe("SearchResultCard", () => {
  const mockChatWithDocument = jest.fn();
  const mockUpdateSelectedDocuments = jest.fn();

  it("renders the document details correctly", () => {
    render(
      <SearchResultCard
        document={mockDocument}
        coverImageUrl={undefined}
        selectedDocuments={[]}
        chatWithDocument={mockChatWithDocument}
        updateSelectedDocuments={mockUpdateSelectedDocuments}
      />
    );

    expect(screen.getByText(mockDocument.fileName)).toBeInTheDocument();
    expect(screen.getByText("keyword1")).toBeInTheDocument();
    expect(screen.getByText("keyword2")).toBeInTheDocument();
  });

  it("calls getFileTypeIconProps with correct file type", () => {
    render(
      <SearchResultCard
        document={mockDocument}
        coverImageUrl={undefined}
        selectedDocuments={[]}
        chatWithDocument={mockChatWithDocument}
        updateSelectedDocuments={mockUpdateSelectedDocuments}
      />
    );
  
    // Expect getFileTypeIconProps to be called with the correct file type based on the mockDocument mimeType
    expect(getFileTypeIconProps).toHaveBeenCalledWith({
      extension: "pdf",
      size: 24,
      imageFileType: "svg",
    });
  });
  

  it("calls updateSelectedDocuments when checkbox is clicked", () => {
    render(
      <SearchResultCard
        document={mockDocument}
        coverImageUrl={undefined}
        selectedDocuments={[]}
        chatWithDocument={mockChatWithDocument}
        updateSelectedDocuments={mockUpdateSelectedDocuments}
      />
    );

    const checkbox = screen.getByRole("checkbox");
    fireEvent.click(checkbox);

    expect(mockUpdateSelectedDocuments).toHaveBeenCalledWith(mockDocument);
  });

  it("opens and closes the dialog when the Details button is clicked", () => {
    render(
      <SearchResultCard
        document={mockDocument}
        coverImageUrl={undefined}
        selectedDocuments={[]}
        chatWithDocument={mockChatWithDocument}
        updateSelectedDocuments={mockUpdateSelectedDocuments}
      />
    );

    const detailsButton = screen.getByText("Details");
    fireEvent.click(detailsButton);

    expect(screen.getByTestId("doc-dialog")).toBeInTheDocument();

    const closeButton = screen.getByText("Close");
    fireEvent.click(closeButton);

    expect(screen.queryByTestId("doc-dialog")).not.toBeInTheDocument();
  });

  it("renders the truncated summary correctly", () => {
    const longSummary = "word ".repeat(40);
    render(
      <SearchResultCard
        document={{ ...mockDocument, summary: longSummary }}
        coverImageUrl={undefined}
        selectedDocuments={[]}
        chatWithDocument={mockChatWithDocument}
        updateSelectedDocuments={mockUpdateSelectedDocuments}
      />
    );

    expect(screen.getByText(/word word word/)).toHaveTextContent("...");
  });

  it("sets the checkbox checked state based on selectedDocuments", () => {
    render(
      <SearchResultCard
        document={mockDocument}
        coverImageUrl={undefined}
        selectedDocuments={[mockDocument]}
        chatWithDocument={mockChatWithDocument}
        updateSelectedDocuments={mockUpdateSelectedDocuments}
      />
    );

    const checkbox = screen.getByRole("checkbox");
    expect(checkbox).toBeChecked();
  });

  it("does not truncate the summary when it is shorter than the limit", () => {
    const shortSummary = "Short summary.";
    render(
      <SearchResultCard
        document={{ ...mockDocument, summary: shortSummary }}
        coverImageUrl={undefined}
        selectedDocuments={[]}
        chatWithDocument={mockChatWithDocument}
        updateSelectedDocuments={mockUpdateSelectedDocuments}
      />
    );

    expect(screen.getByText(shortSummary)).toBeInTheDocument();
  });
  it("calls updateSelectedDocuments when checkbox is clicked and document is not selected", () => {
    render(
      <SearchResultCard
        document={mockDocument}
        coverImageUrl={undefined}
        selectedDocuments={[]}
        chatWithDocument={mockChatWithDocument}
        updateSelectedDocuments={mockUpdateSelectedDocuments}
      />
    );
  
    const checkbox = screen.getByRole("checkbox");
    fireEvent.click(checkbox);
  
    expect(mockUpdateSelectedDocuments).toHaveBeenCalledWith(mockDocument);
  });
  it("renders the truncated summary correctly for different summary lengths", () => {
    const longSummary = "word ".repeat(50); // even longer than before
    render(
      <SearchResultCard
        document={{ ...mockDocument, summary: longSummary }}
        coverImageUrl={undefined}
        selectedDocuments={[]}
        chatWithDocument={mockChatWithDocument}
        updateSelectedDocuments={mockUpdateSelectedDocuments}
      />
    );
  
    expect(screen.getByText(/word word word/)).toHaveTextContent("...");
  });
  it("determines the correct fileType based on mimeType", () => {
    const testCases = [
      { mimeType: "application/pdf", expectedFileType: "pdf" },
      { mimeType: "application/vnd.openxmlformats-officedocument.wordprocessingml.document", expectedFileType: "docx" },
      { mimeType: "application/vnd.ms-powerpoint", expectedFileType: "pptx" },
      { mimeType: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", expectedFileType: "xlsx" },
      { mimeType: "image/jpeg", expectedFileType: "jpg" },
      { mimeType: "application/unknown", expectedFileType: "default" },
    ];
  
    testCases.forEach(({ mimeType, expectedFileType }) => {
      render(
        <SearchResultCard
          document={{ ...mockDocument, mimeType }}
          coverImageUrl={undefined}
          selectedDocuments={[]}
          chatWithDocument={mockChatWithDocument}
          updateSelectedDocuments={mockUpdateSelectedDocuments}
        />
      );
      expect(getFileTypeIconProps).toHaveBeenCalledWith({
        extension: expectedFileType,
        size: 24,
        imageFileType: "svg",
      });
    });
  });
  it("updates checkbox checked state when document is selected", () => {
    // Initial state with selectedDocuments containing the document
    render(
      <SearchResultCard
        document={mockDocument}
        coverImageUrl={undefined}
        selectedDocuments={[mockDocument]}
        chatWithDocument={mockChatWithDocument}
        updateSelectedDocuments={mockUpdateSelectedDocuments}
      />
    );
    
    const checkbox = screen.getByRole("checkbox");
    expect(checkbox).toBeChecked();
  
    // Simulate unchecking
    fireEvent.click(checkbox);
    expect(mockUpdateSelectedDocuments).toHaveBeenCalledWith(mockDocument);
  });
  
  
    
});
