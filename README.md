# Endma Hub

A dependency-free, minimalist Roblox UI library for scripts, admin tools, developer utilities, and custom interfaces.

- Default `Carbon` theme
- Optional `Cyan` and other static themes
- No animated gradients or continuous color effects
- Desktop and mobile support
- Safe callback isolation
- Optional executor config persistence
- RightShift visibility toggle by default

## Load

```lua
local Endma = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/ardadeska-cmyk/endw/main/menu.lua"
))()
```

For Roblox Studio, paste `menu.lua` into a client-side `ModuleScript` and use:

```lua
local Endma = require(path.to.Endma)
```

## Quick Start

```lua
local Endma = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/ardadeska-cmyk/endw/main/menu.lua"
))()

local Window = Endma:CreateWindow({
    Title = "My Script",
    Subtitle = "Powered by Endma Hub",
    Theme = "Carbon",
    ToggleKey = Enum.KeyCode.RightShift,

    SaveConfig = true,
    Config = {
        Folder = "EndmaHub",
        File = "MyScript",
    },
})

local MainTab = Window:CreateTab({
    Name = "Main",
})

local General = MainTab:CreateSection({
    Name = "General",
})

General:AddButton({
    Name = "Run action",
    Description = "Runs a custom callback.",

    Callback = function()
        Window:Notify({
            Title = "Completed",
            Content = "The action was executed.",
            Type = "Success",
        })
    end,
})

General:AddCheckbox({
    Name = "Auto mode",
    Flag = "AutoMode",
    Default = false,

    Callback = function(enabled)
        print("Auto mode:", enabled)
    end,
})

General:AddSlider({
    Name = "Speed",
    Flag = "Speed",
    Min = 0,
    Max = 100,
    Default = 25,
    Increment = 1,
    Suffix = "%",

    Callback = function(value)
        print("Speed:", value)
    end,
})

General:AddDropdown({
    Name = "Target",
    Flag = "Target",
    Options = {
        "Nearest",
        "Lowest Health",
        "Random",
    },
    Default = "Nearest",

    Callback = function(value)
        print("Target:", value)
    end,
})

General:AddKeybind({
    Name = "Action key",
    Flag = "ActionKey",
    Default = Enum.KeyCode.F,

    Callback = function(keyCode)
        print("Selected key:", keyCode.Name)
    end,
})
```

## Structure

```text
Endma
└── CreateWindow(config)
    └── CreateTab(config)
        └── CreateSection(config)
            └── AddControl(config)
```

## Controls

| Method | Important fields | Callback |
|---|---|---|
| `AddButton` | `Name`, `Description`, `ButtonText` | `function()` |
| `AddToggle` | `Name`, `Default`, `Flag` | `function(enabled)` |
| `AddCheckbox` | `Name`, `Default`, `Flag` | `function(enabled)` |
| `AddSlider` | `Min`, `Max`, `Default`, `Increment`, `Flag` | `function(value)` |
| `AddRangeSlider` | `Min`, `Max`, `Default`, `Increment`, `Flag` | `function(low, high)` |
| `AddDropdown` | `Options`, `Default`, `Flag` | `function(value)` |
| `AddMultiDropdown` | `Options`, `Default`, `Flag` | `function(values)` |
| `AddInput` | `Default`, `Placeholder`, `Numeric`, `MaxLength`, `Flag` | `function(text)` |
| `AddKeybind` | `Default`, `Flag` | `function(keyCode)` |
| `AddColorPicker` | `Default`, `Flag` | `function(color)` |
| `AddProgress` | `Min`, `Max`, `Default`, `Flag` | `function(value)` |
| `AddLabel` | `Text` | None |
| `AddParagraph` | `Name`, `Content` | None |
| `AddDivider` | None | None |

Every value control returns an object supporting:

```lua
Control:Get()
Control:Set(value)
Control:SetDisabled(boolean)
Control:SetVisible(boolean)
Control:Destroy()
```

Additional methods:

```lua
Button:Fire()
Button:SetText("New text")

Dropdown:Open()
Dropdown:Close()
Dropdown:Refresh(newOptions, keepValue)

Paragraph:SetTitle("New title")
```

## Window API

```lua
Window:SetTheme("Cyan")
Window:SetVisible(true)
Window:Toggle()
Window:SetMinimized(true)
Window:SetScale(1)
Window:SetToggleKey(Enum.KeyCode.RightShift)
Window:SetDimBackground(true)

Window:GetFlag("Speed")
Window:SetFlag("Speed", 50)

Window:SaveConfig()
Window:LoadConfig()
Window:ResetConfig()
Window:Destroy()
```

## Notifications

```lua
Window:Notify({
    Title = "Saved",
    Content = "Configuration saved successfully.",
    Type = "Success",
    Duration = 4,
})
```

Notification types:

```text
Info
Success
Warning
Error
Danger
```

## Dialogs

```lua
Window:Dialog({
    Title = "Delete configuration",
    Content = "This action cannot be undone.",
    ConfirmText = "Delete",
    CancelText = "Cancel",

    OnConfirm = function()
        print("Confirmed")
    end,

    OnCancel = function()
        print("Cancelled")
    end,
})
```

## Themes

Built-in themes:

```text
Carbon
Monochrome
Slate
Cyan
Emerald
Crimson
Amber
Frost
```

`Carbon` is the default. Theme changes are instant and do not use animated color transitions.

Register a custom theme by overriding any Carbon tokens:

```lua
Endma:RegisterTheme("Custom", {
    Accent = Color3.fromRGB(120, 100, 255),
    Background = Color3.fromRGB(12, 12, 16),
    Surface = Color3.fromRGB(20, 20, 26),
})

Window:SetTheme("Custom")
```

Supported tokens:

```text
Ink
Background
Surface
Surface2
SurfaceHover
Stroke
Text
Muted
Accent
Success
Warning
Danger
```

## Configuration

Configuration is enabled with:

```lua
SaveConfig = true,

Config = {
    Folder = "EndmaHub",
    File = "MyScript",
}
```

When `readfile`, `writefile`, `isfile`, and `makefolder` are available, Endma Hub stores:

- Selected theme
- Toggle key
- UI scale
- Reduced-motion preference
- Background dim preference
- Flag values

If file APIs are unavailable, the UI continues working with in-memory values.

## Notes

- RightShift toggles the window unless a TextBox is focused.
- Touch devices receive a persistent mobile toggle button.
- Re-running the same window ID cleans up the previous GUI and connections.
- Callback errors are isolated and shown as notifications.
- Endma Hub only handles presentation and callbacks.
- Gameplay decisions, purchases, damage, permissions, and other authoritative actions should remain server-controlled.

## License

MIT License

Copyright (c) 2026 Endma Hub contributors

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files, to use, copy, modify, merge, publish, distribute, sublicense, and sell copies of the software, subject to inclusion of this copyright and permission notice.

The software is provided “as is”, without warranty of any kind. The authors are not liable for claims, damages, or other liability arising from the software or its use.
