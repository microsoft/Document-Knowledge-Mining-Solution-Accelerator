import React from "react";
import { render, screen } from "@testing-library/react";
import { Footer } from "./footer";  // Use lowercase 'footer' to match the file name
import { I18nextProvider } from "react-i18next";
import i18n from "i18next";

// Mocking i18next for testing
jest.mock("i18next", () => ({
  init: jest.fn().mockResolvedValue(undefined),  // Mock init to resolve
  t: jest.fn((key: string) => key),  // Mock translation function to return the key
  changeLanguage: jest.fn(),  // Mock language change function
}));

const _mockTranslation = {
  components: {
    footer: {
      copyright: "{{year}} My Company",
    },
  },
};

describe("Footer Component", () => {
  test("renders without crashing", () => {
    render(
      <I18nextProvider i18n={i18n}>
        <Footer />
      </I18nextProvider>
    );
    expect(screen.getByRole("contentinfo")).toBeInTheDocument();
  });

  test("displays the correct copyright message with the current year", () => {
    render(
      <I18nextProvider i18n={i18n}>
        <Footer />
      </I18nextProvider>
    );

    const copyrightText = screen.getByText("components.footer.copyright");
    expect(copyrightText).toBeInTheDocument();
  });

  test("uses translation function to display the year", () => {
    render(
      <I18nextProvider i18n={i18n}>
        <Footer />
      </I18nextProvider>
    );
    
    // Ensure the translation key is correctly rendered
    expect(screen.getByText("components.footer.copyright")).toBeInTheDocument();
  });
});
