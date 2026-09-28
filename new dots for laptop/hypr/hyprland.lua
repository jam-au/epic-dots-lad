-- ~/.config/hypr/hyprland.lua
-- Minimal, lightweight Hyprland config (Lua config format, Hyprland >= 0.55)
--
-- Note: since 0.55, hyprlang (hyprland.conf) is deprecated in favor of this
-- Lua-based config. Hyprland decides which one to load ONCE at startup:
-- if hyprland.lua exists, hyprland.conf next to it is ignored entirely.
-- Delete or rename any old hyprland.conf so it doesn't linger unused.
--
-- Wiki: https://wiki.hypr.land/Configuring/Start/
hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("XCURSOR_SIZE", "24")
------------------
---- MONITORS ----
------------------
hl.monitor({
    output = "",
    mode = "1920x1080@75",
    position = "auto",
    scale = "auto",
})

---------------------
---- MY PROGRAMS ----
---------------------
local terminal = "kitty"
local fileManager = "thunar"
local menu = "wofi --show drun"

-------------------
---- AUTOSTART ----
-------------------
-- exec-once has no direct keyword in Lua; subscribe to the start event instead.
-- hyprland.start fires once at startup, not on every config reload.
hl.on("hyprland.start", function()
    hl.exec_cmd("quickshell")
    hl.exec_cmd("dbus-update-activation-environment --systemd --all")
    hl.exec_cmd("hyprpaper")

end)

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("GBM_BACKEND", "nvidia-drm")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("WLR_NO_HARDWARE_CURSORS", "1")

-----------------------
---- LOOK AND FEEL ----
-----------------------
hl.config({
    general = {
        gaps_in = 3,
        gaps_out = 6,
        border_size = 2,
        col = {
            active_border = { colors = { "rgba(808080ff)", "rgba(808080ff)" }, angle = 45 },
            inactive_border = "rgba(808080ff)",
        },
        resize_on_border = false,
        allow_tearing = false,
        layout = "dwindle",
    },

    decoration = {
        rounding = 0,
        active_opacity = 1.0,
        inactive_opacity = 0.95,
        shadow = {
            enabled = true,
            range = 4,
            render_power = 2,
            color = 0xee1a1a1a,
        },
        blur = {
            enabled = true,
            size = 4,
            passes = 2,
            vibrancy = 0.1696,
        },
    },

    -- Kept off by default for a lightweight setup. Set enabled = true and
    -- add hl.curve/hl.animation calls below (see the upstream example
    -- config) if you want window/workspace motion.
    animations = {
        enabled = true,
    },

    dwindle = {
        preserve_split = true,
    },

    master = {
        new_status = "master",
    },

    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo = true,
    },

    -- vfr moved from misc to debug in a recent Hyprland release
    debug = {
        vfr = true,
    },

    input = {
        kb_layout = "us",
        follow_mouse = 1,
        sensitivity = 0,
        touchpad = {
            natural_scroll = false,
        },
    },

    cursor = {
        no_hardware_cursors = true,
        use_cpu_buffer = true,
    },
})

hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace",
})
---------------------
---- KEYBINDINGS ----
---------------------
local mainMod = "SUPER"

hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + C", hl.dsp.window.close())
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.exit())
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit")) -- dwindle only
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())
hl.bind("SUPER + R", hl.dsp.exec_cmd("rofi -show drun"))
hl.bind("SUPER + E", hl.dsp.exec_cmd("emote"))
-- Move focus with mainMod + arrow keys
hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))

-- Switch workspaces with mainMod + [0-9], move window with + SHIFT
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Scroll through workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Screenshot
hl.bind("PRINT", hl.dsp.exec_cmd("grimblast copy area"))

-- Media / volume keys
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl s 10%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl s 10%-"), { locked = true, repeating = true })

--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------
-- Real glass/blur behind the Waybar surface itself (needs
-- decoration.blur.enabled = true above, which this config already sets).
hl.layer_rule({
    name = "waybar-glass",
    match = { namespace = "^waybar$" },
    blur = true,
    ignore_alpha = 0.2,
})

hl.window_rule({
    name = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    -- Fix some dragging issues with XWayland
    name = "fix-xwayland-drags",
    match = {
        class = "^$",
        title = "^$",
        xwayland = true,
        float = true,
        fullscreen = false,
        pin = false,
    },
    no_focus = true,
})
