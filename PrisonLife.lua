local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Teams = game:GetService("Teams")

local PLACE_ID = 155615604
local C4_TOOL_NAME = "C4 Explosive"
local TOUCH_WAIT = 0.15
local VERIFY_WAIT = 0.5
local HOLD_GAP = 0.1
local TEAM_WAIT = 8
local DETONATE_DELAY = 0.55
local EXPLODED_WAIT = 3
local RETREAT_DISTANCE = 60
local STEAL_SCAN = 1

local LocalPlayer = Players.LocalPlayer
local Global = (getgenv and getgenv()) or _G

if type(Global.__PrisonLifeCleanup) == "function" then
        pcall(Global.__PrisonLifeCleanup)
end

local Reborn
do
        local ok, library = pcall(function()
                return loadstring(game:HttpGet(
                        "https://raw.githubusercontent.com/Toluwer/Reborn/main/src/Reborn.luau"
                ))()
        end)

        if not ok or type(library) ~= "table" or type(library.CreateWindow) ~= "function" then
                warn("[PrisonLife] Failed to load the Reborn UI library.")
                return
        end

        Reborn = library
end

local Window = Reborn:CreateWindow({
        Title = "Prison Life",
        Size = Vector2.new(500, 380),
})

local function registerEarlyExit()
        Global.__PrisonLifeCleanup = function()
                pcall(function()
                        Window:Destroy()
                end)
                Global.__PrisonLifeCleanup = nil
        end
end

if game.PlaceId ~= PLACE_ID then
        local tab = Window:Tab("Main", "zap")
        local section = tab:Section("Prison Life")
        section:Paragraph({Text = "Wrong game."})
        registerEarlyExit()
        return
end

local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
local GiverPressed = Remotes and Remotes:WaitForChild("GiverPressed", 5)
local RequestTeamChange = Remotes and Remotes:WaitForChild("RequestTeamChange", 5)
local InteractWithItem = Remotes and Remotes:WaitForChild("InteractWithItem", 5)
local C4Folder = Remotes and Remotes:WaitForChild("C4", 5)
local ActivateC4 = C4Folder and C4Folder:WaitForChild("ActivateC4", 5)
local GuardsTeam = Teams:FindFirstChild("Guards")

if not (GiverPressed and GiverPressed:IsA("RemoteEvent"))
        or not (RequestTeamChange and RequestTeamChange:IsA("RemoteFunction"))
        or not (InteractWithItem and InteractWithItem:IsA("RemoteFunction"))
        or not (ActivateC4 and ActivateC4:IsA("RemoteFunction"))
        or not GuardsTeam then
        local tab = Window:Tab("Main", "zap")
        local section = tab:Section("Prison Life")
        section:Paragraph({Text = "Game updated?"})
        registerEarlyExit()
        return
end

local PrisonItems = workspace:FindFirstChild("Prison_ITEMS")
local ButtonsFolder = PrisonItems and PrisonItems:FindFirstChild("buttons")

local holdToken = 0
local stealToken = 0
local statusToken = 0
local holding = false
local stealing = false
local busy = false
local lastResult = "Idle"
local stats = {opened = 0, blown = 0, refused = 0}

local function getRoot()
        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if humanoid and root and humanoid.Health > 0 then
                return character, humanoid, root
        end
        return nil
end

local function waitCharacter(timeout)
        local deadline = os.clock() + timeout
        while os.clock() < deadline do
                if getRoot() then
                        return getRoot()
                end
                task.wait(0.1)
        end
        return nil
end

local function isGuard()
        return LocalPlayer.Team == GuardsTeam
end

local function joinGuards()
        if isGuard() then
                return true
        end

        local ok, accepted = pcall(function()
                return RequestTeamChange:InvokeServer(GuardsTeam, 1)
        end)

        if not ok or not accepted then
                lastResult = "Team refused"
                return false
        end

        local deadline = os.clock() + TEAM_WAIT
        while os.clock() < deadline do
                if isGuard() then
                        waitCharacter(6)
                        lastResult = "Guards joined"
                        return true
                end
                task.wait(0.1)
        end

        lastResult = "Team refused"
        return false
end

local function getDoorBlock(door)
        local block = door:FindFirstChild("block")
        if not block then
                return nil
        end
        local hitbox = block:FindFirstChild("hitbox") or block:FindFirstChild("hitbox", true)
        if not hitbox then
                return nil
        end
        return block, hitbox
end

local function getClosedDoors()
        local list = {}
        local _, _, root = getRoot()
        local origin = root and root.Position or Vector3.zero
        for _, door in ipairs(CollectionService:GetTagged("Door")) do
                if not door:GetAttribute("Exploded") then
                        local block, hitbox = getDoorBlock(door)
                        if block and hitbox then
                                local distance = (block:GetPivot().Position - origin).Magnitude
                                table.insert(list, {door = door, block = block, hitbox = hitbox, distance = distance})
                        end
                end
        end
        table.sort(list, function(a, b)
                return a.distance < b.distance
        end)
        return list
end

local function countState()
        local total, open, blown = 0, 0, 0
        for _, door in ipairs(CollectionService:GetTagged("Door")) do
                if getDoorBlock(door) then
                        total = total + 1
                        if door:GetAttribute("Exploded") then
                                blown = blown + 1
                        elseif door:GetAttribute("PlayerOpened") or door:GetAttribute("ScheduledOpen") then
                                open = open + 1
                        end
                end
        end
        return total, open, blown
end

local function touchDoor(entry)
        local _, _, root = getRoot()
        if not root then
                return false
        end
        root.CFrame = CFrame.new(entry.hitbox.Position)
        task.wait(TOUCH_WAIT)
        local door = entry.door
        if door:GetAttribute("PlayerOpened") or door:GetAttribute("ScheduledOpen") then
                return true
        end

        local deadline = os.clock() + VERIFY_WAIT
        while os.clock() < deadline do
                if door:GetAttribute("PlayerOpened") or door:GetAttribute("ScheduledOpen") then
                        return true
                end
                task.wait(0.1)
        end
        return false
end

local function openAll()
        if busy then
                return
        end
        busy = true
        lastResult = "Working"

        if not joinGuards() then
                busy = false
                Window:Notify({
                        Title = "Prison Life",
                        Description = "Could not join Guards.",
                        Duration = 6,
                })
                return
        end

        local doors = getClosedDoors()
        local total = #doors
        local opened = 0

        for _, entry in ipairs(doors) do
                if entry.door.Parent
                        and not entry.door:GetAttribute("PlayerOpened")
                        and not entry.door:GetAttribute("ScheduledOpen")
                        and not entry.door:GetAttribute("Exploded") then
                        if not waitCharacter(6) then
                                lastResult = "No character"
                                break
                        end
                        if touchDoor(entry) then
                                opened = opened + 1
                                stats.opened = stats.opened + 1
                        else
                                stats.refused = stats.refused + 1
                        end
                elseif entry.door.Parent then
                        opened = opened + 1
                end
        end

        busy = false
        lastResult = "Opened " .. opened .. "/" .. total
        Window:Notify({
                Title = "Prison Life",
                Description = lastResult,
                Duration = 8,
        })
end

local function rootTouch(entry)
        local _, _, root = getRoot()
        if not root then
                return
        end
        root.CFrame = CFrame.new(entry.hitbox.Position)
        task.wait(TOUCH_WAIT)
end

local function setHold(enabled)
        if enabled == holding then
                return
        end
        holding = enabled
        if enabled then
                holdToken = holdToken + 1
                local token = holdToken
                task.spawn(function()
                        while holding and token == holdToken do
                                if busy then
                                        task.wait(0.5)
                                elseif not isGuard() then
                                        lastResult = "Not guard"
                                        task.wait(1)
                                elseif not getRoot() then
                                        waitCharacter(5)
                                else
                                        local doors = getClosedDoors()
                                        for _, entry in ipairs(doors) do
                                                if not holding or token ~= holdToken or busy then
                                                        break
                                                end
                                                if not getRoot() then
                                                        break
                                                end
                                                if not entry.door:GetAttribute("PlayerOpened")
                                                        and not entry.door:GetAttribute("ScheduledOpen") then
                                                        rootTouch(entry)
                                                end
                                        end
                                        task.wait(HOLD_GAP)
                                end
                        end
                end)
        else
                holdToken = holdToken + 1
        end
end

local function pressButton(part)
        local _, _, root = getRoot()
        if not root or not part.Parent then
                return false
        end
        root.CFrame = CFrame.new(part.Position + Vector3.new(0, 0, 4))
        task.wait(0.2)

        local ok = pcall(function()
                InteractWithItem:InvokeServer(part)
        end)
        return ok
end

local function pressGateButton()
        if busy then
                return
        end
        busy = true
        lastResult = "Working"

        if not waitCharacter(6) then
                busy = false
                lastResult = "No character"
                return
        end

        local pressed = 0

        if ButtonsFolder then
                local gateModel = ButtonsFolder:FindFirstChild("Prison Gate")
                local gatePart = gateModel and gateModel:FindFirstChild("Prison Gate")
                if gatePart and gatePart:IsA("BasePart") then
                        local before = gateModel:FindFirstChild("isOpen")
                        local wasOpen = before and before:IsA("BoolValue") and before.Value
                        pressButton(gatePart)
                        local deadline = os.clock() + 2
                        local isOpen = wasOpen
                        while os.clock() < deadline do
                                if before and before:IsA("BoolValue") then
                                        isOpen = before.Value
                                end
                                if isOpen ~= wasOpen then
                                        break
                                end
                                task.wait(0.1)
                        end
                        if isOpen ~= wasOpen then
                                pressed = pressed + 1
                        end
                end

                local garage = ButtonsFolder:FindFirstChild("Garage Buttons")
                local garageOpen = garage and garage:FindFirstChild("open")
                if garageOpen and garageOpen:IsA("BasePart") then
                        if pressButton(garageOpen) then
                                pressed = pressed + 1
                        end
                end
        end

        busy = false
        lastResult = pressed > 0 and "Buttons pressed" or "Buttons failed"
        Window:Notify({
                Title = "Prison Life",
                Description = lastResult,
                Duration = 6,
        })
end

local function findC4()
        local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
        if backpack then
                local tool = backpack:FindFirstChild(C4_TOOL_NAME)
                if tool and tool:IsA("Tool") then
                        return tool
                end
        end
        local character = LocalPlayer.Character
        if character then
                local tool = character:FindFirstChild(C4_TOOL_NAME)
                if tool and tool:IsA("Tool") then
                        return tool
                end
        end
        return nil
end

local function findDroppedC4()
        for _, giver in ipairs(CollectionService:GetTagged("Giver")) do
                if CollectionService:HasTag(giver, "Drop")
                        and giver:GetAttribute("ToolName") == C4_TOOL_NAME
                        and giver.Parent then
                        return giver
                end
        end
        for _, child in ipairs(workspace:GetChildren()) do
                if child:IsA("Tool") and child.Name == C4_TOOL_NAME then
                        return child
                end
        end
        return nil
end

local function grabDroppedC4()
        local target = findDroppedC4()
        if not target then
                return nil
        end

        if not waitCharacter(6) then
                return nil
        end

        local _, _, root = getRoot()
        local handle = target:IsA("Tool") and target:FindFirstChild("Handle")
        local position = handle and handle.Position or target:GetPivot().Position
        root.CFrame = CFrame.new(position)

        if target:IsA("Tool") then
                local deadline = os.clock() + 3
                while os.clock() < deadline do
                        local tool = findC4()
                        if tool then
                                return tool
                        end
                        task.wait(0.1)
                end
                return nil
        end

        task.wait(0.2)
        pcall(function()
                GiverPressed:FireServer(target)
        end)

        local deadline = os.clock() + 4
        while os.clock() < deadline do
                local tool = findC4()
                if tool then
                        return tool
                end
                task.wait(0.1)
        end
        return nil
end

local function detonateDoor(entry)
        local character, humanoid, root = getRoot()
        if not character then
                lastResult = "No character"
                return false
        end

        local tool = findC4()
        if not tool then
                return false
        end

        if tool.Parent ~= character then
                pcall(function()
                        humanoid:EquipTool(tool)
                end)
                task.wait(0.15)
        end

        tool:SetAttribute("Local_Mode", "Placement")

        local pivot = entry.block:GetPivot().Position
        local flat = (root.Position - pivot) * Vector3.new(1, 0, 1)
        local approach = flat.Magnitude < 0.5 and Vector3.xAxis or flat.Unit
        root.CFrame = CFrame.lookAt(
                pivot + Vector3.new(0, 2, 0) + approach * 5,
                pivot + Vector3.new(0, 2, 0)
        )
        task.wait(0.2)

        tool:SetAttribute("Local_PlacedAt", os.clock())
        tool:SetAttribute("Local_Mode", "Detonate")

        local placed = false
        pcall(function()
                placed = ActivateC4:InvokeServer(root.Position, pivot) and true or false
        end)

        if not placed then
                lastResult = "Placement refused"
                return false
        end

        root.CFrame = CFrame.new(pivot + approach * RETREAT_DISTANCE + Vector3.new(0, 10, 0))
        task.wait(DETONATE_DELAY)

        pcall(function()
                ActivateC4:InvokeServer()
        end)

        local deadline = os.clock() + EXPLODED_WAIT
        while os.clock() < deadline do
                if entry.door:GetAttribute("Exploded") then
                        return true
                end
                task.wait(0.1)
        end

        return entry.door:GetAttribute("Exploded") == true
end

local function setSteal(enabled)
        if enabled == stealing then
                return
        end
        stealing = enabled
        if enabled then
                stealToken = stealToken + 1
                local token = stealToken
                task.spawn(function()
                        while stealing and token == stealToken do
                                local drop = findDroppedC4()
                                if drop and not busy and not findC4() then
                                        busy = true
                                        local tool = grabDroppedC4()
                                        if tool then
                                                Window:Notify({
                                                        Title = "Prison Life",
                                                        Description = "C4 acquired.",
                                                        Duration = 6,
                                                })
                                                local doors = getClosedDoors()
                                                for _, entry in ipairs(doors) do
                                                        if not findC4() then
                                                                break
                                                        end
                                                        if not entry.door:GetAttribute("Exploded") then
                                                                if not waitCharacter(6) then
                                                                        break
                                                                end
                                                                if detonateDoor(entry) then
                                                                        stats.blown = stats.blown + 1
                                                                        lastResult = "Door destroyed"
                                                                else
                                                                        break
                                                                end
                                                                task.wait(0.3)
                                                        end
                                                end
                                                local _, _, blown = countState()
                                                Window:Notify({
                                                        Title = "Prison Life",
                                                        Description = "Blown " .. blown,
                                                        Duration = 8,
                                                })
                                        end
                                        busy = false
                                end
                                task.wait(STEAL_SCAN)
                        end
                end)
        else
                stealToken = stealToken + 1
        end
end

local tab = Window:Tab("Main", "zap")

local teamSection = tab:Section("Team")
teamSection:Button({
        Text = "Join Guards",
        Primary = true,
        Callback = function()
                task.spawn(function()
                        if joinGuards() then
                                Window:Notify({
                                        Title = "Prison Life",
                                        Description = "Guards joined.",
                                        Duration = 5,
                                })
                        else
                                Window:Notify({
                                        Title = "Prison Life",
                                        Description = "Could not join Guards.",
                                        Duration = 5,
                                })
                        end
                end)
        end,
})

local doorsSection = tab:Section("Doors")
doorsSection:Button({
        Text = "Open All Doors",
        Primary = true,
        Callback = function()
                task.spawn(openAll)
        end,
})
doorsSection:Toggle({
        Text = "Hold Doors Open",
        Value = false,
        Callback = function(value)
                if value and not isGuard() then
                        task.spawn(function()
                                if joinGuards() then
                                        setHold(true)
                                end
                        end)
                else
                        setHold(value)
                end
        end,
})
doorsSection:Button({
        Text = "Press Gate Buttons",
        Callback = function()
                task.spawn(pressGateButton)
        end,
})

local c4Section = tab:Section("C4")
c4Section:Toggle({
        Text = "Steal Dropped C4",
        Value = true,
        Callback = function(value)
                setSteal(value)
        end,
})

local statusSection = tab:Section("Status")
local statusLabel = statusSection:Paragraph({Text = "Team None · Open 0/0 · Blown 0 · Refused 0 · Idle"})

statusSection:Button({
        Text = "Unload",
        Callback = function()
                if type(Global.__PrisonLifeCleanup) == "function" then
                        pcall(Global.__PrisonLifeCleanup)
                end
        end,
})

local function refreshStatus()
        local team = LocalPlayer.Team and LocalPlayer.Team.Name or "None"
        local total, open, blown = countState()
        statusLabel:Set(string.format(
                "Team %s · Open %d/%d · Blown %d · Refused %d · %s",
                team,
                open,
                total,
                blown,
                stats.refused,
                lastResult
        ))
end

Global.__PrisonLifeCleanup = function()
        holdToken = holdToken + 1
        stealToken = stealToken + 1
        statusToken = statusToken + 1
        holding = false
        stealing = false
        busy = false
        pcall(function()
                Window:Destroy()
        end)
        Global.__PrisonLifeCleanup = nil
end

statusToken = statusToken + 1
local token = statusToken
task.spawn(function()
        while token == statusToken do
                local ok = pcall(refreshStatus)
                if not ok then
                        break
                end
                task.wait(1)
        end
end)

setSteal(true)
refreshStatus()
