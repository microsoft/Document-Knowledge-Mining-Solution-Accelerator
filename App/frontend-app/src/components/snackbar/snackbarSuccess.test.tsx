import React from "react";
import { render, screen, fireEvent } from "@testing-library/react";
import { SnackbarSuccess } from "./snackbarSuccess";
import { closeSnackbar ,CustomContentProps } from "notistack";
 
// Mock `notistack` to test `closeSnackbar` functionality
jest.mock("notistack", () => ({
    SnackbarContent: jest.fn(({ children }) => <div data-testid="mock-snackbar">{children}</div>),
    closeSnackbar: jest.fn(),
}));
 
jest.mock("react-i18next", () => ({
    useTranslation: () => ({
        t: (key: string) => key, // Mock translation function
    }),
}));
 
describe("SnackbarSuccess", () => {
    const defaultProps :CustomContentProps = {
        id: "test-snackbar",
        message: "Operation Successful",
        persist: false,
        style: {},
        anchorOrigin: { vertical: "top", horizontal: "right" }, // Valid values
        variant: "success",
        hideIconVariant: false,
        iconVariant: {
            success: "✔️",
            error: "❌",
            warning: "⚠️",
            info: "ℹ️",
        },
    };
     
    it("renders SnackbarContent with children", () => {
        render(<SnackbarSuccess {...defaultProps} />);
        const snackbar = screen.getByTestId("mock-snackbar");
        expect(snackbar).toBeInTheDocument();
    });
 
    it("renders the success Alert with the correct message", () => {
        render(<SnackbarSuccess {...defaultProps} />);
        const alert = screen.getByText("Operation Successful");
        expect(alert).toBeInTheDocument();
        expect(alert).toHaveClass("!text-green-800");
    });
 
    it("invokes closeSnackbar when the dismiss button is clicked", () => {
        render(<SnackbarSuccess {...defaultProps} />);
        const dismissButton = screen.getByLabelText("common.dismiss");
        fireEvent.click(dismissButton);
        expect(closeSnackbar).toHaveBeenCalledWith(defaultProps.id);
    });
 
    it("applies correct classes for styling", () => {
        render(<SnackbarSuccess {...defaultProps} />);
        const alert = screen.getByText("Operation Successful");
        expect(alert).toHaveClass("!bg-green-100");
        expect(alert).toHaveClass("!text-green-800");
    });
});
