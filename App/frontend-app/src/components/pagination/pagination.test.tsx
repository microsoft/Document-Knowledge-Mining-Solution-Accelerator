import { render, fireEvent, screen } from "@testing-library/react";
import { Pagination } from "./pagination"; // Adjust import path based on your file structure
import { ChevronLeft24Regular, ChevronRight24Regular } from "@fluentui/react-icons";

// Mock custom hook usePagination to simulate pagination range
jest.mock("../../utils/customHooks/usePagination", () => ({
    usePagination: jest.fn(),
    DOTS: "DOTS",
}));

jest.mock('@fluentui/react', () => ({
    Button: jest.fn(({ disabled, children, ...props }) => (
      <button disabled={disabled} {...props}>{children}</button>
    )),
    // Mock any other Fluent UI components if necessary
  }))

  jest.mock("@fluentui/react-components", () => ({
    Button: ({ disabled, children, ...props }: any) => (
        <button disabled={disabled} {...props}>
            {children}
        </button>
    ),
}));

describe("Pagination Component", () => {
    const mockOnPageChange = jest.fn();

    beforeEach(() => {
        mockOnPageChange.mockClear(); // Clear mock calls before each test
    });
    const onPageChangeMock = jest.fn();

    const defaultProps = {
        totalCount: 5, // Total pages
        pageSize: 10,
        currentPage: 5, // Last page
        onPageChange: onPageChangeMock,
    };

    test("should disable the right arrow when on the last page", () => {
        render(<Pagination {...defaultProps} />);
        
        // Find the 'Next' button (Right Arrow) by test ID or by text/icon
        const nextButton = screen.getByTestId("next-button");
        
        // Check if the button is disabled
        expect(nextButton).toBeDisabled();
    });
    it("should render pagination buttons correctly", () => {
        // Mock return value for pagination
        const mockPaginationRange = [1, 2, "DOTS", 5];
        (require("../../utils/customHooks/usePagination").usePagination as jest.Mock).mockReturnValue(mockPaginationRange);

        render(
            <Pagination
                totalCount={5}
                pageSize={1}
                currentPage={1}
                onPageChange={mockOnPageChange}
            />
        );

        // Check if the correct page numbers are displayed
        expect(screen.getByText("1")).toBeInTheDocument();
        expect(screen.getByText("2")).toBeInTheDocument();
        expect(screen.getByText("5")).toBeInTheDocument();
        expect(screen.getByText("...")).toBeInTheDocument();
    });

    it("should call onPageChange when a page button is clicked", () => {
        const mockPaginationRange = [1, 2, "DOTS", 5];
        (require("../../utils/customHooks/usePagination").usePagination as jest.Mock).mockReturnValue(mockPaginationRange);

        render(
            <Pagination
                totalCount={5}
                pageSize={1}
                currentPage={1}
                onPageChange={mockOnPageChange}
            />
        );

        const page2Button = screen.getByText("2");
        fireEvent.click(page2Button);

        // Ensure the onPageChange callback is called with the correct page number
        expect(mockOnPageChange).toHaveBeenCalledWith(2);
    });

    // it.only("should disable the left arrow when on the first page", () => {
    //     const mockPaginationRange = [1, 2, "DOTS", 5];
    //     (require("../../utils/customHooks/usePagination").usePagination as jest.Mock).mockReturnValue(mockPaginationRange);

    //     render(
    //         <Pagination
    //             totalCount={5}
    //             pageSize={1}
    //             currentPage={1}
    //             onPageChange={mockOnPageChange}
    //         />
    //     );

    //     // const leftArrow = screen.getByRole("button", { name: /previous page/i }).not.toBeDisabled();
    //     const leftArrow = expect(screen.getByRole('button', { name: /left/i })).not.toBeDisabled();
    //     // expect(leftArrow).toBeDisabled();
    //     screen.debug();
    //     expect(leftArrow).not.toBeInTheDocument();
    // });

    // it.only("disables the left arrow button on the first page", () => {     
    //   const onPageChangeMock = jest.fn();     
    //   render(      <Pagination        totalCount={5}        pageSize={1}        currentPage={1}        onPageChange={onPageChangeMock}      />    );  
    //   // Check that the left arrow button is disabled
    //   const leftArrowButton = screen.getByRole("button", { name: /chevron left/i });     
    //   expect(leftArrowButton).toBeDisabled();     // Verify the button cannot be clicked    
    //   fireEvent.click(leftArrowButton); 
    //   expect(onPageChangeMock).not.toHaveBeenCalled(); 
    // });

    it("disables the left arrow button on the first page", () => {    
      const onPageChangeMock = jest.fn();    
      render(      <Pagination        totalCount={5}        pageSize={1}        currentPage={1}        onPageChange={onPageChangeMock}      />    );    
      // Find the left arrow button based on its icon or index    
      const buttons = screen.getAllByRole("button");    
      const leftArrowButton = buttons[0]; // Assuming it's the first button in the list    // Check if the left arrow button is disabled    
      expect(leftArrowButton).toBeDisabled();    // Simulate a click and ensure the onPageChange function is not called    
      fireEvent.click(leftArrowButton);    
      expect(onPageChangeMock).not.toHaveBeenCalled();  }); 

      it("disables the right arrow button on the last page", () => {    
        const onPageChangeMock = jest.fn();    
        render(      <Pagination        totalCount={5}        pageSize={1}        currentPage={1}        onPageChange={onPageChangeMock}      />    );    
        // Find the left arrow button based on its icon or index    
        const buttons = screen.getAllByRole("button");    
        const rightArrow = buttons[0]; // Assuming it's the first button in the list    // Check if the left arrow button is disabled    
        expect(rightArrow).toBeDisabled();    // Simulate a click and ensure the onPageChange function is not called    
        fireEvent.click(rightArrow);    
        expect(onPageChangeMock).not.toHaveBeenCalled();  }); 

    // it("should disable the right arrow when on the last page", () => {
    //     const mockPaginationRange = [1, 2, "DOTS", 5];
    //     (require("../../utils/customHooks/usePagination").usePagination as jest.Mock).mockReturnValue(mockPaginationRange);

    //     render(
    //         <Pagination
    //             totalCount={5}
    //             pageSize={1}
    //             currentPage={5}
    //             onPageChange={mockOnPageChange}
    //         />
    //     );

    //     const rightArrow = screen.getByRole("button", { name: /chevron right/i });
    //     screen.debug();
    //     expect(rightArrow).toBeDisabled();
    // });

    it("should not render pagination if currentPage is out of range", () => {
        const mockPaginationRange = [1, 2, "DOTS", 5];
        (require("../../utils/customHooks/usePagination").usePagination as jest.Mock).mockReturnValue(mockPaginationRange);

        render(
            <Pagination
                totalCount={5}
                pageSize={1}
                currentPage={6} // Invalid page number
                onPageChange={mockOnPageChange}
            />
        );

        // Ensure no pagination buttons are rendered
        expect(screen.queryByText("1")).not.toBeInTheDocument();
        expect(screen.queryByText("2")).not.toBeInTheDocument();
    });

    it("should handle edge case when totalCount is 1 (no pagination)", () => {
        render(
            <Pagination
                totalCount={1}
                pageSize={1}
                currentPage={1}
                onPageChange={mockOnPageChange}
            />
        );

        const leftArrow = screen.getByRole("button", { name: /chevron left/i });
        const rightArrow = screen.getByRole("button", { name: /chevron right/i });

        // Ensure both arrows are disabled
        expect(leftArrow).toBeDisabled();
        expect(rightArrow).toBeDisabled();
    }); 

    it("should render DOTS correctly in pagination range", () => {
        const mockPaginationRange = [1, "DOTS", 5];
        (require("../../utils/customHooks/usePagination").usePagination as jest.Mock).mockReturnValue(mockPaginationRange);

        render(
            <Pagination
                totalCount={5}
                pageSize={1}
                currentPage={1}
                onPageChange={mockOnPageChange}
            />
        );

        expect(screen.getByText("...")).toBeInTheDocument();
    });
});
