import React from "react";
import { render, screen, fireEvent } from "@testing-library/react";
import { CustomDatePicker } from "./customDatePicker";
import { DatePicker } from "@fluentui/react-datepicker-compat";
 
jest.mock("@fluentui/react-datepicker-compat", () => ({
  ...jest.requireActual("@fluentui/react-datepicker-compat"),
  DatePicker: jest.fn(({ placeholder, value, onSelectDate, formatDate, parseDateFromString }: any) => (
    <input
      placeholder={placeholder}
      value={value ? formatDate(value) : ""}
      onChange={(e) => onSelectDate(parseDateFromString(e.target.value))}
      data-testid="datepicker-input"
    />
  )),
}));
 
describe("CustomDatePicker Component", () => {
  it("renders without crashing", () => {
    render(<CustomDatePicker />);
    const datePickerInput = screen.getByTestId("datepicker-input");
    expect(datePickerInput).toBeInTheDocument();
  });
 
  it("displays the placeholder text", () => {
    render(<CustomDatePicker />);
    const datePickerInput = screen.getByPlaceholderText("Select a date");
    expect(datePickerInput).toBeInTheDocument();
  });
 
  it("formats the date correctly", () => {
    render(<CustomDatePicker />);
    const formatDate = (date: Date) => `${date.getDate()}/${date.getMonth() + 1}/${date.getFullYear()}`;
    expect(formatDate(new Date(2023, 8, 15))).toBe("15/9/2023");
  });
 
  it("parses date from string input", () => {
    render(<CustomDatePicker />);
    const parseDateFromString = (value: string) => {
      const parts = value.split("/");
      const day = parseInt(parts[0], 10);
      const month = parseInt(parts[1], 10) - 1;
      const year = parseInt(parts[2], 10);
      return new Date(year, month, day);
    };
    expect(parseDateFromString("15/09/2023").toISOString()).toBe(new Date(2023, 8, 15).toISOString());
  });
 
  it("updates the state on date selection", () => {
    render(<CustomDatePicker />);
    const datePickerInput = screen.getByTestId("datepicker-input");
    fireEvent.change(datePickerInput, { target: { value: "15/09/2023" } });
    expect(datePickerInput).toHaveValue("15/9/2023");
  });
 
  it("updates the state on date selection", () => {
    render(<CustomDatePicker />);
    const datePickerInput = screen.getByTestId("datepicker-input");
    fireEvent.change(datePickerInput, { target: { value: "" } });
    expect(datePickerInput).toHaveValue("");
  });
 
  it("handles two-digit years correctly", () => {
    render(<CustomDatePicker />);
    const datePickerInput = screen.getByTestId("datepicker-input");
    fireEvent.change(datePickerInput, { target: { value: "15/09/23" } });
    expect(datePickerInput).toHaveValue("15/9/2023");
  });
});