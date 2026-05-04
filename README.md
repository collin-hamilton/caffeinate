# caffinate

caffinate is a tiny native macos menu-bar app. it appears only in the top menu bar while running and provides a ui for a macos power assertion.

## features

- keep-awake toggle with different on/off colors.
- timer presets: until turned off, 15 minutes, 30 minutes, or 1 hour.
- optional launch at login.
- menu-bar state icon.
- power usage settings: turn off when unplugged, or auto disable below a selected battery percentage.
- about/status panel with current timer, battery, and sleep-state details.

## build

```sh
make build
```

the app bundle is created at:

```text
build/caffinate.app
```

## run

```sh
make run
```

click the coffee icon in the menu bar, then use the **keep awake** switch, timer menu, battery options, or quit the app.

## important macos limitation

this app uses apple's public `iopmassertion` api to prevent idle system sleep and idle display sleep while the toggle is on. apple's sdk documents that this kind of assertion may still allow sleep for lid close, low battery, apple menu sleep, and other non-idle sleep reasons.

that means this is a clean menu-bar app with no dock icon, but it cannot honestly guarantee closed-lid operation on every mac using only public macos apis.
