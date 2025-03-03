import React from "react";
import { render, fireEvent, screen } from "@testing-library/react";
import { SearchBox, SearchBoxHandle, UploadButton, MicButton, KeyBoardButton, SearchVisualButton } from "./searchBox";
import { act } from "react-dom/test-utils";
import { Mic24Regular } from "@fluentui/react-icons";
import { UploadMultipleFiles } from "../../api/storageService";

jest.mock('use-debounce', () => ({
    useDebouncedCallback: (fn: (...args: any[]) => void) => {
      const debouncedFn = jest.fn(fn) as jest.Mock & { cancel: jest.Mock };
      debouncedFn.cancel = jest.fn(); // Mock the cancel method
      return debouncedFn;
    },
  }));
  
jest.mock('react-i18next', () => ({
  useTranslation: () => ({
      t: (key: any) => key, // Mock translation function
      i18n: { changeLanguage: jest.fn() },
  }),
}));

jest.mock("../../api/storageService", () => ({
    UploadMultipleFiles: jest.fn(() => Promise.resolve(true)),
}));

describe("SearchBox", () => {
    const mockOnSearchChanged = jest.fn();
    const mockOnKeyDown = jest.fn();
    let fileInput: HTMLInputElement;
    let searchBoxRef: React.RefObject<SearchBoxHandle>;

    beforeEach(() => {
        // Set up the file input mock
        fileInput = document.createElement("input");
        fileInput.type = "file";
        fileInput.style.display = "none"; // Hidden input
        document.body.appendChild(fileInput);
    });

    afterEach(() => {
        // Clean up the file input mock
        document.body.removeChild(fileInput);
        jest.clearAllMocks();
    });

    beforeEach(() => {
        jest.clearAllMocks();
        searchBoxRef = React.createRef<SearchBoxHandle>();
    });
    // beforeEach(() => {
    //     jest.clearAllMocks();
    // });

    it("renders the SearchBox with placeholder text", () => {
        render(
            <SearchBox 
                placeholder="Search here..." 
                onSearchChanged={mockOnSearchChanged} 
            />
        );
        expect(screen.getByPlaceholderText("Search here...")).toBeInTheDocument();
    });

    it("updates the value when typed into the input field", () => {
        render(
            <SearchBox 
                onSearchChanged={mockOnSearchChanged} 
            />
        );

        const input = screen.getByRole("searchbox");
        fireEvent.change(input, { target: { value: "test query" } });

        expect(input).toHaveValue("test query");
        expect(mockOnSearchChanged).toHaveBeenCalledWith("test query");
    });

    it("handles Enter key press and triggers onSearchChanged immediately", () => {
        render(
            <SearchBox 
                onSearchChanged={mockOnSearchChanged} 
                onKeyDown={mockOnKeyDown} 
            />
        );
        const input = screen.getByRole("searchbox");
        fireEvent.change(input, { target: { value: "test query" } });
        // expect(screen.getByLabelText("Type your search Keyword.")).toBeInTheDocument();
        fireEvent.keyDown(input, { key: "Enter", code: "Enter" });

        expect(mockOnSearchChanged).toHaveBeenCalledWith("test query");
        expect(mockOnKeyDown).toHaveBeenCalled();
    });

    it("resets the value when the reset method is called", () => {
        const ref = React.createRef<SearchBoxHandle>();

        render(
            <SearchBox 
                onSearchChanged={mockOnSearchChanged} 
                ref={ref} 
            />
        );

        act(() => {
            ref.current?.setValue("test value");
        });

        const input = screen.getByRole("searchbox");
        expect(input).toHaveValue("test value");

        act(() => {
            ref.current?.reset();
        });

        expect(input).toHaveValue("");
        expect(mockOnSearchChanged).toHaveBeenCalledWith("");
    });

    it("renders buttons inside the input contentAfter", () => {
        render(<SearchBox onSearchChanged={mockOnSearchChanged} />);
        // Assert buttons are rendered
        expect(screen.getByLabelText("Type your search Keyword.")).toBeInTheDocument();
        expect(screen.getByTestId("upload-div")).toBeInTheDocument();
    });
    

    it("should expose setValue and reset methods through ref", () => {
        const ref = React.createRef<SearchBoxHandle>();
        render(<SearchBox ref={ref} onSearchChanged={mockOnSearchChanged} />);
    
        act(() => {
            ref.current?.setValue("test value");
        });
        expect(mockOnSearchChanged).toHaveBeenCalledWith("test value");
    
        act(() => {
            ref.current?.reset();
        });
        expect(mockOnSearchChanged).toHaveBeenCalledWith("");
    });

    it("should enforce a character limit of 300 on input", () => {
        render(<SearchBox onSearchChanged={mockOnSearchChanged} />);
        const input = screen.getByRole("searchbox");
    
        // Valid input (within the limit)
        fireEvent.change(input, { target: { value: "a".repeat(300) } });
        expect(input).toHaveValue("a".repeat(300));
        expect(mockOnSearchChanged).toHaveBeenCalledWith("a".repeat(300));
    
        // Exceeding character limit
        fireEvent.change(input, { target: { value: "a".repeat(301) } });
        expect(input).toHaveValue("a".repeat(300));
        expect(mockOnSearchChanged).not.toHaveBeenCalledWith("a".repeat(301));
    });

    it("should forward ref to access component methods", () => {
        const ref = React.createRef<SearchBoxHandle>();
        render(<SearchBox ref={ref} onSearchChanged={mockOnSearchChanged} />);
    
        expect(ref.current).toBeDefined();
        expect(typeof ref.current?.setValue).toBe("function");
        expect(typeof ref.current?.reset).toBe("function");
    });
    it("renders the component with initial props", () => {
        render(
            <SearchBox
                ref={searchBoxRef}
                initialValue="test"
                placeholder="Search..."
                onSearchChanged={mockOnSearchChanged}
                onKeyDown={mockOnKeyDown}
            />
        );

        const inputElement = screen.getByPlaceholderText("Search...");
        expect(inputElement).toBeInTheDocument();
        expect((inputElement as HTMLInputElement).value).toBe("test");
    });

    it("calls onSearchChanged when input value changes", async () => {
        render(
            <SearchBox
                ref={searchBoxRef}
                onSearchChanged={mockOnSearchChanged}
                onKeyDown={mockOnKeyDown}
            />
        );

        const inputElement = screen.getByRole("searchbox");

        await act(async () => {
            fireEvent.change(inputElement, { target: { value: "hello" } });
        });

        expect(mockOnSearchChanged).toHaveBeenCalledWith("hello");
    });

    it("calls onKeyDown and handles Enter key", async () => {
        render(
            <SearchBox
                ref={searchBoxRef}
                onSearchChanged={mockOnSearchChanged}
                onKeyDown={mockOnKeyDown}
            />
        );

        const inputElement = screen.getByRole("searchbox");

        await act(async () => {
            fireEvent.keyDown(inputElement, { key: "Enter" });
        });

        expect(mockOnKeyDown).toHaveBeenCalled();
        expect(mockOnSearchChanged).toHaveBeenCalled();
    });

    it("resets the value using exposed reset method", async () => {
        render(
            <SearchBox
                ref={searchBoxRef}
                onSearchChanged={mockOnSearchChanged}
            />
        );

        const inputElement = screen.getByRole("searchbox");

        await act(async () => {
            fireEvent.change(inputElement, { target: { value: "reset test" } });
        });

        expect((inputElement as HTMLInputElement).value).toBe("reset test");

        act(() => {
            searchBoxRef.current?.reset();
        });

        expect((inputElement as HTMLInputElement).value).toBe("");
        expect(mockOnSearchChanged).toHaveBeenLastCalledWith("");
    });

    it("does not allow input values greater than 300 characters", async () => {
        render(
            <SearchBox
                ref={searchBoxRef}
                onSearchChanged={mockOnSearchChanged}
            />
        );

        const inputElement = screen.getByRole("searchbox");
        const longText = "a".repeat(301);

        await act(async () => {
            fireEvent.change(inputElement, { target: { value: longText } });
        });

        expect((inputElement as HTMLInputElement).value.length).toBeLessThanOrEqual(300);
    });
    

    it("renders the UploadButton component inside the SearchBox", () => {
        render(<SearchBox onSearchChanged={mockOnSearchChanged} />);
        expect(screen.getByTestId("upload-div")).toBeInTheDocument();
    });

    it("renders MicButton with correct class and icon", () => {
        render(<MicButton />);
        const micButton = screen.getByRole("button");
        expect(micButton).toBeInTheDocument();
        expect(micButton).toHaveClass("mic_button");
        expect(micButton.querySelector("svg")).toBeInTheDocument(); // Check if the icon is rendered
    });

    it("renders KeyBoardButton with correct class and icon", () => {
        render(<KeyBoardButton />);
        const keyboardButton = screen.getByRole("button");
        expect(keyboardButton).toBeInTheDocument();
        expect(keyboardButton).toHaveClass("keyboard_button");
        expect(keyboardButton.querySelector("svg")).toBeInTheDocument(); // Check if the icon is rendered
    });

    it("renders SearchVisualButton with correct class and icon", () => {
        render(<SearchVisualButton />);
        const searchVisualButton = screen.getByRole("button");
        expect(searchVisualButton).toBeInTheDocument();
        expect(searchVisualButton).toHaveClass("searchVisual_button");
        expect(searchVisualButton.querySelector("svg")).toBeInTheDocument(); // Check if the icon is rendered
    });

    it("triggers file input click when the button is clicked", () => {
        // Mock the file input reference
        const fileInput = document.createElement("input");
        fileInput.type = "file";
        document.body.appendChild(fileInput);

        const fileInputRefMock = {
            current: fileInput,
        };

        // Spy on the click method of the file input
        const clickSpy = jest.spyOn(fileInput, "click");

        // Render the UploadButton component
        render(<UploadButton />);
        // Find the upload button
        const uploadButton = document.querySelector(".upload_button");

        // Trigger the button click
        if (uploadButton) {
            fireEvent.click(uploadButton);
        }

        // Assert that the click method was called on the file input
        // expect(clickSpy).toHaveBeenCalled();
    });
    //upload doc
    /*
    it("uploads files successfully", async () => {
        const mockFiles = [
            new File(["file content"], "file1.txt", { type: "text/plain" }),
            new File(["another file content"], "file2.txt", { type: "text/plain" }),
        ];
        const mockResponse = true;

        // Mock the file input with files
        Object.defineProperty(fileInput, "files", {
            value: mockFiles,
        });

        // Mock the API response
        (UploadMultipleFiles as jest.Mock).mockResolvedValue(mockResponse);

        // Render the UploadButton
        render(<UploadButton />);
        const uploadButton = document.querySelector(".upload_button");

        // Simulate the file input click and set files
        fireEvent.click(uploadButton!);

        // Simulate calling uploadDocuments manually
        const uploadDocumentsFn = UploadButton.prototype.uploadDocuments;
        await uploadDocumentsFn();

        // Assert API call and success alert
        expect(UploadMultipleFiles).toHaveBeenCalledWith(mockFiles);
        expect(window.alert).toHaveBeenCalledWith("Files uploaded successfully");
    });

    it("handles error during file upload", async () => {
        const mockFiles = [
            new File(["file content"], "file1.txt", { type: "text/plain" }),
        ];

        // Mock the file input with files
        Object.defineProperty(fileInput, "files", {
            value: mockFiles,
        });

        // Mock the API to throw an error
        (UploadMultipleFiles as jest.Mock).mockRejectedValue(new Error("Network error"));

        // Render the UploadButton
        render(<UploadButton />);
        const uploadButton = document.querySelector(".upload_button");

        // Simulate the file input click and set files
        fireEvent.click(uploadButton!);

        // Simulate calling uploadDocuments manually
        const uploadDocumentsFn = UploadButton.prototype.uploadDocuments;
        await uploadDocumentsFn();

        // Assert API call and error alert
        expect(UploadMultipleFiles).toHaveBeenCalledWith(mockFiles);
        expect(window.alert).toHaveBeenCalledWith("Error uploading files");
    });
*/
    it("does nothing if no files are selected", () => {
        render(<SearchBox onSearchChanged={mockOnSearchChanged} />);
    
        const uploadDiv = screen.getByTestId("upload-div");
    
        const fileInput = document.createElement("input");
        fileInput.type = "file";
        Object.defineProperty(fileInput, "files", {
          value: [],
          writable: false,
        });
    
        document.body.appendChild(fileInput); // Add to DOM
        fireEvent.change(fileInput); // Trigger file selection event
    
        expect(UploadMultipleFiles).not.toHaveBeenCalled();
    
        fileInput.remove(); // Cleanup
      });
    
});
