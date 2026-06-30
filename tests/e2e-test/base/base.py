import json

from config.constants import URL


class BasePage:
    def __init__(self, page):
        self.page = page

    async def scroll_into_view(self, locator):
        reference_list = locator
        await locator.nth(reference_list.count() - 1).scroll_into_view_if_needed()

    async def is_visible(self, locator):
        return await locator.is_visible()

    async def validate_response_status(self, question_api, expected_status=200):
        """Validate API response status for chat endpoint."""
        url = f"{URL}/backend/chat"

        headers = {
            "Content-Type": "application/json",
            "Accept": "*/*",
        }

        payload = {"Question": question_api}

        try:
            response = await self.page.context.request.post(
                url=url, headers=headers, data=json.dumps(payload), timeout=200_000
            )

            error_msg = f"Response code is {response.status}"
            try:
                response_json = await response.json()
                error_msg += f" Response: {response_json}"
            except Exception:
                response_text = await response.text()
                error_msg += f" Response text: {response_text}"

            assert response.status == expected_status, error_msg

            await self.page.wait_for_timeout(4000)
            return response

        except Exception as e:
            print(f"Request failed: {e}")
            raise
