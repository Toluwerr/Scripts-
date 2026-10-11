local SoundService = game:GetService("SoundService")
local HttpService = game:GetService("HttpService")

local Global = (getgenv and getgenv()) or _G

if type(Global.__MonochromePlayerCleanup) == "function" then
        pcall(Global.__MonochromePlayerCleanup)
end

local running = true
local connections = {}

local function track(connection)
        table.insert(connections, connection)
        return connection
end

local function disconnectAll()
        for _, connection in ipairs(connections) do
                pcall(function()
                        connection:Disconnect()
                end)
        end
        table.clear(connections)
end

local httpRequest = nil
if syn and type(syn.request) == "function" then
        httpRequest = syn.request
elseif type(http_request) == "function" then
        httpRequest = http_request
elseif http and type(http.request) == "function" then
        httpRequest = http.request
elseif type(request) == "function" then
        httpRequest = request
end

if not httpRequest then
        warn("[Monochrome] This executor has no HTTP request function.")
        return
end

local TRACKS_BASE = "https://tracks.monochrome.st"
local DEFAULT_DZR_BASE = "https://dzr.tabs-vs-spaces.wtf"
local USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) MonochromePlayer/1.0"

local function urlEncode(s)
        s = tostring(s or "")
        return (s:gsub("[^%w%-_%.~]", function(c)
                return string.format("%%%02X", string.byte(c))
        end))
end

local function clampN(v, lo, hi)
        if v < lo then return lo end
        if v > hi then return hi end
        return v
end

local function fmtTime(sec)
        sec = math.floor(tonumber(sec) or 0)
        if sec < 0 then sec = 0 end
        local h = math.floor(sec / 3600)
        local m = math.floor((sec % 3600) / 60)
        local s = sec % 60
        if h > 0 then
                return string.format("%d:%02d:%02d", h, m, s)
        end
        return string.format("%d:%02d", m, s)
end

local Reborn
do
        local ok, library = pcall(function()
                return loadstring(game:HttpGet(
                        "https://raw.githubusercontent.com/Toluwer/Reborn/main/src/Reborn.luau"
                ))()
        end)

        if not ok or type(library) ~= "table" or type(library.CreateWindow) ~= "function" then
                warn("[Monochrome] Failed to load the Reborn UI library.")
                return
        end

        Reborn = library
end

local Window = Reborn:CreateWindow({
        Title = "Monochrome",
        Size = Vector2.new(560, 470),
})

local function notify(title, description)
        pcall(function()
                Window:Notify({
                        Title = tostring(title),
                        Description = tostring(description or ""),
                        Duration = 3.2,
                })
        end)
end

local ui = {}
local state = {
        queue = {},
        index = 0,
        results = {},
        current = nil,
        candidates = nil,
        candidateIdx = 0,
        loopMode = "Off",
        shuffle = false,
        preferFlac = false,
        dzrBase = DEFAULT_DZR_BASE,
        dzrFormat = "MP3_320",
        gen = 0,
        consecutiveFails = 0,
        lastSeekInput = 0,
        searchGen = 0,
}

local sound = Instance.new("Sound")
sound.Name = "MonochromePlayer"
sound.Volume = 0.5
sound.Parent = SoundService

local saveGen = 0
local function scheduleSave()
        saveGen = saveGen + 1
        local g = saveGen
        task.delay(1.5, function()
                if g == saveGen and running then
                        pcall(function()
                                Window:SaveConfig("default")
                        end)
                end
        end)
end

local function setSearchStatus(text)
        if ui.searchStatus then
                ui.searchStatus:Set(tostring(text))
        end
end

local function updateNowPlaying(tr, sourceLabel)
        if ui.titlePara then ui.titlePara:Set(tr and tr.title or "Nothing playing") end
        if ui.artistPara then ui.artistPara:Set(tr and tr.artist or "-") end
        if ui.sourcePara then ui.sourcePara:Set("Source: " .. tostring(sourceLabel or "-")) end
        if ui.art then
                ui.art:SetVisible(tr ~= nil)
                ui.art:SetImage(tr and tr.artwork or "")
        end
end

local function renderQueue()
        if not ui.queueList then return end
        local items = {}
        for i, tr in ipairs(state.queue) do
                local marker = (i == state.index and state.current) and "> " or ""
                table.insert(items, {
                        Text = marker .. tr.title,
                        Secondary = tr.artist,
                        Trailing = fmtTime(tr.duration),
                })
        end
        ui.queueList:SetItems(items)
        if state.current and state.index >= 1 and state.queue[state.index] then
                ui.queueList:SetSelected(state.index, false)
        end
        local total = 0
        for _, tr in ipairs(state.queue) do
                total = total + (tr.duration or 0)
        end
        if ui.queueStatus then
                ui.queueStatus:Set(#state.queue .. " tracks - " .. fmtTime(total))
        end
end

local function stopPlayback()
        state.gen = state.gen + 1
        sound:Stop()
        state.current = nil
        updateNowPlaying(nil, "-")
        if ui.playBtn then ui.playBtn:Set("Play") end
        renderQueue()
end

local function buildCandidates(tr)
        local list = {}
        local direct = {
                url = TRACKS_BASE .. "/track/" .. tostring(tr.id),
                label = "Monochrome direct",
                timeout = 30,
        }
        if state.preferFlac then
                table.insert(list, direct)
        end
        if tr.isrc and state.dzrBase ~= "" then
                table.insert(list, {
                        url = state.dzrBase .. "/stream/?isrc=" .. urlEncode(tr.isrc) .. "&format=" .. urlEncode(state.dzrFormat),
                        label = "Deezer " .. string.gsub(state.dzrFormat, "_", " "),
                        timeout = 12,
                })
        end
        if not state.preferFlac then
                table.insert(list, direct)
        end
        return list
end

local playFromQueue, startWatchdog, tryNextCandidate, advance

local function onLoaded()
        local cand = state.candidates and state.candidates[state.candidateIdx]
        state.consecutiveFails = 0
        if ui.sourcePara then
                ui.sourcePara:Set("Source: " .. (cand and cand.label or "-"))
        end
        if sound.TimeLength > 0 and ui.seek then
                ui.seek:SetRange(0, math.max(1, math.floor(sound.TimeLength)))
                ui.seek:Set(0, false)
        end
        if ui.playBtn then ui.playBtn:Set("Pause") end
        if state.current and cand then
                notify(state.current.title, state.current.artist .. " - " .. cand.label)
        end
end

function startWatchdog(gen)
        task.spawn(function()
                local waited = 0
                local cand = state.candidates and state.candidates[state.candidateIdx]
                local limit = (cand and cand.timeout) or 12
                while waited < limit do
                        task.wait(0.25)
                        if not running or state.gen ~= gen then return end
                        if sound.IsLoaded or sound.TimeLength > 0 or sound.TimePosition > 0 then
                                onLoaded()
                                return
                        end
                        waited = waited + 0.25
                end
                if not running or state.gen ~= gen then return end
                tryNextCandidate(gen)
        end)
end

function tryNextCandidate(gen)
        if not running or state.gen ~= gen then return end
        state.candidateIdx = state.candidateIdx + 1
        local cand = state.candidates and state.candidates[state.candidateIdx]
        if cand then
                sound:Stop()
                sound.SoundId = cand.url
                sound:Play()
                if ui.sourcePara then
                        ui.sourcePara:Set("Retrying via " .. cand.label .. "...")
                end
                startWatchdog(gen)
                return
        end
        state.consecutiveFails = state.consecutiveFails + 1
        if state.current then
                notify("Could not load", state.current.title)
        end
        if state.consecutiveFails >= 5 then
                state.consecutiveFails = 0
                stopPlayback()
                notify("Stopped", "Too many tracks failed to load in a row.")
                return
        end
        advance(1, true)
end

function playFromQueue()
        local tr = state.queue[state.index]
        if not tr then return end
        state.gen = state.gen + 1
        local gen = state.gen
        state.current = tr
        state.candidates = buildCandidates(tr)
        state.candidateIdx = 1
        sound:Stop()
        sound.SoundId = state.candidates[1].url
        sound:Play()
        updateNowPlaying(tr, "Loading...")
        if ui.playBtn then ui.playBtn:Set("Pause") end
        startWatchdog(gen)
        renderQueue()
end

function advance(delta, auto)
        local n = #state.queue
        if n == 0 then
                notify("Queue is empty", "Search for a song and click a result.")
                return
        end
        if state.shuffle and n > 1 then
                local pick = state.index
                while pick == state.index do
                        pick = math.random(1, n)
                end
                state.index = pick
        else
                local nextIdx = state.index + delta
                if nextIdx > n then
                        if auto and state.loopMode ~= "All" then
                                stopPlayback()
                                return
                        end
                        nextIdx = 1
                elseif nextIdx < 1 then
                        nextIdx = (state.loopMode == "All") and n or 1
                end
                state.index = nextIdx
        end
        playFromQueue()
end

local function prevTrack()
        if state.current and sound.TimeLength > 0 and sound.TimePosition > 3 then
                sound.TimePosition = 0
                return
        end
        advance(-1, false)
end

local function togglePlayPause()
        if not state.current then
                if #state.queue > 0 then
                        if state.index < 1 then state.index = 1 end
                        playFromQueue()
                else
                        notify("Nothing to play", "Search for a song and click a result.")
                end
                return
        end
        if sound.Playing then
                sound:Pause()
                if ui.playBtn then ui.playBtn:Set("Play") end
        else
                sound:Play()
                if ui.playBtn then ui.playBtn:Set("Pause") end
        end
end

local function autoAdvance()
        if not running then return end
        if state.loopMode == "One" and state.current then
                sound:Play()
                return
        end
        advance(1, true)
end

local function playNow(tr)
        if not tr then return end
        if tr.playable == false then
                notify("Not playable", tr.title)
                return
        end
        local existing = 0
        for i, q in ipairs(state.queue) do
                if q.id == tr.id then
                        existing = i
                        break
                end
        end
        if existing > 0 then
                state.index = existing
        else
                table.insert(state.queue, tr)
                state.index = #state.queue
        end
        playFromQueue()
end

local function jumpTo(i)
        if state.queue[i] then
                state.index = i
                playFromQueue()
        end
end

local function removeCurrent()
        if state.index < 1 or not state.queue[state.index] then
                notify("Nothing playing", "Play a track first.")
                return
        end
        local i = state.index
        state.gen = state.gen + 1
        sound:Stop()
        table.remove(state.queue, i)
        state.index = math.min(i, #state.queue)
        state.current = nil
        updateNowPlaying(nil, "-")
        if ui.playBtn then ui.playBtn:Set("Play") end
        renderQueue()
end

local function clearQueue()
        state.queue = {}
        state.index = 0
        stopPlayback()
end

local function renderResults()
        if not ui.resultList then return end
        local items = {}
        for _, tr in ipairs(state.results) do
                table.insert(items, {
                        Text = tr.title .. (tr.explicit and " [E]" or ""),
                        Secondary = tr.artist,
                        Trailing = (tr.playable == false) and "N/A" or fmtTime(tr.duration),
                        Track = tr,
                })
        end
        ui.resultList:SetItems(items)
end

local function runSearch(query)
        query = tostring(query or "")
        query = query:gsub("^%s+", ""):gsub("%s+$", "")
        if query == "" then
                setSearchStatus("Type something to search.")
                return
        end
        state.searchGen = state.searchGen + 1
        local gen = state.searchGen
        setSearchStatus("Searching...")
        task.spawn(function()
                local ok, res = pcall(httpRequest, {
                        Url = TRACKS_BASE .. "/search/tracks?q=" .. urlEncode(query) .. "&limit=25",
                        Method = "GET",
                        Headers = {
                                ["Accept"] = "application/json",
                                ["User-Agent"] = USER_AGENT,
                        },
                })
                if not running or gen ~= state.searchGen then return end
                if not ok or type(res) ~= "table" or (type(res.StatusCode) == "number" and res.StatusCode ~= 200) then
                        setSearchStatus("Search failed.")
                        return
                end
                local okDecode, data = pcall(function()
                        return HttpService:JSONDecode(tostring(res.Body or ""))
                end)
                if not okDecode or type(data) ~= "table" or type(data.tracks) ~= "table" then
                        setSearchStatus("Search returned an unreadable response.")
                        return
                end
                state.results = {}
                for _, raw in ipairs(data.tracks) do
                        if type(raw) == "table" and raw.trackId ~= nil then
                                local dur = tonumber(raw.duration) or 0
                                if dur > 1000 then dur = math.floor(dur / 1000) end
                                local names = type(raw.artistNames) == "table" and raw.artistNames or {}
                                table.insert(state.results, {
                                        id = tostring(raw.trackId),
                                        title = tostring(raw.title or "Unknown Title"),
                                        artist = (#names > 0 and table.concat(names, ", ")) or "Unknown Artist",
                                        duration = dur,
                                        isrc = (raw.isrc ~= nil and raw.isrc ~= "") and tostring(raw.isrc) or nil,
                                        artwork = (raw.artwork ~= nil and raw.artwork ~= "") and tostring(raw.artwork) or "",
                                        explicit = raw.explicit and true or false,
                                        playable = (raw.playable == false) and false or true,
                                })
                        end
                end
                renderResults()
                setSearchStatus(#state.results .. " results")
        end)
end

local function applyConfig()
        pcall(function()
                Window:LoadConfig("default")
        end)
        local loopVal = ui.loop and ui.loop.Value
        if loopVal ~= "One" and loopVal ~= "All" then
                loopVal = "Off"
        end
        state.loopMode = loopVal
        state.shuffle = (ui.shuffle and ui.shuffle.Value) and true or false
        state.preferFlac = (ui.preferFlac and ui.preferFlac.Value) and true or false
        local fmt = ui.dzrFormat and ui.dzrFormat.Value
        if fmt ~= "MP3_320" and fmt ~= "MP3_128" then
                fmt = "MP3_320"
        end
        state.dzrFormat = fmt
        if ui.dzrBase then
                local base = tostring(ui.dzrBase.Text or "")
                base = base:gsub("^%s+", ""):gsub("%s+$", ""):gsub("/+$", "")
                if base:find("://", 1, true) then
                        state.dzrBase = base
                elseif base == "" then
                        state.dzrBase = ""
                else
                        state.dzrBase = DEFAULT_DZR_BASE
                end
        end
        local vol = 50
        if ui.volume and type(ui.volume.Value) == "number" then
                vol = ui.volume.Value
        end
        sound.Volume = vol / 100
end

local searchTab = Window:Tab("Search", "search")
local searchSection = searchTab:Section("Search")

ui.query = searchSection:Input({
        Text = "Query",
        Placeholder = "Song or artist...",
        Live = true,
        Debounce = 0.5,
        Callback = function(text, enter)
                if enter then
                        runSearch(text)
                elseif tostring(text):gsub("%s+", "") ~= "" then
                        runSearch(text)
                end
        end,
})

searchSection:Button({
        Text = "Search",
        Primary = true,
        Callback = function()
                runSearch(ui.query and ui.query.Text or "")
        end,
})

ui.searchStatus = searchSection:Paragraph({
        Text = "Type to search.",
})

ui.resultList = searchSection:List({
        Text = "Results",
        Height = 130,
        MaxHeight = 250,
        Callback = function(item)
                if item and item.Track then
                        playNow(item.Track)
                end
        end,
})

local playerTab = Window:Tab("Player", "music")
local playerSection = playerTab:Section("Now Playing")

ui.art = playerSection:Image({
        Height = 150,
})
ui.art:SetVisible(false)

ui.titlePara = playerSection:Paragraph({
        Text = "Nothing playing",
})

ui.artistPara = playerSection:Paragraph({
        Text = "-",
})

ui.sourcePara = playerSection:Paragraph({
        Text = "Source: -",
})

ui.timePara = playerSection:Paragraph({
        Text = "0:00 / 0:00",
})

ui.seek = playerSection:Slider({
        Text = "Seek",
        Min = 0,
        Max = 100,
        Step = 1,
        Value = 0,
        Format = function(v)
                return fmtTime(v)
        end,
        Callback = function(v)
                state.lastSeekInput = os.clock()
                if sound.IsLoaded and sound.TimeLength > 0 then
                        sound.TimePosition = clampN(v, 0, sound.TimeLength)
                end
        end,
})

local controlsRow = playerSection:Row({ Gap = 8 })

controlsRow:Button({
        Text = "Prev",
        Callback = function()
                prevTrack()
        end,
})

ui.playBtn = controlsRow:Button({
        Text = "Play",
        Primary = true,
        Callback = function()
                togglePlayPause()
        end,
})

controlsRow:Button({
        Text = "Next",
        Callback = function()
                advance(1, false)
        end,
})

controlsRow:Button({
        Text = "Stop",
        Callback = function()
                stopPlayback()
        end,
})

ui.volume = playerSection:Slider({
        Text = "Volume",
        Min = 0,
        Max = 100,
        Step = 1,
        Value = 50,
        Suffix = "%",
        Flag = "Volume",
        Callback = function(v)
                sound.Volume = v / 100
                scheduleSave()
        end,
})

local modeRow = playerSection:Row({ Gap = 8 })

ui.loop = modeRow:Dropdown({
        Text = "Loop",
        Options = { "Off", "One", "All" },
        Value = "Off",
        Flag = "Loop",
        Callback = function(v)
                state.loopMode = tostring(v)
                scheduleSave()
        end,
})

ui.shuffle = modeRow:Toggle({
        Text = "Shuffle",
        Value = false,
        Flag = "Shuffle",
        Callback = function(v)
                state.shuffle = v and true or false
                scheduleSave()
        end,
})

local queueTab = Window:Tab("Queue", "list")
local queueSection = queueTab:Section("Queue")

ui.queueList = queueSection:List({
        Text = "Queue",
        Height = 130,
        MaxHeight = 250,
        Callback = function(item, index)
                jumpTo(index)
        end,
})

local queueRow = queueSection:Row({ Gap = 8 })

queueRow:Button({
        Text = "Remove Playing",
        Callback = function()
                removeCurrent()
        end,
})

queueRow:Button({
        Text = "Clear Queue",
        Callback = function()
                clearQueue()
        end,
})

ui.queueStatus = queueSection:Paragraph({
        Text = "0 tracks",
})

local settingsTab = Window:Tab("Settings", "settings")
local sourcesSection = settingsTab:Section("Playback Sources")

ui.dzrFormat = sourcesSection:Dropdown({
        Text = "Deezer format",
        Options = { "MP3_320", "MP3_128" },
        Value = "MP3_320",
        Flag = "DzrFormat",
        Callback = function(v)
                state.dzrFormat = tostring(v)
                scheduleSave()
        end,
})

ui.preferFlac = sourcesSection:Toggle({
        Text = "Prefer Monochrome direct",
        Value = false,
        Flag = "PreferFlac",
        Callback = function(v)
                state.preferFlac = v and true or false
                scheduleSave()
        end,
})

ui.dzrBase = sourcesSection:Input({
        Text = "Deezer base",
        Value = DEFAULT_DZR_BASE,
        Placeholder = "https://...",
        Flag = "DzrBase",
        Callback = function(text)
                local base = tostring(text or "")
                base = base:gsub("^%s+", ""):gsub("%s+$", ""):gsub("/+$", "")
                if base == "" then
                        state.dzrBase = ""
                elseif base:find("://", 1, true) then
                        state.dzrBase = base
                else
                        state.dzrBase = DEFAULT_DZR_BASE
                end
                scheduleSave()
        end,
})

sourcesSection:Paragraph({
        Text = "Tracks try the Deezer ISRC stream first, then fall back to the Monochrome direct stream.",
})

local keybindsSection = settingsTab:Section("Keybinds")

keybindsSection:Keybind({
        Text = "Toggle UI",
        Value = "RightShift",
        Mode = "Always",
        Flag = "BindToggle",
        Callback = function()
                Window:Toggle()
        end,
})

keybindsSection:Keybind({
        Text = "Play / Pause",
        Value = "None",
        Mode = "Always",
        Flag = "BindPlay",
        Callback = function()
                togglePlayPause()
        end,
})

keybindsSection:Keybind({
        Text = "Next",
        Value = "None",
        Mode = "Always",
        Flag = "BindNext",
        Callback = function()
                advance(1, false)
        end,
})

keybindsSection:Keybind({
        Text = "Previous",
        Value = "None",
        Mode = "Always",
        Flag = "BindPrev",
        Callback = function()
                prevTrack()
        end,
})

local configSection = settingsTab:Section("Config")

ui.cfgStatus = configSection:Paragraph({
        Text = "Settings auto-save.",
})

configSection:Button({
        Text = "Save Now",
        Callback = function()
                local ok = false
                pcall(function()
                        ok = Window:SaveConfig("default")
                end)
                ui.cfgStatus:Set(ok and "Saved." or "Save failed - this executor has no file system.")
        end,
})

configSection:Button({
        Text = "Reload",
        Callback = function()
                applyConfig()
                ui.cfgStatus:Set("Reloaded.")
        end,
})

track(sound.Ended:Connect(autoAdvance))

task.spawn(function()
        while running do
                task.wait(0.25)
                if sound.IsLoaded and sound.TimeLength > 0 then
                        if ui.seek and os.clock() - state.lastSeekInput > 0.5 then
                                ui.seek:Set(sound.TimePosition, false)
                        end
                        if ui.timePara then
                                ui.timePara:Set(fmtTime(sound.TimePosition) .. " / " .. fmtTime(sound.TimeLength))
                        end
                end
        end
end)

applyConfig()
renderQueue()

local function cleanup()
        if not running then
                return
        end
        running = false
        pcall(function()
                Window:SaveConfig("default")
        end)
        disconnectAll()
        pcall(function()
                sound:Stop()
        end)
        pcall(function()
                sound:Destroy()
        end)
end

Global.__MonochromePlayerCleanup = cleanup

track(Window.Gui.Destroying:Connect(cleanup))
