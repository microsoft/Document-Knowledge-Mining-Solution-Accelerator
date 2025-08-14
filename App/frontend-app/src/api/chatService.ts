import { ChatApiResponse, ChatRequest, FeedbackRequest } from "./apiTypes/chatTypes";
import { httpClient } from "../utils/httpClient/httpClient";

export async function Completion(request: ChatRequest): Promise<ChatApiResponse> {
    const response: ChatApiResponse = await httpClient.post(`/chat`, request);
    return response;
}

export async function PostFeedback(request: FeedbackRequest): Promise<boolean> {
    const response: boolean = await httpClient.post(`/api/Chat/Feedback`, request);
    return response;
}