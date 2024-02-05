import pytest
from selenium import webdriver
from selenium.webdriver.firefox.options import Options
from selenium.webdriver.support.events import EventFiringWebDriver, AbstractEventListener


def pytest_addoption(parser):
    # set the location of the fx binary from command line if provided
    parser.addoption(
        "--fx_executable",
        action="store",
        default="/Applications/Firefox Nightly.app/Contents/MacOS/firefox-bin",
        help="Location of Firefox executable to test, TODO: default to correct loc of Nightly per OS",
    )


@pytest.fixture()
def fx_executable(request):
    return request.config.getoption("--fx_executable")


@pytest.fixture(autouse=True)
def session(fx_executable):
    # create a new instance of the browser
    options = Options()
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


