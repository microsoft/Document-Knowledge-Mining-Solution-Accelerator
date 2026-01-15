import atexit
import io
import logging
import os
import time

import pytest
from bs4 import BeautifulSoup
from playwright.sync_api import sync_playwright
from datetime import datetime
from pytest_html import extras

from config.constants import URL


# Create screenshots directory if it doesn't exist
SCREENSHOTS_DIR = os.path.join(os.path.dirname(__file__), "..", "screenshots")
os.makedirs(SCREENSHOTS_DIR, exist_ok=True)


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
    
    # Capture screenshot on failure or error - MUST BE AFTER log processing
    if report.failed:
        page = None
        
        # Try to get page from funcargs (works for call phase failures)
        if "login_logout" in item.fixturenames:
            page = item.funcargs.get("login_logout")
        
        # If page not in funcargs, try alternative methods for setup phase errors
        if not page:
            try:
                # Try to get from fixture manager
                fixturemanager = item.session._fixturemanager
                if hasattr(fixturemanager, '_arg2fixturedefs') and "login_logout" in fixturemanager._arg2fixturedefs:
                    fixdefs = fixturemanager._arg2fixturedefs["login_logout"]
                    for fixdef in fixdefs:
                        if hasattr(fixdef, 'cached_result') and fixdef.cached_result:
                            # cached_result is (result, None, (exc, tb)) for failures
                            # or (result, cache_key, None) for successes
                            if len(fixdef.cached_result) >= 3 and fixdef.cached_result[2]:
                                # Fixture failed, try to extract page from traceback frame locals
                                exc, tb = fixdef.cached_result[2]
                                # Walk through traceback frames looking for 'page' variable
                                current_tb = tb
                                while current_tb:
                                    frame_locals = current_tb.tb_frame.f_locals
                                    if 'page' in frame_locals:
                                        page = frame_locals['page']
                                        break
                                    current_tb = current_tb.tb_next
                            else:
                                # Normal success case
                                page = fixdef.cached_result[0]
                            if page:
                                break
            except Exception as e:
                # If we can't access the fixture, continue without screenshot
                pass
        
        if page:
            try:
                # Generate screenshot filename with timestamp
                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                test_name = item.name.replace(" ", "_").replace("/", "_")
                screenshot_name = f"screenshot_{test_name}_{timestamp}.png"
                screenshot_path = os.path.join(SCREENSHOTS_DIR, screenshot_name)
                
                # Take screenshot
                page.screenshot(path=screenshot_path)
                
                # Add screenshot link to report
                if not hasattr(report, 'extra'):
                    report.extra = []
                
                # Use relative path for screenshots (relative to HTML report location)
                relative_screenshot_path = f"screenshots/{screenshot_name}"
                
                # pytest-html expects this format for extras
                report.extra.append(extras.url(relative_screenshot_path, name='Screenshot'))
                
                print(f"\n📸 Screenshot saved: {screenshot_path}")
                print(f"🔗 Link added to report: {relative_screenshot_path}")
            except Exception as exc:
                # Browser/page might be closed for setup phase errors
                # This is expected when fixture fails before yielding
                pass


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
