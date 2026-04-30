"""Pacelli smoke test — taps every login option, captures error toasts."""
import time
from appium.webdriver.common.appiumby import AppiumBy


def test_apple_signin_flow(driver):
    """Tap Continue with Apple, capture any error toast."""
    time.sleep(3)  # let app settle past splash
    driver.save_screenshot("/tmp/pacelli-01-login.png")

    # Find Continue with Apple button
    apple_btn = driver.find_element(
        AppiumBy.IOS_PREDICATE,
        "label CONTAINS 'Continue with Apple'",
    )
    apple_btn.click()

    time.sleep(8)  # Apple Sign In sheet → Face ID → callback
    driver.save_screenshot("/tmp/pacelli-02-after-apple.png")

    # Check for error snackbar (red banner near bottom)
    page_source = driver.page_source
    if "Apple sign-in failed" in page_source:
        print("[FAIL] Apple sign-in failed snackbar present")
        # Extract the error text
        import re
        m = re.search(r"Apple sign-in failed[^<]*", page_source)
        if m:
            print(f"[ERROR TEXT] {m.group(0)}")
        assert False, "Apple sign-in failed"
    else:
        print("[OK] Apple sign-in did not show failure snackbar")


def test_smoke_full_audit(driver):
    """Run later — taps every menu, every button, every form field
    and verifies app doesn't crash. Captures screenshots at each step.
    """
    pass  # will fill in once login works
