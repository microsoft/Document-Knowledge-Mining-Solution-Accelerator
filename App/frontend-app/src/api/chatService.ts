import { ChatApiResponse, ChatRequest, FeedbackRequest } from "./apiTypes/chatTypes";
import { httpClient } from "../utils/httpClient/httpClient";

/**
 * Chat completion service for sending messages and receiving AI responses
 */
export async function Completion(request: ChatRequest): Promise<ChatApiResponse> {
    try {
        const response: ChatApiResponse = await httpClient.post(`/chat`, request);
        
        // Basic validation of response structure
        if (!response || typeof response.answer !== 'string') {
            throw new Error('Invalid response format from chat service');
        }
        
        return response;
    } catch (error) {
        console.error('Chat completion failed:', error);
        throw error;
    }
}

/**
 * Submit user feedback for chat responses
 */
export async function PostFeedback(request: FeedbackRequest): Promise<boolean> {
    try {
        const response: boolean = await httpClient.post(`/api/Chat/Feedback`, request);
        return response;
    } catch (error) {
        console.error('Feedback submission failed:', error);
        throw error;
    }
}