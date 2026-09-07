import { ChatApiResponse, ChatRequest, FeedbackRequest } from "./apiTypes/chatTypes";
import { httpClient } from "../utils/httpClient/httpClient";


// export async function Completion(request: ChatRequest){
//     const response: ChatApiResponse = await httpClient.post(`https://dpsapi.eastus2.cloudapp.azure.com/chat`, request);

//     return response;
// }

function getDisplayAnswer(answer: unknown): string {
    let answerText: string;
    if (typeof answer === "string") {
        answerText = answer;
    } else if (answer === null || answer === undefined) {
        answerText = "No answer was returned by the chat service. Please try again.";
    } else if (typeof answer === "object") {
        try {
            answerText = JSON.stringify(answer) ?? String(answer);
        } catch {
            answerText = String(answer);
        }
    } else {
        answerText = String(answer);
    }

    const content = answerText
        .trim()
        .replace(/^```json\s*/i, "")
        .replace(/\s*```$/, "");

    try {
        const parsed: unknown = JSON.parse(content);
        if (
            typeof parsed === "object" &&
            parsed !== null &&
            "response" in parsed &&
            typeof parsed.response === "string"
        ) {
            return parsed.response;
        }
    } catch (error) {
        if (!(error instanceof SyntaxError)) {
            throw error;
        }
        const responseMatch = content.match(/"response"\s*:\s*"([\s\S]*?)"\s*,\s*"followings"\s*:/i);
        if (responseMatch) {
            return responseMatch[1]
                .replace(/\\n/g, "\n")
                .replace(/\\"/g, '"');
        }
    }

    return answerText;
}

export async function Completion(request: ChatRequest): Promise<ChatApiResponse> {
    try {
      // Assuming httpClient is similar to Axios, we pass the request body and expect a ChatApiResponse
      const response: ChatApiResponse = await httpClient.post(
        `${import.meta.env.VITE_API_ENDPOINT}/chat`, 
        request,
        {
            headers: {
              'Content-Type': 'application/json', // Ensure JSON format
            },
          }
      );
  
      return { ...response, answer: getDisplayAnswer(response.answer) };
    } catch (error) {
      console.error('Error during API request:', error);
      throw new Error('Failed to fetch the API response.');
    }
  }
  

export async function PostFeedback(request: FeedbackRequest){
    const response: boolean = await httpClient.post(`${window.ENV.API_URL}/api/Chat/Feedback`, request);

    return response;
}