
import React, { useEffect } from "react";
import { msalInstance } from "./msalInstance";
import { loginRequest } from "../msaConfig";
import { useMsal, useIsAuthenticated } from "@azure/msal-react";
import { InteractionStatus } from "@azure/msal-browser";

const AuthWrapper: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const { inProgress } = useMsal();
  const isAuthenticated = useIsAuthenticated();

  // Check for existing session and trigger login if not authenticated
  const checkAuthentication = async () => {
    const accounts = msalInstance.getAllAccounts();
    if (accounts.length === 0 && inProgress === InteractionStatus.None) {
      try {
        await msalInstance.loginRedirect(loginRequest);
      } catch (error) {
        console.error("Login failed:", error);
      }
    }
  };

  useEffect(() => {
    // Trigger login only if no interaction is in progress
    if (!isAuthenticated && inProgress === InteractionStatus.None) {
      checkAuthentication();
    }
  }, [isAuthenticated, inProgress]);

  return <>{children}</>;
};

export default AuthWrapper;

