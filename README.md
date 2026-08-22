# Better Pull Ten

Better Pull Ten is a lightweight World of Warcraft addon that provides
movable pull-timer and ready-check controls. It is designed to make common
group-leader actions quick to access without opening menus or typing commands.

## Features

- Movable Pull Timer and Ready Check buttons
- Configurable pull-timer duration
- Blizzard countdown support
- MRT-compatible BigWigs and DBM pull-timer integration
- Optional visibility rules for combat, Mythic+, and group leadership
- Lockable compact button layout

## Installation

1. Download or clone this repository.
2. Place the `BetterPullTen` folder in:
   `World of Warcraft/_retail_/Interface/AddOns/`
3. Start World of Warcraft or run `/reload` if the game is already open.
4. Enable Better Pull Ten from the character-selection AddOns menu.

## Usage

- Click **Pull Timer** to start the configured pull timer.
- Click **Ready Check** to begin a group ready check.
- Run `/bpt` to open or close the settings window.
- Run `/bpt lock` or `/bpt unlock` to control the button layout.
- Run `/bpt pull <seconds>` to start a one-time pull timer.

Starting group timers and ready checks requires group leader or assistant
permissions.

## Project Structure

- `BetterPullTen.lua` - addon behavior, interface, and settings
- `BetterPullTen.toc` - World of Warcraft addon metadata and load order
- `docs/` - design and implementation notes

## Development Status

Better Pull Ten is under active development. MRT-style chat countdown messages,
an updating cancel button, and second-press timer cancellation are planned next.

## Support

Report bugs or request features through
[GitHub Issues](https://github.com/VadimTofan/BetterPullTen/issues).

This project is maintained through the
[BetterPullTen GitHub repository](https://github.com/VadimTofan/BetterPullTen).
