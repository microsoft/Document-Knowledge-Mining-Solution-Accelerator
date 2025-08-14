import { Fragment, useContext, useEffect, useRef, useState } from "react";
import { ChatApiResponse, ChatOptions, ChatRequest, History, Reference } from "../../api/apiTypes/chatTypes";
import { OptionsPanel } from "./optionsPanel";
import {
    Button,
    Dialog,
    DialogBody,
    DialogContent,
    DialogSurface,
    DialogTitle,
    Tag,
    makeStyles,
} from "@fluentui/react-components";
import { DocDialog } from "../documentViewer/documentViewer";
import { Textarea } from "@fluentai/textarea";
import type { TextareaSubmitEvents, TextareaValueData } from "@fluentai/textarea";
import { CopilotChat, UserMessage, CopilotMessage } from "@fluentai/react-copilot-chat";
import { ChatAdd24Regular } from "@fluentui/react-icons";
import styles from "./chatRoom.module.scss";
import { CopilotProvider, Suggestion } from "@fluentai/react-copilot";
import { Tokens } from "../../api/apiTypes/singleDocument";
import { Completion, PostFeedback } from "../../api/chatService";
import { FeedbackForm } from "./FeedbackForm";
import { Document } from "../../api/apiTypes/documentResults";
import { AppContext } from "../../AppContext";
import { useTranslation } from "react-i18next";
import { marked } from 'marked';
const DefaultChatModel = "chat_4o";

const useStyles = makeStyles({
    tooltipContent: {
        maxWidth: "500px",
    },
});

interface ChatRoomProps {
    searchResultDocuments: Document[];
    disableOptionsPanel?: boolean;
    selectedDocuments: Document[];
    chatWithDocument: Document[];
    clearChatFlag: boolean;

}

export function ChatRoom({ searchResultDocuments, selectedDocuments, chatWithDocument, disableOptionsPanel, clearChatFlag }: ChatRoomProps) {
    const { t } = useTranslation();
    const [chatSessionId, setChatSessionId] = useState<string | null>(null);
    const [isLoading, setIsLoading] = useState<boolean>(false);
    const [disableSources, setDisableSources] = useState<boolean>(false);
    const [model, setModel] = useState<string>("chat_35");
    const [source, setSource] = useState<string>("rag");
    const [temperature, setTemperature] = useState<number>(0.8);
    const [maxTokens, setMaxTokens] = useState<number>(750);
    const [selectedDocument, setSelectedDocument] = useState<Document[]>(chatWithDocument);
    const [button, setButton] = useState<string>("");
    const [dialogMetadata, setDialogMetadata] = useState<Document | null>(null);
    const [isDialogOpen, setIsDialogOpen] = useState(false);
    const [tokens, setTokens] = useState<Tokens | null>(null);
    const [open, setOpen] = useState(false);
    const [isFeedbackFormOpen, setIsFeedbackFormOpen] = useState<boolean>(false);
    const [options, setOptions] = useState<ChatOptions>({
        model: model,
        source: source,
        temperature: temperature,
        maxTokens: maxTokens,
    });
    const [referencesForFeedbackForm, setReferencesForFeedbackForm] = useState<Reference[]>([]);
    const [textAreaValue, setTextAreaValue] = useState("");
    const [textareaKey, setTextareaKey] = useState(0);
    const inputRef = useRef<HTMLTextAreaElement>(null);
    const [allChunkTexts, setAllChunkTexts] = useState<string[]>([]);

    const { conversationAnswers, setConversationAnswers } = useContext(AppContext);
    const [isSticky, setIsSticky] = useState(false);
    const optionsBottom = useRef<HTMLDivElement>(null);

    useEffect(() => {
        setOptions({
            model: model,
            source: source,
            temperature: temperature,
            maxTokens: maxTokens,
        });
    }, [model, source, temperature, maxTokens]);

    useEffect(() => {
        setTimeout(() => {
            inputRef.current?.focus();
        }, 0);
    }, []);

    useEffect(() => {
        handleModelChange(DefaultChatModel)
    }, []);

    // Effect to clear chat when clearChat prop changes
    useEffect(() => {
        if (clearChatFlag) {
            clearChat();
        }
    }, [clearChatFlag]);



    const chatContainerRef = useRef<HTMLDivElement>(null);
    function scrollToBottom() {
        if (chatContainerRef.current) {
            chatContainerRef.current.scrollTop = chatContainerRef.current.scrollHeight;
        }
    }

    useEffect(scrollToBottom, [conversationAnswers]);

    function removeNewlines(text: string) {
        return text.replace(/\\n/g, '\n');
    }

    const makeApiRequest = async (question: string) => {
        setTextAreaValue("");
        setTextareaKey(prev => prev + 1);
        setDisableSources(true);
        setIsLoading(true);

        const userTimestamp = new Date();
        
        let currentSessionId = chatSessionId;
        if (!currentSessionId) {
            const newSessionId = uuidv4();
            setChatSessionId(newSessionId);
            currentSessionId = newSessionId;
        }

        setConversationAnswers((prevAnswers) => [
            ...prevAnswers,
            [question, {
                answer: t('components.chat.fetching-answer'), 
                suggestingQuestions: [],
                documentIds: [],
                keywords: []
            }],
        ]);

        const formattedDocuments = selectedDocuments.map(doc => doc.documentId);

        try {
            const request: ChatRequest = {
                Question: question,
                chatSessionId: currentSessionId,
                DocumentIds: button === "All Documents" ? [] : formattedDocuments
            };

            const response: ChatApiResponse = await Completion(request);
            const answerTimestamp = new Date();

            if (response && response.answer) {
                const formattedAnswer = removeNewlines(response.answer);
                const chatResp = await marked.parse(formattedAnswer);

                setConversationAnswers((prevAnswers) => {
                    const newAnswers = [...prevAnswers];
                    newAnswers[newAnswers.length - 1] = [question, { ...response, answer: chatResp }, userTimestamp, answerTimestamp];
                    return newAnswers;
                });
            }
        } catch (error) {
            const answerTimestamp = new Date();
            setConversationAnswers((prevAnswers) => {
                const newAnswers = [...prevAnswers];
                newAnswers[newAnswers.length - 1] = [question, { 
                    answer: "Sorry, an error occurred while processing your request. Please try again later.", 
                    suggestingQuestions: [],
                    documentIds: [],
                    keywords: []
                }, userTimestamp, answerTimestamp];
                return newAnswers;
            });
        } finally {
            setIsLoading(false);
            setTimeout(() => {
                inputRef.current?.focus();
            }, 0);
        }
    };

    const history: History = conversationAnswers
        .map(([prompt, response, userTimestamp, answerTimestamp]) => {
            if (response) {
                return [
                    { role: "user", content: prompt, datetime: userTimestamp },
                    { role: "assistant", content: response.answer, datetime: answerTimestamp },
                ];
            } else {
                return [];
            }
        })
        .flat();

    const clearChat = () => {
        setTextAreaValue("");
        setConversationAnswers((prevAnswers) => []);
        setChatSessionId(null);
    };

    const handleModelChange = (model: string) => {
        setModel(model);
    };

    const handleSourceChange = (button: string, source: string) => {
        setSource(source);
        setButton(button);
    };

    const handleFollowUpQuestion = async (question: string) => {
        await makeApiRequest(question);
    };

    function handleSend(ev: TextareaSubmitEvents, data: TextareaValueData) {
        if (data.value.trim() != '') {
            makeApiRequest(data.value);
        }
    }

    const handleOpenFeedbackForm = (sources: Reference[]) => {
        setReferencesForFeedbackForm(sources);
        setIsFeedbackFormOpen(true);
    };

    const handleDialogClose = () => {
        setIsDialogOpen(false);
    };

    const handleFeedbackFormClose = () => {
        setIsFeedbackFormOpen(false);
    };

    const handlePositiveFeedback = async (sources: Reference[]) => {
        setIsLoading(true);

        const request = {
            isPositive: true,
            reason: "Correct answer",
            comment: "",
            history: history,
            options: options,
            sources: sources.map((ref) => ({ ...ref })),
            filterByDocumentIds:
                button === "Selected Documents"
                    ? selectedDocuments.map((document) => document.documentId)
                    : button === "Search Results"
                        ? searchResultDocuments.map((document) => document.documentId)
                        : button === "Selected Document"
                            ? [selectedDocument[0]?.documentId || ""]
                            : [],
            groundTruthAnswer: "",
            documentURLs: [],
            chunkTexts: [],
        };

        try {
            const response = await PostFeedback(request);

            if (response) {
                setIsLoading(false);
                setOpen(true);
            }
        } catch (error) {
            setIsLoading(false);
        }
    };

    const handleSubmittedFeedback = (submitted: boolean) => {
        if (submitted) {
            setIsFeedbackFormOpen(false);
            setIsLoading(false);
            setOpen(true);
        } else {
            setIsFeedbackFormOpen(false);
            setIsLoading(false);
        }
    };

    useEffect(() => {
        const optionBottomElement = optionsBottom.current;
        const chatContainer = chatContainerRef.current;
        const handleScroll = () => {
            if (!chatContainer || !optionBottomElement) {
                return;
            }
            const containerTop = chatContainer.getBoundingClientRect().top;
            const bottomOffset = 50
            const OptionsBottomElementTop = optionBottomElement.getBoundingClientRect().top - bottomOffset;
            if (OptionsBottomElementTop < containerTop) {
                setIsSticky(true);
            } else {
                setIsSticky(false);
            }
        };
        if (chatContainer) {
            chatContainer.addEventListener("scroll", handleScroll);
        }
        return () => {
            if (chatContainer) {
                chatContainer.removeEventListener("scroll", handleScroll);
            }
        };
    }, []);

    return (
        <div className="flex w-full flex-1 flex-col items-stretch grey-background !m-0 !p-0 !max-w-none">
            {isDialogOpen && (
                <DocDialog
                    metadata={dialogMetadata as Document}
                    isOpen={isDialogOpen}
                    onClose={handleDialogClose}
                    allChunkTexts={allChunkTexts} clearChatFlag={false}                />
            )}
            <div ref={chatContainerRef} className={`no-scrollbar flex w-full flex-1 flex-col overflow-auto !max-w-none !m-0 !p-0 ${styles["chat-container"]}`}>
            {!disableOptionsPanel && (
                <OptionsPanel
                    className={`px-4 mx-0 my-10 flex flex-col items-center justify-center rounded-xl bg-neutral-500 bg-opacity-10 shadow-md outline outline-1 outline-transparent w-full`}
                    onModelChange={handleModelChange}
                    onSourceChange={handleSourceChange}
                    disabled={disableSources}
                    selectedDocuments={selectedDocuments}
                    isSticky={isSticky}
                />
            )}
            <div ref={optionsBottom}></div>
                <CopilotProvider className={`${styles.chatMessagesContainer} w-full !max-w-none`}>
                    <CopilotChat>
                        {conversationAnswers.map(([prompt, response], index) => (
                            <Fragment key={index}>
                                <UserMessage className="my-3 ml-auto" /* key={`${index}-user`} */>
                                    <div dangerouslySetInnerHTML={{ __html: prompt.replace(/\n/g, "<br />") }} />
                                </UserMessage>
                                <CopilotMessage
                                    className="mr-auto"
                                    progress={{ value: undefined }}
                                    // key={`${index}-chat`}
                                    isLoading={index === conversationAnswers.length - 1 && isLoading}
                                >
                                    <div
                                        dangerouslySetInnerHTML={{ __html: response.answer }}
                                    />
                                    {response.suggestingQuestions?.filter((o) => o).length > 0 && (
                                        <div>
                                            <p className="mt-6">{t("components.chat.suggested-q-title")}</p>
                                            {response.suggestingQuestions.map((followUp, index) => (
                                                <Suggestion
                                                    key={index}
                                                    className={`!mr-2 !mt-2 !text-base ${isLoading ? "pointer-events-none text-gray-400" : ""}`}
                                                    onClick={() => {
                                                        if (!isLoading) {
                                                            handleFollowUpQuestion(followUp);
                                                        }
                                                    }}
                                                >
                                                    {followUp}
                                                </Suggestion>
                                            ))}
                                        </div>
                                    )}

                                    {!isLoading && (
                                        <div className="mt-6">
                                            <div style={{ display: "flex", flexDirection: "row-reverse" }}>
                                                <Tag 
                                                    size="extra-small" 
                                                    className="!bg-transparent !text-gray-500 !border-none !p-0 !flex !flex-row-reverse"
                                                >
                                                    {t("components.dialog-content.ai-generated-tag-incorrect")}
                                                </Tag>
                                            </div>
                                        </div>
                                    )}

                                    {isFeedbackFormOpen && (
                                        <FeedbackForm
                                            isOpen={isFeedbackFormOpen}
                                            onClose={handleFeedbackFormClose}
                                            history={history}
                                            chatOptions={options}
                                            sources={referencesForFeedbackForm}
                                            filterByDocumentIds={
                                                button === "Selected Document"
                                                    ? selectedDocument.map((document) => document.documentId)
                                                    : button === "Search Results"
                                                    ? searchResultDocuments.map((document) => document.documentId)
                                                    : button === "Selected Documents"
                                                    ? selectedDocuments.map((document) => document.documentId)
                                                    : []
                                            }
                                            setSubmittedFeedback={handleSubmittedFeedback}
                                        />
                                    )}

                                    <Dialog open={open} onOpenChange={(event, data) => setOpen(data.open)}>
                                        <DialogSurface>
                                            <DialogBody>
                                                <DialogTitle>{t('components.feedback-form.feedback-thank-you')}</DialogTitle>
                                                <DialogContent>
                                                {t('components.feedback-form.feedback-info')}
                                                </DialogContent>
                                            </DialogBody>
                                        </DialogSurface>
                                    </Dialog>
                                </CopilotMessage>
                            </Fragment>
                        ))}
                    </CopilotChat>
                </CopilotProvider>
            </div>

            <div className={`${styles.questionContainer} mb-6 mt-6 flex w-full justify-center px-2`}>
                <Button
                    className={styles["new-topic"]}
                    shape="circular"
                    appearance="primary"
                    icon={<ChatAdd24Regular />}
                    onClick={() => {
                        clearChat();
                        setDisableSources(false);
                        setSelectedDocument([]);
                        setIsLoading(false);
                        setChatSessionId(null);
                        setTextAreaValue("");
                        setTextareaKey(prev => prev + 1);
                    }}
                >
                    {t('components.chat.new-topic')}
                </Button>

                <Textarea
                    key={textareaKey}
                    ref={inputRef}
                    value={textAreaValue}
                    className="!ml-2 max-h-48 w-full !max-w-none"
                    onChange={(_ev, newValue) => setTextAreaValue(newValue.value)}
                    showCount
                    aria-label="Chat input"
                    placeholder={t('components.chat.input-placeholder')}
                    disabled={isLoading}
                    onSubmit={handleSend}
                    disableSend = {textAreaValue.trim().length === 0 || isLoading}
                    contentAfter={undefined}
                />
            </div>
        </div >
    );
}
function uuidv4() {
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function (c) {
        const r = Math.random() * 16 | 0, v = c === 'x' ? r : (r & 0x3 | 0x8);
        return v.toString(16);
    });
}

