import logging
import time

import pytest

from config.constants import (
    chat_question1,
    chat_question2,
    house_10_11_question,
    search_1,
    search_2,
    handwritten_question1,
    contract_details_question,
)
from pages.dkmPage import DkmPage

logger = logging.getLogger(__name__)


def _store_follow_up_question(dkm):
    """Helper to store follow-up question text as an attribute on the DkmPage object."""
    dkm.follow_up_question = dkm.get_follow_ques_text()


# Define test steps and prompts
test_cases = [
    ("Validate home page is loaded", lambda dkm: dkm.validate_home_page()),
    (
        f"Ask first chat question: {chat_question1}",
        lambda dkm: (
            dkm.enter_a_question(chat_question1),
            dkm.click_send_button(),
            dkm.validate_response_status(chat_question1),
            dkm.wait_until_response_loaded(),
        ),
    ),
    (
        "Click on suggested follow-up question",
        lambda dkm: (
            _store_follow_up_question(dkm),
            dkm.click_suggested_question(),
            dkm.validate_response_status(dkm.follow_up_question),
            dkm.wait_until_response_loaded(),
        ),
    ),
    ("Start new topic", lambda dkm: dkm.click_new_topic()),
    ("Search for 'Housing Report'", lambda dkm: dkm.enter_in_search(search_1)),
    ("Select housing docs", lambda dkm: dkm.select_housing_checkbox()),
    (
        f"Ask housing chat question: {chat_question2}",
        lambda dkm: (
            dkm.enter_a_question(chat_question2),
            dkm.click_send_button(),
            dkm.validate_response_status(chat_question2),
            dkm.wait_until_response_loaded(),
        ),
    ),
    ("View details of housing report", lambda dkm: dkm.click_on_details()),
    (
        f"Ask question in housing report popup: {house_10_11_question}",
        lambda dkm: (
            dkm.click_on_popup_chat(),
            dkm.enter_in_popup_search(house_10_11_question),
            dkm.validate_response_status(house_10_11_question),
            dkm.wait_until_chat_details_response_loaded(),
            dkm.close_pop_up(),
        ),
    ),
    ("Search for 'Contracts'", lambda dkm: dkm.enter_in_search(search_2)),
    ("Select handwritten contract docs", lambda dkm: dkm.select_handwritten_doc()),
    (
        f"Ask question about handwritten contracts: {handwritten_question1}",
        lambda dkm: (
            dkm.enter_a_question(handwritten_question1),
            dkm.click_send_button(),
            dkm.validate_response_status(handwritten_question1),
            dkm.wait_until_response_loaded(),
        ),
    ),
    (
        f"Ask question in contract details popup: {contract_details_question}",
        lambda dkm: (
            dkm.click_on_contract_details(),
            dkm.click_on_popup_chat(),
            dkm.enter_in_popup_search(contract_details_question),
            dkm.validate_response_status(contract_details_question),
            dkm.wait_until_chat_details_response_loaded(),
            dkm.close_pop_up(),
        ),
    ),
]

# Create custom readable test IDs with step numbers
test_ids = [f"{i + 1:02d}. {case[0]}" for i, case in enumerate(test_cases)]


@pytest.mark.parametrize("prompt, action", test_cases, ids=test_ids)
def test_dkm_prompt_case(login_logout, prompt, action, request):
    """
    Executes each DKM user interaction step as an independent test case,
    logs execution time, and attaches it to the test report.
    """
    page = login_logout
    dkm_page = DkmPage(page)
    logger.info(f"Running test step: {prompt}")

    start = time.time()
    if isinstance(action, tuple):
        for step in action:
            if callable(step):
                step()
    else:
        action(dkm_page)
    end = time.time()

    duration = end - start
    logger.info(f"Execution Time for '{prompt}': {duration:.2f}s")

    request.node._report_sections.append(
        ("call", "log", f"Execution time: {duration:.2f}s")
    )
