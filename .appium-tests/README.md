# Pacelli iOS Automation (Appium + WebDriverAgent)

## One-time setup (already done)

- `npm install -g appium`
- `appium driver install xcuitest`
- `brew install libimobiledevice ios-deploy carthage openjdk`
- WDA built and installed on iPhone (UDID `00008150-001275340CD9401C`)
- Apple Dev cert trusted in iPhone Settings → VPN & Device Management

## Daily use

```bash
# Terminal 1 — start Appium server
appium

# Terminal 2 — run tests
cd ~/Developer/pacelli/.appium-tests
pip install appium-python-client pytest    # one-time
/Library/Frameworks/Python.framework/Versions/3.13/bin/python3 -m pytest -v test_smoke.py                    # run all tests
/Library/Frameworks/Python.framework/Versions/3.13/bin/python3 -m pytest -v test_smoke.py::test_apple_signin_flow   # one test
```

## Streaming device logs alongside

```bash
# Stream Pacelli's iOS logs (process: Runner) while tests run
xcrun devicectl device process list --device 00008150-001275340CD9401C
idevicesyslog -u 00008150-001275340CD9401C | grep -iE "Pacelli|Runner|FIRAuth|apple\.com"
```

## Re-installing WDA (if it expires after 7 days for free dev account, 1 year for paid)

```bash
WDA_DIR=/Users/juancarloscelispinto/.appium/node_modules/appium-xcuitest-driver/node_modules/appium-webdriveragent

xcodebuild build-for-testing \
  -project $WDA_DIR/WebDriverAgent.xcodeproj \
  -scheme WebDriverAgentRunner \
  -destination 'id=00008150-001275340CD9401C' \
  -derivedDataPath ~/Developer/wda-build \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM=5PCNU95W9V \
  CODE_SIGN_STYLE=Automatic \
  PRODUCT_BUNDLE_IDENTIFIER=com.pacelli.WebDriverAgentRunner

WDA_APP=$(find ~/Developer/wda-build -name "WebDriverAgentRunner-Runner.app" -type d | head -1)
ios-deploy --bundle "$WDA_APP" --id 00008150-001275340CD9401C --no-wifi
```

## TODO — finish iOS 17+ tunnel setup (paused 2026-04-30)

Pacelli runs iOS 26.3.1 which needs the new "Remoted" tunnel daemon for Appium.
Status: WDA built + signed + installed on iPhone, but Appium can't launch it
because of two issues:

1. **Tunnel registry not running** — needed for iOS 17+ device control.
   Fix: install `pymobiledevice3` and run its tunnel daemon as root:
   ```bash
   pip3 install -U pymobiledevice3 --user
   sudo python3 -m pymobiledevice3 remote tunneld &
   ```

2. **xcodebuild can't find provisioning profile when re-launching WDA**.
   Fix: pass `-allowProvisioningUpdates` automatically (Appium capability:
   `xcodebuild_capabilities: { allowProvisioningUpdates: true }`)
   OR set up a `.xcconfig` that's picked up automatically.

Once both are resolved, Appium tests should run end-to-end on the real iPhone.
