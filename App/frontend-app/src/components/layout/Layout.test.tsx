import { render, screen } from "@testing-library/react";
import { Layout } from "./layout";  // Corrected to lowercase 'layout'
import { useMsal } from "@azure/msal-react";
import { InteractionStatus } from "@azure/msal-browser";
import React from "react";

// Mocking the useMsal hook from @azure/msal-react
jest.mock("@azure/msal-react", () => ({
  useMsal: jest.fn(),
}));

describe("Layout Component", () => {
    test("renders children when inProgress is InteractionStatus.None", () => {
      // Mocking useMsal to return inProgress === InteractionStatus.None
      (useMsal as jest.Mock).mockReturnValue({ inProgress: InteractionStatus.None });
  
      render(
        <Layout>
          <div>Test Content</div>
        </Layout>
      );
  
      // Assert that the child content is rendered
      expect(screen.getByText("Test Content")).toBeInTheDocument();
    });
  
    test("does not render children when inProgress is not InteractionStatus.None", () => {
      // Mocking useMsal to return inProgress === InteractionStatus.Login
      (useMsal as jest.Mock).mockReturnValue({ inProgress: InteractionStatus.Login });
  
      render(
        <Layout>
          <div>Test Content</div>
        </Layout>
      );
  
      // Assert that the child content is NOT rendered
      expect(screen.queryByText("Test Content")).toBeNull();
    });
  
    test("does not render children when inProgress is in a state other than InteractionStatus.None", () => {
        // Mocking useMsal to return inProgress as a generic value that is not InteractionStatus.None
        (useMsal as jest.Mock).mockReturnValue({ inProgress: {} as any });
      render(
        <Layout>
          <div>Test Content</div>
        </Layout>
      );
  
      // Assert that the child content is NOT rendered
      expect(screen.queryByText("Test Content")).toBeNull();
    });
  
    test("renders children when inProgress changes to InteractionStatus.None", () => {
      // Mocking useMsal to return inProgress === InteractionStatus.Login
      (useMsal as jest.Mock).mockReturnValue({ inProgress: InteractionStatus.Login });
  
      const { rerender } = render(
        <Layout>
          <div>Test Content</div>
        </Layout>
      );
  
      // Assert that the child content is NOT rendered
      expect(screen.queryByText("Test Content")).toBeNull();
  
      // Mocking useMsal to return inProgress === InteractionStatus.None
      (useMsal as jest.Mock).mockReturnValue({ inProgress: InteractionStatus.None });
  
      rerender(
        <Layout>
          <div>Test Content</div>
        </Layout>
      );
  
      // Assert that the child content is rendered
      expect(screen.getByText("Test Content")).toBeInTheDocument();
    });
  });
  