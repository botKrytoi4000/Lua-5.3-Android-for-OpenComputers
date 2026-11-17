-- ==========================================================
-- MineDroid OS v1.0 - Android for OpenComputers
-- ==========================================================

local component = require("component")
local computer = require("computer")
local unicode = require("unicode")

local gpu = component.gpu
gpu.bind(component.list("screen")())
gpu.setResolution(80, 25)
local W, H = gpu.getResolution()

-- ==========================================================
-- Палитра Material Design (Dark Theme)
-- ==========================================================
local C = {
  bg          = 0x121212, -- Фон Android
  surface     = 0x1E1E1E, -- Карточки
  primary     = 0x3DDC84, -- Android Green
  accent      = 0xBB86FC, -- Material Purple
  statusBar   = 0x000000, -- Черная полоса сверху
  navBar      = 0x000000, -- Черная полоса снизу
  text        = 0xFFFFFF, -- Белый текст
  textDim     = 0xAAAAAA, -- Серый текст
  cardBg      = 0x2C2C2C, -- Кнопки/Карточки
  danger      = 0xCF6679, -- Красный
  notification= 0x292929, -- Фон уведомления
}

-- ==========================================================
-- Состояние системы (System State)
-- ==========================================================
local state = "LOCK" -- LOCK, HOME, APP, NOTIFICATIONS, RECENTS
local previousState = "HOME"
local currentApp = nil

local notifications = {
  {title = "System", text = "Welcome to MineDroid OS v1.0!"},
  {title = "Play Market", text = "3 updates available."},
}

local quickToggles = {
  {name = "Redstone", active = false, icon = "⚡"},
  {name = "Wi-Fi", active = component.isAvailable("internet"), icon = "📡"},
  {name = "Bluetooth", active = true, icon = "ᛒ"},
  {name = "Flashlight", active = false, icon = "💡"}
}

-- ==========================================================
-- Утилиты
-- ==========================================================
local function getTime()
  local uptime = math.floor(computer.uptime())
  local h = math.floor((uptime / 3600) % 24)
  local m = math.floor((uptime / 60) % 60)
  return string.format("%02d:%02d", h, m)
end

local function getBattery()
  local energy = computer.energy()
  local maxEnergy = computer.maxEnergy()
  return math.floor((energy / maxEnergy) * 100)
end

local function addNotification(title, text)
  table.insert(notifications, 1, {title = title, text = text})
  if #notifications > 5 then table.remove(notifications) end
end

-- ==========================================================
-- Отрисовка системных элементов (UI)
-- ==========================================================

-- 1. Status Bar (Сверху)
local function drawStatusBar()
  gpu.setBackground(C.statusBar)
  gpu.setForeground(C.text)
  gpu.fill(1, 1, W, 1, " ")
  
  -- Левая часть: Время
  gpu.set(2, 1, getTime())
  
  -- Правая часть: Значки (Wi-Fi, Энергия, Уведомления)
  local batteryStr = getBattery() .. "% 🔋"
  local wifiStr = component.isAvailable("internet") and "📶 " or "❌ "
  local notifBadge = #notifications > 0 and "🔔 " or ""
  
  local rightText = notifBadge .. wifiStr .. batteryStr
  gpu.set(W - #rightText, 1, rightText)
end

-- 2. Navigation Bar (Снизу)
local function drawNavBar()
  gpu.setBackground(C.navBar)
  gpu.setForeground(C.textDim)
  gpu.fill(1, H, W, 1, " ")
  
  -- Кнопки Android: Назад, Домой, Недавние
  gpu.set(math.floor(W * 0.25), H, "◀") -- Back
  gpu.setForeground(C.primary)
  gpu.set(math.floor(W * 0.50), H, "●") -- Home
  gpu.setForeground(C.textDim)
  gpu.set(math.floor(W * 0.75), H, "■") -- Recents
end

-- ==========================================================
-- Экраны системы
-- ==========================================================

-- Экран блокировки
local function drawLockScreen()
  gpu.setBackground(C.bg)
  gpu.fill(1, 2, W, H - 2, " ")
  
  -- Часы
  gpu.setForeground(C.text)
  local timeStr = getTime()
  gpu.set(math.floor((W - #timeStr)/2), 6, timeStr)
  
  gpu.setForeground(C.accent)
  local dateStr = "MineDroid Mobile"
  gpu.set(math.floor((W - #dateStr)/2), 8, dateStr)
  
  -- Замок / Инструкция
  gpu.setForeground(C.textDim)
  local unlockStr = "🔒 Click anywhere to Unlock"
  gpu.set(math.floor((W - #unlockStr)/2), H - 4, unlockStr)
end

-- Приложения на Рабочем столе
local apps = {}

local function drawHomeScreen()
  gpu.setBackground(C.bg)
  gpu.fill(1, 2, W, H - 2, " ")
  
  -- Виджет поиска Google / MineDroid
  gpu.setBackground(C.surface)
  gpu.fill(6, 3, W - 12, 1, " ")
  gpu.setForeground(C.primary)
  gpu.set(8, 3, "🔍 Search or type URL...")
  
  -- Отрисовка иконкок
  for _, app in ipairs(apps) do
    gpu.setBackground(C.cardBg)
    gpu.fill(app.x, app.y, 10, 3, " ")
    gpu.setForeground(C.text)
    gpu.set(app.x + 4, app.y + 1, app.icon)
    
    gpu.setBackground(C.bg)
    gpu.setForeground(C.textDim)
    local title = app.name:sub(1, 10)
    gpu.set(app.x + math.floor((10 - #title)/2), app.y + 3, title)
  end
end

-- Шторка уведомлений
local function drawNotificationShade()
  gpu.setBackground(C.surface)
  gpu.fill(1, 2, W, H - 2, " ")
  
  -- Быстрые переключатели (Quick Toggles)
  gpu.setForeground(C.primary)
  gpu.set(3, 3, "Quick Settings")
  
  for i, toggle in ipairs(quickToggles) do
    local tx = 3 + (i - 1) * 18
    local ty = 5
    if toggle.active then
      gpu.setBackground(C.primary)
      gpu.setForeground(C.statusBar)
    else
      gpu.setBackground(C.cardBg)
      gpu.setForeground(C.textDim)
    end
    gpu.fill(tx, ty, 16, 2, " ")
    gpu.set(tx + 2, ty, toggle.icon .. " " .. toggle.name)
    gpu.set(tx + 2, ty + 1, toggle.active and "[ ON ]" or "[ OFF ]")
  end
  
  -- Список уведомлений
  gpu.setBackground(C.surface)
  gpu.setForeground(C.primary)
  gpu.set(3, 9, "Notifications (" .. #notifications .. ")")
  
  local ny = 11
  for i, notif in ipairs(notifications) do
    if ny + 2 < H - 1 then
      gpu.setBackground(C.notification)
      gpu.fill(3, ny, W - 6, 2, " ")
      gpu.setForeground(C.accent)
      gpu.set(5, ny, notif.title)
      gpu.setForeground(C.text)
      gpu.set(5, ny + 1, notif.text)
      ny = ny + 3
    end
  end
end

-- ==========================================================
-- Встроенные приложения (APKs)
-- ==========================================================

-- 1. App: Settings (Настройки)
local function appSettings(event, x, y)
  gpu.setBackground(C.bg)
  gpu.fill(1, 2, W, H - 2, " ")
  
  gpu.setForeground(C.primary)
  gpu.set(3, 3, "⚙ Settings")
  
  gpu.setForeground(C.text)
  gpu.set(3, 5, "OS Version: MineDroid 1.0 (Android 14 API)")
  gpu.set(3, 6, "Kernel: OpenComputers Lua 5.3")
  gpu.set(3, 7, "RAM: " .. math.floor(computer.totalMemory()/1024) .. " KB")
  gpu.set(3, 8, "Free Memory: " .. math.floor(computer.freeMemory()/1024) .. " KB")
  
  -- Кнопка перезагрузки
  gpu.setBackground(C.danger)
  gpu.setForeground(C.text)
  gpu.fill(3, 11, 16, 1, " ")
  gpu.set(5, 11, "Reboot Phone")
  
  if event == "touch" and x >= 3 and x <= 18 and y == 11 then
    computer.shutdown(true)
  end
end

-- 2. App: Calculator
local calcExpr = ""
local calcResult = "0"

local function appCalculator(event, x, y)
  gpu.setBackground(C.bg)
  gpu.fill(1, 2, W, H - 2, " ")
  
  -- Дисплей
  gpu.setBackground(C.cardBg)
  gpu.fill(20, 3, 40, 3, " ")
  gpu.setForeground(C.textDim)
  gpu.set(22, 4, calcExpr)
  gpu.setForeground(C.primary)
  gpu.set(58 - #calcResult, 5, calcResult)
  
  -- Кнопки
  local buttons = {
    {"7", "8", "9", "/"},
    {"4", "5", "6", "*"},
    {"1", "2", "3", "-"},
    {"C", "0", "=", "+"}
  }
  
  for row = 1, 4 do
    for col = 1, 4 do
      local bx = 20 + (col - 1) * 10
      local by = 7 + (row - 1) * 3
      gpu.setBackground(C.surface)
      gpu.setForeground(C.accent)
      gpu.fill(bx, by, 8, 2, " ")
      gpu.set(bx + 3, by + 1, buttons[row][col])
      
      if event == "touch" and x >= bx and x < bx + 8 and y >= by and y < by + 2 then
        local btn = buttons[row][col]
        if btn == "C" then
          calcExpr = ""
          calcResult = "0"
        elseif btn == "=" then
          local fn, err = load("return " .. calcExpr)
          if fn then
            local success, res = pcall(fn)
            calcResult = success and tostring(res) or "Error"
          else
            calcResult = "Error"
          end
        else
          calcExpr = calcExpr .. btn
        end
      end
    end
  end
end

-- 3. App: Termux (Консоль)
local termHistory = {"Termux Android Emulator", "Type 'help' for commands."}
local termInput = ""

local function appTermux(event, x, y, char, code)
  gpu.setBackground(0x000000)
  gpu.fill(1, 2, W, H - 2, " ")
  gpu.setForeground(0x00FF00)
  
  for i = 1, math.min(#termHistory, 18) do
    gpu.set(2, 2 + i, termHistory[#termHistory - math.min(#termHistory, 18) + i])
  end
  
  gpu.set(2, H - 2, "$ " .. termInput .. "_")
  
  if event == "key_down" then
    if code == 28 then -- Enter
      table.insert(termHistory, "$ " .. termInput)
      if termInput == "clear" then termHistory = {}
      elseif termInput == "help" then table.insert(termHistory, "Commands: clear, help, date, ping")
      elseif termInput == "date" then table.insert(termHistory, getTime())
      elseif termInput == "ping" then table.insert(termHistory, "pong 64 bytes from 127.0.0.1")
      else table.insert(termHistory, "sh: command not found: " .. termInput) end
      termInput = ""
    elseif code == 14 then -- Backspace
      termInput = termInput:sub(1, -2)
    elseif char >= 32 and char <= 126 then
      termInput = termInput .. string.char(char)
    end
  end
end

-- 4. App: Play Market
local function appPlayMarket(event, x, y)
  gpu.setBackground(C.bg)
  gpu.fill(1, 2, W, H - 2, " ")
  
  gpu.setForeground(C.primary)
  gpu.set(3, 3, "🛍 Play Market")
  
  local storeApps = {
    {title = "CraftBird (Game)", dev = "Mojang Studios", installed = true},
    {title = "Redstone Smart Home", dev = "MineSoft", installed = false},
    {title = "Spotify Music", dev = "AudioOC", installed = false},
  }
  
  for i, item in ipairs(storeApps) do
    local iy = 4 + (i * 4)
    gpu.setBackground(C.surface)
    gpu.fill(3, iy, W - 6, 3, " ")
    gpu.setForeground(C.text)
    gpu.set(5, iy + 1, item.title)
    gpu.setForeground(C.textDim)
    gpu.set(5, iy + 2, "Dev: " .. item.dev)
    
    if item.installed then
      gpu.setBackground(C.cardBg)
      gpu.setForeground(C.textDim)
      gpu.set(W - 16, iy + 1, "[ Installed ]")
    else
      gpu.setBackground(C.primary)
      gpu.setForeground(C.statusBar)
      gpu.set(W - 16, iy + 1, "  GET/INSTALL ")
      
      if event == "touch" and x >= W - 16 and x <= W - 4 and y == iy + 1 then
        item.installed = true
        addNotification("Play Market", "Installed " .. item.title)
      end
    end
  end
end

-- Регистрация иконок на рабочем столе
apps = {
  {name = "Settings", icon = "⚙", x = 5, y = 6, run = appSettings},
  {name = "Calculator", icon = "🧮", x = 18, y = 6, run = appCalculator},
  {name = "Termux", icon = "💻", x = 31, y = 6, run = appTermux},
  {name = "Play Market", icon = "🛍", x = 44, y = 6, run = appPlayMarket},
}

-- ==========================================================
-- Главный Обработчик событий (Event Loop)
-- ==========================================================

local function render()
  drawStatusBar()
  
  if state == "LOCK" then
    drawLockScreen()
  elseif state == "HOME" then
    drawHomeScreen()
  elseif state == "NOTIFICATIONS" then
    drawNotificationShade()
  elseif state == "APP" and currentApp then
    currentApp.run("draw")
  end
  
  drawNavBar()
end

render()

while true do
  local ev = {computer.pullSignal(0.5)}
  local eType, _, x, y, button, char, code = ev[1], ev[2], ev[3], ev[4], ev[5], ev[6], ev[7]
  
  -- Клики по Navigation Bar (Нижние кнопки Android)
  if eType == "touch" and y == H then
    if x >= W * 0.20 and x <= W * 0.35 then -- BACK
      if state == "APP" or state == "NOTIFICATIONS" then
        state = "HOME"
        currentApp = nil
      end
    elseif x >= W * 0.45 and x <= W * 0.55 then -- HOME
      state = "HOME"
      currentApp = nil
    elseif x >= W * 0.70 and x <= W * 0.80 then -- RECENTS
      addNotification("System", "No background apps cached.")
    end
    render()
    
  -- Клики по Status Bar (Вызов шторки)
  elseif eType == "touch" and y == 1 then
    if state ~= "LOCK" then
      if state == "NOTIFICATIONS" then
        state = previousState
      else
        previousState = state
        state = "NOTIFICATIONS"
      end
      render()
    end
    
  -- События внутри Экрана блокировки
  elseif state == "LOCK" then
    if eType == "touch" then
      state = "HOME"
      render()
    end
    
  -- События на Рабочем столе
  elseif state == "HOME" then
    if eType == "touch" then
      for _, app in ipairs(apps) do
        if x >= app.x and x < app.x + 10 and y >= app.y and y < app.y + 4 then
          currentApp = app
          state = "APP"
          break
        end
      end
      render()
    end
    
  -- События в Шторке уведомлений
  elseif state == "NOTIFICATIONS" then
    if eType == "touch" then
      for i, toggle in ipairs(quickToggles) do
        local tx = 3 + (i - 1) * 18
        if x >= tx and x < tx + 16 and y >= 5 and y <= 6 then
          toggle.active = not toggle.active
          if toggle.name == "Redstone" then
            component.redstone.setOutput(15, toggle.active and 15 or 0)
          end
          break
        end
      end
      render()
    end
    
  -- Передача событий в запущенное Приложение
  elseif state == "APP" and currentApp then
    currentApp.run(eType, x, y, char, code)
    render()
  else
    -- Обновление часов каждые 0.5сек
    drawStatusBar()
  end
end
