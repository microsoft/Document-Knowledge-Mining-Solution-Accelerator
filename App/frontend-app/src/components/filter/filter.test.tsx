import React from "react";
import { render, screen, fireEvent } from "@testing-library/react";
import { Filter } from "./filter";

// Extend the Window interface to include localStorage
declare global {
    interface Window {
        localStorage: {
            getItem: jest.Mock;
            setItem: jest.Mock;
            removeItem: jest.Mock;
            clear: jest.Mock;
        };
    }
}

beforeEach(() => {
    const localStorageMock = (() => {
        let store: Record<string, string> = {};
        return {
            getItem: jest.fn((key: string) => store[key] || null),
            setItem: jest.fn((key: string, value: string) => {
                store[key] = value;
            }),
            removeItem: jest.fn((key: string) => {
                delete store[key];
            }),
            clear: jest.fn(() => {
                store = {};
            }),
        };
    })();

    Object.defineProperty(window, "localStorage", {
        value: localStorageMock,
        configurable: true,
    });
});

describe("Filter component", () => {
    test("renders categories and keywords correctly", () => {
        render(
            <Filter
                keywordFilterInfo={{ Category1: ["Keyword1", "Keyword2"] }}
                onFilterChanged={() => {}}
                prevSelectedFilters={{}}
                clearFilters={false}
                onFilterCleared={() => {}}
            />
        );

        fireEvent.click(screen.getByText("Category1")); // Expand category

        expect(screen.getByLabelText("Keyword1")).toBeInTheDocument();
        expect(screen.getByLabelText("Keyword2")).toBeInTheDocument();
    });

    test("handles checkbox changes correctly", () => {
        const mockOnFilterChanged = jest.fn();
        render(
            <Filter
                keywordFilterInfo={{ Category1: ["Keyword1"] }}
                onFilterChanged={mockOnFilterChanged}
                prevSelectedFilters={{}}
                clearFilters={false}
                onFilterCleared={() => {}}
            />
        );

        fireEvent.click(screen.getByText("Category1")); // Expand category

        const checkbox = screen.getByLabelText("Keyword1");
        fireEvent.click(checkbox);

        expect(mockOnFilterChanged).toHaveBeenCalledWith({
            Category1: ["Keyword1"],
        });
    });

    test("initializes with previous filters", () => {
        render(
            <Filter
                keywordFilterInfo={{ Category1: ["Keyword1", "Keyword2"] }}
                onFilterChanged={() => {}}
                prevSelectedFilters={{ Category1: ["Keyword1"] }}
                clearFilters={false}
                onFilterCleared={() => {}}
            />
        );

        fireEvent.click(screen.getByText("Category1")); // Expand category

        const checkbox1 = screen.getByLabelText("Keyword1");
        const checkbox2 = screen.getByLabelText("Keyword2");

        expect(checkbox1).toBeChecked();
        expect(checkbox2).not.toBeChecked();
    });

    test("handles undefined keywordFilterInfo gracefully", () => {
        render(
            <Filter
                keywordFilterInfo={undefined}
                onFilterChanged={() => {}}
                prevSelectedFilters={{}}
                clearFilters={false}
                onFilterCleared={() => {}}
            />
        );

        expect(screen.queryByRole("button", { name: /Category/i })).toBeNull();
    });

    test("clears all filters when clearFilters prop is true", () => {
        const mockOnFilterCleared = jest.fn();
        const { rerender } = render(
            <Filter
                keywordFilterInfo={{ Category1: ["Keyword1"] }}
                onFilterChanged={() => {}}
                prevSelectedFilters={{ Category1: ["Keyword1"] }}
                clearFilters={false}
                onFilterCleared={mockOnFilterCleared}
            />
        );

        fireEvent.click(screen.getByText("Category1")); // Expand category

        rerender(
            <Filter
                keywordFilterInfo={{ Category1: ["Keyword1"] }}
                onFilterChanged={() => {}}
                prevSelectedFilters={{}}
                clearFilters={true}
                onFilterCleared={mockOnFilterCleared}
            />
        );

        expect(mockOnFilterCleared).toHaveBeenCalled();
        expect(window.localStorage.setItem).toHaveBeenCalledWith(
            "selectedKeywords",
            JSON.stringify({})
        );
    });

    test("updates localStorage when filters change", () => {
        render(
            <Filter
                keywordFilterInfo={{ Category1: ["Keyword1"] }}
                onFilterChanged={() => {}}
                prevSelectedFilters={{}}
                clearFilters={false}
                onFilterCleared={() => {}}
            />
        );

        fireEvent.click(screen.getByText("Category1")); // Expand category

        const checkbox = screen.getByLabelText("Keyword1");
        fireEvent.click(checkbox);

        expect(window.localStorage.setItem).toHaveBeenCalledWith(
            "selectedKeywords",
            JSON.stringify({ Category1: ["Keyword1"] })
        );
    });

    test("renders multiple categories correctly", () => {
        render(
            <Filter
                keywordFilterInfo={{
                    Category1: ["Keyword1", "Keyword2"],
                    Category2: ["Keyword3", "Keyword4"],
                }}
                onFilterChanged={() => {}}
                prevSelectedFilters={{}}
                clearFilters={false}
                onFilterCleared={() => {}}
            />
        );

        fireEvent.click(screen.getByText("Category1"));
        fireEvent.click(screen.getByText("Category2"));

        expect(screen.getByLabelText("Keyword1")).toBeInTheDocument();
        expect(screen.getByLabelText("Keyword3")).toBeInTheDocument();
    });

    test("clears localStorage when all filters are removed", () => {
        render(
            <Filter
                keywordFilterInfo={{ Category1: ["Keyword1"] }}
                onFilterChanged={() => {}}
                prevSelectedFilters={{}}
                clearFilters={false}
                onFilterCleared={() => {}}
            />
        );

        fireEvent.click(screen.getByText("Category1")); // Expand category

        const checkbox = screen.getByLabelText("Keyword1");
        fireEvent.click(checkbox); // Select the keyword
        fireEvent.click(checkbox); // Deselect the keyword

        expect(window.localStorage.setItem).toHaveBeenLastCalledWith(
            "selectedKeywords",
            JSON.stringify({})
        );
    });

    test("renders accessible roles and attributes", () => {
        render(
            <Filter
                keywordFilterInfo={{ Category1: ["Keyword1"] }}
                onFilterChanged={() => {}}
                prevSelectedFilters={{}}
                clearFilters={false}
                onFilterCleared={() => {}}
            />
        );

        fireEvent.click(screen.getByText("Category1"));

        expect(screen.getByRole("checkbox", { name: "Keyword1" })).toBeInTheDocument();
        expect(screen.getByRole("button", { name: "Category1" })).toBeInTheDocument();
    });
});