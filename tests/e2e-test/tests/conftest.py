import atexit
import io
import logging
import os

import pytest
from bs4 import BeautifulSoup
from playwright.sync_api import sync_playwright

from config.constants import URL


@pytest.fixture(scope="session")
def login_logout():
    # perform login and browser close once in a session
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=False, args=["--start-maximized"])
        context = browser.new_context(no_viewport=True)
        context.set_default_timeout(120000)
        page = context.new_page()
        # Navigate to the login URL
        page.goto(URL)
        # Wait for the login form to appear
        page.wait_for_load_state("networkidle")
        yield page
        browser.close()


@pytest.hookimpl(tryfirst=True)
def pytest_html_report_title(report):
    report.title = "Test Automation DKM"


log_streams = {}


@pytest.hookimpl(tryfirst=True)
def pytest_runtest_setup(item):
    stream = io.StringIO()
    handler = logging.StreamHandler(stream)
    handler.setLevel(logging.INFO)

    logger = logging.getLogger()
    logger.addHandler(handler)

    log_streams[item.nodeid] = (handler, stream)


@pytest.hookimpl(hookwrapper=True)
def pytest_runtest_makereport(item, call):
    outcome = yield
    report = outcome.get_result()

    handler, stream = log_streams.get(item.nodeid, (None, None))

    if handler and stream:
        handler.flush()
        log_output = stream.getvalue()

        logger = logging.getLogger()
        logger.removeHandler(handler)

        report.description = f"<pre>{log_output.strip()}</pre>"
        log_streams.pop(item.nodeid, None)
    else:
        report.description = ""


def pytest_collection_modifyitems(items):
    for item in items:
        if hasattr(item, "callspec"):
            prompt = item.callspec.params.get("prompt")
            if prompt:
                item._nodeid = prompt


def rename_duration_column():
    report_path = os.path.abspath("report.html")
    if not os.path.exists(report_path):
        print("Report file not found, skipping column rename.")
        return

    with open(report_path, "r", encoding="utf-8") as f:
        soup = BeautifulSoup(f, "html.parser")

    headers = soup.select("table#results-table thead th")
    for th in headers:
        if th.text.strip() == "Duration":
            th.string = "Execution Time"
            break
    else:
        print("'Duration' column not found in report.")

    with open(report_path, "w", encoding="utf-8") as f:
        f.write(str(soup))


atexit.register(rename_duration_column)
