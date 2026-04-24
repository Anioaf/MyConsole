# My Console
> A console extension for Godot 4 modeled after the **Source 2 Developer Console**.

### Command System

- Runtime command execution
- Command registration API
- Built-in command descriptions
- Command aliases
- Command history navigation (`↑ ↓`)
- Command autocomplete (`TAB`)
- Suggestion hints

### Logging

- Default output
- Info logs
- Warning logs
- Error logs
- BBCode rich output support
- Scroll following
- Selectable console text

## Installation

## 1. Copy the addon folder

Place the addon in the project:

```text
addons/Console/
```

The directory structure should look like this:

```text
addons/
└── Console/
    ├── Console.gd
    ├── font/
    └── plugin files
```

---

## 2. Add font (optional)

Supported formats:

- `.ttf`
- `.otf`
- `.woff`
- `.woff2`

Place any font in:

```text
res://addons/Console/font/
```

The console will automatically load the first font it finds.

---

## 3. Add to scene

Add the script as a node:

```gdscript
extends CanvasLayer
```

or connect via:

```text
Autoload (Singleton)
```

We recommend using **Autoload**.

## Register Custom Commands

## Example

```gdscript
func _ready():
    register_command(
        "god_mode",
        _cmd_god_mode,
        "Enable immortal mode",
        "god_mode"
    )

func _cmd_god_mode(args: Array) -> void:
    player.invincible = true
    print_info("God mode enabled")
```

## Logging API

## Console Output Methods

```gdscript
print_line("Default message")
print_info("Info message")
print_warning("Warning message")
print_error("Error message")
print_bbcode("[color=red]Custom BBCode[/color]")
```
