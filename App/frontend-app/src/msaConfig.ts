// msalConfig.ts
import { Configuration, LogLevel } from '@azure/msal-browser';

export const msalConfig: Configuration = {
  auth: {
    clientId: import.meta.env.VITE_MSAL_AUTH_CLIENTID, 
    authority: import.meta.env.VITE_MSAL_AUTH_AUTHORITY,
    redirectUri: import.meta.env.VITE_MSAL_REDIRECT_URL,
  },
  cache: {
    cacheLocation: 'localStorage', // Use localStorage for persistent cache
    storeAuthStateInCookie: false,
  },
  system: {
    loggerOptions: {
      loggerCallback: (level, message, containsPii) => {
        if (containsPii) return;
        if (level === LogLevel.Error) console.error(message);
        if (level === LogLevel.Info) console.info(message);
        if (level === LogLevel.Verbose) console.debug(message);
        if (level === LogLevel.Warning) console.warn(message);
      },
    },
  },
};

export const loginRequest = {
  scopes: ['User.Read'],
};

export const graphConfig = {
  graphMeEndpoint: "https://graph.microsoft.com/v1.0/me",
};
