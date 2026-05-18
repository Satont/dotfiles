hl.window_rule({
    name = "windowrule-1",
    suppress_event = "maximize",
    match = { class = ".*" },
})

hl.window_rule({
    name = "windowrule-2",
    float = true,
    pin = true,
    match = { title = "^(Picture(-|\\s)in(-|\\s)(p|P)icture)$" },
})

hl.window_rule({
    name = "windowrule-3",
    float = true,
    size = "(monitor_w*0.5) (monitor_h*0.5)",
    match = { class = "org.pulseaudio.pavucontrol" },
})

hl.window_rule({
    name = "windowrule-4",
    float = true,
    size = "(monitor_w*0.5) (monitor_h*0.5)",
    match = { class = "nemo" },
})

hl.window_rule({
    name = "windowrule-5",
    float = true,
    size = "(monitor_w*0.5) (monitor_h*0.5)",
    match = { class = "zen", title = "^Zen Browser$" },
})

hl.window_rule({
    name = "windowrule-6",
    tile = true,
    match = { class = "^(dev.warp.Warp)$" },
})

hl.window_rule({
    name = "windowrule-7",
    float = true,
    match = { title = "^(Untitled - Brave)" },
})

hl.window_rule({
    name = "windowrule-8",
    float = true,
    match = { title = "Bitwarden" },
})

hl.window_rule({
    name = "windowrule-9",
    float = true,
    match = { class = "^(com.github.hluk.copyq)$" },
})

hl.window_rule({
    name = "rulesatty",
    float = true,
    size = "(monitor_w*0.5) (monitor_h*0.5)",
    match = { class = "^(com.gabm.satty)$" },
})

hl.window_rule({
    name = "windowrule-19",
    float = true,
    match = { class = "(feh)", title = "^(feh)(.*)$" },
})

hl.window_rule({
    name = "windowrule-20",
    center = true,
    match = { float = true, class = "(feh)", title = "^(feh:)(.*)$" },
})

hl.window_rule({
    name = "windowrule-21",
    float = true,
    center = true,
    stay_focused = true,
    size = "400 600",
    match = { class = "^(chatterino-usercard)$" },
})

hl.window_rule({
    name = "windowrule-22",
    no_blur = true,
    no_shadow = true,
    match = { class = "^(chatterino.*)$" },
})

hl.window_rule({
    name = "windowrule-23",
    opacity = "0.95 0.95",
    match = { class = "^(dev.zed.Zed-.*)$" },
})

hl.window_rule({
    name = "windowrule-24",
    opacity = "0.9 0.9",
    match = { class = "^(dev.zed.Zed)$" },
})

hl.window_rule({
    name = "windowrule-25",
    opacity = "0.98 0.98",
    match = { class = "^(jetbrains-.*)$" },
})

hl.window_rule({
    name = "spotify-opacity",
    opacity = "0.8 0.8",
    match = { class = "^([Ss]potify)$" },
})

-- hl.window_rule({
--     name = "discord-opacity",
--     opacity = "0.8 0.8",
--     match = { class = "discord" },
-- })

hl.window_rule({
    name = "windowrule-goland",
    opacity = "0.9 0.9",
    match = { class = "jetbrains-goland" },
})

hl.window_rule({
    name = "windowrule-27",
    float = true,
    workspace = "5",
    match = { class = "^(steam)$" },
})

hl.window_rule({
    name = "windowrule-28",
    tile = true,
    size = "(monitor_w*0.3) (monitor_h*1)",
    match = { class = "^(steam)$", title = "Friends List" },
})

hl.window_rule({
    name = "windowrule-29",
    tile = true,
    size = "(monitor_w*0.7) (monitor_h*1)",
    match = { class = "^(steam)$", title = "Steam" },
})

hl.window_rule({
    name = "windowrule-30",
    stay_focused = true,
    min_size = "1 1",
    match = { title = "^()$", class = "^(steam)$" },
})

hl.window_rule({
    name = "windowrule-31",
    min_size = "280 635",
    match = { class = "^(steam)$", title = "^(Friends.*)$" },
})

hl.window_rule({
    name = "windowrule-32",
    fullscreen = true,
    match = { class = "^(gamescope)$" },
})

hl.window_rule({
    name = "windowrule-33",
    fullscreen = true,
    opacity = "1.0 override",
    match = { class = "^(steam_app_.*)$" },
})

hl.window_rule({
    name = "windowrule-34",
    opacity = "1.0 override",
    match = { fullscreen = true },
})

hl.window_rule({
    name = "windowrule-35",
    fullscreen = true,
    match = { class = "^(steam_app_238960)$" },
})

hl.window_rule({
    name = "windowrule-36",
    immediate = true,
    match = { content = "game" },
})

hl.window_rule({
    name = "windowrule-37",
    content = "game",
    match = { initial_class = "^(steam_app_\\d+)$" },
})

hl.window_rule({
    name = "opencode-float",
    float = true,
    center = true,
    size = "(monitor_w*0.7) (monitor_h*0.8)",
    workspace = "special:opencode",
    match = { initial_title = "^OpenCode Float$" },
})

hl.window_rule({
  name = "ghostty-no-blur",
  match = { class = "com.mitchellh.ghostty" },
  no_blur = true,
})
