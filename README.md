# Swift Starter App Boilerplate

<p align="center">
  <img src="Resources/AppIcon.png" width="128" height="128" alt="App Icon" />
</p>

A minimal, zero-dependency macOS starter boilerplate written in native Swift and AppKit. Designed to be stripped clean, quickly configured, and used as the foundation for building lightweight menu bar (status bar) or desktop macOS applications.

## Quick Start

```bash
# Configure the app ID and name (run once, before the first build)
make setup

# Build the application bundle
make build

# Launch the application
make run

# Terminate running instances
make kill

# Run the test suite
make test

# Build the release DMG
make dmg

# Publish a new release (version is required and must be higher than the current one)
make release 1.2.3

# Reset permissions and macOS caches
make revoke

# Clean build artifacts
make clean
```

## Makefile Targets

| Target | Description |
|---|---|
| `make help` | Display available targets and descriptions |
| `make setup` | Ask for the app ID and name and write them to `scripts/config.sh` |
| `make build` | Compile the `.app` bundle into `build/`, incrementing `BUILD_NUMBER` |
| `make run` | Terminate existing instances, rebuild, and launch the app |
| `make kill` | Terminate running instances of the application |
| `make test` | Run the native Swift test suite |
| `make dmg` | Rebuild the app and package it in a styled DMG that uses the app icon |
| `make release <version>` | Summarize all commits since the previous release, run tests, bump `VERSION`, build DMG, tag, and publish |
| `make revoke` | Reset TCC permissions and flush macOS QuickLook & LaunchServices caches |
| `make clean` | Remove `build/` artifacts and temporary test binaries |

## Project Structure

```text
swift-boilerplate/
├── Makefile                # Build orchestration and lifecycle targets
├── Package.swift           # Swift Package Manager manifest
├── VERSION                 # Current semantic version
├── BUILD_NUMBER            # Auto-incrementing build counter
├── Resources/
│   ├── AppIcon.icns        # Application icon (macOS icns)
│   ├── AppIcon.png         # Generic black square with white italic "st"
│   ├── StatusBarIcon.png   # 18x18 status bar icon ("st")
│   ├── StatusBarIcon@2x.png# 36x36 retina status bar icon ("st")
│   └── dmg_background*.png # DMG distribution styling
├── Sources/
│   └── App/
│       ├── Main.swift                # Application entry point (@main)
│       ├── AppDelegate.swift         # NSApplicationDelegate lifecycle
│       ├── AppConfig.swift           # App metadata and version resolution
│       └── StatusBarController.swift # Menu bar status item & menu
├── templates/
│   ├── AppDelegate.both.swift        # Template: Dock icon, window & status bar item (default)
│   ├── AppDelegate.dock.swift        # Template: Dock icon & window only
│   └── AppDelegate.statusbar.swift   # Template: Menu bar status item only
├── Tests/
│   └── AppTests/
│       ├── AppTests.swift  # Minimal test suite
│       └── TestMain.swift  # Test runner entry point
└── scripts/
    ├── config.sh           # App name, bundle ID, and build settings
    ├── setup.sh            # Interactive app ID / name setup
    ├── build.sh            # Direct swiftc compilation & code signing
    ├── test.sh             # Native test compilation & execution
    ├── build_dmg.sh        # DMG packaging script
    └── release.sh          # Version bump & automated release workflow
```

## Customizing

Run `make setup` and enter your app ID (bundle identifier), app name, and app display name.
The app name defaults to the last component of the ID, and the display name (which supports spaces)
defaults to the app name (or previously configured display name). You will also be prompted for the application UI mode (default is `both`):
- `both`: Desktop window, Dock icon, and menu bar status item (`AppDelegate.both.swift`, default)
- `statusbar`: Menu bar status item only (no Dock icon, `LSUIElement=true`, `AppDelegate.statusbar.swift`)
- `dock`: Regular desktop application with window and Dock icon (`LSUIElement=false`, `AppDelegate.dock.swift`)

When a choice is made, `setup.sh` replaces `Sources/App/AppDelegate.swift` from the corresponding template in `templates/` and updates [scripts/config.sh](scripts/config.sh). You can also edit them directly:

```bash
export APP_NAME="MyApp"
export APP_DISPLAY_NAME="My App" # Display name shown in Finder / Dock (supports spaces)
export BUNDLE_ID="com.example.MyApp"
export APP_MODE="both" # Options: both, statusbar, dock
export LS_UI_ELEMENT="false" # Set to true if you want a menu-bar-only app
```

## Build Rules

- **Universal binary**: Builds for both Apple Silicon (`arm64`) and Intel (`x86_64`) by default, configured via `ARCHS` in `scripts/config.sh`.
- **Version**: The app version is always the contents of the `VERSION` file (`X.Y.Z`). Every build
  writes it to `CFBundleShortVersionString`; environment overrides are ignored.
- **Build number**: Every `make build` (including `make run`, `make dmg`, and `make release`)
  increments `BUILD_NUMBER` and writes it to `CFBundleVersion`.
- **Permissions**: Builds are ad-hoc signed with a designated requirement pinned to the bundle ID
  (`identifier "<BUNDLE_ID>"`) instead of the default per-build hash, so permissions granted in
  System Settings persist across rebuilds. No keychain or certificate is involved, and the build
  fails if the signed requirement differs. Changing the bundle ID starts with fresh permissions.
  Use `make revoke` to reset permissions deliberately.
- **DMG**: The disk image, its mounted volume, and its window use the app's icon.

## Releasing

```bash
export GEMINI_API_KEY="your-api-key"
make release 1.2.3
```

- A version is required, must be `X.Y.Z`, and must be strictly greater than both `VERSION` and the
  latest `vX.Y.Z` tag. Equal or lower versions are rejected.
- The working tree must be clean (`BUILD_NUMBER` excepted).
- The release runs in three phases: **gather, ask, do**.
  1. **Gather** (read-only): validate the version, check the branch is not behind `origin` and `gh`
     is authenticated, collect every commit between the previous release tag and `HEAD`, generate
     the release notes (a Gemini summary, the complete commit list, and a compare link), and run
     the unit tests.
  2. **Ask**: print the full release preview: versions, build number, branch, the entire release
     log (every commit with author, date, message, and changed files), the exact release notes,
     and the list of actions. Nothing happens unless you type `yes`.
  3. **Do**: set `VERSION`, build the DMG, commit `VERSION` and `BUILD_NUMBER`, tag `vX.Y.Z`, push,
     and publish the GitHub release. If a step fails before the commit, `VERSION` is restored.

### Releasing with `grel`

The repository also includes a `.release.sh` hook for releasing via `grel`:

```bash
# Preview release actions without making changes
grel 1.2.3 --notes "Initial release" --preview

# Perform release with piped or inline release notes
gemini-release-notes | grel 1.2.3
grel 1.2.3 --notes "Release notes text"
grel 1.2.3 -f release-notes.md
```
