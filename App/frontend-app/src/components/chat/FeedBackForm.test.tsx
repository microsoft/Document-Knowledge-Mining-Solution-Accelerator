import { render, fireEvent, screen, waitFor } from "@testing-library/react";
import { FeedbackForm } from "./FeedbackForm";
import { PostFeedback } from "../../api/chatService";
import { act } from "react-dom/test-utils";

jest.mock("../../api/chatService", () => ({
    PostFeedback: jest.fn(),
}));

jest.mock("react-i18next", () => ({
    useTranslation: () => ({
        t: (key: string) => key,
    }),
}));

describe("FeedbackForm Component", () => {
    const mockOnClose = jest.fn();
    const mockSetSubmittedFeedback = jest.fn();

    const defaultProps = {
        history: [],
        chatOptions: {},
        sources: [],
        filterByDocumentIds: [],
        isOpen: true,
        onClose: mockOnClose,
        setSubmittedFeedback: mockSetSubmittedFeedback,
    };

    it("renders the form correctly when isOpen is true", () => {
        render(<FeedbackForm {...defaultProps} />);
        expect(screen.getByText("components.feedback-form.submit")).toBeInTheDocument();
    });


    it("calls onClose when the close button is clicked", () => {
        render(<FeedbackForm {...defaultProps} />);
        const closeButton = screen.getByLabelText("Close");
        fireEvent.click(closeButton);
        expect(mockOnClose).toHaveBeenCalled();
    });

    it("displays a validation error when no reason is selected", () => {
        render(<FeedbackForm {...defaultProps} />);
        const submitButton = screen.getByText("components.feedback-form.submit");
        fireEvent.click(submitButton);
        expect(screen.getByText("components.feedback-form.required-fields")).toBeInTheDocument();
    });

    it("submits the feedback successfully when all fields are valid", async () => {
        (PostFeedback as jest.Mock).mockResolvedValueOnce(true);

        render(<FeedbackForm {...defaultProps} />);
        const radioOption = screen.getByLabelText("Search Result");
        fireEvent.click(radioOption);

        const commentInput = screen.getByPlaceholderText("components.feedback-form.leave-comment");
        fireEvent.change(commentInput, { target: { value: "This is a comment." } });

        const submitButton = screen.getByText("components.feedback-form.submit");
        fireEvent.click(submitButton);

        await waitFor(() => {
            expect(PostFeedback).toHaveBeenCalledWith(
                expect.objectContaining({
                    isPositive: false,
                    reason: "Search Result",
                    comment: "This is a comment.",
                })
            );
        });
        expect(mockOnClose).toHaveBeenCalled();
    });

    it("handles errors during feedback submission", async () => {
        (PostFeedback as jest.Mock).mockRejectedValueOnce(new Error("Network error"));

        render(<FeedbackForm {...defaultProps} />);
        const radioOption = screen.getByLabelText("Answer");
        fireEvent.click(radioOption);

        const submitButton = screen.getByText("components.feedback-form.submit");
        fireEvent.click(submitButton);

        await waitFor(() => {
            expect(screen.getByText("components.feedback-form.feedback-error")).toBeInTheDocument();
        });
    });
  

    it("updates advanced feedback fields correctly", () => {
        render(<FeedbackForm {...defaultProps} />);
        const checkbox = screen.getByLabelText("components.feedback-form.advanced-feedback-title");
        fireEvent.click(checkbox);

        const groundTruthInput = screen.getByPlaceholderText("components.feedback-form.ground-truth-placeholder") as HTMLInputElement;
        fireEvent.change(groundTruthInput, { target: { value: "Ground Truth Example" } });
        expect((groundTruthInput as HTMLInputElement).value).toBe("Ground Truth Example");

        const docURLInput = screen.getByPlaceholderText("components.feedback-form.text-area-placeholder") as HTMLInputElement;
        fireEvent.change(docURLInput, { target: { value: "http://example.com" } });
        expect((docURLInput as HTMLInputElement).value).toBe("http://example.com");

        const chunkTextInput = screen.getByPlaceholderText("components.feedback-form.chunk-texts-placeholder");
        fireEvent.change(chunkTextInput, { target: { value: "Chunk Text Example" } });
        expect((chunkTextInput as HTMLInputElement).value).toBe("Chunk Text Example");
    });

    it("Should able to add documentURLFields when addAdditionalDocumentURLField button clicked", async() => {
        render(<FeedbackForm {...defaultProps} />);

        const checkbox = screen.getByTestId('checkbox-feedbackTitle');
        expect(checkbox).not.toBeChecked();
        await act(()=>{
            fireEvent.click(checkbox);
        })
        await waitFor(()=>{
            expect(checkbox).toBeChecked();
        })

        const buttonClose = screen.getByTestId("button-close");
        act(()=>{
            fireEvent.click(buttonClose);
        })

        const textareas = screen.getAllByTestId('textareaEle');

        expect(textareas).toHaveLength(2);

    });

    it("Should able to remove documentURLFields when removeAdditionalDocumentURLField button clicked", async() => {
        render(<FeedbackForm {...defaultProps} />);

        const checkbox = screen.getByTestId('checkbox-feedbackTitle');
        expect(checkbox).not.toBeChecked();
        await act(()=>{
            fireEvent.click(checkbox);
        })
        await waitFor(()=>{
            expect(checkbox).toBeChecked();
        })

        const buttonClose = screen.getByTestId("button-close");
        act(()=>{
            fireEvent.click(buttonClose);
        })

        await waitFor(()=>{
            const buttonSubtractCircleIcon = screen.getByTestId("button-SubtractCircleIcon");

            act(()=>{
                fireEvent.click(buttonSubtractCircleIcon);
            })
        })

        const textareas = screen.getAllByTestId('textareaEle');

        expect(textareas).toHaveLength(1);

    });


    it("Should able to add chunktextFields when addAdditionalChunkTextField button clicked", async() => {
        render(<FeedbackForm {...defaultProps} />);

        const checkbox = screen.getByTestId('checkbox-feedbackTitle');
        expect(checkbox).not.toBeChecked();
        await act(()=>{
            fireEvent.click(checkbox);
        })
        await waitFor(()=>{
            expect(checkbox).toBeChecked();
        })

        const buttonaddAdditionalChunkTextField = screen.getByTestId("button-addAdditionalChunkTextField");
        act(()=>{
            fireEvent.click(buttonaddAdditionalChunkTextField);
        })

        const textareaschunkTextField = screen.getAllByTestId('textarea-chunkTextField');

        expect(textareaschunkTextField).toHaveLength(2);

    });

    it("Should able to remove chunktextFields when removeAdditionalChunkTextField button clicked", async() => {
        render(<FeedbackForm {...defaultProps} />);

        const checkbox = screen.getByTestId('checkbox-feedbackTitle');
        expect(checkbox).not.toBeChecked();
        await act(()=>{
            fireEvent.click(checkbox);
        })
        await waitFor(()=>{
            expect(checkbox).toBeChecked();
        })

        const buttonaddAdditionalChunkTextField = screen.getByTestId("button-addAdditionalChunkTextField");
        act(()=>{
            fireEvent.click(buttonaddAdditionalChunkTextField);
        })

        const textareaschunkTextField = screen.getAllByTestId('textarea-chunkTextField');

        expect(textareaschunkTextField).toHaveLength(2);

        await waitFor(()=>{
            const buttonSubtractCircleIcon = screen.getByTestId("button-removeAdditionalChunkTextField");

            act(()=>{
                fireEvent.click(buttonSubtractCircleIcon);
            })
        })

        const textareaschunkTextField1 = screen.getAllByTestId('textarea-chunkTextField');

        expect(textareaschunkTextField1).toHaveLength(1);

    });
});