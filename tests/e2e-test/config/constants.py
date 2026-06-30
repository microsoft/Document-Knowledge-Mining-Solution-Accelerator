import os

from dotenv import load_dotenv

load_dotenv()
URL = os.getenv("url")
if URL.endswith("/"):
    URL = URL[:-1]

# DKM input data
chat_question1 = "What are the main factors contributing to the current housing affordability issues?"
chat_question2 = "Analyze the two annual reports and compare the positive and negative outcomes YoY. Show the results in a table."
house_10_11_question = "Can you summarize and compare the tables on page 10 and 11?"
handwritten_question1 = "Analyze these forms and create a table with all buyers, sellers, and corresponding purchase prices."
search_1 = "Housing Report"
search_2 = "Contracts"
contract_details_question = (
    "What liabilities is the buyer responsible for within the contract?"
)
