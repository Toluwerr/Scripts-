local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local API_BASE = "https://api.rscripts.net"
local SITE_BASE = "https://rscripts.net"
local FOLDER = "scriptfinder"
-- rscripts wants a key even for read-only routes, so this one ships with
-- the script; nobody should have to make a dashboard account just to browse
local API_KEY = "rsc_live_zA1n48C_ZCzYLOr_AvGyGBrcctAp7bLH"
local FAVORITES_FILE = FOLDER .. "/favorites.json"
local HISTORY_FILE = FOLDER .. "/history.json"
local PAGE_SIZE = 10
local TRENDING_SIZE = 12
local SAVED_ROWS = 10
local HISTORY_LIMIT = 30
local FAVORITES_LIMIT = 100

local LocalPlayer = Players.LocalPlayer
local Global = (getgenv and getgenv()) or _G

if type(Global.__ScriptFinderCleanup) == "function" then
        pcall(Global.__ScriptFinderCleanup)
end

local Reborn
do
        local ok, library = pcall(function()
                return loadstring(game:HttpGet(
                        "https://raw.githubusercontent.com/Toluwer/Reborn/main/src/Reborn.luau"
                ))()
        end)

        if not ok or type(library) ~= "table" or type(library.CreateWindow) ~= "function" then
                warn("[ScriptFinder] Failed to load the Reborn UI library.")
                return
        end

        Reborn = library
end

-- executors disagree on which http global exists; take the first one that
-- can send headers, because the rscripts api wants X-Api-Key
local function pickFunction(...)
        for i = 1, select("#", ...) do
                local candidate = select(i, ...)
                if type(candidate) == "function" then
                        return candidate
                end
        end

        return nil
end

local HttpRequest = pickFunction(
        (syn and syn.request),
        (http and type(http) == "table") and http.request or nil,
        (fluxus and type(fluxus) == "table") and fluxus.request or nil,
        (type(http_request) == "function") and http_request or nil,
        (type(request) == "function") and request or nil
)

local Clipboard = pickFunction(
        (type(setclipboard) == "function") and setclipboard or nil,
        (type(set_clipboard) == "function") and set_clipboard or nil,
        (type(toclipboard) == "function") and toclipboard or nil,
        (clipboard and type(clipboard) == "table") and clipboard.set or nil
)

local CanWrite = type(writefile) == "function"
local CanRead = type(readfile) == "function"

local Session = {
        Dead = false,
        Mode = nil,
        Picked = nil,
        Game = nil,
}

local Favorites = { Items = {} }
local History = { Items = {} }

local function notify(kind, title, description)
        if Session.Dead then
                return
        end

        pcall(function()
                Reborn:Notify({
                        Title = title,
                        Description = description,
                        Type = kind,
                })
        end)
end

local function trimToNil(text)
        if type(text) ~= "string" then
                return nil
        end

        text = text:gsub("^%s+", ""):gsub("%s+$", "")

        if text == "" then
                return nil
        end

        return text
end

local function clipText(text, limit)
        text = tostring(text or "")

        if #text > limit then
                return text:sub(1, limit) .. "..."
        end

        return text
end

local function fmtCount(value)
        value = tonumber(value)

        if not value then
                return nil
        end

        if value >= 1000000 then
                return string.format("%.1fm", value / 1000000)
        end

        if value >= 1000 then
                return string.format("%.1fk", value / 1000)
        end

        return tostring(math.floor(value))
end

local function countLabel(value, noun)
        local number = tonumber(value)

        if not number then
                return nil
        end

        return fmtCount(number) .. " " .. noun .. (number == 1 and "" or "s")
end

local function nowStamp()
        local ok, stamp = pcall(function()
                return os.time()
        end)

        if ok and type(stamp) == "number" then
                return stamp
        end

        return 0
end

local function timeLabel(stamp)
        stamp = tonumber(stamp)

        if not stamp or stamp <= 0 then
                return nil
        end

        local ok, label = pcall(function()
                return os.date("%m/%d %H:%M", stamp)
        end)

        if ok and type(label) == "string" then
                return label
        end

        return tostring(stamp)
end

-- small file helpers; everything degrades to memory when the executor
-- has no writefile (favorites then survive only for this session)
local function ensureFolder()
        if type(makefolder) == "function" then
                pcall(function()
                        makefolder(FOLDER)
                end)
        end
end

local function writeFile(path, text)
        if not CanWrite then
                return false
        end

        ensureFolder()

        return select(1, pcall(function()
                writefile(path, text)
        end))
end

local function readFile(path)
        if not CanRead then
                return nil
        end

        local ok, text = pcall(function()
                if type(isfile) == "function" and not isfile(path) then
                        return nil
                end

                return readfile(path)
        end)

        if ok and type(text) == "string" then
                return text
        end

        return nil
end

local function loadJsonArray(path)
        local text = readFile(path)

        if not text or text == "" then
                return nil
        end

        local ok, decoded = pcall(function()
                return HttpService:JSONDecode(text)
        end)

        if not ok or type(decoded) ~= "table" then
                return nil
        end

        local items = {}

        for _, item in ipairs(decoded) do
                if type(item) == "table" then
                        table.insert(items, item)
                end
        end

        return items
end

local function saveJsonArray(path, items)
        local ok, encoded = pcall(function()
                return HttpService:JSONEncode(items)
        end)

        if not ok then
                return false
        end

        return writeFile(path, encoded)
end

local function pickField(source, ...)
        for i = 1, select("#", ...) do
                local key = select(i, ...)
                local value = source[key]

                if value ~= nil and value ~= "" then
                        return value
                end
        end

        return nil
end

-- the api documents risk as a "summary" without promising a shape,
-- so flatten whatever arrives into one displayable string
local function flattenRisk(risk)
        if type(risk) == "string" then
                return risk ~= "" and risk or nil
        end

        if type(risk) == "table" then
                return pickField(risk, "level", "severity", "summary", "label", "title", "message", "description")
        end

        if risk == nil then
                return nil
        end

        return tostring(risk)
end

-- one uniform row object no matter which endpoint produced it
local function normalizeHit(raw, kind)
        raw = raw or {}

        if not kind then
                if pickField(raw, "rawScript", "raw", "rawUrl", "raw_url") then
                        kind = "script"
                elseif pickField(raw, "placeId", "place_id", "gameId", "game_id") then
                        kind = "game"
                elseif pickField(raw, "username", "userName", "uploader") then
                        kind = "user"
                else
                        kind = "script"
                end
        end

        local gameValue = raw.game
        local gameName = nil

        if type(gameValue) == "table" then
                gameName = pickField(gameValue, "name", "title", "Name")
        elseif type(gameValue) == "string" then
                gameName = gameValue
        end

        local userValue = pickField(raw, "username", "userName", "uploader", "author")
        local user = nil

        if type(userValue) == "table" then
                user = pickField(userValue, "username", "name")
        elseif type(userValue) == "string" then
                user = userValue
        end

        local scriptsCount = raw.scripts

        if type(scriptsCount) == "table" then
                scriptsCount = #scriptsCount
        end

        local slug = pickField(raw, "slug", "Slug")

        -- place ids are integer tokens; carry them as clean strings so they
        -- never serialize as 6516141723.0 on any runtime
        local placeId = tonumber(pickField(raw, "placeId", "place_id", "gameId", "game_id"))

        if placeId and placeId <= 0 then
                placeId = nil
        end

        if placeId then
                placeId = string.format("%.0f", placeId)
        end

        return {
                Kind = kind,
                Title = clipText(pickField(raw, "title", "name", "Name", "scriptName", "username", "userName") or "(untitled)", 120),
                Game = gameName,
                User = user,
                Raw = pickField(raw, "rawScript", "raw", "rawUrl", "raw_url"),
                Slug = slug,
                Page = pickField(raw, "url", "page") or ((kind == "script" and slug) and (SITE_BASE .. "/script/" .. tostring(slug)) or nil),
                PlaceId = placeId,
                Views = tonumber(pickField(raw, "views", "viewCount", "viewsCount")),
                Likes = tonumber(pickField(raw, "likes", "likeCount", "likesCount")),
                Executions = tonumber(pickField(raw, "executions", "executionCount", "execs")),
                Scripts = tonumber(scriptsCount),
                Keyless = raw.keyless or raw.isKeyless or nil,
                Mobile = raw.mobile or raw.isMobile or nil,
                Risk = flattenRisk(raw.risk or raw.riskSummary),
        }
end

local function extractList(value)
        if type(value) ~= "table" then
                return {}
        end

        if type(value.results) == "table" then
                value = value.results
        elseif type(value.hits) == "table" then
                value = value.hits
        end

        local items = {}

        for _, item in ipairs(value) do
                if type(item) == "table" then
                        table.insert(items, item)
                end
        end

        return items
end

-- search answers either a flat list (single index) or grouped
-- scripts/games/users buckets (multi index); handle both
local function collectHits(data)
        local hits = {}

        if type(data) ~= "table" then
                return hits
        end

        local function grab(value, kind)
                for _, raw in ipairs(extractList(value)) do
                        table.insert(hits, normalizeHit(raw, kind))
                end
        end

        if type(data.scripts) == "table" or type(data.games) == "table" or type(data.users) == "table" then
                grab(data.scripts, "script")
                grab(data.games, "game")
                grab(data.users, "user")
        else
                local list = data.results or data.hits or data.items or data.scripts

                if type(list) ~= "table" and #data > 0 then
                        list = data
                end

                if type(list) == "table" then
                        for _, raw in ipairs(list) do
                                if type(raw) == "table" then
                                        table.insert(hits, normalizeHit(raw, nil))
                                end
                        end
                end
        end

        return hits
end

local function buildUrl(path, params)
        local url = API_BASE .. path
        local parts = {}

        for key, value in pairs(params or {}) do
                if value ~= nil and value ~= "" then
                        local encoded = HttpService:UrlEncode(tostring(value))

                        -- commas stay literal: index=scripts,games,users is a
                        -- comma separated value, not three params
                        encoded = encoded:gsub("%%2[cC]", ",")

                        table.insert(parts, tostring(key) .. "=" .. encoded)
                end
        end

        if #parts > 0 then
                url = url .. "?" .. table.concat(parts, "&")
        end

        return url
end

-- every rscripts response is {success = true, data = ...} or
-- {success = false, error = {code, message}}; return (data, err)
local function apiGet(path, params)
        if HttpRequest == nil then
                return nil, "this executor has no request function that can send headers"
        end

        local response
        local ok = pcall(function()
                response = HttpRequest({
                        Url = buildUrl(path, params),
                        Method = "GET",
                        Headers = { ["X-Api-Key"] = API_KEY },
                })
        end)

        if not ok or type(response) ~= "table" then
                return nil, "request to rscripts failed"
        end

        local code = tonumber(response.StatusCode or response.status or response.code)
                or (response.Success == true and 200)
                or 0
        local body = response.Body or response.body or ""

        local decoded = nil

        if type(body) == "string" and body ~= "" then
                local jsonOk
                jsonOk, decoded = pcall(function()
                        return HttpService:JSONDecode(body)
                end)

                if not jsonOk then
                        decoded = nil
                end
        end

        local apiError = type(decoded) == "table" and type(decoded.error) == "table" and decoded.error or nil

        if code == 401 or (apiError and apiError.code == "UNAUTHORIZED") then
                return nil, "bad or missing api key"
        end

        if code == 429 then
                return nil, "rate limited - rscripts allows 1000 requests per minute"
        end

        if code ~= 200 then
                return nil, (apiError and apiError.message) or ("rscripts answered " .. tostring(code))
        end

        if type(decoded) ~= "table" then
                return nil, "rscripts sent unreadable json"
        end

        if decoded.success == false then
                if apiError then
                        return nil, apiError.message or apiError.code or "api error"
                end

                return nil, "api error"
        end

        if decoded.data ~= nil then
                return decoded.data, nil
        end

        return decoded, nil
end

-- raw files live on rscripts.net/raw/<file>.txt; HttpGet is enough for
-- them, the header-capable request is the fallback
local function fetchSource(url)
        local body
        local ok = pcall(function()
                body = game:HttpGet(url)
        end)

        if not ok or type(body) ~= "string" or #body == 0 then
                ok = false

                if HttpRequest ~= nil then
                        ok = pcall(function()
                                local response = HttpRequest({ Url = url, Method = "GET" })
                                body = response.Body
                        end)
                end
        end

        if not ok or type(body) ~= "string" or #body == 0 then
                return nil, "couldn't download the script"
        end

        local head = body:sub(1, 300):lower()

        if head:find("<!doctype", 1, true) or head:find("<html", 1, true) or head:find("checking your browser", 1, true) then
                return nil, "rscripts served a webpage instead of a script"
        end

        return body
end

-- persisted state, loaded before the ui exists so the lists start populated
do
        local favorites = loadJsonArray(FAVORITES_FILE)

        if favorites then
                Favorites.Items = favorites
        end

        local history = loadJsonArray(HISTORY_FILE)

        if history then
                History.Items = history
        end
end

local PickRefreshers = {}
local SavedRenderers = {}

local function refreshPickers()
        for _, refresh in ipairs(PickRefreshers) do
                refresh()
        end
end

local function renderSaved()
        for _, render in ipairs(SavedRenderers) do
                render()
        end
end

local function setPicked(hit)
        Session.Picked = hit
        refreshPickers()
end

local function rowText(hit)
        if hit.Kind == "game" then
                local text = "game  ·  " .. hit.Title

                if hit.Scripts then
                        text = text .. "  ·  " .. tostring(hit.Scripts) .. " scripts"
                end

                return clipText(text, 78)
        elseif hit.Kind == "user" then
                return clipText("uploader  ·  " .. hit.Title, 78)
        end

        local text = hit.Title

        if hit.Game and hit.Game ~= "" then
                text = text .. "  ·  " .. hit.Game
        end

        return clipText(text, 78)
end

local function rowTooltip(hit)
        local parts = {}

        if hit.Kind == "game" then
                table.insert(parts, "place " .. tostring(hit.PlaceId or "?"))
                table.insert(parts, "pick to list its scripts")

                return table.concat(parts, " · ")
        elseif hit.Kind == "user" then
                table.insert(parts, "pick to browse their uploads")

                return table.concat(parts, " · ")
        end

        if hit.User then
                table.insert(parts, "by " .. hit.User)
        end

        local views = countLabel(hit.Views, "view")

        if views then
                table.insert(parts, views)
        end

        local likes = countLabel(hit.Likes, "like")

        if likes then
                table.insert(parts, likes)
        end

        local runs = countLabel(hit.Executions, "run")

        if runs then
                table.insert(parts, runs)
        end

        if hit.Keyless then
                table.insert(parts, "keyless")
        end

        if hit.Mobile then
                table.insert(parts, "mobile ready")
        end

        if hit.Risk then
                table.insert(parts, "risk: " .. hit.Risk)
        end

        if hit.At then
                local label = timeLabel(hit.At)

                if label then
                        table.insert(parts, (hit.Ran and "ran " or "saved ") .. label)
                end
        end

        if #parts == 0 then
                return ""
        end

        return table.concat(parts, " · ")
end

local function describeHit(hit)
        local lines = {}

        if hit.Kind == "game" then
                table.insert(lines, "game · " .. hit.Title)

                if hit.PlaceId then
                        table.insert(lines, "placeId " .. tostring(hit.PlaceId))
                end

                if hit.Scripts then
                        table.insert(lines, tostring(hit.Scripts) .. " scripts uploaded")
                end

                table.insert(lines, "pick this to list its scripts")
        elseif hit.Kind == "user" then
                table.insert(lines, "uploader · " .. hit.Title)

                if hit.Scripts then
                        table.insert(lines, tostring(hit.Scripts) .. " uploads")
                end

                table.insert(lines, "pick this to browse their uploads")
        else
                table.insert(lines, "script · " .. hit.Title)

                if hit.Game and hit.Game ~= "" then
                        table.insert(lines, "for " .. hit.Game)
                end

                local stats = {}

                if hit.User then
                        table.insert(stats, "by " .. hit.User)
                end

                local views = countLabel(hit.Views, "view")

                if views then
                        table.insert(stats, views)
                end

                local likes = countLabel(hit.Likes, "like")

                if likes then
                        table.insert(stats, likes)
                end

                local runs = countLabel(hit.Executions, "run")

                if runs then
                        table.insert(stats, runs)
                end

                if hit.Keyless then
                        table.insert(stats, "keyless")
                end

                if hit.Mobile then
                        table.insert(stats, "mobile ready")
                end

                if #stats > 0 then
                        table.insert(lines, table.concat(stats, " · "))
                end

                if hit.Risk then
                        table.insert(lines, "risk: " .. hit.Risk)
                end
        end

        if hit.Page then
                table.insert(lines, hit.Page)
        end

        return table.concat(lines, "\n")
end

local function sameTarget(a, b)
        if type(a) ~= "table" or type(b) ~= "table" then
                return false
        end

        if a.Raw and b.Raw then
                return a.Raw == b.Raw
        end

        if a.Page and b.Page then
                return a.Page == b.Page
        end

        return a.Title == b.Title and a.Kind == b.Kind
end

local function shallowHit(hit, ran)
        local entry = {}
        local keys = {
                "Kind", "Title", "Game", "User", "Raw", "Slug", "Page",
                "PlaceId", "Views", "Likes", "Executions", "Scripts",
                "Keyless", "Mobile", "Risk",
        }

        for _, key in ipairs(keys) do
                local value = hit[key]

                if value ~= nil then
                        entry[key] = value
                end
        end

        entry.At = nowStamp()
        entry.Ran = ran or nil

        return entry
end

local function isFavorite(hit)
        for _, entry in ipairs(Favorites.Items) do
                if sameTarget(entry, hit) then
                        return true
                end
        end

        return false
end

local function pushHistory(hit)
        for i = #History.Items, 1, -1 do
                if sameTarget(History.Items[i], hit) then
                        table.remove(History.Items, i)
                end
        end

        table.insert(History.Items, 1, shallowHit(hit, true))

        while #History.Items > HISTORY_LIMIT do
                table.remove(History.Items)
        end

        saveJsonArray(HISTORY_FILE, History.Items)
        renderSaved()
end

local function toggleFavorite(hit, wanted)
        if wanted then
                if #Favorites.Items >= FAVORITES_LIMIT then
                        notify("error", "Favorites full", FAVORITES_LIMIT .. " saved scripts is the cap")

                        return
                end

                table.insert(Favorites.Items, 1, shallowHit(hit, false))
                saveJsonArray(FAVORITES_FILE, Favorites.Items)
                notify("success", "Saved", hit.Title)
        else
                for i = #Favorites.Items, 1, -1 do
                        if sameTarget(Favorites.Items[i], hit) then
                                table.remove(Favorites.Items, i)
                        end
                end

                saveJsonArray(FAVORITES_FILE, Favorites.Items)
        end

        renderSaved()
        refreshPickers()
end

local function copyText(text, label)
        if Clipboard == nil then
                notify("error", "No clipboard", "this executor has no setclipboard")

                return false
        end

        local ok = pcall(Clipboard, text)

        if ok then
                notify("success", "Copied", label or (#text .. " characters"))
        else
                notify("error", "Copy failed", "setclipboard threw an error")
        end

        return ok
end

local function runPicked()
        local hit = Session.Picked

        if not hit or hit.Kind ~= "script" or type(hit.Raw) ~= "string" then
                notify("error", "Nothing to run", "pick a script from a list first")

                return
        end

        if type(loadstring) ~= "function" then
                notify("error", "Run failed", "this executor has no loadstring")

                return
        end

        task.spawn(function()
                local source, err = fetchSource(hit.Raw)

                if Session.Dead then
                        return
                end

                if not source then
                        notify("error", "Run failed", err or "download failed")

                        return
                end

                local chunk, loadErr = loadstring(source)

                if not chunk then
                        notify("error", "Run failed", "syntax error: " .. tostring(loadErr))

                        return
                end

                pushHistory(hit)
                notify("success", "Executed", hit.Title)

                local ok, runErr = pcall(chunk)

                if not ok then
                        notify("error", "Script errored", tostring(runErr))
                end
        end)
end

local function copyPickedLoadstring()
        local hit = Session.Picked

        if not hit or hit.Kind ~= "script" or type(hit.Raw) ~= "string" then
                notify("error", "Nothing picked", "pick a script from a list first")

                return
        end

        copyText('loadstring(game:HttpGet("' .. hit.Raw .. '"))()', "paste this into any executor")
end

local function copyPickedPage()
        local hit = Session.Picked

        if not hit or not hit.Page then
                notify("error", "Nothing picked", "pick something with a rscripts page first")

                return
        end

        copyText(hit.Page, "rscripts page url")
end

local function copyPickedRaw()
        local hit = Session.Picked

        if not hit or hit.Kind ~= "script" or type(hit.Raw) ~= "string" then
                notify("error", "Nothing picked", "pick a script from a list first")

                return
        end

        copyText(hit.Raw, "direct link to the raw script file")
end

-- browsers: one per listing. Rows and Status are attached when the ui
-- is built; everything below only reads them at call time.
local SearchBrowser = { Busy = false, Hits = {}, Page = 1 }
local TrendingBrowser = { Busy = false }
local GameBrowser = { Busy = false, Hits = {}, Page = 1 }

local SearchIndex = "scripts"
local GameSort = "newest"

local INDEX_MAP = {
        Scripts = "scripts",
        Games = "games",
        Users = "users",
        Everything = "scripts,games,users",
}

local function describeResults(browser, data)
        if #browser.Hits == 0 then
                return browser.EmptyText or "no hits"
        end

        local total = nil

        if type(data) == "table" then
                total = data.total or data.count

                if type(data.meta) == "table" then
                        total = total or data.meta.total or data.meta.count
                end
        end

        local text = "page " .. tostring(browser.Page or 1) .. " · " .. #browser.Hits .. " shown"

        if total then
                text = text .. " of " .. tostring(total)
        end

        return text
end

local function loadInto(browser, path, params)
        if browser.Busy then
                return
        end

        browser.Busy = true

        if browser.Status then
                browser.Status:Set("loading...")
        end

        task.spawn(function()
                local data, err = apiGet(path, params)

                browser.Busy = false

                if Session.Dead or not browser.Rows then
                        return
                end

                if err then
                        browser.Status:Set("failed · " .. err)

                        return
                end

                browser.Hits = collectHits(data)
                browser.Rows.Set(browser.Hits)
                browser.Status:Set(describeResults(browser, data))

                if browser.AfterLoad then
                        browser.AfterLoad(browser.Hits)
                end
        end)
end

local function modeText(mode)
        if not mode then
                return "idle · type a game or script name"
        end

        if mode.Kind == "Search" then
                return "searching " .. mode.Index .. " for: " .. mode.Query
        elseif mode.Kind == "Place" then
                return "game: " .. (mode.Label or "?") .. " (" .. tostring(mode.PlaceId) .. ")"
        elseif mode.Kind == "User" then
                return "uploader: " .. (mode.Username or "?")
        end

        return "idle"
end

local function refreshSearch()
        local mode = Session.Mode

        if not mode then
                return
        end

        if SearchBrowser.ModeLabel then
                SearchBrowser.ModeLabel:Set(modeText(mode))
        end

        if mode.Kind == "Search" then
                loadInto(SearchBrowser, "/v1/search", {
                        q = mode.Query,
                        index = mode.Index,
                        limit = PAGE_SIZE,
                        page = SearchBrowser.Page,
                })
        elseif mode.Kind == "Place" then
                loadInto(SearchBrowser, "/v1/scripts", {
                        placeId = mode.PlaceId,
                        sort = "newest",
                        limit = PAGE_SIZE,
                        page = SearchBrowser.Page,
                })
        elseif mode.Kind == "User" then
                loadInto(SearchBrowser, "/v1/scripts", {
                        username = mode.Username,
                        sort = "newest",
                        limit = PAGE_SIZE,
                        page = SearchBrowser.Page,
                })
        end
end

local function runSearch(query)
        query = trimToNil(query)

        if not query then
                notify("error", "Empty query", "type a game or script name first")

                return
        end

        Session.Mode = {
                Kind = "Search",
                Query = query,
                Index = SearchIndex,
        }
        SearchBrowser.Page = 1

        refreshSearch()
end

local function turnPage(delta)
        local page = (SearchBrowser.Page or 1) + delta

        if page < 1 then
                return
        end

        SearchBrowser.Page = page
        refreshSearch()
end

local function browsePicked()
        local hit = Session.Picked

        if not hit then
                return
        end

        if hit.Kind == "game" then
                if not hit.PlaceId then
                        notify("error", "No placeId", "this game hit didn't include a placeId")

                        return
                end

                Session.Mode = {
                        Kind = "Place",
                        PlaceId = hit.PlaceId,
                        Label = hit.Title,
                }
                SearchBrowser.Page = 1

                refreshSearch()
                notify("info", "Browsing", "scripts for " .. hit.Title)
        elseif hit.Kind == "user" then
                local username = hit.User or hit.Title

                Session.Mode = {
                        Kind = "User",
                        Username = username,
                }
                SearchBrowser.Page = 1

                refreshSearch()
                notify("info", "Browsing", "uploads by " .. username)
        end
end

local function refreshTrending()
        if TrendingBrowser.Busy then
                return
        end

        TrendingBrowser.Busy = true

        if TrendingBrowser.RisingStatus then
                TrendingBrowser.RisingStatus:Set("loading...")
        end

        if TrendingBrowser.HotStatus then
                TrendingBrowser.HotStatus:Set("loading...")
        end

        task.spawn(function()
                local data, err = apiGet("/v1/trending", {})

                TrendingBrowser.Busy = false

                if Session.Dead then
                        return
                end

                if err then
                        if TrendingBrowser.RisingStatus then
                                TrendingBrowser.RisingStatus:Set("failed · " .. err)
                        end

                        if TrendingBrowser.HotStatus then
                                TrendingBrowser.HotStatus:Set("failed · " .. err)
                        end

                        return
                end

                local rising = extractList(type(data) == "table" and data.rising or nil)
                local hot = extractList(type(data) == "table" and (data.trending or data.hot) or nil)

                local risingHits = {}
                local hotHits = {}

                for _, raw in ipairs(rising) do
                        table.insert(risingHits, normalizeHit(raw, "script"))
                end

                for _, raw in ipairs(hot) do
                        table.insert(hotHits, normalizeHit(raw, "script"))
                end

                if TrendingBrowser.RisingRows then
                        TrendingBrowser.RisingRows.Set(risingHits)
                end

                if TrendingBrowser.HotRows then
                        TrendingBrowser.HotRows.Set(hotHits)
                end

                if TrendingBrowser.RisingStatus then
                        TrendingBrowser.RisingStatus:Set(#risingHits == 0 and "nothing rising right now" or (#risingHits .. " gaining views fast"))
                end

                if TrendingBrowser.HotStatus then
                        TrendingBrowser.HotStatus:Set(#hotHits == 0 and "nothing hot right now" or (#hotHits .. " most viewed in the last 48 hours"))
                end
        end)
end

local GameLabel

local function detectGame()
        local placeId = game.PlaceId
        local name = nil

        if placeId and placeId > 0 then
                pcall(function()
                        local info = MarketplaceService:GetProductInfo(placeId)
                        name = info.Name
                end)
        end

        Session.Game = {
                PlaceId = placeId,
                Name = name,
        }

        if GameLabel then
                if placeId and placeId > 0 then
                        GameLabel:Set((name or "unknown game") .. "\nplaceId " .. tostring(placeId))
                else
                        GameLabel:Set("not in a published game (studio?)\ncan't list scripts for this")
                end
        end
end

local function refreshGameScripts()
        detectGame()

        if not Session.Game or not Session.Game.PlaceId or Session.Game.PlaceId <= 0 then
                if GameBrowser.Status then
                        GameBrowser.Status:Set("no game to browse")
                end

                return
        end

        loadInto(GameBrowser, "/v1/scripts", {
                placeId = Session.Game.PlaceId,
                sort = GameSort,
                limit = PAGE_SIZE,
                page = GameBrowser.Page,
        })
end

local function capabilityReport()
        local name = "unknown"

        if type(identifyexecutor) == "function" then
                local ok, result = pcall(identifyexecutor)

                if ok and type(result) == "string" then
                        name = result
                end
        end

        local function yesNo(flag)
                return flag and "yes" or "no"
        end

        return table.concat({
                "executor: " .. name,
                "request with headers: " .. yesNo(HttpRequest ~= nil) .. " (search needs this)",
                "clipboard: " .. yesNo(Clipboard ~= nil),
                "file persistence: " .. yesNo(CanWrite) .. " (favorites and history)",
                "loadstring: " .. yesNo(type(loadstring) == "function"),
        }, "\n")
end

-- a result list is just a stack of hidden buttons that get retitled and
-- unhidden per slot; reborn has no way to repopulate a dropdown's options,
-- and button rows read better anyway
local function buildResultRows(section, count)
        local hits = {}
        local slots = {}

        for i = 1, count do
                local slot = section:Button({
                        Text = "",
                        Callback = function()
                                local hit = hits[i]

                                if hit then
                                        setPicked(hit)
                                end
                        end,
                })

                slot:SetVisible(false)
                slots[i] = slot
        end

        local widget = {}

        function widget.Set(list)
                hits = list or {}

                for i = 1, count do
                        local hit = hits[i]

                        if hit then
                                slots[i]:Set(rowText(hit))
                                slots[i]:SetTooltip(rowTooltip(hit))
                                slots[i]:SetVisible(true)
                        else
                                slots[i]:SetVisible(false)
                        end
                end
        end

        return widget
end

local function buildPickedSection(section)
        local details = section:Paragraph({ Text = "nothing picked yet" })

        local runButton = section:Button({
                Text = "Run Script",
                Primary = true,
                Tooltip = "downloads the raw file from rscripts and loadstrings it",
                Callback = runPicked,
        })

        local loadstringButton = section:Button({
                Text = "Copy Loadstring",
                Tooltip = "the one-liner you would paste into an executor yourself",
                Callback = copyPickedLoadstring,
        })

        local rawButton = section:Button({
                Text = "Copy Raw URL",
                Tooltip = "direct link to the raw .txt on rscripts",
                Callback = copyPickedRaw,
        })

        local pageButton = section:Button({
                Text = "Copy Page URL",
                Tooltip = "link to the script page, good for sharing",
                Callback = copyPickedPage,
        })

        local favoriteToggle = section:Toggle({
                Text = "Favorite",
                Value = false,
                Tooltip = "written to scriptfinder/favorites.json, survives rejoins",
                Callback = function(value)
                        local hit = Session.Picked

                        if hit then
                                toggleFavorite(hit, value)
                        end
                end,
        })

        local relatedButton = section:Button({
                Text = "Related",
                Callback = browsePicked,
        })

        local actions = { runButton, loadstringButton, rawButton, pageButton, favoriteToggle, relatedButton }

        local function refresh()
                local hit = Session.Picked

                if not hit then
                        details:Set("nothing picked yet · click a result row")
                        favoriteToggle:Set(false, false)

                        for _, action in ipairs(actions) do
                                action:SetVisible(false)
                        end

                        return
                end

                details:Set(describeHit(hit))

                runButton:SetVisible(hit.Kind == "script")
                loadstringButton:SetVisible(hit.Kind == "script")
                rawButton:SetVisible(hit.Kind == "script")
                pageButton:SetVisible(hit.Page ~= nil)
                favoriteToggle:SetVisible(hit.Kind == "script")
                favoriteToggle:Set(isFavorite(hit), false)

                if hit.Kind == "game" then
                        relatedButton:Set("List Scripts For This Game")
                        relatedButton:SetVisible(true)
                elseif hit.Kind == "user" then
                        relatedButton:Set("Browse Uploads By " .. hit.Title)
                        relatedButton:SetVisible(true)
                else
                        relatedButton:SetVisible(false)
                end
        end

        table.insert(PickRefreshers, refresh)
        refresh()

        return refresh
end

local Window = Reborn:CreateWindow({
        Title = "ScriptFinder",
        Size = Vector2.new(760, 540),
})

Window.ToggleKey = "Right Shift"

local SearchTab = Window:Tab("Search", "radar")
local TrendingTab = Window:Tab("Trending", "flame")
local GameTab = Window:Tab("This Game", "gamepad-2")
local SavedTab = Window:Tab("Saved", "star")
local SettingsTab = Window:Tab("Settings", "settings")

TrendingTab:SetColumns(2)
SavedTab:SetColumns(2)
SettingsTab:SetColumns(2)

do
local QuerySection = SearchTab:Section("Query")

SearchBrowser.ModeLabel = QuerySection:Paragraph({ Text = modeText(Session.Mode) })

local QueryInput

QueryInput = QuerySection:Input({
        Text = "Query",
        Value = "",
        Placeholder = "e.g. arsenal, blox fruits, doors",
        Tooltip = "enter runs the search; the picker below decides what gets searched",
        Callback = function(text, enter)
                if enter then
                        runSearch(text)
                end
        end,
})

QuerySection:Dropdown({
        Text = "Look Through",
        Value = "Scripts",
        Options = { "Scripts", "Games", "Users", "Everything" },
        Tooltip = "games and users show up as rows you can pick to drill into",
        Callback = function(value)
                SearchIndex = INDEX_MAP[value] or "scripts"
        end,
})

QuerySection:Button({
        Text = "Search",
        Primary = true,
        Callback = function()
                runSearch(QueryInput.Text)
        end,
})
end

do
local ResultsSection = SearchTab:Section("Results")

SearchBrowser.Status = ResultsSection:Paragraph({ Text = "nothing searched yet" })

SearchBrowser.PrevButton = ResultsSection:Button({
        Text = "Previous Page",
        Callback = function()
                turnPage(-1)
        end,
})

SearchBrowser.PrevButton:SetVisible(false)

SearchBrowser.Rows = buildResultRows(ResultsSection, PAGE_SIZE)

SearchBrowser.NextButton = ResultsSection:Button({
        Text = "Next Page",
        Callback = function()
                turnPage(1)
        end,
})

SearchBrowser.NextButton:SetVisible(false)

SearchBrowser.AfterLoad = function(hits)
        local page = SearchBrowser.Page or 1

        SearchBrowser.PrevButton:SetVisible(page > 1)
        SearchBrowser.NextButton:SetVisible(#hits >= PAGE_SIZE)
end

SearchBrowser.EmptyText = "no hits · try another spelling, or search for the game and drill in"
end

do
local PickedSection = SearchTab:Section("Picked")

buildPickedSection(PickedSection)
end

do
local RisingSection = TrendingTab:Section("Rising")

RisingSection:Button({
        Text = "Refresh",
        Callback = refreshTrending,
})

TrendingBrowser.RisingStatus = RisingSection:Paragraph({
        Text = "not loaded yet",
})

TrendingBrowser.RisingRows = buildResultRows(RisingSection, TRENDING_SIZE)

local HotSection = TrendingTab:Section("Hot")

TrendingBrowser.HotStatus = HotSection:Paragraph({
        Text = "not loaded yet",
})

TrendingBrowser.HotRows = buildResultRows(HotSection, TRENDING_SIZE)

local TrendingPickedSection = TrendingTab:Section("Picked")

buildPickedSection(TrendingPickedSection)
end

do
local GameSection = GameTab:Section("Detected Game")

GameLabel = GameSection:Paragraph({ Text = "detecting..." })

GameSection:Dropdown({
        Text = "Sort",
        Value = "Newest",
        Options = { "Newest", "Views", "Likes" },
        Tooltip = "newest is the only one documented; the others are a guess the api may reject",
        Callback = function(value)
                GameSort = value:lower()
                GameBrowser.Page = 1
                refreshGameScripts()
        end,
})

GameSection:Button({
        Text = "Refresh",
        Callback = function()
                GameBrowser.Page = 1
                refreshGameScripts()
        end,
})
end

do
local GameListSection = GameTab:Section("Scripts For This Game")

GameBrowser.Status = GameListSection:Paragraph({ Text = "idle" })
GameBrowser.Rows = buildResultRows(GameListSection, PAGE_SIZE)
GameBrowser.EmptyText = "no scripts uploaded for this game yet"

local GamePickedSection = GameTab:Section("Picked")

buildPickedSection(GamePickedSection)
end

do
local FavoritesSection = SavedTab:Section("Favorites")

local FavoritesStatus = FavoritesSection:Paragraph({ Text = "..." })

local FavoritesRows = buildResultRows(FavoritesSection, SAVED_ROWS)

table.insert(SavedRenderers, function()
        FavoritesRows.Set(Favorites.Items)

        if #Favorites.Items == 0 then
                FavoritesStatus:Set("nothing saved yet · favorite a script from any list")
        elseif #Favorites.Items > SAVED_ROWS then
                FavoritesStatus:Set(#Favorites.Items .. " saved · showing the first " .. SAVED_ROWS)
        else
                FavoritesStatus:Set(#Favorites.Items .. " saved")
        end
end)

local HistorySection = SavedTab:Section("History")

local HistoryStatus = HistorySection:Paragraph({ Text = "..." })

local HistoryRows = buildResultRows(HistorySection, SAVED_ROWS)

table.insert(SavedRenderers, function()
        HistoryRows.Set(History.Items)

        if #History.Items == 0 then
                HistoryStatus:Set("nothing ran yet")
        elseif #History.Items > SAVED_ROWS then
                HistoryStatus:Set("last " .. HISTORY_LIMIT .. " runs · showing the first " .. SAVED_ROWS)
        else
                HistoryStatus:Set(#History.Items .. " recently run")
        end
end)

HistorySection:Button({
        Text = "Clear History",
        Callback = function()
                History.Items = {}
                saveJsonArray(HISTORY_FILE, History.Items)
                renderSaved()
                notify("info", "History cleared", "")
        end,
})

local SavedPickedSection = SavedTab:Section("Picked")

buildPickedSection(SavedPickedSection)
end

do
local ApiSection = SettingsTab:Section("Rscripts API")

ApiSection:Paragraph({
        Text = "api key is baked in · search and trending work right away, nothing to paste",
})

local InterfaceSection = SettingsTab:Section("Interface")

InterfaceSection:Toggle({
        Text = "Notifications",
        Value = true,
        Callback = function(value)
                Reborn.NotificationsEnabled = value and true or false
        end,
})

InterfaceSection:Keybind({
        Text = "Open / Close UI",
        Value = "Right Shift",
        Callback = function()
                Window:Toggle()
        end,
})

local AboutSection = SettingsTab:Section("About")

AboutSection:Paragraph({
        Text = "front end for the rscripts.net community script index · search, trending and per-game listings all come from their public api",
})

AboutSection:Paragraph({
        Text = "ui: reborn by toluwer (github.com/toluwer/reborn) · scripts: whatever the rscripts community uploaded · read the risk line before running something unknown",
})

AboutSection:Paragraph({ Text = capabilityReport() })
end

local function cleanup()
        Session.Dead = true

        pcall(function()
                Window:Destroy()
        end)
end

Global.__ScriptFinderCleanup = cleanup

pcall(function()
        Window.Gui.Destroying:Connect(function()
                Session.Dead = true
        end)
end)

renderSaved()
detectGame()

refreshTrending()
refreshGameScripts()

notify("info", "ScriptFinder", "ready · right shift hides the window")
