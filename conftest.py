import logging
import platform

import pytest
from selenium.webdriver import Firefox
from selenium.webdriver.common.by import By
from selenium.webdriver.firefox.options import Options
from selenium.webdriver.firefox.service import Service
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.ui import WebDriverWait


def pytest_addoption(parser):
    """Set custom command-line options"""
    parser.addoption(
        "--ci",
        action="store_true",
        default=False,
        help="Is this running in a CI environment?",
    )

    parser.addoption(
        "--fx-executable",
        action="store",
        default="",
        help="Path to the Firefox executable under test.",
    )

    parser.addoption(
        "--geckodriver",
        action="store",
        default="",
        help="Path to geckodriver. If empty, Selenium Manager resolves it.",
    )

    parser.addoption(
        "--run-headless",
        action="store_true",
        default=False,
        help="Run Firefox in headless mode.",
    )

    parser.addoption(
        "--implicit-timeout",
        action="store",
        default=10,
        help="Timeout for implicit waits, set 0 for no wait (default 10).",
    )

    parser.addoption(
        "--window-size",
        action="store",
        default="1152x864",
        help="Size for the Firefox window, default is '1152x864'.",
    )


@pytest.fixture(scope="session")
def opt_ci(request):
    return request.config.getoption("--ci")


@pytest.fixture()
def opt_headless(request):
    return request.config.getoption("--run-headless")


@pytest.fixture()
def opt_implicit_timeout(request):
    return int(request.config.getoption("--implicit-timeout"))


@pytest.fixture()
def opt_window_size(request):
    return request.config.getoption("--window-size")


@pytest.fixture(scope="session")
def fx_executable(request):
    return request.config.getoption("--fx-executable")


@pytest.fixture(scope="session")
def geckodriver(request):
    return request.config.getoption("--geckodriver")


@pytest.fixture()
def prefs_list():
    """List of (preference, value) tuples to set before launch. Override per-suite."""
    return []


@pytest.fixture()
def test_case():
    """TestRail case id for the test. Override in the test module."""
    return None


@pytest.fixture(autouse=True)
def driver(
    fx_executable: str,
    geckodriver: str,
    opt_ci: bool,
    opt_headless: bool,
    opt_implicit_timeout: int,
    opt_window_size: str,
    prefs_list: list,
):
    """Return a Firefox webdriver configured for the page-object framework."""
    options = Options()
    # Required so the page objects can switch to the chrome (browser UI) context.
    options.add_argument("--remote-allow-system-access")
    if fx_executable:
        options.binary_location = fx_executable
    if opt_headless:
        options.add_argument("--headless")
    for pref, value in prefs_list:
        options.set_preference(pref, value)

    if geckodriver:
        driver = Firefox(service=Service(executable_path=geckodriver), options=options)
    else:
        driver = Firefox(options=options)

    try:
        separator = "x" if "x" in opt_window_size else ","
        width, height = (int(s) for s in opt_window_size.split(separator))
        driver.set_window_size(width, height)

        timeout = 30 if opt_ci else opt_implicit_timeout
        driver.implicitly_wait(timeout)
        WebDriverWait(driver, timeout=40).until(
            EC.presence_of_element_located((By.TAG_NAME, "body"))
        )

        yield driver
    finally:
        logging.info("Quitting driver.")
        driver.quit()


@pytest.fixture()
def sys_platform():
    return platform.system()