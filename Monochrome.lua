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
local SC_HOME = "https://soundcloud.com/"
local SC_API = "https://api-v2.soundcloud.com"
local SC_FALLBACK_ID = "vI5BsvpTIlavDLl7RDbbcFAPg8kls8Bg"
local CACHE_FOLDER = "monochrome"
local CACHE_LIMIT = 12
local USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"

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

local FS = {
        write = (type(writefile) == "function") and writefile or nil,
        read = (type(readfile) == "function") and readfile or nil,
        isFile = (type(isfile) == "function") and isfile or nil,
        isFolder = (type(isfolder) == "function") and isfolder or nil,
        makeFolder = (type(makefolder) == "function") and makefolder or nil,
        delFile = (type(delfile) == "function") and delfile or nil,
        listFiles = (type(listfiles) == "function") and listfiles or nil,
}

local customAsset = nil
if type(getcustomasset) == "function" then
        customAsset = getcustomasset
elseif type(getsynasset) == "function" then
        customAsset = getsynasset
end

local function httpGet(url)
        local ok, res = pcall(httpRequest, {
                Url = url,
                Method = "GET",
                Headers = {
                        ["Accept"] = "*/*",
                        ["User-Agent"] = USER_AGENT,
                },
        })
        if not ok or type(res) ~= "table" then
                return nil, 0
        end
        local code = tonumber(res.StatusCode or res.Status or 0) or 0
        return tostring(res.Body or ""), code
end

local function ensureCacheFolder()
        if FS.isFolder and FS.makeFolder and not FS.isFolder(CACHE_FOLDER) then
                pcall(FS.makeFolder, CACHE_FOLDER)
        end
end

local function cacheOrderPath()
        return CACHE_FOLDER .. "/.order"
end

local function readCacheOrder()
        if FS.read then
                local ok, body = pcall(FS.read, cacheOrderPath())
                if ok and type(body) == "string" and #body > 2 then
                        local okD, data = pcall(function()
                                return HttpService:JSONDecode(body)
                        end)
                        if okD and type(data) == "table" then
                                local names = {}
                                for _, n in ipairs(data) do
                                        if type(n) == "string" then
                                                table.insert(names, n)
                                        end
                                end
                                return names
                        end
                end
        end
        if FS.listFiles then
                local ok, files = pcall(FS.listFiles, CACHE_FOLDER)
                if ok and type(files) == "table" then
                        local names = {}
                        for _, f in ipairs(files) do
                                local name = tostring(f):gsub("^" .. CACHE_FOLDER .. "/", "")
                                if name:sub(-4) == ".mp3" then
                                        table.insert(names, name)
                                end
                        end
                        return names
                end
        end
        return {}
end

local function writeCacheOrder(names)
        if FS.write then
                pcall(FS.write, cacheOrderPath(), HttpService:JSONEncode(names))
        end
end

local function trimCache(names)
        if FS.delFile then
                while #names > CACHE_LIMIT do
                        local victim = table.remove(names, 1)
                        pcall(FS.delFile, CACHE_FOLDER .. "/" .. victim)
                end
        end
        return names
end

local function evictCache(trackId)
        if not FS.delFile then return end
        local name = tostring(trackId) .. ".mp3"
        pcall(FS.delFile, CACHE_FOLDER .. "/" .. name)
        local names = {}
        for _, n in ipairs(readCacheOrder()) do
                if n ~= name then
                        table.insert(names, n)
                end
        end
        writeCacheOrder(names)
end

local refreshCacheStatus = function() end

local function downloadToCache(tr, url)
        if not FS.write or not customAsset then
                return nil, "no file system"
        end
        ensureCacheFolder()
        local name = tostring(tr.id) .. ".mp3"
        local path = CACHE_FOLDER .. "/" .. name
        if FS.isFile and FS.isFile(path) then
                local okC, cached = pcall(customAsset, path)
                if okC and type(cached) == "string" and #cached > 0 then
                        return cached
                end
        end
        local body, code = httpGet(url)
        if code ~= 200 or type(body) ~= "string" or #body == 0 then
                return nil, "download HTTP " .. tostring(code)
        end
        if #body < 65536 then
                return nil, "download too small"
        end
        if body:sub(1, 3) ~= "ID3" and body:byte(1) ~= 255 then
                return nil, "response is not an MP3"
        end
        local okW, errW = pcall(FS.write, path, body)
        if not okW then
                return nil, "writefile: " .. tostring(errW)
        end
        local names = readCacheOrder()
        local present = false
        for _, n in ipairs(names) do
                if n == name then
                        present = true
                        break
                end
        end
        if not present then
                table.insert(names, name)
        end
        names = trimCache(names)
        writeCacheOrder(names)
        refreshCacheStatus()
        local okA, asset = pcall(customAsset, path)
        if okA and type(asset) == "string" and #asset > 0 then
                return asset
        end
        evictCache(tr.id)
        return nil, "getcustomasset failed"
end

local scClientId = SC_FALLBACK_ID
local scRefreshed = false

local function refreshScId()
        scRefreshed = true
        local body, code = httpGet(SC_HOME)
        if code ~= 200 or type(body) ~= "string" then
                return nil
        end
        local seen = {}
        local tried = 0
        for assetUrl in body:gmatch("https://a%-v2%.sndcdn%.com/assets/[%w%.%-]+%.js") do
                if not seen[assetUrl] then
                        seen[assetUrl] = true
                        tried = tried + 1
                        if tried > 10 then
                                break
                        end
                        local js, jsCode = httpGet(assetUrl)
                        if jsCode == 200 and type(js) == "string" then
                                local cid = js:match('client_id:"([%w%-_]+)"')
                                if cid and #cid >= 20 then
                                        scClientId = cid
                                        return cid
                                end
                        end
                end
        end
        return nil
end

local function scSearchUrl(query)
        return SC_API .. "/search/tracks?q=" .. urlEncode(query) .. "&limit=50&client_id=" .. scClientId
end

local function scBestProgressive(data, targetMs)
        local best, bestDiff = nil, math.huge
        local collection = type(data.collection) == "table" and data.collection or {}
        for _, item in ipairs(collection) do
                if type(item) == "table" and item.kind == "track" and tostring(item.policy or "") ~= "BLOCK" then
                        local dur = tonumber(item.duration) or 0
                        local diff = math.abs(dur - targetMs)
                        if diff <= 15000 and diff < bestDiff then
                                local media = type(item.media) == "table" and item.media or {}
                                local transcodings = type(media.transcodings) == "table" and media.transcodings or {}
                                for _, tc in ipairs(transcodings) do
                                        if type(tc) == "table" and type(tc.url) == "string" then
                                                local fmt = type(tc.format) == "table" and tc.format or {}
                                                if fmt.mime_type == "audio/mpeg" and tc.url:find("/stream/progressive", 1, true) then
                                                        best = tc.url
                                                        bestDiff = diff
                                                        break
                                                end
                                        end
                                end
                        end
                end
        end
        return best, bestDiff
end

local function scPickTrack(tr)
        local query = tostring(tr.title or "")
        local hasArtist = tr.artist ~= nil and tr.artist ~= "" and tr.artist ~= "Unknown Artist"
        if hasArtist then
                query = query .. " " .. tr.artist
        end
        for attempt = 1, 2 do
                local body, code = httpGet(scSearchUrl(query))
                if code == 401 or code == 403 then
                        if scRefreshed then
                                return nil, "SoundCloud rejected the client id"
                        end
                        if not refreshScId() then
                                return nil, "SoundCloud rejected the client id"
                        end
                        body, code = httpGet(scSearchUrl(query))
                end
                if code ~= 200 or type(body) ~= "string" then
                        return nil, "SoundCloud HTTP " .. tostring(code)
                end
                local okD, data = pcall(function()
                        return HttpService:JSONDecode(body)
                end)
                if not okD or type(data) ~= "table" then
                        return nil, "SoundCloud sent an unreadable response"
                end
                local turl, diff = scBestProgressive(data, (tonumber(tr.duration) or 0) * 1000)
                if turl then
                        local signed, code2 = httpGet(turl .. "?client_id=" .. scClientId)
                        if code2 ~= 200 or type(signed) ~= "string" then
                                return nil, "stream URL HTTP " .. tostring(code2)
                        end
                        local okS, sdata = pcall(function()
                                return HttpService:JSONDecode(signed)
                        end)
                        if not okS or type(sdata) ~= "table" or type(sdata.url) ~= "string" then
                                return nil, "stream URL unreadable"
                        end
                        local off = math.floor(diff / 1000 + 0.5)
                        if off <= 0 then
                                return sdata.url, "SoundCloud (exact length)"
                        end
                        return sdata.url, "SoundCloud (off by " .. off .. "s)"
                end
                if attempt == 1 and hasArtist then
                        query = tostring(tr.title or "")
                else
                        break
                end
        end
        return nil, "no SoundCloud match"
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

local function clearCache()
        local names = readCacheOrder()
        if FS.listFiles then
                local ok, files = pcall(FS.listFiles, CACHE_FOLDER)
                if ok and type(files) == "table" then
                        for _, f in ipairs(files) do
                                local name = tostring(f):gsub("^" .. CACHE_FOLDER .. "/", "")
                                table.insert(names, name)
                        end
                end
        end
        local removed = 0
        if FS.delFile then
                for _, n in ipairs(names) do
                        if pcall(FS.delFile, CACHE_FOLDER .. "/" .. n) then
                                removed = removed + 1
                        end
                end
        end
        writeCacheOrder({})
        refreshCacheStatus()
        notify("Cache cleared", removed .. " files removed.")
end

local ui = {}
local state = {
        queue = {},
        index = 0,
        results = {},
        current = nil,
        loopMode = "Off",
        shuffle = false,
        scEnabled = true,
        dzrEnabled = true,
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

local playFromQueue, advance

local function onLoaded(sourceLabel)
        state.consecutiveFails = 0
        if ui.sourcePara then
                ui.sourcePara:Set("Source: " .. tostring(sourceLabel or "-"))
        end
        if sound.TimeLength > 0 and ui.seek then
                ui.seek:SetRange(0, math.max(1, math.floor(sound.TimeLength)))
                ui.seek:Set(0, false)
        end
        if ui.playBtn then ui.playBtn:Set("Pause") end
        if state.current then
                notify(state.current.title, state.current.artist .. " - " .. tostring(sourceLabel or ""))
        end
end

local function buildSources(tr)
        local list = {}
        if state.scEnabled then
                table.insert(list, { label = "SoundCloud", kind = "sc" })
        end
        if state.dzrEnabled and tr.isrc and state.dzrBase ~= "" then
                table.insert(list, {
                        label = "Deezer",
                        kind = "dzr",
                        url = state.dzrBase .. "/stream/?isrc=" .. urlEncode(tr.isrc) .. "&format=" .. urlEncode(state.dzrFormat),
                })
        end
        return list
end

local function runResolver(src, tr)
        if src.kind == "sc" then
                return scPickTrack(tr)
        end
        return src.url, "Deezer"
end

local function waitForSound(gen, budget)
        local waited = 0
        while waited < budget do
                task.wait(0.2)
                if not running or state.gen ~= gen then return false end
                if sound.IsLoaded or sound.TimeLength > 0 or sound.TimePosition > 0 then
                        return true
                end
                waited = waited + 0.2
        end
        return false
end

local function loadTrack(tr, gen)
        task.spawn(function()
                local sources = buildSources(tr)
                local reason = "no playback sources enabled"
                for _, src in ipairs(sources) do
                        if not running or state.gen ~= gen then return end
                        if ui.sourcePara then
                                ui.sourcePara:Set("Loading via " .. src.label .. "...")
                        end
                        local url, info = runResolver(src, tr)
                        if not running or state.gen ~= gen then return end
                        if url then
                                local asset, err = downloadToCache(tr, url)
                                if not running or state.gen ~= gen then return end
                                if asset then
                                        sound:Stop()
                                        sound.SoundId = asset
                                        sound:Play()
                                        if waitForSound(gen, 15) then
                                                onLoaded(info or src.label)
                                                return
                                        end
                                        if not running or state.gen ~= gen then return end
                                        sound:Stop()
                                        evictCache(tr.id)
                                        reason = src.label .. " audio never loaded"
                                else
                                        reason = src.label .. ": " .. tostring(err)
                                end
                        else
                                reason = tostring(info)
                        end
                end
                if not running or state.gen ~= gen then return end
                state.consecutiveFails = state.consecutiveFails + 1
                if state.current then
                        notify("Could not load", state.current.title .. " - " .. tostring(reason))
                end
                if state.consecutiveFails >= 5 then
                        state.consecutiveFails = 0
                        stopPlayback()
                        notify("Stopped", "Too many tracks failed in a row.")
                        return
                end
                advance(1, true)
        end)
end

function playFromQueue(userInitiated)
        local tr = state.queue[state.index]
        if not tr then return end
        state.gen = state.gen + 1
        local gen = state.gen
        state.current = tr
        if userInitiated then
                state.consecutiveFails = 0
        end
        sound:Stop()
        updateNowPlaying(tr, "Loading...")
        if ui.playBtn then ui.playBtn:Set("Pause") end
        renderQueue()
        if not customAsset or not FS.write then
                notify("Cannot play", "This executor has no getcustomasset/writefile, audio cannot be loaded.")
                return
        end
        loadTrack(tr, gen)
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
        playFromQueue(not auto)
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
                        playFromQueue(true)
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
        playFromQueue(true)
end

local function jumpTo(i)
        if state.queue[i] then
                state.index = i
                playFromQueue(true)
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
        state.scEnabled = not (ui.scEnabled and ui.scEnabled.Value == false)
        state.dzrEnabled = not (ui.dzrEnabled and ui.dzrEnabled.Value == false)
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

ui.scEnabled = sourcesSection:Toggle({
        Text = "Use SoundCloud",
        Value = true,
        Flag = "ScEnabled",
        Callback = function(v)
                state.scEnabled = v and true or false
                scheduleSave()
        end,
})

ui.dzrEnabled = sourcesSection:Toggle({
        Text = "Use Deezer ISRC",
        Value = true,
        Flag = "DzrEnabled",
        Callback = function(v)
                state.dzrEnabled = v and true or false
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
        Text = "SoundCloud matches a full-length upload by duration. Deezer streams the exact ISRC. Sources are tried in order until one loads.",
})

local cacheSection = settingsTab:Section("Cache")

ui.cacheStatus = cacheSection:Paragraph({
        Text = "0 cached tracks",
})

refreshCacheStatus = function()
        if ui.cacheStatus then
                ui.cacheStatus:Set(#readCacheOrder() .. " cached tracks (max " .. CACHE_LIMIT .. ")")
        end
end

refreshCacheStatus()

cacheSection:Button({
        Text = "Clear cache",
        Callback = function()
                clearCache()
        end,
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
