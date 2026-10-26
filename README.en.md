# CodexVolt

![CodexVolt](docs/images/hero.png)

**Your Codex quota, at a glance.** A tiny native macOS menu bar battery with the remaining percentage inside the icon.

[Download](https://github.com/xx1999DK/CodexVolt/releases/latest) · [中文](README.md) · [MIT](LICENSE)

![Ten native themes, rendered with a sample value of 73%](docs/images/themes.png)

## Features

- Ten switchable themes: Aurora, Segments, Minimal, Terminal, Pixel, Neko, Ribbon, Mecha, Lunar and Forest.
- Account quota windows and reset times, automatic or fixed-window selection.
- Polling every 15, 30 or 60 seconds, or 5 minutes; manual refresh available.
- Light/dark appearance, compact width, Retina vectors and accessibility labels.
- Sleep-aware scheduling, low-power mode and failure backoff.
- Native Swift + AppKit. No bundled CLI, web runtime or third-party libraries.

The application interface is currently Chinese. Documentation is available in both languages.

## Install

Requires **macOS 13+** and the [official Codex CLI](https://github.com/openai/codex), already installed and signed in.

Download a ZIP from [Releases](https://github.com/xx1999DK/CodexVolt/releases/latest), unzip it and move `CodexVolt.app` to Applications. Choose `arm64` for Apple Silicon or `x86_64` for Intel. The Intel build is cross-compiled and has not been tested on Intel hardware.

Click the menu bar icon for settings. Reopen the app to show the theme gallery. If discovery fails, select your CLI executable in the menu.

Current binaries are ad-hoc signed, **not Developer ID signed or notarized**. macOS may show an origin-verification warning. Verify the source and SHA-256, or build locally. Do not disable system security protections.

## How it works

CodexVolt invokes the official CLI's App Server over stdio and reads `account/rateLimits/read`. It displays `100 − usedPercent`, rounded down, for the selected quota window. This is subscription quota, not API credit or an exact remaining token count.

Automatic selection uses the lowest remaining window in the chosen bucket. Missing data displays a dash; stale, paused or failed data retains the last real reading with an orange indicator. Reset times never fabricate a full battery. Polling is near real time, not a per-token stream.

The app does not read or store login tokens, request model inference, persist quota history or include its own telemetry. The official CLI makes the service request using its existing login. Only appearance and scheduling preferences are saved locally.

Icons redraw on changes, with no continuous animation. Each CLI process exits after a query. Earlier measurements of the same core implementation found about 11 MB physical memory for the freshly started menu bar app and 45–46 MB after opening the gallery; CLI queries add transient overhead. See [validation notes](docs/VALIDATION.md) for methodology and limitations.

## Build

With Xcode Command Line Tools installed:

```sh
bash scripts/test.sh
bash scripts/build.sh
# Optional cross-build:
CODEXVOLT_ARCH=x86_64 bash scripts/build.sh
```

Archives go to `dist/`; compiler intermediates go to `.build/`. Application bundles are staged in a temporary folder to avoid cloud-provider metadata invalidating the signature. Override `CODEXVOLT_BUILD_DIR` and `CODEXVOLT_DIST_DIR` if needed.

To regenerate the original vector-based branding and theme preview, run `bash scripts/render-assets.sh` on macOS.

## Upgrade and uninstall

Quit the original Codex Meter prototype before opening CodexVolt. Appearance preferences migrate once; login items must be enabled separately. To uninstall, disable the login item if enabled, quit and remove the app. Preferences use `io.github.xx1999DK.CodexVolt`.

## License

[MIT](LICENSE). [Contributions](CONTRIBUTING.md) are welcome. This is an independent project, not affiliated with or endorsed by OpenAI.
