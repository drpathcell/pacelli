"""Appium iOS test setup for Pacelli on real device.

Usage:
  appium &                                  # in another terminal
  pip install appium-python-client pytest
  pytest -v tests.py
"""
import pytest
from appium import webdriver
from appium.options.ios import XCUITestOptions

DEVICE_UDID = "00008150-001275340CD9401C"
BUNDLE_ID = "com.pacelli.pacelli"
TEAM_ID = "5PCNU95W9V"


@pytest.fixture(scope="session")
def driver():
    options = XCUITestOptions()
    options.platform_name = "iOS"
    options.platform_version = "26.3.1"
    options.device_name = "iPhone"
    options.udid = DEVICE_UDID
    options.bundle_id = BUNDLE_ID
    options.xcode_org_id = TEAM_ID
    options.xcode_signing_id = "Apple Development"
    options.updated_wda_bundle_id = "com.pacelli.WebDriverAgentRunner"
    options.use_new_wda = False         # we already installed WDA
    options.skip_log_capture = False    # we want logs!
    options.show_xcode_log = True

    drv = webdriver.Remote("http://127.0.0.1:4723", options=options)
    yield drv
    drv.quit()
