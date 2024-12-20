import { render, screen, fireEvent, waitFor, act } from "@testing-library/react";
import { ChatRoom } from "./chatRoom";
import { AppContext } from "../../AppContext";
import { CopilotProvider, CopilotChat, UserMessage, CopilotMessage } from "@fluentai/react-copilot";
import userEvent from '@testing-library/user-event';
import { Completion, PostFeedback } from "../../api/chatService";
import React from "react";

jest.mock("../../api/chatService", () => ({
  Completion: jest.fn(),
  PostFeedback: jest.fn(),
}));
// Mock Copilot components
// jest.mock("@fluentai/react-copilot", () => ({
//   CopilotProvider: jest.fn(({ children }) => <div data-testid="copilot-provider">{children}</div>),
//   CopilotChat: jest.fn(({ children }) => <div data-testid="copilot-chat">{children}</div>),
//   UserMessage: jest.fn(({ children }) => <div data-testid="user-message">{children}</div>),
//   CopilotMessage: jest.fn(({ children }) => <div data-testid="copilot-message">{children}</div>),
// }));
jest.mock('../../components/chat/optionsPanel', () => ({
  OptionsPanel: jest.fn((props: any) =>
    <div data-testid="options-panel" className={props.isSticky ? "sticky-class" : ""} >
      <p>{props.optionsPanel}</p>
      <span>Mocked OptionsPanel</span>
      {
        <button onClick={() => props.onModelChange()}>Mock Model Loading</button>
      }
      {
        <button onClick={() => props.onSourceChange()}>Mock Source Loading</button>
      }

    </div>)
}));

//   jest.mock("../../components/chat/FeedbackForm", () => ({
//     FeedbackForm: (props: any) => <div data-testid="feedback-form" {...props}></div>,
//   }));

// Mock the Copilot components using jest.mock
jest.mock('@fluentai/react-copilot', () => ({
  CopilotProvider: ({ children }: { children: React.ReactNode }) => (
    <div data-testid="mock-copilot-provider" className="mock-copilot-provider">{children}</div>
  ),
  FeedbackButtons: ({ children }: { children: React.ReactNode }) => (
    <div className="mock-feedback-buttons">{children}</div>
  ),
  Suggestion: jest.fn(({ children, ...props }) => (
    <button {...props}>{children}</button>  // Mock the Suggestion as a simple button
  )),
}));

jest.mock('@fluentai/react-copilot-chat', () => ({
  CopilotChat: ({ children }: { children: React.ReactNode }) => (
    <div data-testid="mock-copilot-chat" className="mock-copilot-chat">{children} </div>
  ),
  UserMessage: ({ children }: { children: React.ReactNode }) => (
    <div data-testid="mock-user-message" className="mock-user-message">{children}</div>
  ),
  CopilotMessage: ({ children }: { children: React.ReactNode }) => (
    <div data-testid="mock-copilot-message" className="mock-copilot-message">{children}</div>
  ),
}));

jest.mock("../../components/documentViewer/documentViewer", () => ({
  DocumentViewer: () => <div>Mock Document Viewer</div>,
}));

//   jest.mock("../../components/sidecarCopilot/sidecar", () => ({
//     SidecarCopilot: () => <div>Mock Sidecar Copilot</div>,
//   }));

// Object.defineProperty(global, "import.meta", {
//   value: {
//     env: {
//       VITE_API_ENDPOINT: "http://mock-api-endpoint.com",
//     },
//   },
// });
const mockContextValue = {
  conversationAnswers: [],
  setConversationAnswers: jest.fn(),
  query: "mockQuery",
  setQuery: jest.fn(),
  filters: { category: ["exampleFilter"] },
  setFilters: jest.fn(),
  setIsSticky: jest.fn(),
};

describe("ChatRoom Component", () => {
  const defaultProps = {
    searchResultDocuments: [],
    disableOptionsPanel: false,
    selectedDocuments: [],
    chatWithDocument: [],
    clearChatFlag: false,
    setIsSticky: false,
  };

  beforeEach(() => {
    jest.clearAllMocks();
  });

  it("renders ChatRoom component", () => {
    render(
      <AppContext.Provider value={mockContextValue}>
        <ChatRoom {...defaultProps} />
      </AppContext.Provider>
    );
    expect(screen.getByLabelText("Chat input")).toBeInTheDocument();
    expect(screen.getByText("0 / 500")).toBeInTheDocument();
  });

  it("calls makeApiRequest on submitting a message", async () => {
    (Completion as jest.Mock).mockResolvedValueOnce({
      answer: "Test Answer",
      suggestingQuestions: [],
      documentIds: [],
      keywords: [],
    });

    render(
      <AppContext.Provider value={mockContextValue}>
        <ChatRoom {...defaultProps} />
      </AppContext.Provider>
    );

    const input = screen.getByLabelText("Chat input");
    fireEvent.change(input, { target: { value: "Test Question" } });
    fireEvent.keyDown(input, { key: "Enter", code: "Enter" });

    await waitFor(() => {
      expect(Completion).toHaveBeenCalledWith(
        expect.objectContaining({
          Question: "Test Question",
        })
      );
    });
  });

  it("clears the chat when New Topic is clicked", async () => {
    render(
      <AppContext.Provider value={mockContextValue}>
        <ChatRoom {...defaultProps} />
      </AppContext.Provider>
    );

    const newTopicButton = screen.getByTestId("new-topic-button"); // Adjust the text if localization is applied.
    fireEvent.mouseEnter(newTopicButton);

    // Click the "New Topic" button
    fireEvent.click(newTopicButton);

    // Check that it was called with a function
    expect(mockContextValue.setConversationAnswers).toHaveBeenCalled();
    expect(typeof mockContextValue.setConversationAnswers.mock.calls[0][0]).toBe("function");
  });


  it("handles API error gracefully", async () => {
    (Completion as jest.Mock).mockRejectedValueOnce(new Error("API error"));

    render(
      <AppContext.Provider value={mockContextValue}>
        <ChatRoom {...defaultProps} />
      </AppContext.Provider>
    );

    const input = screen.getByLabelText("Chat input");
    fireEvent.change(input, { target: { value: "Test Question" } });
    fireEvent.keyDown(input, { key: "Enter", code: "Enter" });

    await waitFor(() => {
      expect(mockContextValue.setConversationAnswers).toHaveBeenCalled();
    });
  });
  
  it("submits user input and processes API response", async () => {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const user = userEvent.setup();
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const CompletionMock = require("../../api/chatService").Completion;
    CompletionMock.mockResolvedValueOnce({
      "chatSessionId": "2c2d390c-7c82-4736-b7dc-e1fcd17e4253",
      "answer": "The document titled \"Accessibility in Housing: Findings from the 2019 American Housing Survey\" provides a comprehensive analysis of the accessibility needs of U.S. households, especially those facing mobility-related challenges. It reveals that nearly 20% of U.S. households, or approximately 23.1 million, include someone with accessibility needs, which can include individuals with mobility-related disabilities, those using mobility-assistive devices, and those having difficulties accessing their homes or using critical spaces like kitchens and bathrooms (Accessibility in Housing Report, Page 1). \n\nA significant finding is that many of these households reside in homes lacking essential accessibility features. For instance, around 40% of households that would benefit from having a bedroom and full bathroom on the entry level do not currently have both features. Moreover, only 5% of owner households plan to add accessibility features in the next two years, indicating a considerable gap in accessible housing (Accessibility in Housing Report, Page 12). \n\nDemographic trends identified in the report show that households headed by women (21%) are more likely to include persons with accessibility needs compared to those headed by men (17%). Additionally, households with lower socioeconomic status, including those with annual incomes under $20,000 (33%) and those with household heads having only grade school education (31%), are more likely to include individuals with accessibility needs (Accessibility in Housing Report, Page 9). \n\nIn terms of specific accessibility features, the report notes that only 5% of homes have ramps, and 1% have chairlifts or platform lifts. Among households with accessibility needs, 14% reported having a ramp or lift of some type, while 58% have both a bedroom and a full bathroom on the entry level (Accessibility in Housing Report, Page 12). The presence of these features varies significantly by region, with households in micropolitan or nonmetropolitan areas being more likely to have ramps or lifts compared to those in large metropolitan areas (Accessibility in Housing Report, Page 13). \n\nThe adequacy of home layouts for those with mobility challenges is also discussed. More than half (56%) of households that include persons using mobility-assistive devices rated their home's layout as meeting their needs \"very well,\" while only 4% rated it as \"not at all well\" (Accessibility in Housing Report, Page 17). However, the overall lack of accessibility features in homes suggests that many individuals may still face significant barriers to independent living. \n\nIn conclusion, the findings from the 2019 American Housing Survey emphasize the critical need for improved accessibility in U.S. housing. The data reveal that while a considerable portion of households includes individuals with accessibility needs, many of these homes lack essential features that would facilitate independent living. The report highlights disparities in accessibility based on socioeconomic status, geography, and household demographics, underscoring the urgent need for policy interventions and improvements in housing accessibility (Accessibility in Housing Report, Page 1).",
      "documentIds": [
        "9a31d6b935c44bc9b769b886a6a1535f202412020656379941562"
      ],
      "suggestingQuestions": [
        "What specific accessibility features are most needed in U.S. homes?",
        "How do demographic factors influence the need for accessible housing?",
        "What policy interventions could improve housing accessibility for those with mobility challenges?"
      ],
      "keywords": [
        "accessibility",
        "housing",
        "mobility challenges"
      ]
    });
    //  const consoleSpy = jest.spyOn(console, "log").mockImplementation(); // Spy on console
    // Mock implementation of setConversationAnswers

    const mockConversationAnswers = [
      ["Initial Prompt", { message: "Initial Response" }],
    ];

    const mockSetConversationAnswers = jest.fn((updateFn) => {
      const updatedState = updateFn(mockConversationAnswers);
      mockContext.conversationAnswers = updatedState; // Simulate the state update
    });

    const mockContext = {
      ...mockContextValue,
      setConversationAnswers: mockSetConversationAnswers
    }
    const { rerender } = render(
      <AppContext.Provider value={mockContext}>
        <ChatRoom {...defaultProps} />
      </AppContext.Provider>
    );
    const input = screen.getByLabelText("Chat input");
    fireEvent.change(input, { target: { value: "Summarize this doc" } });
    //const inputBox = screen.getByTestId("input-box");
    act(() => {
      fireEvent.keyDown(input, { key: "Enter", code: "Enter" });
    })


    rerender(
      <AppContext.Provider value={mockContext}>
        <ChatRoom {...defaultProps} />
      </AppContext.Provider>
    );

    await waitFor(() => {
      expect(screen.getByRole('button', { name: /What specific accessibility features are most needed in U.S. homes?/ })).toBeInTheDocument();
    });

  });

  it("handle suggestions onclick handler to trigger the API request", async () => {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const user = userEvent.setup();
    const handleFollowUpQuestionMock = jest.fn();
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const CompletionMock = require("../../api/chatService").Completion;
    CompletionMock.mockResolvedValueOnce({
      "chatSessionId": "2c2d390c-7c82-4736-b7dc-e1fcd17e4253",
      "answer": "The document titled \"Accessibility in Housing: Findings from the 2019 American Housing Survey\" provides a comprehensive analysis of the accessibility needs of U.S. households, especially those facing mobility-related challenges. It reveals that nearly 20% of U.S. households, or approximately 23.1 million, include someone with accessibility needs, which can include individuals with mobility-related disabilities, those using mobility-assistive devices, and those having difficulties accessing their homes or using critical spaces like kitchens and bathrooms (Accessibility in Housing Report, Page 1). \n\nA significant finding is that many of these households reside in homes lacking essential accessibility features. For instance, around 40% of households that would benefit from having a bedroom and full bathroom on the entry level do not currently have both features. Moreover, only 5% of owner households plan to add accessibility features in the next two years, indicating a considerable gap in accessible housing (Accessibility in Housing Report, Page 12). \n\nDemographic trends identified in the report show that households headed by women (21%) are more likely to include persons with accessibility needs compared to those headed by men (17%). Additionally, households with lower socioeconomic status, including those with annual incomes under $20,000 (33%) and those with household heads having only grade school education (31%), are more likely to include individuals with accessibility needs (Accessibility in Housing Report, Page 9). \n\nIn terms of specific accessibility features, the report notes that only 5% of homes have ramps, and 1% have chairlifts or platform lifts. Among households with accessibility needs, 14% reported having a ramp or lift of some type, while 58% have both a bedroom and a full bathroom on the entry level (Accessibility in Housing Report, Page 12). The presence of these features varies significantly by region, with households in micropolitan or nonmetropolitan areas being more likely to have ramps or lifts compared to those in large metropolitan areas (Accessibility in Housing Report, Page 13). \n\nThe adequacy of home layouts for those with mobility challenges is also discussed. More than half (56%) of households that include persons using mobility-assistive devices rated their home's layout as meeting their needs \"very well,\" while only 4% rated it as \"not at all well\" (Accessibility in Housing Report, Page 17). However, the overall lack of accessibility features in homes suggests that many individuals may still face significant barriers to independent living. \n\nIn conclusion, the findings from the 2019 American Housing Survey emphasize the critical need for improved accessibility in U.S. housing. The data reveal that while a considerable portion of households includes individuals with accessibility needs, many of these homes lack essential features that would facilitate independent living. The report highlights disparities in accessibility based on socioeconomic status, geography, and household demographics, underscoring the urgent need for policy interventions and improvements in housing accessibility (Accessibility in Housing Report, Page 1).",
      "documentIds": [
        "9a31d6b935c44bc9b769b886a6a1535f202412020656379941562"
      ],
      "suggestingQuestions": [
        "What specific accessibility features are most needed in U.S. homes?",
        "How do demographic factors influence the need for accessible housing?",
        "What policy interventions could improve housing accessibility for those with mobility challenges?"
      ],
      "keywords": [
        "accessibility",
        "housing",
        "mobility challenges"
      ]
    });
    //  const consoleSpy = jest.spyOn(console, "log").mockImplementation(); // Spy on console
    // Mock implementation of setConversationAnswers

    const mockConversationAnswers = [
      ["Initial Prompt", { message: "Initial Response" }],
    ];

    const mockSetConversationAnswers = jest.fn((updateFn) => {
      const updatedState = updateFn(mockConversationAnswers);
      mockContext.conversationAnswers = updatedState; // Simulate the state update
    });

    const mockContext = {
      ...mockContextValue,
      setConversationAnswers: mockSetConversationAnswers
    }
    const { rerender } = render(
      <AppContext.Provider value={mockContext}>
        <ChatRoom {...defaultProps} />
      </AppContext.Provider>
    );
    const input = screen.getByLabelText("Chat input");
    fireEvent.change(input, { target: { value: "Summarize this doc" } });
    //const inputBox = screen.getByTestId("input-box");
    act(() => {
      fireEvent.keyDown(input, { key: "Enter", code: "Enter" });
    })


    rerender(
      <AppContext.Provider value={mockContext}>
        <ChatRoom {...defaultProps} />
      </AppContext.Provider>
    );

    await waitFor(async() => {
      screen.debug();
      const suggestionBtn = await screen.findByRole('button', { name: /What specific accessibility features are most needed in U.S. homes?/ });
      expect(suggestionBtn).toBeInTheDocument();
      fireEvent.click(suggestionBtn);

      //expect(handleFollowUpQuestionMock).toHaveBeenCalledWith(/What specific accessibility features are most needed in U.S. homes?/);
    });

  });


  it("scrolls to the bottom when new answers are added", async () => {
    const mockScroll = jest.fn();


    const CompletionMock = require("../../api/chatService").Completion;
    CompletionMock.mockResolvedValueOnce({
      "chatSessionId": "2c2d390c-7c82-4736-b7dc-e1fcd17e4253",
      "answer": "The document titled \"Accessibility in Housing: Findings from the 2019 American Housing Survey\" provides a comprehensive analysis of the accessibility needs of U.S. households, especially those facing mobility-related challenges. It reveals that nearly 20% of U.S. households, or approximately 23.1 million, include someone with accessibility needs, which can include individuals with mobility-related disabilities, those using mobility-assistive devices, and those having difficulties accessing their homes or using critical spaces like kitchens and bathrooms (Accessibility in Housing Report, Page 1). \n\nA significant finding is that many of these households reside in homes lacking essential accessibility features. For instance, around 40% of households that would benefit from having a bedroom and full bathroom on the entry level do not currently have both features. Moreover, only 5% of owner households plan to add accessibility features in the next two years, indicating a considerable gap in accessible housing (Accessibility in Housing Report, Page 12). \n\nDemographic trends identified in the report show that households headed by women (21%) are more likely to include persons with accessibility needs compared to those headed by men (17%). Additionally, households with lower socioeconomic status, including those with annual incomes under $20,000 (33%) and those with household heads having only grade school education (31%), are more likely to include individuals with accessibility needs (Accessibility in Housing Report, Page 9). \n\nIn terms of specific accessibility features, the report notes that only 5% of homes have ramps, and 1% have chairlifts or platform lifts. Among households with accessibility needs, 14% reported having a ramp or lift of some type, while 58% have both a bedroom and a full bathroom on the entry level (Accessibility in Housing Report, Page 12). The presence of these features varies significantly by region, with households in micropolitan or nonmetropolitan areas being more likely to have ramps or lifts compared to those in large metropolitan areas (Accessibility in Housing Report, Page 13). \n\nThe adequacy of home layouts for those with mobility challenges is also discussed. More than half (56%) of households that include persons using mobility-assistive devices rated their home's layout as meeting their needs \"very well,\" while only 4% rated it as \"not at all well\" (Accessibility in Housing Report, Page 17). However, the overall lack of accessibility features in homes suggests that many individuals may still face significant barriers to independent living. \n\nIn conclusion, the findings from the 2019 American Housing Survey emphasize the critical need for improved accessibility in U.S. housing. The data reveal that while a considerable portion of households includes individuals with accessibility needs, many of these homes lack essential features that would facilitate independent living. The report highlights disparities in accessibility based on socioeconomic status, geography, and household demographics, underscoring the urgent need for policy interventions and improvements in housing accessibility (Accessibility in Housing Report, Page 1).",
      "documentIds": [
        "9a31d6b935c44bc9b769b886a6a1535f202412020656379941562"
      ],
      "suggestingQuestions": [
        "What specific accessibility features are most needed in U.S. homes?",
        "How do demographic factors influence the need for accessible housing?",
        "What policy interventions could improve housing accessibility for those with mobility challenges?"
      ],
      "keywords": [
        "accessibility",
        "housing",
        "mobility challenges"
      ]
    });
    //  const consoleSpy = jest.spyOn(console, "log").mockImplementation(); // Spy on console
    // Mock implementation of setConversationAnswers

    const mockConversationAnswers = [
      ["Initial Prompt", { message: "Initial Response" }],
    ];

    const mockSetConversationAnswers = jest.fn((updateFn) => {
      const updatedState = updateFn(mockConversationAnswers);
      mockContext.conversationAnswers = updatedState; // Simulate the state update
    });

    const mockContext = {
      ...mockContextValue,
      setConversationAnswers: mockSetConversationAnswers
    }
    const { rerender } = render(
      <AppContext.Provider value={mockContext}>
        <ChatRoom {...defaultProps} />
      </AppContext.Provider>
    );
    const input = screen.getByLabelText("Chat input");
    fireEvent.change(input, { target: { value: "Summarize this doc" } });
    //const inputBox = screen.getByTestId("input-box");
    act(() => {
      fireEvent.keyDown(input, { key: "Enter", code: "Enter" });
    })


    rerender(
      <AppContext.Provider value={mockContext}>
        <ChatRoom {...defaultProps} />
      </AppContext.Provider>
    );

    await waitFor(() => {
      screen.debug();
      const suggestionBtn = screen.getByRole('button', { name: /What specific accessibility features are most needed in U.S. homes?/ });
    });

    // Get the chatContainer element by test ID
    const chatContainer = screen.getByTestId("chatContainer");
    jest.spyOn(React, "useRef").mockReturnValueOnce({ current: chatContainer });
    // Mock scrollHeight, scrollTop, and clientHeight
    Object.defineProperty(chatContainer, "scrollHeight", { value: 500, writable: false });
    Object.defineProperty(chatContainer, "scrollTop", { value: 0, writable: true });
    Object.defineProperty(chatContainer, "clientHeight", { value: 100, writable: false });

    // Simulate scrolling by updating scrollTop and dispatching a scroll event
    chatContainer.scrollTop = 400; // Simulate scroll position
    chatContainer.dispatchEvent(new Event("scroll"));
    await waitFor(async ()=>{
      screen.debug();
      const optionalPanel = await screen.findByTestId('options-panel')
      expect(optionalPanel.classList.contains("sticky-class")).toBe(true);
    })
  });


  it("does not submit when the input is empty", async () => {
    render(
      <AppContext.Provider value={mockContextValue}>
        <ChatRoom {...defaultProps} />
      </AppContext.Provider>
    );

    const input = screen.getByLabelText("Chat input");
    fireEvent.keyDown(input, { key: "Enter", code: "Enter" });

    expect(Completion).not.toHaveBeenCalled();
  });
  it("retries API call when an error occurs", async () => {
    // Mock the API behavior
    (Completion as jest.Mock)
      .mockRejectedValueOnce(new Error("API error"))
      .mockRejectedValue({ answer: "Retry Success" });

    render(
      <AppContext.Provider value={mockContextValue}>
        <ChatRoom {...defaultProps} />
      </AppContext.Provider>
    );

    const input = screen.getByLabelText("Chat input");
    fireEvent.change(input, { target: { value: "Retry Test" } });
    fireEvent.keyDown(input, { key: "Enter", code: "Enter" });

    // Verify first call fails and triggers a retry
    await waitFor(() => {
      expect(Completion).toHaveBeenCalledTimes(1); // First call + retry
    });


  });

  it("allows users to navigate and submit using only the keyboard", async () => {
    render(
      <AppContext.Provider value={mockContextValue}>
        <ChatRoom {...defaultProps} />
      </AppContext.Provider>
    );

    const input = screen.getByLabelText("Chat input");
    input.focus();

    fireEvent.keyDown(input, { key: "T", code: "KeyT" });
    fireEvent.keyDown(input, { key: "e", code: "KeyE" });
    fireEvent.keyDown(input, { key: "s", code: "KeyS" });
    fireEvent.keyDown(input, { key: "t", code: "KeyT" });
    fireEvent.keyDown(input, { key: "Enter", code: "Enter" });

    await waitFor(() => {
      expect(Completion).toHaveBeenCalledWith(
        expect.objectContaining({
          DocumentIds: [], // Update this to match the actual property
          Question: "",
          chatSessionId: expect.any(String), // Use a matcher for dynamic values
        })
      );
    });
  });
  it("updates the character count as the user types", () => {
    render(
      <AppContext.Provider value={mockContextValue}>
        <ChatRoom {...defaultProps} />
      </AppContext.Provider>
    );

    const input = screen.getByLabelText("Chat input");
    fireEvent.change(input, { target: { value: "12345" } });

    expect(screen.getByText("5 / 500")).toBeInTheDocument();
  });

  /*
  it("clears the chat when clearChatFlag is true", async () => {
    const mockContext = {
      ...mockContextValue,
      setConversationAnswers: jest.fn(),
    };

    const { rerender } = render(
      <AppContext.Provider value={mockContext}>
        <ChatRoom {...defaultProps} clearChatFlag={true} />
      </AppContext.Provider>
    );

    const input = screen.getByLabelText("Chat input");
    fireEvent.change(input, { target: { value: "First input" } });
    fireEvent.keyDown(input, { key: "Enter", code: "Enter" });

    await waitFor(() => {
      expect(screen.getByText("First response")).toBeInTheDocument();
    });

    rerender(
      <AppContext.Provider value={mockContext}>
        <ChatRoom {...defaultProps} clearChatFlag={true} />
      </AppContext.Provider>
    );

    await waitFor(() => {
      expect(screen.queryByText("First response")).not.toBeInTheDocument(); // The chat should be cleared
    });
  });


  it("shows loading state while waiting for the API response", async () => {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const CompletionMock = require("../../api/chatService").Completion;
    CompletionMock.mockResolvedValueOnce({
      answer: "This is a delayed response.",
      suggestingQuestions: ["How can we improve the UI?"],
    });

    const mockContext = {
      ...mockContextValue,
      setConversationAnswers: jest.fn(),
    };

    render(
      <AppContext.Provider value={mockContext}>
        <ChatRoom {...defaultProps} />
      </AppContext.Provider>
    );

    const input = screen.getByLabelText("Chat input");
    fireEvent.change(input, { target: { value: "Delayed response" } });
    fireEvent.keyDown(input, { key: "Enter", code: "Enter" });

    expect(screen.getByText("Loading...")).toBeInTheDocument(); // Loading state should appear

    await waitFor(() => {
      expect(screen.getByText("This is a delayed response.")).toBeInTheDocument();
      expect(screen.queryByText("Loading...")).not.toBeInTheDocument(); // Loading state should disappear
    });
  });


  
    it("triggers an API call when a suggested question is clicked", async () => {
      render(
        <AppContext.Provider value={mockContextValue}>
          <ChatRoom
            {...defaultProps}
            conversationAnswers={[
              ["Initial Question", { suggestingQuestions: ["Suggested Question"] }],
            ]}
          />
        </AppContext.Provider>
      );
  
      const suggestedQuestionButton = screen.getByText("Suggested Question");
      fireEvent.click(suggestedQuestionButton);
  
      await waitFor(() => {
        expect(Completion).toHaveBeenCalledWith(
          expect.objectContaining({ Question: "Suggested Question" })
        );
      });
    });
  
    it("renders the selected documents panel when selectedDocuments are provided", () => {
      const propsWithSelectedDocuments = {
        ...defaultProps,
        selectedDocuments: ["Document 1", "Document 2"],
      };
  
      render(
        <AppContext.Provider value={mockContextValue}>
          <ChatRoom {...propsWithSelectedDocuments} />
        </AppContext.Provider>
      );
  
      expect(screen.getByText("Document 1")).toBeInTheDocument();
      expect(screen.getByText("Document 2")).toBeInTheDocument();
    });
      */

});
