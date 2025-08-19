import time

from playwright.sync_api import TimeoutError as PlaywrightTimeoutError
from playwright.sync_api import expect

from base.base import BasePage


class DkmPage(BasePage):
    WELCOME_PAGE_TITLE = "(//div[@class='order-5 my-auto pb-3 text-lg font-semibold leading-tight text-white mt-3'])[1]"
    NEWTOPIC = "//button[normalize-space()='New Topic']"
    Suggested_follow_up_questions = "body > div:nth-child(3) > div:nth-child(1) > main:nth-child(2) > div:nth-child(1) > div:nth-child(4) > div:nth-child(1) > div:nth-child(1) > div:nth-child(1) > div:nth-child(1) > div:nth-child(3) > div:nth-child(1) > div:nth-child(6) > div:nth-child(3) > button:nth-child(2)"
    SCROLL_DOWN = "//div[10]//div[2]//div[2]//i[1]//img[1]"
    ASK_QUESTION = (
        "//textarea[@placeholder='Ask a question or request (ctrl + enter to submit)']"
    )
    SEARCH_BOX = "//input[@type='search']"
    HOUSING_2022 = "//body[1]/div[2]/div[1]/main[1]/div[1]/div[2]/div[4]/div[1]/div[1]/div[3]/div[2]/div[2]/span[1]"
    HOUSING_2023 = "//body[1]/div[2]/div[1]/main[1]/div[1]/div[2]/div[4]/div[1]/div[1]/div[2]/div[2]/div[2]/span[1]"
    CONTRACTS_DETAILS_PAGE = "//body[1]/div[2]/div[1]/main[1]/div[1]/div[2]/div[4]/div[1]/div[1]/div[1]/div[2]/div[2]/div[1]/button[1]"
    DETAILS_PAGE = "body > div:nth-child(3) > div:nth-child(1) > main:nth-child(2) > div:nth-child(1) > div:nth-child(2) > div:nth-child(4) > div:nth-child(1) > div:nth-child(1) > div:nth-child(2) > div:nth-child(2) > div:nth-child(2) > div:nth-child(3) > button:nth-child(2)"
    POP_UP_CHAT = "//button[@value='Chat Room']"
    CLOSE_POP_UP = "//button[@aria-label='close']"
    CLLEAR_ALL_POP_UP = "//button[normalize-space()='Clear all']"
    HANDWRITTEN_DOC1 = "//body[1]/div[2]/div[1]/main[1]/div[1]/div[2]/div[4]/div[1]/div[1]/div[1]/div[2]/div[2]/span[1]"
    HANDWRITTEN_DOC2 = "//body[1]/div[2]/div[1]/main[1]/div[1]/div[2]/div[4]/div[1]/div[1]/div[2]/div[2]/div[2]/span[1]"
    HANDWRITTEN_DOC3 = "//body[1]/div[2]/div[1]/main[1]/div[1]/div[2]/div[4]/div[1]/div[1]/div[6]/div[2]/div[2]/span[1]"
    SEND_BUTTON = "//button[@aria-label='Send']"
    POP_UP_CHAT_SEARCH = "(//textarea[@placeholder='Ask a question or request (ctrl + enter to submit)'])[2]"
    POP_UP_CHAT_SEND = "(//button[@type='submit'])[2]"
    DOCUMENT_FILTER = "//button[normalize-space()='Accessibility Features']"
    HEADING_TITLE = "//div[.='Document Knowledge Mining']"

    def __init__(self, page):
        self.page = page

    def validate_home_page(self):
        self.page.wait_for_timeout(5000)
        # expect(self.page.locator(self.DOCUMENT_FILTER)).to_be_visible()
        expect(self.page.locator(self.HEADING_TITLE)).to_be_visible()
        self.page.wait_for_timeout(2000)

    def enter_a_question(self, text):
        self.page.locator(self.ASK_QUESTION).fill(text)
        self.page.wait_for_timeout(5000)

    def enter_in_search(self, text):
        self.page.locator(self.SEARCH_BOX).fill(text)
        self.page.wait_for_timeout(5000)

    def enter_in_popup_search(self, text):
        self.page.locator(self.POP_UP_CHAT_SEARCH).fill(text)
        self.page.wait_for_timeout(5000)
        self.page.locator(self.POP_UP_CHAT_SEND).click()
        # self.page.wait_for_load_state('networkidle')

    def select_housing_checkbox(self):
        self.page.locator(self.HOUSING_2022).click()
        self.page.locator(self.HOUSING_2023).click()
        self.page.wait_for_timeout(5000)

    def click_on_details(self):
        self.page.wait_for_timeout(5000)
        self.page.locator(self.DETAILS_PAGE).click()
        self.page.wait_for_timeout(13000)

    def click_on_popup_chat(self):
        self.page.locator(self.POP_UP_CHAT).click()
        self.page.wait_for_timeout(5000)

    def close_pop_up(self):
        self.page.locator(self.CLOSE_POP_UP).click()
        self.page.wait_for_timeout(2000)
        self.page.locator(self.CLLEAR_ALL_POP_UP).click()
        self.page.wait_for_timeout(2000)

    def select_handwritten_doc(self):
        self.page.locator(self.HANDWRITTEN_DOC1).click()
        self.page.locator(self.HANDWRITTEN_DOC2).click()
        self.page.locator(self.HANDWRITTEN_DOC3).click()
        self.page.wait_for_timeout(2000)

    def click_send_button(self):
        # Click on send button in question area
        self.page.locator(self.SEND_BUTTON).click()
        self.page.wait_for_timeout(5000)

        # self.page.wait_for_load_state('networkidle')

    def wait_until_response_loaded(self, timeout=200000):
        start_time = time.time()
        interval = 0.1
        end_time = start_time + timeout / 1000
        locator = self.page.locator(self.ASK_QUESTION)

        while time.time() < end_time:
            if locator.is_enabled():
                return
            time.sleep(interval)

        raise PlaywrightTimeoutError(
            "Response is not generated and it has been timed out."
        )
        # try:
        #  # Wait for it to appear in the DOM and be visible
        #     locator = self.page.locator(self.ASK_QUESTION)
        #     locator.wait_for(state="enabled", timeout=200000)  # adjust timeout as needed
        # except PlaywrightTimeoutError:
        #     raise Exception("Response is not generated and it has been timed out.")

    def wait_until_chat_details_response_loaded(self, timeout=200000):

        start_time = time.time()
        interval = 0.1
        end_time = start_time + timeout / 1000
        locator = self.page.locator(self.POP_UP_CHAT_SEARCH)

        while time.time() < end_time:
            if locator.is_enabled():
                return
            time.sleep(interval)

        raise PlaywrightTimeoutError(
            "Response is not generated and it has been timed out."
        )

    def click_new_topic(self):
        self.page.locator(self.NEWTOPIC).click()
        self.page.wait_for_timeout(2000)
        self.page.wait_for_load_state("networkidle")

    def get_follow_ques_text(self):
        follow_up_question = self.page.locator(
            self.Suggested_follow_up_questions
        ).text_content()
        return follow_up_question

    def click_suggested_question(self):
        self.page.locator(self.Suggested_follow_up_questions).click()
        self.page.wait_for_timeout(2000)
        self.page.wait_for_load_state("networkidle")

    def click_on_contract_details(self):
        self.page.locator(self.CONTRACTS_DETAILS_PAGE).click()
        self.page.wait_for_timeout(12000)
