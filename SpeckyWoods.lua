local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local PLACE_ID = 2539588846
local GOD_HEALTH = 1000000000
local HEAL_GAP = 0.15
local WATCH_GAP = 2
local DOOR_EPS = 0.5
local CLICK_GAP = 0.45
local SETTLE_GAP = 0.3
local RESOLVE_GAP = 1.5
local RESOLVE_TRIES = 3

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
local noScares = false
local noDeathScreen = false
local antiCheatDead = false
local lastSpotOwned = false
local resetOk = false
local fakeSpotOn = false
local savedSpot = nil
local healToken = 0

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

local function killStoryScripts()
        if not (noScares or noDeathScreen) then
                return
        end
        local function drop(parent, name)
                local target = parent and parent:FindFirstChild(name)
                if target then
                        pcall(function()
                                target:Destroy()
                        end)
                end
        end
        local gui = LocalPlayer:FindFirstChild("PlayerGui")
        if noScares then
                drop(PlayerScripts, "RainBlur")
                drop(PlayerScripts, "PopUp")
                drop(PlayerScripts, "Cam")
                drop(PlayerScripts, "LockSlide")
                local popGui = gui and gui:FindFirstChild("PopUp")
                local popFrame = popGui and popGui:FindFirstChild("Frame")
                drop(popFrame, "LocalScript")
                local fadeGui = gui and gui:FindFirstChild("Fade")
                local fadeFrame = fadeGui and fadeGui:FindFirstChild("Frame")
                drop(fadeFrame, "LocalScript")
        end
        if noDeathScreen then
                local dsGui = gui and gui:FindFirstChild("DeathScreen")
                local dsFrame = dsGui and dsGui:FindFirstChild("Frame")
                drop(dsFrame, "End")
        end
end

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
                killStoryScripts()
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
                lastPos = nil,
                lastClick = 0,
                lastMove = 0,
                pending = false,
                closes = 0,
                tries = 0,
                giveUp = false,
                missing = false,
        },
        {
                label = "Blue Tent",
                modelName = "BlueTent",
                enabled = false,
                running = false,
                door = nil,
                lastPos = nil,
                lastClick = 0,
                lastMove = 0,
                pending = false,
                closes = 0,
                tries = 0,
                giveUp = false,
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
                        if lock.giveUp or lock.missing then
                                state = "No door"
                        else
                                state = "On (" .. tostring(lock.closes) .. " closes)"
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
                                local door = lock.door
                                if door and door.Parent ~= model then
                                        door = nil
                                        lock.door = nil
                                        lock.lastPos = nil
                                end
                                if not door then
                                        local found = nil
                                        local bestDist = math.huge
                                        for _, child in ipairs(model:GetChildren()) do
                                                if child:IsA("BasePart") and child ~= marker then
                                                        local dist = (child.Position - marker.Position).Magnitude
                                                        if dist < bestDist then
                                                                bestDist = dist
                                                                found = child
                                                        end
                                                end
                                        end
                                        if found and bestDist <= DOOR_EPS then
                                                lock.door = found
                                                lock.lastPos = found.Position
                                                lock.lastMove = os.clock()
                                                lock.closes = 0
                                                lock.pending = false
                                                lock.tries = 0
                                                lock.giveUp = false
                                        elseif not lock.giveUp and os.clock() - lock.lastClick >= RESOLVE_GAP then
                                                lock.lastClick = os.clock()
                                                lock.tries = lock.tries + 1
                                                if lock.tries >= RESOLVE_TRIES then
                                                        lock.giveUp = true
                                                        pushTentStatus()
                                                end
                                                pcall(function()
                                                        fireclickdetector(cd)
                                                end)
                                        end
                                else
                                        local now = os.clock()
                                        if lock.lastPos and (door.Position - lock.lastPos).Magnitude > 0.01 then
                                                lock.lastMove = now
                                        end
                                        lock.lastPos = door.Position
                                        local dist = (door.Position - marker.Position).Magnitude
                                        if dist <= DOOR_EPS then
                                                if lock.pending then
                                                        lock.pending = false
                                                        lock.closes = lock.closes + 1
                                                        pushTentStatus()
                                                end
                                        elseif not lock.pending then
                                                lock.lastClick = now
                                                lock.pending = true
                                                pcall(function()
                                                        fireclickdetector(cd)
                                                end)
                                        elseif now - lock.lastClick >= CLICK_GAP and now - lock.lastMove >= SETTLE_GAP then
                                                lock.lastClick = now
                                                pcall(function()
                                                        fireclickdetector(cd)
                                                end)
                                        end
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

local shields = {on = false, tents = 0, spike = false, bear = false}
local shieldsStatusParagraph = nil
local lastShieldsText = ""

local function shieldsStatusText()
        if not shields.on then
                return "Story Shields: Off"
        end
        return table.concat({
                "Story Shields: On",
                "Tent Flags: " .. tostring(shields.tents) .. "/2",
                "Spike Flag: " .. (shields.spike and "Set" or "Missing"),
                "Bear Flag: " .. (shields.bear and "Set" or "Missing"),
        }, "\n")
end

local function pushShieldsStatus()
        local text = shieldsStatusText()
        if text == lastShieldsText then
                return
        end
        lastShieldsText = text
        if shieldsStatusParagraph then
                shieldsStatusParagraph:Set(text)
        end
end

table.insert(conns, RunService.Heartbeat:Connect(function()
        if not shields.on then
                return
        end
        local character = LocalPlayer.Character
        if not character then
                shields.tents = 0
                shields.spike = false
                shields.bear = false
                pushShieldsStatus()
                return
        end
        local tents = 0
        local location = character:FindFirstChild("Location")
        if location then
                local blue = location:FindFirstChild("BlueTent")
                if blue and blue:IsA("BoolValue") then
                        if blue.Value ~= true then
                                blue.Value = true
                        end
                        tents = tents + 1
                end
                local red = location:FindFirstChild("RedTent")
                if red and red:IsA("BoolValue") then
                        if red.Value ~= true then
                                red.Value = true
                        end
                        tents = tents + 1
                end
        end
        shields.tents = tents
        local spike = character:FindFirstChild("hitspikes")
        if spike and spike:IsA("BoolValue") then
                if spike.Value ~= false then
                        spike.Value = false
                end
                shields.spike = true
        else
                shields.spike = false
        end
        local bear = character:FindFirstChild("beardb")
        if bear and bear:IsA("BoolValue") then
                if bear.Value ~= false then
                        bear.Value = false
                end
                shields.bear = true
        else
                shields.bear = false
        end
        pushShieldsStatus()
end))

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

local storySection = mainTab:Section("Story Control")

shieldsStatusParagraph = storySection:Paragraph({Text = shieldsStatusText()})

storySection:Toggle({
        Text = "No Scares",
        Value = false,
        Callback = function(v)
                noScares = v
                if v then
                        killStoryScripts()
                        Window:Notify({
                                Title = "Story Control",
                                Description = "Scare and blur scripts removed.",
                                Duration = 4,
                        })
                end
        end,
})

storySection:Toggle({
        Text = "No Death Screen",
        Value = false,
        Callback = function(v)
                noDeathScreen = v
                if v then
                        killStoryScripts()
                        Window:Notify({
                                Title = "Story Control",
                                Description = "Death screen removed. Respawns stay server-timed.",
                                Duration = 4,
                        })
                end
        end,
})

storySection:Toggle({
        Text = "Story Shields (Test)",
        Value = false,
        Callback = function(v)
                shields.on = v
                pushShieldsStatus()
                if v then
                        Window:Notify({
                                Title = "Story Control",
                                Description = "Locking tent, spike and bear flags on your character. Report results.",
                                Duration = 6,
                        })
                end
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
        shields.on = false
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
