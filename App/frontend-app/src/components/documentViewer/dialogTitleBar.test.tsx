import React from "react";
import { render, screen, fireEvent } from "@testing-library/react";
import { DialogTitleBar } from "./dialogTitleBar";

// Mock the dependencies
jest.mock("react-i18next", () => ({
  useTranslation: () => ({
    t: (key: string) => key,
  }),
}));

jest.mock("../chat/chatRoom", () => ({
  ChatRoom: () => <div data-testid="chat-room">Chat Room Component</div>,
}));

describe("DialogTitleBar Component", () => {
  const defaultProps = {
    handleDialogClose: jest.fn(),
    metadata: { title: "Document Title", source_last_modified: "2023-12-01" },
    selectedPage: null,
    selectedTab: "Document",
    onTabSelect: jest.fn(),
    pageMetadata: null,
    selectedPageMetadata: null,
    handleReturnToDocumentTab: jest.fn(),
    downloadFile: jest.fn(),
    urlWithSasToken: "https://example.com",
    styles: {},
    props: {},
    clearChatFlag: true,
    setClearChatFlag: jest.fn(),
  };

  it("renders without crashing", () => {
    render(<DialogTitleBar {...defaultProps} />);
    expect(screen.getByText("Document Title")).toBeInTheDocument();
    expect(screen.getByText("2023-12-01")).toBeInTheDocument();
  });

  it("calls handleDialogClose when the close button is clicked", () => {
    render(<DialogTitleBar {...defaultProps} />);
    const closeButton = screen.getByLabelText("close");
    fireEvent.click(closeButton);
    expect(defaultProps.handleDialogClose).toHaveBeenCalled();
  });

  it("calls onTabSelect when a tab is selected", () => {
    render(<DialogTitleBar {...defaultProps} />);
    const documentTab = screen.getByText("components.dialog-title-bar.document");
    fireEvent.click(documentTab);
    expect(defaultProps.onTabSelect).toHaveBeenCalled();
  });

  it("renders correctly when metadata is incomplete", () => {
    render(<DialogTitleBar {...defaultProps} metadata={{}} />);
    expect(screen.queryByText("Document Title")).not.toBeInTheDocument();
    expect(screen.queryByText("2023-12-01")).not.toBeInTheDocument();
  });

  it("does not render the 'Pages' tab when pageMetadata is empty", () => {
    render(<DialogTitleBar {...defaultProps} pageMetadata={[]} />);
    expect(screen.queryByText("components.dialog-title-bar.pages")).not.toBeInTheDocument();
  });

  it("renders the correct tab content for 'AI Knowledge'", () => {
    render(<DialogTitleBar {...defaultProps} selectedTab="AI Knowledge" />);
    expect(screen.getByText("components.dialog-title-bar.ai-knowledge")).toBeInTheDocument();
  });

  it("renders close button with aria-label", () => {
    render(<DialogTitleBar {...defaultProps} />);
    const closeButton = screen.getByLabelText("close");
    expect(closeButton).toBeInTheDocument();
  });

  it("disables the download button when urlWithSasToken is undefined", () => {
    render(<DialogTitleBar {...defaultProps} urlWithSasToken={undefined} />);
    const downloadButton = screen.getByText("components.dialog-title-bar.download");
    expect(downloadButton).toBeDisabled();
  });

  it("enables the download button when urlWithSasToken is provided", () => {
    render(<DialogTitleBar {...defaultProps} />);
    const downloadButton = screen.getByText("components.dialog-title-bar.download");
    expect(downloadButton).toBeEnabled();
  });

  it("calls downloadFile when the download button is clicked", () => {
    render(<DialogTitleBar {...defaultProps} />);
    const downloadButton = screen.getByText("components.dialog-title-bar.download");
    fireEvent.click(downloadButton);
    expect(defaultProps.downloadFile).toHaveBeenCalled();
  });

  it("renders the ChatRoom component when the 'Chat Room' tab is active", () => {
    render(<DialogTitleBar {...defaultProps} selectedTab="Chat Room" />);
    expect(screen.getByTestId("chat-room")).toBeInTheDocument();
  });

  it("calls handleReturnToDocumentTab when the return button is clicked", () => {
    render(
      <DialogTitleBar
        {...defaultProps}
        selectedTab="Page Number"
        selectedPage={1}
        selectedPageMetadata={{ tables: [1] }}
      />
    );
    const returnButton = screen.getByText("components.dialog-title-bar.return-to-document");
    fireEvent.click(returnButton);
    expect(defaultProps.handleReturnToDocumentTab).toHaveBeenCalled();
  });

  it("matches snapshot for the default state", () => {
    const { asFragment } = render(<DialogTitleBar {...defaultProps} />);
    expect(asFragment()).toMatchSnapshot();
  });
});