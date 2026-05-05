# Zournal

A journal app for detective/mistery games written in [Zig](https://codeberg.org/ziglang/zig).

https://github.com/user-attachments/assets/595b612c-91d8-4041-95b7-99821cee31ab

## Info

Detective games often give you a lot of info to keep in your head: suspects, clues, events, alibis, locations, contradictions, and relationships.

**Zournal** aims to keep everything in one place:
- Create investigation projects
- Split your work into cases
- Track people and suspects
- Write case notes and person-specific notes
- Visualize relationships between people
- Build timelines of events and connect them together

## Features

- [x] Projects
- [x] Cases
- [x] Notes
- [x] Relationship graph
- [x] Timeline events
- [ ] Global timeline
- [ ] An exit button
- [ ] Suspect management with role/status colors, like [The Séance of Blake Manor](https://store.steampowered.com/app/1395520/The_Sance_of_Blake_Manor/)

## Download
Download the latest version of **Zournal** from the releases [page](https://github.com/SimoneFelici/Zournal/releases/latest).

## Building from source

### Requirements

- Zig 0.16.0

### Build

```bash
git clone https://github.com/SimoneFelici/Zournal.git
cd Zournal
zig build -Doptimize=ReleaseFast
```

## Database location:
- Linux: `~/.local/share/Zournal/`
- Windows: `~/Library/Application Support/Zournal/`
- Macos: `%APPDATA%\Zournal\`
