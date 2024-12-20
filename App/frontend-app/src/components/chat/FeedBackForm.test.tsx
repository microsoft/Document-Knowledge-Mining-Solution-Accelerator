import { render, fireEvent, screen, waitFor } from "@testing-library/react";
import { FeedbackForm } from "./FeedbackForm";
import { PostFeedback } from "../../api/chatService";
import { useTranslation } from "react-i18next";
import { Dialog } from "@fluentui/react-components";

// Mocking external dependencies
jest.mock("../../api/chatService", () => ({
  PostFeedback: jest.fn(),
}));

jest.mock("react-i18next", () => ({
  useTranslation: jest.fn().mockReturnValue({
    t: (key: string) => key,
  }),
}));

describe("FeedbackForm", () => {
  const defaultProps = {
    history: [],
    chatOptions: {},
    sources: [],
    filterByDocumentIds: [],
    isOpen: true,
    onClose: jest.fn(),
    setSubmittedFeedback: jest.fn(),
  };

  it("renders the feedback form", () => {
    render(<FeedbackForm {...defaultProps} />);
    expect(screen.getByText("components.feedback-form.title")).toBeInTheDocument();
  });

  it("shows validation error when reason is not selected", async () => {
    render(<FeedbackForm {...defaultProps} />);
    fireEvent.click(screen.getByText("components.feedback-form.submit"));
    expect(await screen.findByText("components.feedback-form.required-fields")).toBeInTheDocument();
  });

  it("submits feedback when valid data is entered", async () => {
    const submitFeedbackMock = PostFeedback as jest.Mock;
    submitFeedbackMock.mockResolvedValueOnce({});

    render(<FeedbackForm {...defaultProps} />);

    fireEvent.click(screen.getByLabelText("Search Result")); // Selecting a reason
    fireEvent.click(screen.getByText("components.feedback-form.submit"));

    await waitFor(() => expect(submitFeedbackMock).toHaveBeenCalledTimes(1));
    expect(defaultProps.onClose).toHaveBeenCalled();
  });

  it("handles submission error gracefully", async () => {
    const submitFeedbackMock = PostFeedback as jest.Mock;
    submitFeedbackMock.mockRejectedValueOnce(new Error("Submission error"));

    render(<FeedbackForm {...defaultProps} />);

    fireEvent.click(screen.getByLabelText("Search Result"));
    fireEvent.click(screen.getByText("components.feedback-form.submit"));

    await waitFor(() => expect(screen.getByText("components.feedback-form.feedback-error")).toBeInTheDocument());
  });

//   it.only("adds and removes document URL fields dynamically", () => {
//     render(<FeedbackForm {...defaultProps} />);
//     const addButton = screen.getByLabelText("Add Circle Icon"); // Adjust based on actual button icon label
//     const removeButton = screen.getByLabelText("Subtract Circle Icon");

//     fireEvent.click(addButton); // Add a document URL field
//     expect(screen.getAllByPlaceholderText("components.feedback-form.text-area-placeholder")).toHaveLength(2);

//     fireEvent.click(removeButton); // Remove a document URL field
//     expect(screen.getAllByPlaceholderText("components.feedback-form.text-area-placeholder")).toHaveLength(1);
//   });
    it("adds and removes document URL fields dynamically", () => {
    render(<FeedbackForm {...defaultProps} />);
  
    // Use getByLabelText with the aria-labels from the Button components
    const addButton = screen.getByLabelText('Close');  // Make sure this matches the aria-label in your component
    const removeButton = screen.getByLabelText('Subtract Circle Icon');  // Same for this aria-label
  
    // Initially, there should be one document URL field
    expect(screen.getAllByPlaceholderText("components.feedback-form.text-area-placeholder")).toHaveLength(1);
  
    // Click on the add button to add a document URL field
    fireEvent.click(addButton);
  
    // Now, there should be two document URL fields
    expect(screen.getAllByPlaceholderText("components.feedback-form.text-area-placeholder")).toHaveLength(2);
  
    // Click on the remove button to remove a document URL field
    fireEvent.click(removeButton);
  
    // Now, there should be one document URL field again
    expect(screen.getAllByPlaceholderText("components.feedback-form.text-area-placeholder")).toHaveLength(1);
  });
  it("adds and removes chunk text fields dynamically", () => {
    render(<FeedbackForm {...defaultProps} />);
    const addButton = screen.getByLabelText("Add Circle Icon"); // Adjust based on actual button icon label
    const removeButton = screen.getByLabelText("Subtract Circle Icon");

    fireEvent.click(addButton); // Add a chunk text field
    expect(screen.getAllByPlaceholderText("components.feedback-form.chunk-texts-placeholder")).toHaveLength(2);

    fireEvent.click(removeButton); // Remove a chunk text field
    expect(screen.getAllByPlaceholderText("components.feedback-form.chunk-texts-placeholder")).toHaveLength(1);
  });

  it("shows advanced feedback fields when positive feedback is selected", () => {
    render(<FeedbackForm {...defaultProps} />);
    
    const checkbox = screen.getByLabelText("components.feedback-form.advanced-feedback-title");
    fireEvent.click(checkbox);

    expect(screen.getByLabelText("components.feedback-form.ground-truth-title")).toBeInTheDocument();
    expect(screen.getByLabelText("components.feedback-form.doc-urls")).toBeInTheDocument();
    expect(screen.getByLabelText("components.feedback-form.chunk-texts-title")).toBeInTheDocument();
  });

  it("calls onClose when the form is closed", () => {
    render(<FeedbackForm {...defaultProps} />);
    fireEvent.click(screen.getByLabelText("Close"));
    expect(defaultProps.onClose).toHaveBeenCalled();
  });
});
