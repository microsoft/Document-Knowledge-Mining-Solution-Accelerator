/// <reference types="vite/client" />

interface ImportMetaEnv {
    VITE_API_ENDPOINT: string
    VITE_ENABLE_UPLOAD_BUTTON : string
    // Add other environment variables here
  }
  
  interface ImportMeta {
    readonly env: ImportMetaEnv
  }