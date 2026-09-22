<img width="1280" height="640" alt="Detective Ziguana" src="https://github.com/user-attachments/assets/913926cb-b3cc-445e-b005-c1595924ad13" />
Detective Ziguana by [Ayyur](https://ayyurlinks.carrd.co/)

# Zournal

A journal app for detective/mistery games written in [Zig](https://codeberg.org/ziglang/zig).

https://github.com/user-attachments/assets/595b612c-91d8-4041-95b7-99821cee31ab

## Info

Detective games give you a lot of information to keep track of.

**Zournal** aims to keep everything in one place.

I personally use it by creating a Project for the game I'm playing, then a Case for each mystery.

This is especially useful in games like [The Case of the Golden Idol](https://store.steampowered.com/app/1677770/The_Case_of_the_Golden_Idol/), where there are many separate cases but everything is connected.
Everything you do in a Case is only visible within that case.

You can then choose to "upgrade" things like Notes to make them globally visible, and you can import people into other cases, so if a character appears in more than one case you already have their information.

## Features
- Create a Project for each game
- Create cases for each mystery
- Notes section
- Relationships graph
- Events timeline
- Colored avatar to keep track of suspects

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
- Linux: `$HOME/.local/share/Zournal/`
- Windows: `%LOCALAPPDATA%\Temp\`
- Macos: `$HOME/Library/Application Support/`
