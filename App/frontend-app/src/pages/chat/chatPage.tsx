import { Header } from "../../components/header/header";
import { HeaderBar, NavLocation } from "../../components/headerBar/headerBar";
import { HeaderMenuTabs } from "../../components/headerMenu/HeaderMenuTabs";
import { ChatRoom } from "../../components/chat/chatRoom";
import { Document } from "../../api/apiTypes/documentResults";
import { useLocation } from "react-router-dom";
import { useState } from "react";

export function ChatPage() {
    const location = useLocation();

    const searchResultDocuments = location.state ? location.state.searchResultDocuments : [];
    const selectedDocumentsFromHomePage = location.state ? location.state.selectedDocuments : [];
    const inheritedTokens = location.state ? location.state.tokens : null;
    const chatWithSingleSelectedDocument: Document[] = location.state ? location.state.chatWithSingleSelectedDocument : [];

    const [selectedDocuments, setSelectedDocuments] = useState<Document[]>(selectedDocumentsFromHomePage);

    const updateSelectedDocuments = (document: Document) => {
        setSelectedDocuments((prevDocuments) => {
            const isAlreadySelected = prevDocuments.some(
                (prevDocument) => prevDocument.documentId === document.documentId
            );

            if (isAlreadySelected) {
                return prevDocuments.filter((prevDocument) => prevDocument.documentId !== document.documentId);
            } else {
                return [...prevDocuments, document];
            }
        });
    };

    return (
        <div 
            data-testid="chat-page"
            className="flex w-full flex-1 flex-col bg-neutral-100" 
            style={{ 
                width: '100vw', 
                maxWidth: '100vw', 
                margin: 0, 
                padding: 0,
                backgroundColor: 'red', // Debug: should show red background
                border: '2px solid blue' // Debug: blue border to see container boundaries
            }}
        >
            <Header className="flex flex-col justify-between bg-contain bg-right-bottom bg-no-repeat" size="small">
                <div className="-ml-8">
                    <HeaderBar location={NavLocation.Home} />
                </div>
            </Header>
            <main className="flex flex-1 flex-col w-full" style={{ 
                width: '100%', 
                maxWidth: '100%',
                backgroundColor: 'yellow', // Debug: should show yellow background
                border: '2px solid green' // Debug: green border to see main boundaries
            }}>
                <div className="flex flex-1 flex-col w-full" style={{ 
                    width: '100%', 
                    maxWidth: '100%',
                    backgroundColor: 'lightblue', // Debug: should show light blue background
                    border: '2px solid purple' // Debug: purple border to see inner div boundaries
                }}>
                    <HeaderMenuTabs
                        className=""
                        searchResultDocuments={searchResultDocuments}
                        selectedDocuments={selectedDocuments}
                        tokens={inheritedTokens}
                        updateSelectedDocuments={updateSelectedDocuments}
                    />
                    <div className="absolute left-0 right-0 mt-11 w-full border-b border-b-neutral-300"></div>
                    <div style={{ 
                        width: '100%', 
                        maxWidth: '100%',
                        backgroundColor: 'orange', // Debug: should show orange background
                        border: '2px solid red' // Debug: red border around ChatRoom
                    }}>
                        <ChatRoom
                            searchResultDocuments={searchResultDocuments}
                            selectedDocuments={selectedDocuments}
                            chatWithDocument={chatWithSingleSelectedDocument ? chatWithSingleSelectedDocument : []} clearChatFlag={false}                        />
                    </div>
                </div>
            </main>
        </div>
    );
}
