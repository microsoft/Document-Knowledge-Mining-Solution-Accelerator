export interface ChatOptions {
    model?: string;
    source?: string;
    temperature?: number;
    maxTokens?: number;
}

export type ChatMessage = {
    role?: string;
    content: string;
};

export type HistoryItem = {
    role: string;
    content: string;
    datetime?: Date;
  };
  
export type History = HistoryItem[];

export type ChatRequest = {
    Question: string;
    chatSessionId: string;
    DocumentIds: string[];
};

export type ChatApiResponse = {
    answer: string;
    documentIds: string[];
    suggestingQuestions: string[];
    keywords: string[];
}

// UI-side wrapper around ChatApiResponse used to track per-message client state
// (e.g., overlapping-request prevention, error rendering). Server responses do
// not include these fields; they are populated and consumed by the chat UI only.
export type ChatUiResponse = ChatApiResponse & {
    requestId?: string;
    pending?: boolean;
    error?: boolean;
}

export type Reference = {
    title: string;
    parent_id: string;
    chunk_id: string;
    chunk_text: string;
};

export type AskResponse = {
    answer: string;
};

export interface FeedbackRequest {
    history: History;
    options: ChatOptions;
    sources: Reference[];    
    filterByDocumentIds?: string[];
    isPositive?: boolean;
    comment?: string;
    reason?: string;
    groundTruthAnswer?: string;
    documentURLs?: string[];
    chunkTexts?: string[];    
}


