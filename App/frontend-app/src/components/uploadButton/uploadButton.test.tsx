import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import UploadButton from "./uploadButton";
import { jest } from "@jest/globals";
import { act } from "react-dom/test-utils";
import { importDocuments } from "../../api/documentsService";

jest.mock("../../api/documentsService", () => ({
    importDocuments: jest.fn(),
}));

const testIDS = {
    FILE_DROP_AREA: "file-drop-area",
    UPLOAD_DIALOG_CLOSE_BTN: "upload-dialog-close-btn",
};

function mockData(files: any[]) {
    return {
        dataTransfer: {
            files,
            items: files.map((file) => ({
                kind: "file",
                type: file.type,
                getAsFile: () => file,
            })),
            types: ["Files"],
        },
    };
}

describe("Upload Button Component", () => {
    beforeEach(() => {
        jest.clearAllMocks();
    });

    it("On click close upload dialog should close", async () => {
        render(<UploadButton />);

        // Click event for upload button we are doing here
        const uploadDocumentsButton = await screen.findByRole("button", { name: /upload documents/i });
        fireEvent.click(uploadDocumentsButton);

        // In upload dialog
        const headingWithUploadDocumentsText = await screen.findByRole("heading", { name: /upload Documents/i });
        expect(headingWithUploadDocumentsText).toBeInTheDocument();

        const closeUploadDialogBtn = screen.getByTestId(testIDS.UPLOAD_DIALOG_CLOSE_BTN);
        fireEvent.click(closeUploadDialogBtn);

        await waitFor(() => {
            expect(screen.queryByRole("button", { name: /browse files/i })).not.toBeInTheDocument();
        });
    });

    it("input should handle File Drop correctly and upload file >", async () => {
        (importDocuments as jest.Mock).mockReturnValue({ status: "success" });

        render(<UploadButton />);

        const uploadButton = screen.getByRole("button", { name: /upload documents/i });
        fireEvent.click(uploadButton);

        await act(() => {
            const dropElement = screen.getByTestId(testIDS.FILE_DROP_AREA);
            const file = new File(["file content"], "example.pdf", { type: "application/pdf" });
            const dropEventData = mockData([file]);

            fireEvent.dragEnter(dropElement, dropEventData);

            fireEvent.drop(dropElement, dropEventData);
        });

        await waitFor(
            () => {
                expect(importDocuments).toHaveBeenCalledTimes(1);
                const fileNameElement = screen.queryByText("example.pdf");
                expect(fileNameElement).toBeInTheDocument();
                const uploadCompleteText = screen.queryByText("Upload complete");
                expect(uploadCompleteText).toBeInTheDocument();
            },
            { timeout: 3000 }
        );
    });

    it("Upload fail should handle properly", async () => {
        (importDocuments as jest.Mock).mockReturnValue({ status: "success" });

        render(<UploadButton />);

        const uploadButton = screen.getByRole("button", { name: /upload documents/i });
        fireEvent.click(uploadButton);

        await act(() => {
            const dropElement = screen.getByTestId(testIDS.FILE_DROP_AREA);
            const file = new File(["file content"], "example.pdf", { type: "application/pdf" });
            const dropEventData = mockData([file]);

            fireEvent.dragEnter(dropElement, dropEventData);

            fireEvent.drop(dropElement, dropEventData);
        });

        (importDocuments as jest.Mock).mockRejectedValueOnce(new Error("Upload document failed ") as never);

        await waitFor(
            () => {
                expect(importDocuments).toHaveBeenCalledTimes(1);
                const fileNameElement = screen.queryByText("example.pdf");
                expect(fileNameElement).toBeInTheDocument();
                const uploadCompleteText = screen.queryByText("Upload failed");
                expect(uploadCompleteText).toBeInTheDocument();
            },
            { timeout: 3000 }
        );
    });
});
