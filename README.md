# Better Media

An MPRIS now-playing widget for the Omarchy bar, cloned from the built-in `omarchy.media`, plus support for the [cliamp](https://github.com/bjarneo/cliamp) headless daemon.

Shows the playing track with a play/pause glyph in the bar. Right-clicking opens a popup with album art, a seekable progress bar, transport controls, and a list of active media sources.

![Better Media preview](preview.png)

## Features

From the built-in `omarchy.media`:

- Bar widget with play/pause state and "title · artist" display
- Popup card with album art, title, artist, album and transport controls
- Multi-source list with switching
- MPRIS tracking across players
- IPC `media` target for scripts and hotkeys

New in this clone:

- Seekable progress bar with elapsed/total time, clickable for seeking within a track
- Shuffle and repeat toggles in the popup
- Switching sources pauses the previous track and plays the selected one
- [cliamp](https://github.com/bjarneo/cliamp) headless daemon support (`cliamp --daemon`, no MPRIS bridge needed)
- Full keyboard navigation in the popup (arrow keys to move, enter to activate, q to close)

## Requirements

- Omarchy quattro
- `cliamp` on `PATH` (only for cliamp support)

`fd` and `jq` are not required by this plugin.

## Install

This is a personal clone of the built-in `omarchy.media`; on this machine it lives in the shell plugin monorepo and is installed under the id `bibek.media`. To install from the standalone repo on a fresh system:

```bash
omarchy plugin add https://github.com/BibekBhusal0/omarchy-better-media.git --enable
```

## Usage

The bar widget appears automatically while something is playing:

| Action           | Effect                |
| ---------------- | --------------------- |
| Left click       | Play/pause            |
| Middle click     | Next track            |
| Right click      | Toggle the popup      |
| Scroll up / down | Previous / next track |

### Popup

The popup shows:

- **Album art** with track title, artist, and album
- **Progress bar** - click or drag to seek; shows elapsed and total time. Hidden when the player doesn't expose position/length
- **Transport controls** - shuffle, previous, play/pause, next, repeat (shuffle/repeat only shown when supported)
- **Source list** - click to switch active media source (pauses the previous, plays the selected)

### IPC

```bash
omarchy-shell media status
omarchy-shell media playPause
omarchy-shell media next
omarchy-shell media previous
omarchy-shell media sourceNext
omarchy-shell media sourcePrevious
```

## cliamp headless

[Headless daemon mode](https://github.com/bjarneo/cliamp/blob/main/docs/headless.md) runs cliamp with no TUI and no MPRIS bridge. The plugin polls `cliamp status --json` over cliamp's IPC socket and exposes the daemon as a media source, so the bar widget, popup, and `omarchy-shell media ...` commands all control it.

Start the daemon (e.g. as a systemd user unit or login autostart):

```bash
cliamp --daemon
```

The daemon and the widget share one source: while a cliamp MPRIS player is present the CLI player is skipped, so there is never a duplicate cliamp entry in the source list.

## Uninstall

```bash
omarchy plugin remove bibek.media
```

## Credits

Bar widget and service adapted from the built-in `omarchy.media` by the Omarchy team.

This plugin is licensed under the [MIT License](LICENSE).

## Others

Here are my other Omarchy plugins:

- [Focusd](https://github.com/BibekBhusal0/omarchy-focusd) - pomodoro timer with streak, history and daily goal
- [Better Lock](https://github.com/BibekBhusal0/omarchy-better-lock) - lock screen with date/time, media and power controls
- [Better Menu](https://github.com/BibekBhusal0/omarchy-better-menu) - fuzzy menu with app grid, calculator and web search
- [Obsidian Search](https://github.com/BibekBhusal0/omarchy-obsidian-search) - fuzzy-search your Obsidian vault
- [Readest](https://github.com/BibekBhusal0/omarchy-readest) - fuzzy-search your Readest library
- [yt-dlp](https://github.com/BibekBhusal0/omarchy-ytdl) - video downloads with progress and history

Please give a star if you find them useful!
