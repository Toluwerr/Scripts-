local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local MarketplaceService = game:GetService("MarketplaceService")

local LocalPlayer = Players.LocalPlayer
local Global = (getgenv and getgenv()) or _G

if type(Global.__GameLinkCleanup) == "function" then
        pcall(Global.__GameLinkCleanup)
end

local Reborn
do
        local ok, library = pcall(function()
                return loadstring(game:HttpGet(
                        "https://raw.githubusercontent.com/Toluwer/Reborn/main/src/Reborn.luau"
                ))()
        end)

        if not ok or type(library) ~= "table" or type(library.CreateWindow) ~= "function" then
                return
        end

        Reborn = library
end

local TOKEN = ""
if type(Global.GameLinkToken) == "string" then
        TOKEN = Global.GameLinkToken:gsub("^[%s]+", ""):gsub("[%s]+$", "")
end

local BASE = ""
if type(Global.GameLinkBase) == "string" then
        BASE = Global.GameLinkBase:gsub("[%s]+$", ""):gsub("[/\\]+$", "")
end

local sid = nil
local stats = {
        cmds = 0,
        remotes = 0,
        errors = 0,
        lastResult = "none"
}
local activeCommands = 0
local linked = false
local stopping = false

local running = true
local connections = {}

local function track(connection)
        table.insert(connections, connection)
        return connection
end

local function disconnect(connection)
        if connection then
                pcall(function()
                        connection:Disconnect()
                end)
        end
end

local function jsonEscape(text)
        local value = tostring(text)
        value = value:gsub("\\", "\\\\")
        value = value:gsub('"', '\\"')
        value = value:gsub("\n", "\\n")
        value = value:gsub("\r", "\\r")
        value = value:gsub("\t", "\\t")
        return value
end

local function jsonEncode(value)
        local kind = type(value)

        if kind == "string" then
                return '"' .. jsonEscape(value) .. '"'
        elseif kind == "number" then
                if value ~= value or value == math.huge or value == -math.huge then
                        return '"' .. tostring(value) .. '"'
                end

                return string.format("%.14g", value)
        elseif kind == "boolean" then
                return value and "true" or "false"
        elseif kind ~= "table" then
                return "null"
        end

        local count = #value

        if count > 0 then
                local items = {}

                for i = 1, math.min(count, 64) do
                        items[#items + 1] = jsonEncode(value[i])
                end

                return "[" .. table.concat(items, ",") .. "]"
        end

        local fields = {}
        local seen = 0

        for key, item in pairs(value) do
                seen = seen + 1

                if seen <= 32 then
                        fields[#fields + 1] = '"' .. jsonEscape(tostring(key)) .. '":' .. jsonEncode(item)
                end
        end

        if #fields == 0 then
                return "{}"
        end

        return "{" .. table.concat(fields, ",") .. "}"
end

local function serialize(value, depth)
        depth = depth or 0

        if depth > 7 then
                return "..."
        end

        local kind = type(value)

        if kind == "number" or kind == "boolean" then
                return value
        end

        if kind == "string" then
                if #value > 2000 then
                        return value:sub(1, 2000) .. "..."
                end

                return value
        end

        if kind == "nil" then
                return nil
        end

        if kind == "function" or kind == "thread" or kind == "userdata" then
                return tostring(value):sub(1, 120)
        end

        local instanceOk, isInstance = pcall(function()
                return value:IsA("Instance")
        end)

        if instanceOk and isInstance then
                local fullNameOk, fullName = pcall(function()
                        return value:GetFullName()
                end)

                return {
                        __inst = fullNameOk and fullName or value.Name,
                        class = value.ClassName
                }
        end

        if kind ~= "table" then
                return tostring(value):sub(1, 120)
        end

        local out = {}
        local itemCount = #value

        if itemCount > 0 then
                for i = 1, math.min(itemCount, 48) do
                        out[i] = serialize(value[i], depth + 1)
                end

                return out
        end

        local seen = 0

        for key, item in pairs(value) do
                seen = seen + 1

                if seen > 32 then
                        out.__trunc = "keys hidden"
                        break
                end

                out[tostring(key)] = serialize(item, depth + 1)
        end

        return out
end

local function requestFn()
        if type(request) == "function" then
                return request
        end

        if type(http_request) == "function" then
                return http_request
        end

        if type(syn) == "table" and type(syn.request) == "function" then
                return syn.request
        end

        return nil
end

local function httpPost(path, body)
        local fn = requestFn()

        if not fn then
                return false, "no request function"
        end

        local ok, res = pcall(fn, {
                Url = BASE .. path,
                Method = "POST",
                Headers = {
                        ["Content-Type"] = "application/json",
                        ["x-link-token"] = TOKEN
                },
                Body = jsonEncode(body)
        })

        if ok and type(res) == "table" and type(res.StatusCode) == "number" and res.StatusCode < 400 then
                return true, tostring(res.Body or "")
        end

        local detail = ok and tostring(res and res.Body):sub(1, 120) or tostring(res):sub(1, 120)
        return false, detail
end

local function httpGetCmd()
        -- cache buster: some executors cache HttpGet by url, which would stop
        -- the server from seeing our polls and flip the session to stale
        local url = BASE .. "/api/link/cmd?t=" .. TOKEN .. "&sid=" .. sid .. "&_=" .. tostring(os.clock() * 1000)

        local ok, body = pcall(function()
                return game:HttpGet(url, true)
        end)

        if ok and type(body) == "string" then
                return true, body
        end

        local fn = requestFn()

        if not fn then
                return false, ""
        end

        local ok2, res = pcall(fn, {
                Url = url,
                Method = "GET",
                Headers = { ["x-link-token"] = TOKEN }
        })

        if ok2 and type(res) == "table" and type(res.Body) == "string" then
                return true, res.Body
        end

        return false, ""
end

local function parseCmd(body)
        if type(body) ~= "string" or #body == 0 then
                return 0, nil
        end

        local nl = body:find("\n", 1, true)

        if not nl then
                return 0, nil
        end

        local id = tonumber(body:sub(1, nl - 1))
        local code = body:sub(nl + 1)

        if not id or #code == 0 then
                return 0, nil
        end

        return id, code
end

local pending = {}
local pendingLock = false
local droppedCount = 0

local function queueEvent(kind, data)
        if #pending >= 250 then
                droppedCount = droppedCount + 1
                return
        end

        pending[#pending + 1] = { t = os.time() * 1000, kind = kind, data = data }
end

local hookInstalled = false
local hookActive = false
local originalNamecall = nil

local function queueRemote(remote, method, args)
        stats.remotes = stats.remotes + 1

        local fullNameOk, fullName = pcall(function()
                return remote:GetFullName()
        end)

        local src = nil

        if type(getcallingscript) == "function" then
                local srcOk, caller = pcall(getcallingscript)

                if srcOk and caller ~= nil then
                        local callerNameOk, callerName = pcall(function()
                                return caller:GetFullName()
                        end)

                        src = callerNameOk and callerName or caller.Name
                end
        end

        queueEvent("remote", {
                remote = fullNameOk and fullName or remote.Name,
                method = method,
                args = serialize(args),
                src = src
        })
end

local function installHook()
        if hookInstalled or type(hookmetamethod) ~= "function" then
                return
        end

        local ok, original = pcall(hookmetamethod, "__namecall", function(self, ...)
                if hookActive then
                        local isRemoteOk, isRemote = pcall(function()
                                return self:IsA("RemoteEvent") or self:IsA("RemoteFunction") or self:IsA("UnreliableRemoteEvent")
                        end)

                        if isRemoteOk and isRemote then
                                local method = ""

                                if type(getnamecallmethod) == "function" then
                                        method = tostring(getnamecallmethod())
                                end

                                if method == "FireServer" or method == "InvokeServer" then
                                        queueRemote(self, method, ...)
                                end
                        end
                end

                return original(self, ...)
        end)

        if ok then
                originalNamecall = original
                hookInstalled = true
        end
end

local function restoreHook()
        if not hookInstalled then
                return
        end

        hookActive = false

        if originalNamecall ~= nil and type(hookmetamethod) == "function" then
                pcall(hookmetamethod, "__namecall", originalNamecall)
        end

        hookInstalled = false
        originalNamecall = nil
end

local function buildState()
        local character = LocalPlayer.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local position = "no character"

        if root then
                position = tostring(root.Position)
        end

        local team = "none"

        if LocalPlayer.Team then
                team = LocalPlayer.Team.Name
        end

        local tools = {}

        local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")

        if backpack then
                for _, item in ipairs(backpack:GetChildren()) do
                        tools[#tools + 1] = item.Name
                end
        end

        if character then
                for _, item in ipairs(character:GetChildren()) do
                        if item:IsA("Tool") then
                                tools[#tools + 1] = item.Name
                        end
                end
        end

        local health = "n/a"

        if humanoid then
                health = math.floor(humanoid.Health + 0.5)
        end

        return {
                place = game.Name,
                team = team,
                position = position,
                health = health,
                players = #Players:GetPlayers(),
                tools = tools
        }
end

local statusLabel = nil
local baseUrlLabel = nil

local function setStatus(text)
        if statusLabel then
                pcall(function()
                        statusLabel:Set(tostring(text))
                end)
        end
end

local function flushAndBeat(beat)
        local payload = { sid = sid }

        if #pending > 0 then
                local events = pending
                pending = {}

                if droppedCount > 0 then
                        events[#events + 1] = { t = os.time() * 1000, kind = "log", data = { msg = "dropped " .. droppedCount .. " remote events" } }
                        droppedCount = 0
                end

                payload.events = events
        end

        if beat then
                payload.state = buildState()
        end

        if payload.events ~= nil or payload.state ~= nil then
                return httpPost("/api/link/event", payload)
        end

        return true, ""
end

local function executeCommand(id, code)
        if activeCommands >= 2 then
                httpPost("/api/link/result", { sid = sid, id = id, ok = false, error = "busy: 2 commands already running" })
                return
        end

        activeCommands = activeCommands + 1

        task.spawn(function()
                local chunk, chunkErr = loadstring(code, "GameLink" .. tostring(id))

                if not chunk then
                        activeCommands = activeCommands - 1
                        stats.lastResult = "syntax error"
                        httpPost("/api/link/result", { sid = sid, id = id, ok = false, error = tostring(chunkErr):sub(1, 300) })
                        return
                end

                local ok, value = pcall(chunk)

                activeCommands = activeCommands - 1

                if ok then
                        stats.lastResult = "ok"
                        httpPost("/api/link/result", { sid = sid, id = id, ok = true, value = serialize(value) })
                else
                        stats.lastResult = "runtime error"
                        httpPost("/api/link/result", { sid = sid, id = id, ok = false, error = tostring(value):sub(1, 300) })
                end
        end)
end

local function publicPlaceName()
        local ok, info = pcall(function()
                return MarketplaceService:GetProductInfo(game.PlaceId)
        end)

        if ok and type(info) == "table" and type(info.Name) == "string" and #info.Name > 0 then
                return info.Name
        end

        return nil
end

local function connect()
        if linked or stopping then
                return
        end

        if #BASE == 0 then
                setStatus("No bridge URL. Run: getgenv().GameLinkBase = \"your preview url\" then press Connect")
                return
        end

        if #TOKEN == 0 then
                setStatus("No token. Copy the snippet from the site (it sets getgenv().GameLinkToken) then press Connect")
                return
        end

        if requestFn() == nil then
                setStatus("This executor has no request/http_request/syn.request - cannot POST to the bridge")
                return
        end

        sid = string.format("gl-%d-%d", game.PlaceId or 0, math.floor(os.clock() * 1000))

        local helloOk, helloErr = httpPost("/api/link/hello", {
                sid = sid,
                placeId = game.PlaceId,
                placeName = game.Name,
                universeId = game.GameId,
                publicName = publicPlaceName(),
                jobId = game.JobId or "",
                player = LocalPlayer.Name,
                userId = LocalPlayer.UserId,
                displayName = LocalPlayer.DisplayName,
                executor = identifyexecutor and identifyexecutor() or "unknown",
                transport = "request"
        })

        if not helloOk then
                setStatus("Connect failed: " .. tostring(helloErr):sub(1, 100))
                return
        end

        linked = true
        installHook()
        hookActive = true

        task.spawn(function()
                local tick = 0
                local failures = 0

                while linked and running do
                        tick = tick + 1

                        -- Heartbeat EVERY round trip (used to be every 5th):
                        -- the server counts any event POST as a beat, so one
                        -- slow request can no longer open a 10s+ silence gap
                        -- that flips the session offline and blocks the agent.
                        -- The cmd poll below also refreshes presence serverside.
                        local flushOk = flushAndBeat(true)

                        local cmdOk, body = httpGetCmd()
                        local id, code = parseCmd(body)

                        if id and id > 0 and code then
                                stats.cmds = stats.cmds + 1
                                executeCommand(id, code)
                        end

                        if flushOk and cmdOk then
                                failures = 0
                        else
                                failures = failures + 1
                                stats.errors = stats.errors + 1
                        end

                        if failures >= 30 then
                                -- never give up on the link: back off and keep
                                -- retrying so it heals itself when the bridge
                                -- comes back instead of stopping for good
                                setStatus("Link unstable - retrying (" .. failures .. " failed round trips)")
                                task.wait(5)
                        end

                        if tick % 5 == 0 then
                                setStatus("Live - cmds " .. stats.cmds .. " - remotes " .. stats.remotes .. " - errors " .. stats.errors .. " - last " .. stats.lastResult)
                        end

                        task.wait(1)
                end
        end)
end

local function disconnectLink()
        if not linked then
                return
        end

        linked = false
        restoreHook()
        pending = {}
        setStatus("Disconnected")
end

local Window = Reborn:CreateWindow({
        Title = "GameLink",
        Size = Vector2.new(480, 300)
})

local LinkTab = Window:Tab("Link", "satellite")
local LinkSection = LinkTab:Section("Bridge")

statusLabel = LinkSection:Paragraph({
        Text = "Idle."
})

baseUrlLabel = LinkSection:Paragraph({
        Text = "URL: " .. (#BASE > 0 and BASE or "unset - getgenv().GameLinkBase = \"...\"") .. " | token: " .. (#TOKEN > 0 and "set" or "unset - getgenv().GameLinkToken = \"...\"")
})

LinkSection:Toggle({
        Text = "Remote traffic capture",
        Value = true,
        Callback = function(value)
                hookActive = value and true or false
        end
})

LinkSection:Button({
        Text = "Connect",
        Primary = true,
        Callback = function()
                Global.GameLinkAuto = true
                connect()
        end
})

LinkSection:Button({
        Text = "Disconnect",
        Callback = function()
                Global.GameLinkAuto = false
                disconnectLink()
        end
})

LinkSection:Button({
        Text = "Unload",
        Callback = function()
                if type(Global.__GameLinkCleanup) == "function" then
                        pcall(Global.__GameLinkCleanup)
                end
        end
})

-- auto-connect when the snippet already provided base + token; also re-runs
-- after a teleport (queue_on_teleport below), so the session always matches
-- the place the player is actually in
if #BASE > 0 and #TOKEN > 0 and Global.GameLinkAuto ~= false then
        task.defer(connect)
end

local queueTeleport = queue_on_teleport or (syn and syn.queue_on_teleport)

if type(queueTeleport) == "function" then
        pcall(queueTeleport, 'loadstring(game:HttpGet("https://raw.githubusercontent.com/Toluwerr/Scripts-/main/GameLink.lua"))()')
end

local function cleanup()
        if not running then
                return
        end

        running = false
        linked = false
        stopping = true
        restoreHook()

        for _, connection in ipairs(connections) do
                disconnect(connection)
        end

        table.clear(connections)

        if Window.Gui and Window.Gui.Parent then
                pcall(function()
                        Window.Gui:Destroy()
                end)
        end
end

Global.__GameLinkCleanup = cleanup

track(Window.Gui.Destroying:Connect(cleanup))
