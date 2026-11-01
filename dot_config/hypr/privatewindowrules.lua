-- 1. Создаём named rules, но ВЫКЛЮЧЕННЫЕ по умолчанию
local hideSensitive = hl.window_rule({
    name = "hide_sensitive_apps",
    no_screen_share = true,
    match = { 
    	class = "^(zen-work)$",
   	}
})
hideSensitive:set_enabled(false)

-- Telegram (64Gram): скрываем все окна, кроме окна с чатом «Satont.»
local hideTelegram = hl.window_rule({
    name = "hide_telegram",
    no_screen_share = true,
    match = {
        class = "^(org.telegram.desktop|io.github.tdesktop_x64.TDesktop)$",
        title = "negative:.*Satont\\..*",
    }
})
hideTelegram:set_enabled(false)

local hideDiscord = hl.window_rule({
    name = "hide_discord",
    no_screen_share = true,
    match = {
        class = "^discord$",
		title = "negative:.*(?i:twir ?app).*"
    }
})
hideDiscord:set_enabled(false)

local hideWorkStuff = hl.window_rule({
	name = "hide_work_stuff",
	no_screen_share = true,
	match = {
		title = ".*(Documents/M).*"
	}
})

hideWorkStuff:set_enabled(false)

local hideEnv = hl.window_rule({
    name = "hide_env_edit",
    no_screen_share = true,
    match = {
        class = "^(dev.zed.Zed|com.mitchellh.ghostty)$",
        title = ".*\\.env.*"
    }
})
hideEnv:set_enabled(false)

-- 2. Функция переключения
local function setPrivacy(enabled)
    hideSensitive:set_enabled(enabled)
    hideEnv:set_enabled(enabled)
    hideWorkStuff:set_enabled(enabled)
    hideDiscord:set_enabled(enabled)
    hideTelegram:set_enabled(enabled)
    
    if enabled then
        hl.notification.create({ 
            text = "🔒 Privacy ON — OBS запущен", 
            timeout = 2000 
        })
    else
        hl.notification.create({ 
            text = "🔓 Privacy OFF — OBS закрыт", 
            timeout = 2000 
        })
    end
end

-- 3. Таймер: проверяем каждые 2 секунды, запущен ли OBS
local privacyTimer = hl.timer(function()
    local handle = io.popen("pgrep -x obs")
    local result = handle:read("*a")
    handle:close()
    
    local obsRunning = result ~= "" and result ~= nil
    local currentlyEnabled = hideSensitive:is_enabled()
    
    if obsRunning and not currentlyEnabled then
        setPrivacy(true)
    elseif not obsRunning and currentlyEnabled then
        setPrivacy(false)
    end
end, { 
    timeout = 2000,  -- проверка каждые 2 сек
    type = "repeat" 
})

privacyTimer:set_enabled(true)

-- 4. При старте Hyprland тоже проверим (на случай если OBS уже был запущен)
hl.on("hyprland.start", function()
    local handle = io.popen("pgrep -x obs")
    local result = handle:read("*a")
    handle:close()
    if result ~= "" and result ~= nil then
        setPrivacy(true)
    end
end)
