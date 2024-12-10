import React from "react";
import { render, screen, fireEvent } from "@testing-library/react";
import "@testing-library/jest-dom";
import { DialogConfirm } from "./dialogConfirm";
import { useTranslation } from "react-i18next";


jest.mock("react-i18next", () => ({
    useTranslation: () => ({
        t: (key: string) => key, 
    }),
}));

describe("DialogConfirm Component", () => {
    const mockOnOk = jest.fn(); 
    const mockOnOpenChange = jest.fn(); 

    const defaultProps = {
        open: true,
        onOpenChange: mockOnOpenChange,
        title: "Test Dialog Title",
        children: <p>Test dialog content</p>,
        onOk: mockOnOk,
    };

    afterEach(() => {
        jest.clearAllMocks(); 
    });

    test("renders the dialog with title and content when open", () => {
        render(<DialogConfirm {...defaultProps} />);

        
        expect(screen.getByText("Test Dialog Title")).toBeInTheDocument();

        expect(screen.getByText("Test dialog content")).toBeInTheDocument();
    });

    test("calls onOk handler when 'Yes' button is clicked", () => {
        render(<DialogConfirm {...defaultProps} />);


        const yesButton = screen.getByText("common.yes");
        fireEvent.click(yesButton);

        expect(mockOnOk).toHaveBeenCalledTimes(1);
    });

    test("closes dialog when 'No' button is clicked", () => {
        render(<DialogConfirm {...defaultProps} />);

        const noButton = screen.getByText("common.no");
        fireEvent.click(noButton);

        expect(mockOnOpenChange).toHaveBeenCalledTimes(1);
        expect(mockOnOpenChange).toHaveBeenCalledWith(expect.any(Object), expect.any(Object));
    });

    test("does not render dialog when open is false", () => {
        render(<DialogConfirm {...defaultProps} open={false} />);

        expect(screen.queryByText("Test Dialog Title")).not.toBeInTheDocument();
        expect(screen.queryByText("Test dialog content")).not.toBeInTheDocument();
    });
});
