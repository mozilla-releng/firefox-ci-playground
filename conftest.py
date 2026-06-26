import pytest
import os
import platform

from selenium import webdriver
from selenium.common.exceptions import TimeoutException, WebDriverException
from selenium.webdriver import Firefox
from selenium.webdriver.common.by import By
from selenium.webdriver.firefox.options import Options
from selenium.webdriver.firefox.service import Service
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.firefox.options import Options
from selenium.webdriver.support.events import EventFiringWebDriver, AbstractEventListener


def pytest_addoption(parser):
    """Set custom command-line options"""
    parser.addoption(
        "--ci",
        action="store_true",
        default=False,
        help="Is this running in a CI environment?",
    )

    parser.addoption(
        "--fx-channel",
        action="store",
        default="Custom",
        help="Firefox channel to test. See README for exact paths to builds",
    )

    parser.addoption(
        "--fx-executable",
        action="store",
        default="",
        help="Path to Fx executable. Will overwrite --fx-channel.",
    )

    parser.addoption(
        "--geckodriver",
        action="store",
        default="",
        help="Path to geckodriver.",
    )

    parser.addoption(
        "--run-headless",
        action="store_true",
        default=False,
        help="Run in headless mode: --run-headless",
    )

    parser.addoption(
        "--implicit-timeout",
        action="store",
        default=10,
        help="Timeout for implicit waits, set 0 for no wait (default 10)",
    )

    parser.addoption(
        "--window-size",
        action="store",
        default="1152x864",
        help="Size for Fx window, default is '1152x864'",
    )


@pytest.fixture(scope="session")
def sys_platform():
    return platform.system()


@pytest.fixture(scope="session")
def geckodriver(request):
    return request.config.getoption("--geckodriver")


@pytest.fixture(scope="session")
def fx_executable(request, sys_platform):
    return request.config.getoption("--fx-executable")


@pytest.fixture()
def machine_config():
    """Return the os type, version, and architecture for the machine"""
    uname = platform.uname()
    if uname.system == "Darwin":
        mac_major = platform.mac_ver()[0].split(".")[0]
        return f"MacOS {mac_major} {uname.machine.lower()}"
    else:
        os_major = uname.version.split(".")[0]
        return f"{uname.system} {os_major} {uname.machine.lower()}"


@pytest.fixture()
def hard_quit():
    return False


@pytest.fixture(autouse=True)
def session(fx_executable):
    # create a new instance of the browser
    options = Options()
    options.add_argument("--headless")
    options.binary_location = fx_executable
    options.set_preference("browser.toolbars.bookmarks.visibility", "always")
    s = webdriver.Firefox(options=options)
    yield s

    s.quit()


@pytest.fixture()
def session_and_events(session):
    class ThisListener(AbstractEventListener):
        def init_log(self):
            self.log = []

        def before_navigate_to(self, url, driver):
            self.log.append(f"Preparing to navigate to {url}.")
        def after_navigate_to(self, url, driver):
            self.log.append(f"Navigated to {url}.")

    listener = ThisListener()
    listener.init_log()
    ef = EventFiringWebDriver(session, listener)
    yield (ef, listener)

    ef.quit()