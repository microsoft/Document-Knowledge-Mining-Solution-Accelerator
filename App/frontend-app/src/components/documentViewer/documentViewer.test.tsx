import { render, screen, fireEvent, act } from "@testing-library/react";
import { DocDialog } from "./documentViewer";
import { Document } from "../../api/apiTypes/embedded";
import { useTranslation } from "react-i18next";

// Mocking necessary components and hooks
jest.mock("react-i18next", () => ({
    useTranslation: jest.fn(),
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

Object.defineProperty(global, "import.meta", {
    value: {
      env: {
        VITE_API_ENDPOINT: "http://mock-api-endpoint.com",
      },
    },
  });
  
describe("DocDialog", () => {
    const mockOnClose = jest.fn();
    const metadata: Document = {
        documentId: "123",
        fileName: "test.pdf",
        document_url: "",
        page_number: 1,
        keywords: {
            field1: "value1",
            field2: "value2",
        },
        importedTime: "string",      // ISO timestamp for when the document was imported
        processingTime: "string",    // Time taken to process the document
        mimeType: "string",          // MIME type of the document (e.g., PDF, DOCX)
        summary: "string",           // Summary of the document's contents
        id: "string",                // Additional identifier
        __partitionkey: "string"
    };
    const allChunkTexts = ["chunk1", "chunk2"];
    const clearChatFlag = false;

    beforeEach(() => {
        (useTranslation as jest.Mock).mockReturnValue({ t: (key: string) => key });
    });

    it("renders the document tab correctly", () => {
        render(
            <DocDialog
                metadata={metadata}
                isOpen={true}
                allChunkTexts={allChunkTexts}
                clearChatFlag={clearChatFlag}
                onClose={mockOnClose}
            />
        );
        
        // Check if IFrameComponent is rendered
        expect(screen.getByText("IFrameComponent")).toBeInTheDocument();

        // Check if DialogContentComponent is rendered
        expect(screen.getByText("DialogContentComponent")).toBeInTheDocument();
    });

    it("renders the pages tab correctly", () => {
        render(
            <DocDialog
                metadata={metadata}
                isOpen={true}
                allChunkTexts={allChunkTexts}
                clearChatFlag={clearChatFlag}
                onClose={mockOnClose}
            />
        );
        
        // Simulate selecting the "Pages" tab
        fireEvent.click(screen.getByText("Pages"));

        // Check if PagesTab is rendered
        expect(screen.getByText("PagesTab")).toBeInTheDocument();
    });

    it("renders AI Knowledge tab correctly", () => {
        render(
            <DocDialog
                metadata={metadata}
                isOpen={true}
                allChunkTexts={allChunkTexts}
                clearChatFlag={clearChatFlag}
                onClose={mockOnClose}
            />
        );

        // Simulate selecting the "AI Knowledge" tab
        fireEvent.click(screen.getByText("AI Knowledge"));

        // Check if AIKnowledgeTab is rendered
        expect(screen.getByText("AIKnowledgeTab")).toBeInTheDocument();
    });

    it("renders Page Number tab when a page is selected", () => {
        render(
            <DocDialog
                metadata={metadata}
                isOpen={true}
                allChunkTexts={allChunkTexts}
                clearChatFlag={clearChatFlag}
                onClose={mockOnClose}
            />
        );

        // Simulate selecting a page
        fireEvent.click(screen.getByText("Pages"));
        fireEvent.click(screen.getByText("Page Number"));

        // Check if PageNumberTab is rendered
        expect(screen.getByText("PageNumberTab")).toBeInTheDocument();
    });

    it("downloads the document when the download button is clicked", () => {
        render(
            <DocDialog
                metadata={metadata}
                isOpen={true}
                allChunkTexts={allChunkTexts}
                clearChatFlag={clearChatFlag}
                onClose={mockOnClose}
            />
        );

        // Mock window.open to track calls
        const openSpy = jest.spyOn(window, "open").mockImplementation(() => null);

        // Simulate download button click
        fireEvent.click(screen.getByText("Download"));

        // Ensure window.open was called with the correct URL
        expect(openSpy).toHaveBeenCalledWith(metadata.document_url, "_blank");

        openSpy.mockRestore();
    });

    it("calls onClose when the dialog is closed", () => {
        render(
            <DocDialog
                metadata={metadata}
                isOpen={true}
                allChunkTexts={allChunkTexts}
                clearChatFlag={clearChatFlag}
                onClose={mockOnClose}
            />
        );

        // Simulate closing the dialog
        fireEvent.click(screen.getByText("Close"));

        // Ensure onClose is called
        expect(mockOnClose).toHaveBeenCalled();
    });

    it("handles clearChatFlag state change", () => {
        render(
            <DocDialog
                metadata={metadata}
                isOpen={true}
                allChunkTexts={allChunkTexts}
                clearChatFlag={clearChatFlag}
                onClose={mockOnClose}
            />
        );

        // Initially, the clearChatFlag state should be false
        expect(screen.queryByText("AIKnowledgeTab")).not.toBeInTheDocument();

        // Simulate clearing the chat
        fireEvent.change(screen.getByText("Clear Chat"), { target: { value: true } });

        // Check if the AI Knowledge Tab is rendered after clearing chat
        expect(screen.getByText("AIKnowledgeTab")).toBeInTheDocument();
    });
});
