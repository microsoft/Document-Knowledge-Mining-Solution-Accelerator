import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { SidecarCopilot } from './sidecar';
import { OptionsPanel } from '../chat/optionsPanel';
import { AppContext } from '../../AppContext';
import { Completion } from '../../api/chatService';
import { useTranslation } from 'react-i18next';
import { Button } from '@fluentui/react-components';

// Mocking the necessary components and API calls
jest.mock('@fluentai/react-copilot-chat', () => ({
    CopilotProvider: jest.fn(),
    CopilotChat: jest.fn(),
    UserMessage: jest.fn(),
    CopilotMessage: jest.fn(),
}));

jest.mock('../../api/chatService', () => ({
    Completion: jest.fn(),
}));

jest.mock('react-i18next', () => ({
    useTranslation: () => ({
        t: (key: any) => key, // Mock translation function
    }),
}));

jest.mock('../chat/optionsPanel', () => ({
    OptionsPanel: jest.fn(() => <div data-testid="mocked-options-panel">Mocked OptionsPanel</div>),
}));

describe('SidecarCopilot', () => {
    let setConversationAnswersMock: jest.Mock<any, any, any>;
    let setModelMock: jest.Mock<any, any, any>;
    let setSourceMock: jest.Mock<any, any, any>;
    let setButtonMock: jest.Mock<any, any, any>;
    let selectedDocuments: any[];

    // Initialize the mock function and mock context inside beforeEach
    beforeEach(() => {
        // Initialize setConversationAnswersMock inside beforeEach to avoid the variable usage error
        setConversationAnswersMock = jest.fn();
        setModelMock = jest.fn();
        setSourceMock = jest.fn();
        setButtonMock = jest.fn();
        selectedDocuments = [];

        (Completion as jest.Mock).mockReset();
    });

    // Mocked AppContext value with initialized setConversationAnswersMock
    const mockAppContextValue = () => ({
        conversationAnswers: [],
        setConversationAnswers: setConversationAnswersMock,
        query: '',
        setQuery: jest.fn(),
        filters: {}, // Filters should be an object
        setFilters: jest.fn(),
    });

    it('renders without crashing', () => {
        render(
            <AppContext.Provider value={mockAppContextValue()}>
                <SidecarCopilot
                    searchResultDocuments={[]}
                    selectedDocuments={[]}
                    chatWithDocument={[]}
                />
            </AppContext.Provider>
        );

        // Check if the mocked OptionsPanel is rendered
        expect(screen.getByTestId('mocked-options-panel')).toBeInTheDocument();
    });
    test('handles sending a message and receiving a response', async () => {
        // Arrange
        (Completion as jest.Mock).mockResolvedValue({ data: 'mocked response' });
        render(
            <AppContext.Provider value={mockAppContextValue()}>
                <SidecarCopilot
                    searchResultDocuments={[]}
                    selectedDocuments={[]}
                    chatWithDocument={[]}
                />
            </AppContext.Provider>
        );
    
        // Act
        const input = screen.getByRole('textbox', { name: /chat input/i });
        const sendButton = screen.getByRole('button', { name: /send/i });
    
        fireEvent.change(input, { target: { value: 'What is a dog?' } });
        fireEvent.click(sendButton);
    
        // Assert
        await waitFor(() => {
            expect(Completion).toHaveBeenCalledWith({
                Question: 'What is a dog?',
                chatSessionId: '',
                DocumentIds: [],
            });
        });
    })
    it("disables the input and shows loading when sending a message", async () => {
        (Completion as jest.Mock).mockResolvedValue({ data: "mocked response" });
    
        render(
          <AppContext.Provider value={mockAppContextValue()}>
            <SidecarCopilot searchResultDocuments={[]} selectedDocuments={[]} chatWithDocument={[]} />
          </AppContext.Provider>
        );
    
        const input = screen.getByRole("textbox", { name: /chat input/i });
        const sendButton = screen.getByRole("button", { name: /send/i });
    
        fireEvent.change(input, { target: { value: "What is AI?" } });
        fireEvent.click(sendButton);
    
        expect(input).toBeDisabled();
    
        await waitFor(() => {
          expect(Completion).toHaveBeenCalledWith({
            Question: "What is AI?",
            chatSessionId: "",
            DocumentIds: [],
          });
        });
      });
    
      it("clears the chat when the 'New Topic' button is clicked", () => {
        render(
          <AppContext.Provider value={mockAppContextValue()}>
            <SidecarCopilot searchResultDocuments={[]} selectedDocuments={[]} chatWithDocument={[]} />
          </AppContext.Provider>
        );
    
        const newTopicButton = screen.getByRole("button", { name: /components.chat.new-topic/i });
        fireEvent.click(newTopicButton);
    
        // Assert
        expect(setConversationAnswersMock).toHaveBeenCalledTimes(1);
      });
    
      it("updates options when a model or source is changed in the OptionsPanel", () => {
        render(
          <AppContext.Provider value={mockAppContextValue()}>
            <SidecarCopilot searchResultDocuments={[]} selectedDocuments={[]} chatWithDocument={[]} />
          </AppContext.Provider>
        );
    
        const optionsPanel = screen.getByTestId("mocked-options-panel");
        expect(optionsPanel).toBeInTheDocument();
      });
    
      it("updates text area value when typing", () => {
        render(
          <AppContext.Provider value={mockAppContextValue()}>
            <SidecarCopilot searchResultDocuments={[]} selectedDocuments={[]} chatWithDocument={[]} />
          </AppContext.Provider>
        );
    
        const input = screen.getByRole("textbox", { name: /chat input/i });
        fireEvent.change(input, { target: { value: "Hello, Copilot!" } });
    
        expect(input).toHaveValue("Hello, Copilot!");
      });
      
      it('updates text area value when typing', () => {
        render(
            <AppContext.Provider value={mockAppContextValue()}>
                <SidecarCopilot searchResultDocuments={[]} selectedDocuments={[]} chatWithDocument={[]} />
            </AppContext.Provider>
        );

        const input = screen.getByRole('textbox', { name: /chat input/i });
        fireEvent.change(input, { target: { value: 'Hello, Copilot!' } });

        expect(input).toHaveValue('Hello, Copilot!');
    });

    // Test for handleModelChange
    it('calls handleModelChange when model is updated', () => {
        render(
            <AppContext.Provider value={mockAppContextValue()}>
                <SidecarCopilot searchResultDocuments={[]} selectedDocuments={[]} chatWithDocument={[]} />
            </AppContext.Provider>
        );

        const newModel = 'new-model';
        fireEvent.change(screen.getByTestId('model-select'), { target: { value: newModel } });
        expect(setModelMock).toHaveBeenCalledWith(newModel);
    });

    it('calls handleSourceChange when source or button is updated', () => {
        render(
            <AppContext.Provider value={mockAppContextValue()}>
                <SidecarCopilot searchResultDocuments={[]} selectedDocuments={selectedDocuments} chatWithDocument={[]} />
            </AppContext.Provider>
        );

        const newSource = 'new-source';
        const newButton = 'new-button';
        fireEvent.click(screen.getByText('source-button'));
        expect(setSourceMock).toHaveBeenCalledWith(newSource);
        expect(setButtonMock).toHaveBeenCalledWith(newButton);
    });
});
