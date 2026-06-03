# Lightly

A dead-simple scratchpad/note-taking app for macOS. One file, one window, no ceremony.

<p align="center">
  <a href="https://github.com/neerajsingh0101/lightly/releases/latest/download/lightly-macos.dmg">
    <img src="./docs/assets/macos-badge.png" alt="Download Lightly for macOS" width="180" />
  </a>
</p>

Lightly is **not** a note-taking app. There is exactly one scratchpad — open
the app and start typing. That's it.

## Features

- **One scratchpad.** No "new note", no list, no titles.
- **No formatting.** Plain text only. No to-dos, no checkmarks, no rich text.
- **Autosave.** Everything you type is written to disk automatically.
- **One file you control.** Point it at a Dropbox folder and your scratchpad is
  backed up everywhere.
- **Clickable links.** URLs in the scratchpad open on click.
- **Font size controls.** Adjust the editor from Settings or the View menu.
- **Auto updates.** Lightly uses Sparkle to check for and install GitHub
  release updates.

## Installation instructions

1. Download [lightly-macos.dmg](https://github.com/neerajsingh0101/lightly/releases/latest/download/lightly-macos.dmg).
2. Open the DMG and drag `Lightly.app` to Applications.
3. Launch Lightly. Future updates are delivered through the app's Sparkle
   updater, and you can manually check with **Lightly -> Check for Updates...**.

## Settings

The only setting is *where the file lives*. Open **Lightly → Settings…** (`⌘,`)
and choose a location — typically somewhere inside Dropbox so the file syncs and
backs up.

- If the chosen file already exists, Lightly adopts its contents.
- If it doesn't exist yet, your current text is written there.

The file is a single plain-text `.txt`. The app's own config lives separately in
`~/.config/lightly/settings.json`, so moving the scratchpad never drags app
state along with it. The default location is `~/Documents/Lightly.txt`.

## Tech Stack

<p>
 <a href="https://www.swift.org/"><img src="https://img.shields.io/badge/Swift-F05138?logo=swift&logoColor=white" alt="Swift"></a>
 <a href="https://developer.apple.com/documentation/appkit"><img src="https://img.shields.io/badge/AppKit-333333?logo=apple&logoColor=white" alt="AppKit"></a>
 <a href="https://sparkle-project.org/"><img src="https://img.shields.io/badge/Sparkle-2.9-2E7D32" alt="Sparkle"></a>
 <a href="https://developer.apple.com/swift/"><img src="https://img.shields.io/badge/Swift_Package_Manager-F05138?logo=swift&logoColor=white" alt="SPM"></a>
</p>

## Building

Requires macOS 14+ and a Swift toolchain.

```bash
swift build            # debug build
swift run lightly-app  # build & run

# Package a distributable .app + DMG:
bash scripts/build-dmg.sh 1.0.0
```

`scripts/build-dmg.sh` also writes `appcast.xml` when Sparkle's `sign_update`
tool is available. Upload both `lightly-macos.dmg` and `appcast.xml` to the
same GitHub release so installed copies can update automatically.

## Project layout

```
Sources/LightlyApp/
  main.swift                  # process entry point
  AppDelegate.swift           # window, menu, Settings…, Sparkle updater
  EditorWindowController.swift# the single plain-text editor + autosave
  ScratchpadStore.swift       # load / save / relocate the one file
  LightlySettings.swift       # persists the scratchpad file path
scripts/build-dmg.sh          # packages the .app and DMG
```
