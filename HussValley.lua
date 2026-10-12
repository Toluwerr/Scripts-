local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PLACE_ID = 107535308163741
local SPOOF_INTERVAL = 0.25
local SPOOF_ATTRIBUTES = {
        "AbilityReadyAt",
        "GearReadyAt",
        "TackleReadyAt",
        "TruckAbilityReadyAt",
        "StepOverReadyAt",
        "GhostAbilityReadyAt",
        "CloneAbilityReadyAt",
}

local LocalPlayer = Players.LocalPlayer
local Global = (getgenv and getgenv()) or _G

if type(Global.__HussValleyCleanup) == "function" then
        pcall(Global.__HussValleyCleanup)
end

local Reborn
do
        local ok, library = pcall(function()
                return loadstring(game:HttpGet(
                        "https://raw.githubusercontent.com/Toluwer/Reborn/main/src/Reborn.luau"
                ))()
        end)

        if not ok or type(library) ~= "table" or type(library.CreateWindow) ~= "function" then
                warn("[HussValley] Failed to load the Reborn UI library.")
                return
        end

        Reborn = library
end

local Window = Reborn:CreateWindow({
        Title = "Huss Valley",
        Size = Vector2.new(500, 330),
})

local function registerEarlyExit()
        Global.__HussValleyCleanup = function()
                pcall(function()
                        Window:Destroy()
                end)
                Global.__HussValleyCleanup = nil
        end
end

if game.PlaceId ~= PLACE_ID then
        local tab = Window:Tab("Main", "zap")
        local section = tab:Section("Huss Valley")
        section:Paragraph({Text = "Wrong game."})
        registerEarlyExit()
        return
end

local ChickenOrHero = ReplicatedStorage:WaitForChild("ChickenOrHero", 10)
if not ChickenOrHero then
        local tab = Window:Tab("Main", "zap")
        local section = tab:Section("Huss Valley")
        section:Paragraph({Text = "Game updated?"})
        registerEarlyExit()
        return
end

local Movement = ChickenOrHero:FindFirstChild("Movement")
local MovementModelScript = Movement and Movement:FindFirstChild("MovementModel")
local GameFolder = ChickenOrHero:FindFirstChild("Game")
local TacklePredictionScript = GameFolder and GameFolder:FindFirstChild("TacklePrediction")
local GearFolder = ChickenOrHero:FindFirstChild("Gear")
local GearEvent = GearFolder and GearFolder:FindFirstChild("GearEvent")
local GameAction = GameFolder and GameFolder:FindFirstChild("GameAction")
local Presentation = ChickenOrHero:FindFirstChild("Presentation")
local MovementGuardEvent = Presentation and Presentation:FindFirstChild("MovementGuardEvent")

local okModel, MovementModel = pcall(function()
        return require(MovementModelScript)
end)
local okTackle, TacklePrediction = pcall(function()
        return require(TacklePredictionScript)
end)

if not okModel
        or type(MovementModel) ~= "table"
        or type(MovementModel.step) ~= "function"
        or not okTackle
        or type(TacklePrediction) ~= "table"
        or type(TacklePrediction.remaining) ~= "function"
        or not GearEvent
        or not GameAction then
        local tab = Window:Tab("Main", "zap")
        local section = tab:Section("Huss Valley")
        section:Paragraph({Text = "Game updated?"})
        registerEarlyExit()
        return
end

local connections = {}
local loopToken = 0
local spoofActive = false
local dashActive = false
local tackleActive = false
local originalStep = nil
local originalRemaining = nil
local lastServer = {}
local stats = {ok = 0, rejected = 0, serverCd = 0, fairPlay = 0}

local function connect(signal, callback)
        local connection = signal:Connect(callback)
        table.insert(connections, connection)
        return connection
end

local function setDash(enabled)
        if enabled == dashActive then
                return
        end
        if enabled then
                if MovementModel.__HussValleyWrapped then
                        return
                end
                originalStep = MovementModel.step
                MovementModel.__HussValleyWrapped = true
                MovementModel.step = function(model, moveDirection, speed, dt, profile, grounded, ...)
                        local result = originalStep(model, moveDirection, speed, dt, profile, grounded, ...)
                        model.cooldown = 0
                        model.recoveryRemaining = 0
                        return result
                end
                dashActive = true
        else
                if MovementModel.__HussValleyWrapped then
                        MovementModel.step = originalStep
                        MovementModel.__HussValleyWrapped = nil
                end
                originalStep = nil
                dashActive = false
        end
end

local function setTackle(enabled)
        if enabled == tackleActive then
                return
        end
        if enabled then
                if TacklePrediction.__HussValleyWrapped then
                        return
                end
                originalRemaining = TacklePrediction.remaining
                TacklePrediction.__HussValleyWrapped = true
                TacklePrediction.remaining = function()
                        return 0
                end
                tackleActive = true
        else
                if TacklePrediction.__HussValleyWrapped then
                        TacklePrediction.remaining = originalRemaining
                        TacklePrediction.__HussValleyWrapped = nil
                end
                originalRemaining = nil
                tackleActive = false
        end
end

local function setSpoof(enabled)
        if enabled then
                if spoofActive then
                        return
                end
                spoofActive = true
                loopToken = loopToken + 1
                local token = loopToken
                task.spawn(function()
                        while spoofActive and token == loopToken do
                                for _, name in ipairs(SPOOF_ATTRIBUTES) do
                                        if LocalPlayer:GetAttribute(name) ~= 0 then
                                                LocalPlayer:SetAttribute(name, 0)
                                        end
                                end
                                task.wait(SPOOF_INTERVAL)
                        end
                end)
        else
                spoofActive = false
                loopToken = loopToken + 1
        end
end

local tab = Window:Tab("Main", "zap")

local dashSection = tab:Section("Dash")
dashSection:Toggle({
        Text = "No Dash Cooldown",
        Value = true,
        Callback = function(value)
                setDash(value)
        end,
})

local abilitySection = tab:Section("Abilities")
abilitySection:Toggle({
        Text = "No Ability Cooldown",
        Value = true,
        Callback = function(value)
                setSpoof(value)
                setTackle(value)
        end,
})

local statusSection = tab:Section("Status")
local statusLabel = statusSection:Paragraph({Text = "Accepted 0 · Rejected 0 · Server CD 0 · FairPlay 0"})

statusSection:Button({
        Text = "Unload",
        Primary = true,
        Callback = function()
                if type(Global.__HussValleyCleanup) == "function" then
                        pcall(Global.__HussValleyCleanup)
                end
        end,
})

local function refreshStatus()
        statusLabel:Set(string.format(
                "Accepted %d · Rejected %d · Server CD %d · FairPlay %d",
                stats.ok,
                stats.rejected,
                stats.serverCd,
                stats.fairPlay
        ))
end

connect(GearEvent.OnClientEvent, function(action, payload)
        if action == "PredictionResult" and type(payload) == "table" then
                if payload.accepted == true then
                        stats.ok = stats.ok + 1
                else
                        stats.rejected = stats.rejected + 1
                end
                refreshStatus()
        end
end)

connect(GameAction.OnClientEvent, function(action, id, accepted, info)
        if action == "TackleResult" then
                if accepted then
                        stats.ok = stats.ok + 1
                else
                        stats.rejected = stats.rejected + 1
                end
                refreshStatus()
        end
end)

for _, name in ipairs(SPOOF_ATTRIBUTES) do
        connect(LocalPlayer:GetAttributeChangedSignal(name), function()
                local value = LocalPlayer:GetAttribute(name)
                if value ~= 0 then
                        lastServer[name] = value
                        stats.serverCd = stats.serverCd + 1
                        refreshStatus()
                end
        end)
end

if MovementGuardEvent then
        connect(MovementGuardEvent.OnClientEvent, function(action, payload)
                if action == "Warning" and type(payload) == "table" then
                        stats.fairPlay = stats.fairPlay + 1
                        refreshStatus()
                        Window:Notify({
                                Title = "Fair Play",
                                Description = tostring(payload.message or payload.title or "Warning"),
                                Duration = 6,
                        })
                end
        end)
end

Global.__HussValleyCleanup = function()
        setSpoof(false)
        setTackle(false)
        setDash(false)
        for _, connection in ipairs(connections) do
                pcall(function()
                        connection:Disconnect()
                end)
        end
        for _, name in ipairs(SPOOF_ATTRIBUTES) do
                if lastServer[name] == nil then
                        LocalPlayer:SetAttribute(name, nil)
                else
                        LocalPlayer:SetAttribute(name, lastServer[name])
                end
        end
        pcall(function()
                Window:Destroy()
        end)
        Global.__HussValleyCleanup = nil
end

setDash(true)
setSpoof(true)
setTackle(true)
refreshStatus()
