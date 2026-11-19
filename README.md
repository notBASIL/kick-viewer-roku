# Kick Viewer for Roku

<p align="center"><img src="images/icon_fhd.png" width="270" alt="Kick Viewer icon"></p>

A free, lightweight Roku app for watching [Kick](https://kick.com) live streams on a Roku TV. You install it yourself through Roku's developer mode, so it doesn't need a paid third-party app.

> **Unofficial.** This app isn't made by or affiliated with Kick or Roku. It reads the same public endpoints the kick.com website uses, so it may stop working if Kick changes its site. It's meant for personal use on your own TV.

## Download

**[⬇ Download KickViewer.zip (v1.5)](https://github.com/notBASIL/kick-viewer-roku/raw/main/dist/KickViewer.zip)**, a ready-to-install build. Don't unzip it; upload it as is (see *Install on your Roku* below).

## Features

- **Your channels in one place.** Add streamers once and they're saved on the TV. You can paste many names at once, separated by commas. Links like `kick.com/name` work too.
- **Live indicator.** A red dot, viewer count, category and stream title show for anyone who's live. Offline channels get a gray dot.
- **Live channels first.** Live streamers are sorted to the top, biggest first.
- **Auto-refresh.** The list rechecks who's live every minute.
- **Highest quality by default.** The stream is locked to the best rendition the streamer offers, such as 1080p60. You can switch to a specific quality or to Auto.
- **Live chat beside the video.** It shows streamer-colored usernames and refreshes every few seconds. It's read-only.
- **Full screen toggle.** Hide the chat with one button.
- **Rewind.** Jump back into the live stream, using Kick's live recording, and move through it with Roku's normal seek bar.
- **LIVE badge.** A red LIVE badge shows when you're watching live. When you rewind it turns gray and shows how far behind you are. Select it to jump back to live.
- **Fast start.** The whole app is about 115 KB, and the splash screen has no added delay.

## Remote controls

| Where | Button | Action |
|---|---|---|
| Channel list | OK | Watch / add channels |
| Channel list | ✱ | Remove the selected channel |
| Watching live | Up | Toggle full screen / chat |
| Watching live | Left or ⏪ | Rewind (go back in the stream) |
| Watching live | ✱ | Options: rewind, chat, quality |
| Watching live | Back | Return to the list |
| Rewinding | Left / Right, OK | Seek, pause |
| Rewinding | Down, then OK on the LIVE badge | Return to live |
| Rewinding | Back or ✱ → Back to LIVE | Return to live |

The Roku mobile app works as the remote. Its keyboard button lets you type or paste channel names from your phone.

## Install on your Roku

1. **Enable developer mode.** On the remote, press **Home ×3, Up ×2, Right, Left, Right, Left, Right**. Note the IP address shown, choose **Enable installer and restart**, accept the agreement, and set a password.
2. **Get the zip.** [Download it](https://github.com/notBASIL/kick-viewer-roku/raw/main/dist/KickViewer.zip), or build it from this folder:
   ```bash
   ./build.sh        # creates KickViewer.zip
   ```
3. **Upload.** In a browser on the same Wi‑Fi, open `http://<your-roku-ip>`, sign in as `rokudev` with your password, upload `KickViewer.zip`, and click **Install**.

Developer mode allows one sideloaded app at a time. Installing a new build replaces the old one, and your saved channels and settings stay. Turning developer mode off removes the app.

## How it works

| File | Purpose |
|---|---|
| `components/MainScene.*` | UI: channel list, player, chat panel, options menu, key handling |
| `components/ChannelItem.*` | List row with the live dot and status line |
| `components/KickApi.brs` | Shared HTTP helpers, channel lookup, HLS master-playlist parsing |
| `components/KickTask.*` | Loads a channel's live stream and its quality levels |
| `components/StatusTask.*` | Checks which saved channels are live |
| `components/ChatTask.*` | Polls recent chat messages every 2.5 s |
| `components/RewindTask.*` | Finds the in-progress recording of a live stream for rewinding |
| `images/` | Icons, splash screens, logo |

It's built with Roku SceneGraph and BrightScript. Network calls run in Task nodes so the UI never blocks. Settings are stored in the Roku registry.

## Known limitations

- Signing in isn't supported. Kick's official API doesn't expose a user's followed channels, so channels are added by name instead.
- Chat is read-only and polled, so it can lag a few seconds behind.
- Emotes show as text, for example `:KEKW:`.
- If Kick blocks or changes its endpoints, loading will fail with an error code on screen.
