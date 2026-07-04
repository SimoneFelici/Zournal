# Zournal

A journal app for detective/mistery games written in [Zig](https://codeberg.org/ziglang/zig).

https://github.com/user-attachments/assets/595b612c-91d8-4041-95b7-99821cee31ab

## Info

Detective games give you a lot of information to keep track of.

**Zournal** aims to keep everything in one place:
- Create investigation projects
- Split your work into cases
- Track people and suspects
- Write case notes and person-specific notes
- Visualize relationships between people

## Features

- [x] Projects
- [x] Cases
- [x] Notes
- [x] Relationship graph
- [x] Timeline events
- [x] An exit button
- [x] Edit people note name
- [x] Remove Cases
- [x] Fix people icons
- [ ] Add a search person functionality
- [ ] Open more notes simulatniously (if you exit the person, they close automatically)
- [ ] Global timeline
- [ ] Suspect management with role/status colors, like [The Séance of Blake Manor](https://store.steampowered.com/app/1395520/The_Sance_of_Blake_Manor/)

## Download
Download the latest version of **Zournal** from the [releases page](https://github.com/SimoneFelici/Zournal/releases/latest).

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
