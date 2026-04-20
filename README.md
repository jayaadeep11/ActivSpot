# ActivSpot — Dynamic Island for Hyprland

My vision of a dynamic island for Hyprland. Originally developed for personal use, shared after genuine interest from the Reddit community.

> Based on [nixos-configuration](https://github.com/ilyamiro/nixos-configuration) by ilyamiro

---

## Features

**Contextual content** — automatically switches based on system state:
- Music player (album art, title, artist, progress)
- Discord voice call (live timer, mute button)
- Screen recording indicator
- Notifications with expand-to-read
- Clock + weather (default)

**Dual bubble** — Discord call pill appears alongside music player simultaneously  
**App Launcher** — island morphs into Spotlight-style launcher with fuzzy search and icons  
**Clipboard Viewer** — cliphist-based history with image/text detection  
**VPN badge** — lock icon with snap-shut animation under temperature  
**Pet pill** — animated cat reacts to music and notifications  

---

## Stack

| Component     | Technology              |
|---------------|-------------------------|
| Shell         | Quickshell              |
| Language      | QML                     |
| Compositor    | Hyprland                |
| IPC           | inotifywait on /tmp/qs_* |
| Music         | playerctl               |
| Weather       | wttr.in                 |
| Clipboard     | cliphist + wl-copy      |
| Notifications | custom daemon           |

---

## Dependencies
quickshell inotify-tools playerctl cliphist wl-clipboard
python3 gtk-launch flatpak (optional)
JetBrains Mono, Iosevka Nerd Font

---

## Installation

Clone repo

Run instalation script

---

## Keybinds

| Bind          | Action           |
|---------------|------------------|
| Super + Space | App Launcher     |
| Super + C     | Clipboard Viewer |

---


<img width="368" height="67" alt="image" src="https://github.com/user-attachments/assets/6b1e909a-c3ab-4de4-a492-14d4215bf18f" />
<img width="491" height="72" alt="image" src="https://github.com/user-attachments/assets/3417d83d-12a4-49ca-a692-7443f2533233" />
<img width="380" height="81" alt="image" src="https://github.com/user-attachments/assets/390b11e1-6bb0-4755-a616-45997fcef61d" />
<img width="789" height="653" alt="image" src="https://github.com/user-attachments/assets/62824d74-a4bd-4d90-83bf-12e5fe19c1db" />
<img width="799" height="479" alt="image" src="https://github.com/user-attachments/assets/a50dcc30-e9ad-4a4a-a1ac-22b294ec1e4d" />
<img width="793" height="369" alt="image" src="https://github.com/user-attachments/assets/e13da3d2-187c-4f65-b17a-14a7fb46b03c" />
and more ..




## Architecture

Each component is a separate `PanelWindow`. IPC works via `inotifywait` on `/tmp/qs_*` files — no sockets, no daemons. The island hides itself when the launcher opens via `/tmp/qs_launcher_state`, creating a morph illusion since both windows share the same top-center position.
