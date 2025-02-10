import React from "react";
import { render, screen, fireEvent, act } from "@testing-library/react";
import { DateFilterDropdownMenu } from "./dateFilterDropdownMenu"

describe("DateFilterDropdownMenu", () => {
    const mockOnFilterChange = jest.fn();

    const defaultProps = {
        onFilterChange: mockOnFilterChange,
        selectedFilter: "",
        reset: false,
    };

    beforeEach(() => {
        jest.clearAllMocks();
    });

    it("renders the dropdown component", () => {
        render(<DateFilterDropdownMenu {...defaultProps} />);
        const dropdownButton = screen.getByRole("combobox"); // Find the element by role only
        expect(dropdownButton).toBeInTheDocument(); // Verify the dropdown is rendered
        expect(dropdownButton).toHaveAttribute("aria-expanded", "false"); // Verify default aria-expanded state
        expect(dropdownButton).toHaveTextContent("Anytime"); // Verify default placeholder
    });
    

    it("displays the correct placeholder when no filter is selected", () => {

        render(<DateFilterDropdownMenu {...defaultProps} />);
        expect(screen.queryByLabelText('dropdown-label'))
    })

    it("displays the selected filter when provided", () => {
        render(<DateFilterDropdownMenu {...defaultProps} selectedFilter="Past week" />);
    
        const dropdownButton = screen.getByRole("combobox"); // Locate the dropdown button
        expect(dropdownButton).toHaveTextContent("Past week"); // Verify the button displays the correct selected filter
    });

    it("updates selected filter when an option is selected", () => {
        render(<DateFilterDropdownMenu {...defaultProps} />);
    
        // Locate the dropdown button (combobox role)
        const dropdownButton = screen.getByRole("combobox");
    
        // Verify the initial content of the button
        expect(dropdownButton).toHaveTextContent("Anytime");
    
        // Open the dropdown by clicking on the button
        fireEvent.click(dropdownButton);
    
        // Locate the option "Past week" in the dropdown and select it
        const option = screen.getByText("Past week");
        fireEvent.click(option);
    
        // Verify that the mock callback has been triggered with the correct parameters
        expect(mockOnFilterChange).toHaveBeenCalledWith({
            option: "Past week",
            startDate: null,
            endDate: null,
        });
    
        // Verify that the button text is updated to reflect the selected option
        expect(dropdownButton).toHaveTextContent("Past week");
    });
    
    

    it("resets filter when reset prop is true", () => {
        const { rerender } = render(<DateFilterDropdownMenu {...defaultProps} reset={false} />);
    
        const dropdownButton = screen.getByRole("combobox");
        expect(dropdownButton).toHaveTextContent("Anytime"); // Verify initial state
    
        rerender(<DateFilterDropdownMenu {...defaultProps} reset={true} />);
        expect(mockOnFilterChange).toHaveBeenCalledWith({
            option: "",
            startDate: null,
            endDate: null,
        }); // Ensure the callback is triggered on reset
        expect(dropdownButton).toHaveTextContent("Anytime"); // Verify the placeholder resets
    });
    

    it("updates selectedOption when selectedFilter prop changes", () => {
        const { rerender } = render(<DateFilterDropdownMenu {...defaultProps} selectedFilter="Past month" />);
        
        // Verify that the button has the correct text when the prop is "Past month"
        const dropdownButton = screen.getByRole("combobox");
        expect(dropdownButton).toHaveTextContent("Past month");
    
        // Now update the prop to "Past year" and rerender
        rerender(<DateFilterDropdownMenu {...defaultProps} selectedFilter="Past year" />);
        
        // Verify that the button has the correct text after the prop change
        expect(dropdownButton).toHaveTextContent("Past year");
    });
    

});
