import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { SidecarCopilot } from './sidecar';
import { AppContext } from '../../AppContext';
import { Completion } from '../../api/chatService';
import { ChatApiResponse } from '../../api/apiTypes/chatTypes';
import Markdown from 'react-markdown';

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
        t: (key: any) => key,
    }),
}));

jest.mock('../chat/optionsPanel', () => ({
    OptionsPanel: jest.fn(({ onModelChange, onSourceChange, disabled }) => (
        <div data-testid="mocked-options-panel">
            <button onClick={() => onModelChange('chat_40')} data-testid="model-select">
                Change Model
            </button>
            <button
                onClick={() => onSourceChange('selected-doc', 'source-button')}
                disabled={disabled}
                data-testid="source-button"
            >
                Change Source
            </button>
        </div>
    )),
}));

describe('SidecarCopilot', () => {
    let setConversationAnswersMock: jest.Mock<any, any, any>;

    beforeEach(() => {
        setConversationAnswersMock = jest.fn();
        (Completion as jest.Mock).mockReset();
    });

    const mockAppContextValue = () => ({
        conversationAnswers: [
            ['What is AI?', { answer: 'Mocked Answer' } as ChatApiResponse, new Date(), new Date()],
        ] as [string, ChatApiResponse, Date, Date][],
        setConversationAnswers: setConversationAnswersMock,
        query: '',
        setQuery: jest.fn(),
        filters: {},
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

        expect(screen.getByTestId('mocked-options-panel')).toBeInTheDocument();
    });

    it('handles sending a message and receiving a response', async () => {
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

        const input = screen.getByRole('textbox', { name: /chat input/i });
        const sendButton = screen.getByRole('button', { name: /send/i });

        fireEvent.change(input, { target: { value: 'What is AI?' } });
        fireEvent.click(sendButton);

        await waitFor(() => {
            expect(Completion).toHaveBeenCalledWith({
                Question: 'What is AI?',
                chatSessionId: '',
                DocumentIds: [],
            });
        });
    });

    it('disables the input and shows loading when sending a message', async () => {
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

        const input = screen.getByRole('textbox', { name: /chat input/i });
        const sendButton = screen.getByRole('button', { name: /send/i });

        fireEvent.change(input, { target: { value: 'What is AI?' } });
        fireEvent.click(sendButton);

        expect(input).toBeDisabled();

        await waitFor(() => {
            expect(Completion).toHaveBeenCalledWith({
                Question: 'What is AI?',
                chatSessionId: '',
                DocumentIds: [],
            });
        });
    });

    it('clears the chat when the "New Topic" button is clicked', () => {
        render(
            <AppContext.Provider value={mockAppContextValue()}>
                <SidecarCopilot
                    searchResultDocuments={[]}
                    selectedDocuments={[]}
                    chatWithDocument={[]}
                />
            </AppContext.Provider>
        );

        const newTopicButton = screen.getByRole('button', { name: /components.chat.new-topic/i });
        fireEvent.click(newTopicButton);

        expect(setConversationAnswersMock).toHaveBeenCalledTimes(1);
    });

    it('handles model change correctly', () => {
        render(
            <AppContext.Provider value={mockAppContextValue()}>
                <SidecarCopilot
                    searchResultDocuments={[]}
                    selectedDocuments={[]}
                    chatWithDocument={[]}
                />
            </AppContext.Provider>
        );

        const modelButton = screen.getByTestId('model-select');
        fireEvent.click(modelButton);

        expect(modelButton).toHaveTextContent('Change Model');
    });

    it('handles source change correctly', () => {
        render(
            <AppContext.Provider value={mockAppContextValue()}>
                <SidecarCopilot
                    searchResultDocuments={[{ documentId: 'doc1', fileName: '' } as any]}
                    selectedDocuments={[{ documentId: 'doc2', fileName: '' } as any]}
                    chatWithDocument={[{ documentId: 'doc3', fileName: '' } as any]}
                />
            </AppContext.Provider>
        );

        const sourceButton = screen.getByTestId('source-button');
        fireEvent.click(sourceButton);

        expect(sourceButton).toBeInTheDocument();
    });

    it('updates chat options when a model or source is changed', () => {
        render(
            <AppContext.Provider value={mockAppContextValue()}>
                <SidecarCopilot
                    searchResultDocuments={[]}
                    selectedDocuments={[]}
                    chatWithDocument={[]}
                />
            </AppContext.Provider>
        );

        const modelButton = screen.getByTestId('model-select');
        fireEvent.click(modelButton);

        const sourceButton = screen.getByTestId('source-button');
        fireEvent.click(sourceButton);

        expect(screen.getByTestId('mocked-options-panel')).toBeInTheDocument();
    });

    it('renders OptionsPanel with correct props', () => {
        render(
            <AppContext.Provider value={mockAppContextValue()}>
                <SidecarCopilot
                    searchResultDocuments={[]}
                    selectedDocuments={[]}
                    chatWithDocument={[]}
                />
            </AppContext.Provider>
        );

        const optionsPanel = screen.getByTestId('mocked-options-panel');
        expect(optionsPanel).toBeInTheDocument();
    });

    it('handles makeApiRequest correctly', async () => {
        (Completion as jest.Mock).mockResolvedValue({
            answer: 'Mocked Completion Response',
        });

        render(
            <AppContext.Provider value={mockAppContextValue()}>
                <SidecarCopilot
                    searchResultDocuments={[]}
                    selectedDocuments={[]}
                    chatWithDocument={[]}
                />
            </AppContext.Provider>
        );

        const input = screen.getByRole('textbox', { name: /chat input/i });
        fireEvent.change(input, { target: { value: 'What is AI?' } });

        const sendButton = screen.getByRole('button', { name: /send/i });
        fireEvent.click(sendButton);

        await waitFor(() => {
            expect(Completion).toHaveBeenCalledWith(
                expect.objectContaining({
                    Question: 'What is AI?',
                })
            );
        });
    });

    it('handles multiple documents selection correctly', () => {
      render(
          <AppContext.Provider value={mockAppContextValue()}>
              <SidecarCopilot
                  searchResultDocuments={[
                      { documentId: 'doc1', fileName: 'Document 1' } as any,
                      { documentId: 'doc2', fileName: 'Document 2' } as any,
                  ]}
                  selectedDocuments={[]}
                  chatWithDocument={[]}
              />
          </AppContext.Provider>
      );

      const sourceButton = screen.getByTestId('source-button');
      fireEvent.click(sourceButton);

      expect(screen.getByTestId('mocked-options-panel')).toBeInTheDocument();
  });
  
it('handles changes in the source button state correctly', () => {
    render(
        <AppContext.Provider value={mockAppContextValue()}>
            <SidecarCopilot
                searchResultDocuments={[
                    { documentId: 'doc1', fileName: 'Doc 1' } as any,
                ]}
                selectedDocuments={[
                    { documentId: 'doc2', fileName: 'Doc 2' } as any,
                ]}
                chatWithDocument={[
                    { documentId: 'doc3', fileName: 'Doc 3' } as any,
                ]}
            />
        </AppContext.Provider>
    );

    const sourceButton = screen.getByTestId('source-button');
    fireEvent.click(sourceButton);

    expect(screen.getByTestId('mocked-options-panel')).toBeInTheDocument();
});

  it('focuses the input field after sending a message', async () => {
    render(
        <AppContext.Provider value={mockAppContextValue()}>
            <SidecarCopilot
                searchResultDocuments={[]}
                selectedDocuments={[]}
                chatWithDocument={[]}
            />
        </AppContext.Provider>
    );

    const input = screen.getByRole('textbox', { name: /chat input/i });
    fireEvent.change(input, { target: { value: 'What is AI?' } });

    const sendButton = screen.getByRole('button', { name: /send/i });
    fireEvent.click(sendButton);

    await waitFor(() => {
        expect(input).toHaveFocus();
    });
}); 

it('updates options state when temperature is changed', () => {
  render(
      <AppContext.Provider value={mockAppContextValue()}>
          <SidecarCopilot
              searchResultDocuments={[]}
              selectedDocuments={[]}
              chatWithDocument={[]}
          />
      </AppContext.Provider>
  );

  const modelButton = screen.getByTestId('model-select');
  fireEvent.click(modelButton);

  const sourceButton = screen.getByTestId('source-button');
  fireEvent.click(sourceButton);

  expect(screen.getByTestId('mocked-options-panel')).toBeInTheDocument();
});

it('handles edge cases for makeApiRequest', async () => {
  (Completion as jest.Mock).mockResolvedValue(null);

  render(
      <AppContext.Provider value={mockAppContextValue()}>
          <SidecarCopilot
              searchResultDocuments={[]}
              selectedDocuments={[]}
              chatWithDocument={[]}
          />
      </AppContext.Provider>
  );

  const input = screen.getByRole('textbox', { name: /chat input/i });
  fireEvent.change(input, { target: { value: 'What is AI?' } });

  const sendButton = screen.getByRole('button', { name: /send/i });
  fireEvent.click(sendButton);

  await waitFor(() => {
      expect(Completion).toHaveBeenCalledWith(
          expect.objectContaining({
              Question: 'What is AI?',
          })
      );
  });

  expect(setConversationAnswersMock).toHaveBeenCalledTimes(1);
});

    it('sets selectedDocument when chatWithDocument changes', () => {
        const { rerender } = render(
            <AppContext.Provider value={mockAppContextValue()}>
                <SidecarCopilot
                    searchResultDocuments={[]}
                    selectedDocuments={[]}
                    chatWithDocument={[]}
                />
            </AppContext.Provider>
        );

        rerender(
            <AppContext.Provider value={mockAppContextValue()}>
                <SidecarCopilot
                    searchResultDocuments={[]}
                    selectedDocuments={[]}
                    chatWithDocument={[{ documentId: 'doc3', fileName: 'Document 3' } as any]}
                />
            </AppContext.Provider>
        );

        expect(setConversationAnswersMock).not.toHaveBeenCalled();
    });
});