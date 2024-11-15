// src/msalInstance.ts
import { PublicClientApplication } from "@azure/msal-browser";
import { msalConfig } from "../msaConfig";

export const msalInstance = new PublicClientApplication(msalConfig);
