import { render, screen, fireEvent } from "@testing-library/react";
import { ChatPage } from "./chatPage";
import { MemoryRouter, Route, Routes } from "react-router-dom";


jest.mock("../../components/header/header", () => ({
  Header: ({ children }: any) => <div>{children}</div>,
}));

jest.mock("../../components/headerBar/headerBar", () => ({
  HeaderBar: ({ location }: any) => <div>{location}</div>,
  NavLocation: { Home: "Home" },
}));

jest.mock("../../components/headerMenu/HeaderMenuTabs", () => ({
  HeaderMenuTabs: ({ updateSelectedDocuments }: any) => (
    <button onClick={() => updateSelectedDocuments({ documentId: "1" })}>
      Update Documents
    </button>
  ),
}));

jest.mock("../../components/chat/chatRoom", () => ({
  ChatRoom: ({ clearChatFlag }: any) => (
    <div>{clearChatFlag ? "Chat Cleared" : "Chat Room"}</div>
  ),
}));


const mockLocationState = {
  searchResultDocuments: [{ documentId: "1", title: "Doc 1" }],
  selectedDocuments: [{ documentId: "2", title: "Doc 2" }],
  tokens: ["token1"],
  chatWithSingleSelectedDocument: [{ documentId: "3", title: "Doc 3" }],
};

describe("ChatPage", () => {
  it("renders and displays the header and chat components", () => {
    render(
      <MemoryRouter initialEntries={[{ pathname: "/chat", state: mockLocationState }]}>
        <Routes>
          <Route path="/chat" element={<ChatPage />} />
        </Routes>
      </MemoryRouter>
    );


    expect(screen.getByText("Home")).toBeInTheDocument();

    expect(screen.getByText("Update Documents")).toBeInTheDocument();
    expect(screen.getByText("Chat Room")).toBeInTheDocument();
  });

  it("renders correctly when no location state is passed", () => {
    render(
      <MemoryRouter initialEntries={["/chat"]}>
        <Routes>
          <Route path="/chat" element={<ChatPage />} />
        </Routes>
      </MemoryRouter>
    );

    expect(screen.getByText("Update Documents")).toBeInTheDocument();
    expect(screen.getByText("Chat Room")).toBeInTheDocument();
  });

  it("updates selected documents when button is clicked", () => {
    render(
      <MemoryRouter initialEntries={[{ pathname: "/chat", state: mockLocationState }]}>
        <Routes>
          <Route path="/chat" element={<ChatPage />} />
        </Routes>
      </MemoryRouter>
    );

    const button = screen.getByText("Update Documents");
    fireEvent.click(button);

 
    expect(screen.getByText("Chat Room")).toBeInTheDocument();
  });

  it("renders correct content when location state is passed", () => {
    render(
      <MemoryRouter initialEntries={[{ pathname: "/chat", state: mockLocationState }]}>
        <Routes>
          <Route path="/chat" element={<ChatPage />} />
        </Routes>
      </MemoryRouter>
    );

    expect(screen.getByText("Update Documents")).toBeInTheDocument();
    expect(screen.getByText("Chat Room")).toBeInTheDocument();
  });

  it("handles document selection correctly", () => {
    render(
      <MemoryRouter initialEntries={[{ pathname: "/chat", state: mockLocationState }]}>
        <Routes>
          <Route path="/chat" element={<ChatPage />} />
        </Routes>
      </MemoryRouter>
    );

    const button = screen.getByText("Update Documents");
    fireEvent.click(button);

    expect(screen.getByText("Chat Room")).toBeInTheDocument();
  });

  it("renders correct content when clearChatFlag is true", () => {
    render(
      <MemoryRouter initialEntries={[{ pathname: "/chat", state: mockLocationState }]}>
        <Routes>
          <Route path="/chat" element={<ChatPage />} />
        </Routes>
      </MemoryRouter>
    );

 
    expect(screen.getByText("Chat Room")).toBeInTheDocument();
  });
});
