import React from 'react';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { SnackbarError } from './snackbarError';
import { closeSnackbar, CustomContentProps } from 'notistack';
import { DismissRegular } from '@fluentui/react-icons';
import { useTranslation } from 'react-i18next';
import { SnackbarSuccess } from './snackbarSuccess';

jest.mock("./snackbarSuccess", () => {
    return {
        // eslint-disable-next-line react/display-name
        SnackbarSuccess: React.forwardRef((props: any, ref: any) => (
            <div ref={ref} data-testid="mock-snackbar-success" role="alert">
                {props.message}
            </div>
        )),
    };
});
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

describe('SnackbarError', () => {
  beforeEach(() => {
    jest.clearAllMocks(); // Reset mocks before each test
  });
  it("renders multiple `msgItems` as separate lines", async () => {
    const msgItems = ["Error line 1", "Error line 2", "Error line 3"];
    const defaultProps : CustomContentProps = {
        id: "test-id",
        message: "Success!",
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
        
    }

    render(<SnackbarError msgItems={msgItems} {...defaultProps}  />);

    const alert = screen.getByRole("alert");
    expect(alert).toBeInTheDocument();
    await waitFor(()=>{
    // Check if all `msgItems` are rendered with <br /> between them
    expect(screen.getByText(/Error line 1/i)).toBeInTheDocument();
    expect(screen.getByText(/Error line 2/i)).toBeInTheDocument();
    expect(screen.getByText(/Error line/i)).toBeInTheDocument();
})
});

it("renders the `message` when `msgItems` is not provided", () => {
    const defaultProps : CustomContentProps = {
        id: "test-id",
        message: "Success!",
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
        
    }

    render(<SnackbarError {...defaultProps} msgItems={[]} />);
    expect(screen.getByRole('alert')).toBeInTheDocument();
});
  it('renders with a message prop', () => {
    const defaultProps : CustomContentProps = {
        id: "test-id",
        message: "Success!",
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
        
    }
    

    render(<SnackbarError msgItems={[]} {...defaultProps} />);

    expect(screen.getByRole('alert')).toBeInTheDocument();
  });


  it('calls closeSnackbar when dismiss icon is clicked', () => {
   
    const defaultProps : CustomContentProps = {
        id: "test-id",
        message: "Success!",
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
        
    }

    render(<SnackbarError msgItems={[]} {...defaultProps} />);

    const dismissButton = screen.getByLabelText('common.dismiss'); // The aria-label is set to "common.dismiss"
    fireEvent.click(dismissButton);

    // Verify closeSnackbar is called
    expect(closeSnackbar).toHaveBeenCalledWith('test-id');
  });

});
