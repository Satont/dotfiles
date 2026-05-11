-- Migrated from hyprland.conf for Hyprland 0.55+
-- hyprpaper remains on hyprlang via hyprpaper.conf

hl.monitor({ output = "DP-1", mode = "2560x1440@165", position = "1920x0", scale = "1", vrr = 0 })
hl.monitor({ output = "HDMI-A-2", mode = "1920x1080", position = "0x0", scale = "1" })
hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@75", position = "4480x0", scale = "1" })

hl.workspace_rule({ workspace = "1", monitor = "DP-1", persistent = true, default = true })
hl.workspace_rule({ workspace = "2", monitor = "DP-1" })
hl.workspace_rule({ workspace = "3", monitor = "DP-1" })
hl.workspace_rule({ workspace = "4", monitor = "DP-1" })
hl.workspace_rule({ workspace = "5", monitor = "DP-1" })
hl.workspace_rule({ workspace = "6", monitor = "DP-1" })
hl.workspace_rule({ workspace = "7", monitor = "DP-1" })
hl.workspace_rule({ workspace = "8", monitor = "DP-1" })
hl.workspace_rule({ workspace = "9", monitor = "HDMI-A-1", persistent = true })
hl.workspace_rule({ workspace = "10", monitor = "HDMI-A-1", default = true, persistent = true })
hl.workspace_rule({ workspace = "11", monitor = "HDMI-A-2", persistent = true })
hl.workspace_rule({ workspace = "12", monitor = "HDMI-A-2", default = true, persistent = true })

hl.config({
    input = {
        kb_layout = "us,ru",
        kb_options = "grp:win_space_toggle",
        kb_variant = "",
        kb_model = "",
        kb_rules = "",
        follow_mouse = 1,
        touchpad = {
            natural_scroll = false,
        },
        sensitivity = -0.5,
        numlock_by_default = true,
    },
})

hl.config({
    general = {
        gaps_in = 2,
        gaps_out = 8,
        border_size = 1,
        col = {
            active_border = "rgba(ffffff66)",
            inactive_border = "rgba(ffffff33)",
        },
        layout = "dwindle",
        allow_tearing = false,
    },
})

hl.config({
    decoration = {
        rounding = 10,
        rounding_power = 2,
        active_opacity = 1.0,
        inactive_opacity = 1.0,
        shadow = {
            enabled = true,
            range = 4,
            render_power = 3,
            color = "rgba(1a1a1aee)",
        },
        blur = {
            enabled = true,
            size = 10,
            passes = 2,
            new_optimizations = true,
            ignore_opacity = true,
            xray = true,
            vibrancy = 0.1696,
        },
    },
})

hl.config({
    animations = {
        enabled = true,
    },
})

hl.curve("myBezier", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })

hl.animation({ leaf = "windows", enabled = true, speed = 1, bezier = "default" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1, bezier = "default", style = "popin 80%" })
hl.animation({ leaf = "border", enabled = true, speed = 5, bezier = "default" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 6, bezier = "default" })
hl.animation({ leaf = "fade", enabled = true, speed = 1, bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = false })

hl.config({
    dwindle = {
        preserve_split = true,
    },
})

hl.config({
    master = {
        new_on_top = true,
    },
})

hl.config({
    misc = {
        force_default_wallpaper = 0,
        middle_click_paste = false,
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        mouse_move_enables_dpms = true,
    },
})

hl.config({
    debug = {
        vfr = true,
    },
})

ACTIVE_BORDER_COLOR = { colors = { "rgba(33ccffee)", "rgba(00ff99ee)" }, angle = 45 }
INACTIVE_BORDER_COLOR = "rgba(595959aa)"

hl.config({
    group = {
        col = {
            border_active = ACTIVE_BORDER_COLOR,
            border_inactive = INACTIVE_BORDER_COLOR,
            border_locked_active = "0x00000000",
            border_locked_inactive = "0x00000000",
        },
        groupbar = {
            font_size = 12,
            font_family = "monospace",
            font_weight_active = "ultraheavy",
            font_weight_inactive = "normal",
            indicator_height = 0,
            indicator_gap = 0,
            height = 15,
            gaps_in = 0,
            gaps_out = 0,
            text_color = "rgb(ffffff)",
            text_color_inactive = "rgba(ffffff90)",
            col = {
                active = "rgba(00000040)",
                inactive = "rgba(00000020)",
            },
            gradients = true,
            gradient_rounding = 0,
            gradient_round_only_edges = false,
        },
    },
})

MAIN_MOD = "SUPER"
TERMINAL = "ghostty"
FILE_MANAGER = "nautilus"
BROWSER = "zen-browser"
MENU = "vicinae vicinae://toggle"

dofile(os.getenv("HOME") .. "/.config/hypr/windowrules.lua")
dofile(os.getenv("HOME") .. "/.config/hypr/env.lua")
dofile(os.getenv("HOME") .. "/.config/hypr/exec.lua")
dofile(os.getenv("HOME") .. "/.config/hypr/binds.lua")
