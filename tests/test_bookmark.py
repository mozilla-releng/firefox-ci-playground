import pytest
from time import sleep
from os import getcwd
from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.ui import WebDriverWait

@pytest.fixture()
def test_url():
    return "https://www.mozilla.org"

def test_aboutprefs(session):
    session.get("about:preferences")
    sleep(1)

    session.find_element(By.ID, "category-privacy").click()

    strict_security = session.find_element(By.ID, "strictRadio")
    WebDriverWait(session, 10).until(
        EC.element_to_be_clickable(
            strict_security
        )
    )

    strict_security.click()

    WebDriverWait(session, 10).until(
        EC.element_selection_state_to_be(strict_security, True)
    )


@pytest.mark.skip(reason="refresh button not operable in selenium")
def test_refresh(session_and_events, test_url):
    (session, events) = session_and_events
    unix_time_site = f"file:///{getcwd()}/date_test.html"
    session.get(unix_time_site)

    WebDriverWait(session, 10).until(
        EC.presence_of_element_located((By.ID,"timestamp"))
    )
    timestamp = session.find_element(By.ID, "timestamp").text

    with session.context(session.CONTEXT_CHROME):
        refresh_button = session.find_element(By.ID, "stop-reload-button")
        refresh_button.click()

    new_timestamp = timestamp
    elapsed = 0.0
    while new_timestamp == timestamp and elapsed < 5:
        new_timestamp = session.find_element(By.ID, "timestamp").text
        elapsed += 0.5
        sleep(0.5)

    assert new_timestamp > timestamp

def test_bookmark(session, test_url):
    moz_desc = "Internet for people, not profit — Mozilla (US)"
    session.get(test_url)
    WebDriverWait(session, 10).until(EC.url_changes(test_url))

    with session.context(session.CONTEXT_CHROME):
        star_button = session.find_element(By.ID, "star-button")
        star_button.click()

        WebDriverWait(session, 10).until(
            EC.presence_of_element_located(
                (By.CSS_SELECTOR, f".bookmark-item[label='{moz_desc}']")
            )
        )

        assert star_button.get_attribute("starred") == "true"

        with open("chromesource", "w") as ofh:
            ofh.write(session.page_source)
