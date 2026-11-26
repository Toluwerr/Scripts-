local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local global = _G

local previous = global.__SYMPHONY_AP
if previous then
    previous.alive = false
    if type(previous.cleanup) == "function" then
        pcall(previous.cleanup)
    else
        pcall(function() previous.conn:Disconnect() end)
        pcall(function() previous.win:Destroy() end)
    end
    global.__SYMPHONY_AP = nil
end

local state = {
    alive = true,
    enabled = false,
    humanize = false,
    antiAFK = true,
    amount = 35,
    lastNote = {},
    offsets = setmetatable({}, {__mode = "k"}),
    played = setmetatable({}, {__mode = "k"})
}

local function upvalues(fn)
    local ok, values = pcall(getupvalues, fn)
    if ok and type(values) == "table" then return values end
end

local function isKeymap(value)
    if type(value) ~= "table" then return false end
    for key in pairs(value) do
        return typeof(key) == "EnumItem"
    end
    return false
end

local function validateLaneDown(fn)
    if type(fn) ~= "function" then return end
    local values = upvalues(fn)
    if not values or #values < 13 then return end
    local config = values[8]
    if type(config) ~= "table"
        or type(rawget(config, "PerfectWindow")) ~= "number"
        or type(rawget(config, "DefaultLaneKeys")) ~= "table"
        or type(values[4]) ~= "number"
        or type(values[7]) ~= "number"
        or type(values[10]) ~= "table"
        or type(values[2]) ~= "table"
        or type(values[11]) ~= "number"
        or type(values[12]) ~= "function" then
        return
    end
    return {laneDown = fn, Config = config, held = values[2]}
end

local function resolveEngine()
    for _, connection in ipairs(getconnections(player:GetAttributeChangedSignal("OrchestraPadKeys"))) do
        local outer = upvalues(connection.Function)
        if not outer or type(outer[1]) ~= "function"
            or type(outer[2]) ~= "boolean" or type(outer[3]) ~= "function" then
            continue
        end
        local bindings = upvalues(outer[3])
        if not bindings then continue end
        for _, action in ipairs(bindings) do
            if type(action) ~= "function" then continue end
            local values = upvalues(action)
            if not values then continue end
            local keymap
            for _, value in ipairs(values) do
                if isKeymap(value) then keymap = value end
            end
            if not keymap then continue end
            for _, value in ipairs(values) do
                local engine = validateLaneDown(value)
                if engine then
                    engine.onLaneAction = action
                    engine.keymap = keymap
                    return engine
                end
            end
        end
    end
    error("RhythmClient lane engine not found")
end

local resolved, result = pcall(resolveEngine)
local engine = resolved and result or nil
local resolveError = not resolved and tostring(result) or nil
state.engine = engine

local function keyForLane(lane)
    local key = engine.Config.LaneKeys and engine.Config.LaneKeys[lane]
    if key and engine.keymap[key] == lane then return key end
    for candidate, mapped in pairs(engine.keymap) do
        if mapped == lane then return candidate end
    end
end

local function pressLane(lane)
    local key = keyForLane(lane)
    if not key then return false end
    return pcall(engine.onLaneAction, nil, Enum.UserInputState.Begin, {KeyCode = key})
end

local function releaseLane(lane)
    if engine and state.lastNote[lane] then
        pcall(function() engine.held[lane] = nil end)
    end
    state.lastNote[lane] = nil
end

local function resetNotes()
    for lane in pairs(state.lastNote) do releaseLane(lane) end
    table.clear(state.offsets)
    table.clear(state.played)
end

local function setEnabled(value)
    state.enabled = state.alive and engine ~= nil and value == true
    if not state.enabled then resetNotes() end
end

local function finite(value, fallback)
    if type(value) == "number" and value == value and math.abs(value) < math.huge then
        return value
    end
    return fallback
end

local random = Random.new()

local function noteDelay(note, perfect, frameTime)
    if not state.humanize then return 0 end
    local offset = state.offsets[note]
    if offset == nil then
        offset = random:NextNumber()
        state.offsets[note] = offset
    end
    local allowance = math.max(0, math.min(perfect * 0.5, perfect - frameTime * 1.5))
    return offset * allowance * state.amount / 100
end

local function update(dt)
    if not state.alive or not state.enabled then return end
    local values = upvalues(engine.laneDown)
    if not values then return end
    local clockOffset, songStart, notes = values[4], values[7], values[10]
    if type(clockOffset) ~= "number" or type(songStart) ~= "number" or type(notes) ~= "table" then
        return
    end

    if state.songStart ~= songStart then
        resetNotes()
        state.songStart = songStart
    end

    local config = engine.Config
    local audioOffset = finite(config.AudioOffset, 0)
        + finite(player:GetAttribute("OrchestraAudioOffset"), 0) / 1000
    local position = os.clock() + clockOffset - songStart - audioOffset
    local good = finite(values[11], finite(config.GoodWindow, 0.12))
    local horizon = good + finite(config.LateGrace, 0.05) - 0.02
    local perfect = math.max(0, finite(config.PerfectWindow, 0))
    local frameTime = math.max(0, finite(dt, 1 / 60))

    for lane, held in pairs(state.lastNote) do
        if position > held.time + held.length + 0.06 then
            releaseLane(lane)
        end
    end

    for _, note in ipairs(notes) do
        if type(note) ~= "table" or note.Judged or state.played[note] then continue end
        local time, lane = note.Time, note.Lane
        if type(time) ~= "number" or type(lane) ~= "number"
            or lane < 1 or lane > 4 or lane % 1 ~= 0 then
            continue
        end

        local delta = position - time
        if delta < noteDelay(note, perfect, frameTime) or delta > horizon then continue end

        if pressLane(lane) then
            state.played[note] = true
            state.lastNote[lane] = {
                time = time,
                length = math.max(0, finite(tonumber(note.Length), 0))
            }
        end
    end
end

local function cleanup()
    state.alive = false
    setEnabled(false)
    if state.conn then
        pcall(function() state.conn:Disconnect() end)
        state.conn = nil
    end
    if state.idleConnection then
        state.idleConnection:Disconnect()
        state.idleConnection = nil
    end
    if global.__SYMPHONY_AP == state then
        global.__SYMPHONY_AP = nil
    end
end

state.cleanup = cleanup

local ok, library = pcall(function()
    return loadstring(game:HttpGet(
        "https://raw.githubusercontent.com/Toluwer/Reborn/main/src/Reborn.luau?t="
            .. tostring(DateTime.now().UnixTimestampMillis)
    ))()
end)

if not ok or type(library) ~= "table" or type(library.CreateWidget) ~= "function" then
    cleanup()
    warn("Symphony: Reborn widget unavailable")
    return
end

local built, widget = pcall(function()
    local ui = library:CreateWidget({
        Title = "Symphony",
        Width = 280,
        OnClose = cleanup
    })
    state.win = ui
    local status = ui:Paragraph({Text = engine and "Ready" or "Engine unavailable"})
    local autoplay
    autoplay = ui:Toggle({
        Text = "Autoplay",
        Value = false,
        Callback = function(value)
            setEnabled(value)
            if value and not state.enabled then
                if autoplay then autoplay:Set(false, false) end
                status:Set("Engine unavailable")
            else
                status:Set(state.enabled and "Playing" or "Ready")
            end
        end
    })
    ui:Toggle({
        Text = "Humanize",
        Value = false,
        Callback = function(value)
            state.humanize = value == true
        end
    })
    ui:Slider({
        Text = "Timing variation (%)",
        Min = 0,
        Max = 100,
        Value = state.amount,
        Callback = function(value)
            state.amount = math.clamp(finite(tonumber(value), 35), 0, 100)
        end
    })
    ui:Toggle({
        Text = "Anti-AFK",
        Value = state.antiAFK,
        Callback = function(value)
            state.antiAFK = value == true
        end
    })
    if resolveError then status:Set("Engine unavailable: " .. resolveError:sub(1, 80)) end
    return ui
end)

if not built then
    cleanup()
    if state.win then pcall(function() state.win:Destroy() end) end
    warn("Symphony: " .. tostring(widget))
    return
end

global.__SYMPHONY_AP = state

state.idleConnection = player.Idled:Connect(function()
    if not state.alive or not state.antiAFK then return end
    pcall(function()
        local virtualUser = game:GetService("VirtualUser")
        virtualUser:CaptureController()
        virtualUser:ClickButton2(Vector2.zero)
    end)
end)

if engine then
    state.conn = RunService.Heartbeat:Connect(update)
end
