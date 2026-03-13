import React from "react";
import { InteractionStatus } from "@azure/msal-browser";
import { useMsal } from "@azure/msal-react";

export function Layout({ children }: { children?: React.ReactNode }) {
    const { inProgress } = useMsal();

    return !inProgress || inProgress === InteractionStatus.None ? (
        <>            
            {children}
        </>
    ) : null;
}
