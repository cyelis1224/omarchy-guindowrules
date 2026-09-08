# 󰖲 GUIndowRules

> **KDE System Settings-style visual window rules manager for Hyprland with crosshair window detection and live property synchronization.**

GUIndowRules is an [Omarchy Shell](https://github.com/cyelis1224) plugin that lets you inspect, create, customize, reorder, and manage all your Hyprland window rules through an intuitive, aesthetic graphical interface.

It works directly with your `~/.config/hypr/windowrules.lua`, preserving custom code, comments, section headers, and non-rule tails (such as layer rules and dynamic logic).

---

## ✨ Features

- **🎯 Crosshair Window Detector**: Click **Detect Window** to get a fullscreen scrim with a crosshair cursor. Click any window on any monitor, and choose matching criteria (`class`, `title`, `initial_class`, `initial_title`).
- **🎛️ Dynamic KDE-Style Property Cards**:
  - Add and remove individual properties (`float`, `tile`, `opacity`, `workspace`, `monitor`, `size`, `move`, `no_blur`, `hyprbars:no_bar`, etc.).
  - Intuitive controls for every property type: toggle switches for booleans, dropdowns for enums, and sliders with percentage presets for opacity.
  - Delete individual properties directly from cards (`󰅖`) without affecting the rest of the rule.
- **⚡ Real-Time Live Property Sync**:
  - Dragging the opacity slider or changing properties immediately updates open matching windows in real-time via Hyprland's `hl.dsp.window.set_prop` dispatcher (~4ms).
- **📋 Rule List & Order Management**:
  - Reorder rules using **Move Up** (`󰁝`) and **Move Down** (`󰁅`) to control evaluation precedence.
  - **Duplicate** (`󰉍`) rules with one click.
  - **Enable / Disable** rules with quick toggle switches.
  - **Direct Deletion** (`󰆴`) from the list or editor.
- **🛡️ Safe Bidirectional Lua Sync**:
  - Automatically parses `~/.config/hypr/windowrules.lua` into reactive models.
  - Creates timestamped backups (`.bak`) before saving.
  - Preserves section comments (`-- Opacity Rules`, `-- Floating Window Rules`) and any non-rule custom Lua tails (layer rules, loops, helper functions).

---

## 🚀 Keybindings

Add to your `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + W", "Window Rules Manager", "omarchy-shell -q dagyr.guindowrules toggle")
```

---

## 🔌 CLI & IPC Commands

Open, close, or toggle the GUIndowRules panel from terminal or scripts:

```bash
# Toggle panel
omarchy-shell dagyr.guindowrules toggle

# Open panel
omarchy-shell dagyr.guindowrules open

# Close panel
omarchy-shell dagyr.guindowrules close
```

---

## 📦 Installation

Clone or link this repository into your Omarchy plugins directory:

```bash
omarchy plugin add https://github.com/cyelis1224/omarchy-guindowrules.git --enable
omarchy-restart-shell
```

---

## 📄 License

[MIT](LICENSE) © 2026 Dagyr
