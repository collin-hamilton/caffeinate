# caffinate

caffinate is a tiny native macOS menu-bar app. It appears only in the top menu bar while running, does not appear in the Dock, and provides a minimal switch UI for a macOS power assertion.

## Build

```sh
make build
```

The app bundle is created at:

```text
build/caffinate.app
```

## Run

```sh
make run
```

Click the moon/sun icon in the menu bar, then use the **Keep awake** switch or quit the app.

## Important macOS Limitation

This app uses Apple's public `IOPMAssertion` API to prevent idle system sleep and idle display sleep while the toggle is on. Apple's SDK documents that this kind of assertion may still allow sleep for lid close, low battery, Apple menu sleep, and other non-idle sleep reasons.

That means this is a clean menu-bar app with no Dock icon, but it cannot honestly guarantee closed-lid operation on every Mac using only public macOS APIs.
