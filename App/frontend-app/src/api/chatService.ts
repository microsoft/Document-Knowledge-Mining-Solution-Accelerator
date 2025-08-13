import { ChatApiResponse, ChatRequest, FeedbackRequest } from "./apiTypes/chatTypes";
import { httpClient } from "../utils/httpClient/httpClient";


// export async function Completion(request: ChatRequest){
//     const response: ChatApiResponse = await httpClient.post(`https://dpsapi.eastus2.cloudapp.azure.com/chat`, request);

//     return response;
// }

export async function Completion(request: ChatRequest): Promise<ChatApiResponse> {
    try {
      // Get API endpoint with fallback
      const apiEndpoint = import.meta.env.VITE_API_ENDPOINT || window.location.origin;
      
      if (!apiEndpoint) {
        throw new Error('API endpoint not configured. Please check your environment variables.');
      }

      console.log('Making API request to:', `${apiEndpoint}/chat`);
      
      // Assuming httpClient is similar to Axios, we pass the request body and expect a ChatApiResponse
      const response: ChatApiResponse = await httpClient.post(
        `${apiEndpoint}/chat`, 
        request,
        {
            headers: {
              'Content-Type': 'application/json', // Ensure JSON format
            },
          }
      );
  
      // Return the actual response data (assuming Axios-style response structure)
      return response;
    } catch (error) {
      console.error('Error during API request:', error);
      throw new Error(`Failed to fetch the API response: ${error instanceof Error ? error.message : String(error)}`);
    }
  }
  

export async function PostFeedback(request: FeedbackRequest): Promise<boolean> {
    try {
        // Get API endpoint with fallback
        const apiEndpoint = import.meta.env.VITE_API_ENDPOINT || window.location.origin;
        
        if (!apiEndpoint) {
            throw new Error('API endpoint not configured. Please check your environment variables.');
        }

        console.log('Making feedback API request to:', `${apiEndpoint}/api/Chat/Feedback`);
        
        const response: boolean = await httpClient.post(
            `${apiEndpoint}/api/Chat/Feedback`, 
            request,
            {
                headers: {
                    'Content-Type': 'application/json',
                },
            }
        );
        return response;
    } catch (error) {
        console.error('Error during feedback submission:', error);
        throw new Error(`Failed to submit feedback: ${error instanceof Error ? error.message : String(error)}`);
    }
}