import { initReactI18next } from "react-i18next";

const i18nMock = {
    createInstance: () => ({
        use: () => i18nMock,
        init: (config: Record<string, any>) => {
            // Simulate a no-op init method
        },
        t: (key: string, options?: Record<string, any>) => {
            // Return a mock translation string with interpolation handling
            if (options?.year) {
                return `© ${options.year}`;
            }
            return key;
        },
    }),
};

export default i18nMock;
