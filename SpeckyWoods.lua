local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local PLACE_ID = 2539588846
local GOD_HEALTH = 1000000000
local HEAL_GAP = 0.15
local WATCH_GAP = 2
local PROBE_MOVE_EPS = 0.1
local PROBE_WINDOW = 1.0
local PROBE_RETRY = 1.0
local BOOT_EPS = 3.0
local CLOSED_EPS = 0.4
local REFIRE_GAP = 0.25
local CALM_FRAMES = 3
local STILL_LIMIT = 45
local TP_LIFT = 3

local LocalPlayer = Players.LocalPlayer
local Global = (getgenv and getgenv()) or _G

if type(Global.__SpeckyWoodsCleanup) == "function" then
        pcall(Global.__SpeckyWoodsCleanup)
end

local Reborn
do
        local ok, library = pcall(function()
                return loadstring(game:HttpGet(
                        "https://raw.githubusercontent.com/Toluwer/Reborn/main/src/Reborn.luau"
                ))()
        end)

        if not ok or type(library) ~= "table" or type(library.CreateWindow) ~= "function" then
                warn("[SpeckyWoods] Failed to load the Reborn UI library.")
                return
        end

        Reborn = library
end

local Window = Reborn:CreateWindow({
        Title = "Specky Woods",
        Size = Vector2.new(500, 430),
})

local function registerEarlyExit()
        Global.__SpeckyWoodsCleanup = function()
                pcall(function()
                        Window:Destroy()
                end)
                Global.__SpeckyWoodsCleanup = nil
        end
end

if game.PlaceId ~= PLACE_ID then
        local tab = Window:Tab("Main", "zap")
        local section = tab:Section("Specky Woods")
        section:Paragraph({Text = "Wrong game."})
        registerEarlyExit()
        return
end

local LastSpot = ReplicatedStorage:WaitForChild("LastSpot", 5)

if not (LastSpot and LastSpot:IsA("RemoteEvent")) then
        local tab = Window:Tab("Main", "zap")
        local section = tab:Section("Specky Woods")
        section:Paragraph({Text = "Game updated?"})
        registerEarlyExit()
        return
end

local alive = true
local conns = {}

local settings = {walkSpeed = 16, jumpPower = 50, hipHeight = 0}
local godMode = false
local infJump = false
local blockKickback = true
local antiCheatDead = false
local lastSpotOwned = false
local resetOk = false
local fakeSpotOn = false
local savedSpot = nil
local healToken = 0
local Mouse = LocalPlayer:GetMouse()
local itemSpotIndex = 0

local statusParagraph = nil
local walkSlider, jumpSlider, hipSlider
local jumpToggle, godToggle

local function statusText()
        return table.concat({
                "Anti-Cheat: " .. (antiCheatDead and "Dead" or "Waiting"),
                "LastSpot: " .. (lastSpotOwned and "Owned" or "Waiting"),
                "Reset: " .. (resetOk and "Enabled" or "Pending"),
                "Kickback Lock: " .. (blockKickback and "On" or "Off"),
        }, "\n")
end

local function pushStatus()
        if statusParagraph then
                statusParagraph:Set(statusText())
        end
end

local function getChar()
        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if humanoid and root and humanoid.Health > 0 then
                return character, humanoid, root
        end
        return nil
end

local function applyGod(humanoid)
        if not humanoid or not antiCheatDead then
                return
        end
        if godMode then
                humanoid.MaxHealth = GOD_HEALTH
                humanoid.Health = GOD_HEALTH
        else
                humanoid.MaxHealth = 100
                humanoid.Health = math.min(humanoid.Health, 100)
        end
end

local function applyMovement(humanoid)
        if not humanoid or not antiCheatDead then
                return
        end
        humanoid.WalkSpeed = settings.walkSpeed
        humanoid.JumpPower = settings.jumpPower
        humanoid.HipHeight = settings.hipHeight
        applyGod(humanoid)
end

local function startHeal()
        healToken = healToken + 1
        local token = healToken
        task.spawn(function()
                while alive and token == healToken and godMode do
                        local _, humanoid = getChar()
                        if humanoid and humanoid.Health > 0 then
                                humanoid.Health = humanoid.MaxHealth
                        end
                        task.wait(HEAL_GAP)
                end
        end)
end

local function enableReset(tries)
        task.spawn(function()
                for i = 1, tries do
                        if not alive then
                                return
                        end
                        local ok = pcall(function()
                                StarterGui:SetCore("ResetButtonCallback", true)
                        end)
                        if ok then
                                resetOk = true
                                pushStatus()
                                return
                        end
                        task.wait(1)
                end
        end)
end

local PlayerScripts = LocalPlayer:WaitForChild("PlayerScripts", 10)

task.spawn(function()
        if not PlayerScripts then
                antiCheatDead = true
                lastSpotOwned = true
                pushStatus()
                return
        end
        local anti = PlayerScripts:WaitForChild("AntiExploit", 8)
        if anti then
                pcall(function()
                        anti:Destroy()
                end)
        end
        antiCheatDead = true
        local loc = PlayerScripts:FindFirstChild("LastLocation")
        if loc then
                pcall(function()
                        loc:Destroy()
                end)
        end
        lastSpotOwned = true
        pushStatus()
        while alive do
                task.wait(WATCH_GAP)
                if not alive then
                        return
                end
                local a = PlayerScripts:FindFirstChild("AntiExploit")
                if a then
                        pcall(function()
                                a:Destroy()
                        end)
                end
                local l = PlayerScripts:FindFirstChild("LastLocation")
                if l then
                        pcall(function()
                                l:Destroy()
                        end)
                end
        end
end)

task.spawn(function()
        if not PlayerScripts then
                return
        end
        local rev = PlayerScripts:WaitForChild("ReviveCount", 10)
        if not rev then
                return
        end
        table.insert(conns, rev:GetPropertyChangedSignal("Value"):Connect(function()
                if blockKickback and rev.Value >= 3 then
                        rev.Value = 0
                end
        end))
end)

local function onCharacter(character)
        local humanoid = character:WaitForChild("Humanoid", 10)
        if not humanoid or not alive then
                return
        end
        local root = character:WaitForChild("HumanoidRootPart", 10)
        if not root or not alive then
                return
        end
        applyMovement(humanoid)
        humanoid.Died:Connect(function()
                local spot = root.Position
                if fakeSpotOn and savedSpot then
                        spot = savedSpot
                end
                pcall(function()
                        LastSpot:FireServer(spot)
                end)
        end)
        enableReset(10)
end

table.insert(conns, LocalPlayer.CharacterAdded:Connect(onCharacter))
if LocalPlayer.Character then
        task.spawn(onCharacter, LocalPlayer.Character)
end
enableReset(10)

table.insert(conns, UserInputService.JumpRequest:Connect(function()
        if not infJump then
                return
        end
        local _, humanoid = getChar()
        if humanoid then
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end
end))

local tentLocks = {
        {
                label = "Red Tent",
                modelName = "RedTent",
                enabled = false,
                running = false,
                door = nil,
                closedPos = nil,
                lastPos = nil,
                lastDist = nil,
                lastClick = 0,
                pending = false,
                closes = 0,
                calm = 0,
                still = 0,
                probeTries = 0,
                probeSnap = nil,
                probeDeadline = 0,
                nextProbe = 0,
                missing = false,
        },
        {
                label = "Blue Tent",
                modelName = "BlueTent",
                enabled = false,
                running = false,
                door = nil,
                closedPos = nil,
                lastPos = nil,
                lastDist = nil,
                lastClick = 0,
                pending = false,
                closes = 0,
                calm = 0,
                still = 0,
                probeTries = 0,
                probeSnap = nil,
                probeDeadline = 0,
                nextProbe = 0,
                missing = false,
        },
}

local tentStatusParagraph = nil
local redLockToggle, blueLockToggle

local function tentStatusText()
        local lines = {}
        for _, lock in ipairs(tentLocks) do
                local state = "Off"
                if lock.enabled then
                        if lock.missing then
                                state = "No tent"
                        elseif lock.door then
                                state = "On (" .. tostring(lock.closes) .. " closes)"
                        else
                                state = "Finding door (" .. tostring(lock.probeTries) .. ")"
                        end
                end
                table.insert(lines, lock.label .. ": " .. state)
        end
        return table.concat(lines, "\n")
end

local function pushTentStatus()
        if tentStatusParagraph then
                tentStatusParagraph:Set(tentStatusText())
        end
end

local function startTentLock(lock)
        if lock.running then
                return
        end
        lock.running = true
        task.spawn(function()
                while alive and lock.enabled do
                        local model = workspace:FindFirstChild(lock.modelName)
                        local entrance = model and model:FindFirstChild("Entrance")
                        local clicker = entrance and entrance:FindFirstChild("Clicker")
                        local cd = clicker and clicker:FindFirstChild("ClickDetector")
                        local marker = entrance and entrance:FindFirstChild("Closed")
                        if cd and marker then
                                if lock.missing then
                                        lock.missing = false
                                        pushTentStatus()
                                end
                                local now = os.clock()
                                local door = lock.door
                                if door and door.Parent ~= model then
                                        door = nil
                                        lock.door = nil
                                        lock.closedPos = nil
                                        lock.lastPos = nil
                                        lock.lastDist = nil
                                        lock.pending = false
                                        lock.calm = 0
                                        lock.still = 0
                                end
                                if not door then
                                        if lock.probeSnap then
                                                local found = nil
                                                local bestMove = 0
                                                for part, was in pairs(lock.probeSnap) do
                                                        if part.Parent == model then
                                                                local move = (part.Position - was).Magnitude
                                                                if move > PROBE_MOVE_EPS and move > bestMove then
                                                                        bestMove = move
                                                                        found = part
                                                                end
                                                        end
                                                end
                                                if found then
                                                        lock.door = found
                                                        lock.probeSnap = nil
                                                        lock.closes = 0
                                                        lock.calm = 0
                                                        lock.still = 0
                                                        lock.pending = false
                                                        pushTentStatus()
                                                elseif now >= lock.probeDeadline then
                                                        lock.probeSnap = nil
                                                        lock.nextProbe = now + PROBE_RETRY
                                                end
                                        elseif now >= lock.nextProbe then
                                                local snap = {}
                                                for _, child in ipairs(model:GetChildren()) do
                                                        if child:IsA("BasePart") then
                                                                snap[child] = child.Position
                                                        end
                                                end
                                                lock.probeSnap = snap
                                                lock.probeDeadline = now + PROBE_WINDOW
                                                lock.probeTries = lock.probeTries + 1
                                                pushTentStatus()
                                                pcall(function()
                                                        fireclickdetector(cd)
                                                end)
                                        end
                                else
                                        local anchor = lock.closedPos or marker.Position
                                        local eps = lock.closedPos and CLOSED_EPS or BOOT_EPS
                                        local dist = (door.Position - anchor).Magnitude
                                        if dist <= eps then
                                                if lock.pending then
                                                        lock.pending = false
                                                        lock.closes = lock.closes + 1
                                                        pushTentStatus()
                                                end
                                                if lock.lastPos and (door.Position - lock.lastPos).Magnitude <= 0.01 then
                                                        lock.calm = lock.calm + 1
                                                else
                                                        lock.calm = 0
                                                end
                                                if not lock.closedPos and lock.calm >= CALM_FRAMES then
                                                        lock.closedPos = door.Position
                                                end
                                        else
                                                lock.calm = 0
                                                if lock.lastPos and (door.Position - lock.lastPos).Magnitude <= 0.01 then
                                                        lock.still = lock.still + 1
                                                else
                                                        lock.still = 0
                                                end
                                                if lock.pending and lock.still >= STILL_LIMIT then
                                                        lock.closedPos = door.Position
                                                        lock.pending = false
                                                        lock.closes = lock.closes + 1
                                                        pushTentStatus()
                                                elseif not lock.pending then
                                                        lock.pending = true
                                                        lock.lastClick = now
                                                        pcall(function()
                                                                fireclickdetector(cd)
                                                        end)
                                                elseif now - lock.lastClick >= REFIRE_GAP
                                                        and (not lock.lastDist or dist >= lock.lastDist - 0.02) then
                                                        lock.lastClick = now
                                                        pcall(function()
                                                                fireclickdetector(cd)
                                                        end)
                                                end
                                        end
                                        lock.lastPos = door.Position
                                        lock.lastDist = dist
                                end
                        else
                                if not lock.missing then
                                        lock.missing = true
                                        pushTentStatus()
                                end
                        end
                        RunService.Heartbeat:Wait()
                end
                lock.running = false
        end)
end

local mainTab = Window:Tab("Main", "zap")
local moveSection = mainTab:Section("Movement")
local guardSection = mainTab:Section("Client Guards")

statusParagraph = guardSection:Paragraph({Text = statusText()})

walkSlider = moveSection:Slider({
        Text = "Walk Speed",
        Min = 16,
        Max = 500,
        Value = settings.walkSpeed,
        Callback = function(v)
                settings.walkSpeed = v
                local _, humanoid = getChar()
                applyMovement(humanoid)
        end,
})

jumpSlider = moveSection:Slider({
        Text = "Jump Power",
        Min = 50,
        Max = 500,
        Value = settings.jumpPower,
        Callback = function(v)
                settings.jumpPower = v
                local _, humanoid = getChar()
                applyMovement(humanoid)
        end,
})

hipSlider = moveSection:Slider({
        Text = "Hip Height",
        Min = 0,
        Max = 20,
        Value = settings.hipHeight,
        Callback = function(v)
                settings.hipHeight = v
                local _, humanoid = getChar()
                applyMovement(humanoid)
        end,
})

jumpToggle = moveSection:Toggle({
        Text = "Infinite Jump",
        Value = false,
        Callback = function(v)
                infJump = v
        end,
})

godToggle = moveSection:Toggle({
        Text = "God Health",
        Value = false,
        Callback = function(v)
                godMode = v
                local _, humanoid = getChar()
                applyGod(humanoid)
                if v then
                        startHeal()
                end
        end,
})

moveSection:Button({
        Text = "Restore Defaults",
        Callback = function()
                settings.walkSpeed = 16
                settings.jumpPower = 50
                settings.hipHeight = 0
                if walkSlider then
                        walkSlider:Set(16, true)
                end
                if jumpSlider then
                        jumpSlider:Set(50, true)
                end
                if hipSlider then
                        hipSlider:Set(0, true)
                end
                if jumpToggle then
                        jumpToggle:Set(false, true)
                end
                if godToggle then
                        godToggle:Set(false, true)
                end
                local _, humanoid = getChar()
                if humanoid and antiCheatDead then
                        pcall(function()
                                humanoid.WalkSpeed = 16
                                humanoid.JumpPower = 50
                                humanoid.HipHeight = 0
                        end)
                end
                Window:Notify({
                        Title = "Specky Woods",
                        Description = "Defaults restored.",
                        Duration = 4,
                })
        end,
})

guardSection:Toggle({
        Text = "Block Revive Kickback",
        Value = true,
        Callback = function(v)
                blockKickback = v
                pushStatus()
        end,
})

local lockSection = mainTab:Section("Tent Locks")

tentStatusParagraph = lockSection:Paragraph({Text = tentStatusText()})

local function setTentLock(lock, toggleRef, v)
        lock.enabled = v
        if v then
                if type(fireclickdetector) ~= "function" then
                        lock.enabled = false
                        Window:Notify({
                                Title = "Tent Locks",
                                Description = "fireclickdetector unavailable.",
                                Duration = 4,
                        })
                        if toggleRef then
                                toggleRef:Set(false, true)
                        end
                else
                        startTentLock(lock)
                end
        end
        pushTentStatus()
end

redLockToggle = lockSection:Toggle({
        Text = "Lock Red Tent",
        Value = false,
        Callback = function(v)
                setTentLock(tentLocks[1], redLockToggle, v)
        end,
})

blueLockToggle = lockSection:Toggle({
        Text = "Lock Blue Tent",
        Value = false,
        Callback = function(v)
                setTentLock(tentLocks[2], blueLockToggle, v)
        end,
})

local tpSection = mainTab:Section("Teleport")

local function teleportTo(pos, label)
        local _, _, root = getChar()
        if not root then
                Window:Notify({
                        Title = "Teleport",
                        Description = "No character.",
                        Duration = 4,
                })
                return
        end
        if typeof(pos) ~= "Vector3" then
                Window:Notify({
                        Title = "Teleport",
                        Description = label .. " not found.",
                        Duration = 4,
                })
                return
        end
        local target = pos + Vector3.new(0, TP_LIFT, 0)
        pcall(function()
                root.CFrame = CFrame.new(target) * root.CFrame.Rotation
        end)
        Window:Notify({
                Title = "Teleport",
                Description = string.format(
                        "%s (%.0f, %.0f, %.0f).",
                        label,
                        target.X,
                        target.Y,
                        target.Z
                ),
                Duration = 4,
        })
end

local function tentDoorPos(rootName)
        local tent = workspace:FindFirstChild(rootName)
        local entrance = tent and tent:FindFirstChild("Entrance")
        local closed = entrance and entrance:FindFirstChild("Closed")
        if closed and closed:IsA("BasePart") then
                return closed.Position
        end
        return nil
end

tpSection:Button({
        Text = "To Mouse",
        Callback = function()
                teleportTo(Mouse.Hit.Position, "Mouse")
        end,
})

tpSection:Button({
        Text = "Spawn",
        Callback = function()
                local sl = workspace:FindFirstChild("SpawnLocation")
                teleportTo(sl and sl.Position or nil, "Spawn")
        end,
})

tpSection:Button({
        Text = "Red Tent Door",
        Callback = function()
                teleportTo(tentDoorPos("RedTent"), "Red Tent Door")
        end,
})

tpSection:Button({
        Text = "Blue Tent Door",
        Callback = function()
                teleportTo(tentDoorPos("BlueTent"), "Blue Tent Door")
        end,
})

tpSection:Button({
        Text = "Shed",
        Callback = function()
                local shed = workspace:FindFirstChild("shed")
                teleportTo(shed and shed:GetPivot().Position or nil, "Shed")
        end,
})

tpSection:Button({
        Text = "Firepit",
        Callback = function()
                local firepit = workspace:FindFirstChild("Firepit")
                teleportTo(firepit and firepit:GetPivot().Position or nil, "Firepit")
        end,
})

tpSection:Button({
        Text = "Next Item Spot",
        Callback = function()
                itemSpotIndex = itemSpotIndex % 10 + 1
                local holder = workspace:FindFirstChild("SpawnPointsItems")
                local point = holder and holder:FindFirstChild("Point" .. itemSpotIndex)
                teleportTo(point and point.Position or nil, "Item Spot " .. itemSpotIndex)
        end,
})

local testsTab = Window:Tab("Tests", "skull")
local tentSection = testsTab:Section("Tent Doors")
local spotSection = testsTab:Section("Death Spot")

local function fireTent(rootName, label)
        if type(fireclickdetector) ~= "function" then
                Window:Notify({
                        Title = "Tents",
                        Description = "fireclickdetector unavailable.",
                        Duration = 4,
                })
                return
        end
        local tent = workspace:FindFirstChild(rootName)
        local entrance = tent and tent:FindFirstChild("Entrance")
        local clicker = entrance and entrance:FindFirstChild("Clicker")
        local cd = clicker and clicker:FindFirstChild("ClickDetector")
        if not cd then
                Window:Notify({
                        Title = "Tents",
                        Description = label .. " not found.",
                        Duration = 4,
                })
                return
        end
        pcall(function()
                fireclickdetector(cd)
        end)
        Window:Notify({
                Title = "Tents",
                Description = label .. " clicked.",
                Duration = 4,
        })
end

tentSection:Button({
        Text = "Toggle Red Tent",
        Callback = function()
                fireTent("RedTent", "Red Tent")
        end,
})

tentSection:Button({
        Text = "Toggle Blue Tent",
        Callback = function()
                fireTent("BlueTent", "Blue Tent")
        end,
})

spotSection:Button({
        Text = "Save Current Spot",
        Callback = function()
                local _, _, root = getChar()
                if not root then
                        Window:Notify({
                                Title = "Death Spot",
                                Description = "No character.",
                                Duration = 4,
                        })
                        return
                end
                savedSpot = root.Position
                Window:Notify({
                        Title = "Death Spot",
                        Description = string.format(
                                "Saved (%.0f, %.0f, %.0f).",
                                savedSpot.X,
                                savedSpot.Y,
                                savedSpot.Z
                        ),
                        Duration = 4,
                })
        end,
})

spotSection:Toggle({
        Text = "Fake Death Spot",
        Value = false,
        Callback = function(v)
                fakeSpotOn = v
                if v and not savedSpot then
                        Window:Notify({
                                Title = "Death Spot",
                                Description = "No spot saved yet.",
                                Duration = 4,
                        })
                end
        end,
})

spotSection:Button({
        Text = "Force Death",
        Callback = function()
                local _, humanoid = getChar()
                if not humanoid then
                        Window:Notify({
                                Title = "Death Spot",
                                Description = "No character.",
                                Duration = 4,
                        })
                        return
                end
                humanoid.Health = 0
        end,
})

Global.__SpeckyWoodsCleanup = function()
        alive = false
        healToken = healToken + 1
        for _, lock in ipairs(tentLocks) do
                lock.enabled = false
        end
        for _, c in ipairs(conns) do
                pcall(function()
                        c:Disconnect()
                end)
        end
        local _, humanoid = getChar()
        if humanoid and antiCheatDead then
                pcall(function()
                        humanoid.WalkSpeed = 16
                        humanoid.JumpPower = 50
                        humanoid.HipHeight = 0
                        humanoid.MaxHealth = 100
                        humanoid.Health = math.min(humanoid.Health, 100)
                end)
        end
        pcall(function()
                Window:Destroy()
        end)
        Global.__SpeckyWoodsCleanup = nil
end
