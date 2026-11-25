-- Executor chat client (WebSocket with automatic HTTP-poll fallback)
local SERVER = "https://nonfq-chat.doorplayz123.workers.dev"

local env = (getgenv and getgenv()) or _G
if env.__ChatCleanup then pcall(env.__ChatCleanup) end

-- The admin token is NOT stored in this script (it's public). It is loaded from:
--   1) a file named chat_admin.txt in your executor's workspace folder (just the token, nothing else), or
--   2) getgenv().ChatAdminToken = "..." set in your own autoexec before this script runs.
-- If neither exists, admin commands are simply off.
local ADMIN_TOKEN = ""
do
	local ok, v = pcall(function()
		if env.ChatAdminToken then return env.ChatAdminToken end
		if isfile and readfile and isfile("chat_admin.txt") then return readfile("chat_admin.txt") end
	end)
	if ok and type(v) == "string" then ADMIN_TOKEN = (v:gsub("%s+", "")) end
end

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local lp = Players.LocalPlayer

-- id must match CHANNELS in worker.js
local CHANNELS = {
	{ id = "main", name = "Main Chat" },
	{ id = "lounge", name = "Lounge" },
	{ id = "offtopic", name = "Off-Topic" },
}

local WS_URL = (SERVER:gsub("^http", "ws")) .. "/ws"
local MAX_LEN = 200
local WIN_W, WIN_H = 740, 488
local MIN_W, MIN_H = 570, 365
local TITLE_H = 44
local SIDE_W = 184

local req = request or http_request or (syn and syn.request) or (http and http.request) or (fluxus and fluxus.request)
local hasWS = (WebSocket and WebSocket.connect) and true or false

-- hardware id (used for HWID bans)
local HWID = ""
do
	local ok, v = pcall(function()
		if gethwid then return gethwid() end
		return game:GetService("RbxAnalyticsService"):GetClientId()
	end)
	if ok and type(v) == "string" then HWID = v end
end

local alive = true
local banned = false
local conns = {}
local function bind(signal, fn)
	local c = signal:Connect(fn)
	conns[#conns + 1] = c
	return c
end

-- ---------- emoji shortcodes (:sob: -> emoji) ----------
local EMOJI_RAW = {
	smile = 0x1F604, grin = 0x1F601, joy = 0x1F602, rofl = 0x1F923, smiley = 0x1F603, laughing = 0x1F606,
	sweat_smile = 0x1F605, wink = 0x1F609, blush = 0x1F60A, innocent = 0x1F607, slight_smile = 0x1F642,
	upside_down = 0x1F643, relaxed = 0x263A, relieved = 0x1F60C, heart_eyes = 0x1F60D, star_struck = 0x1F929,
	kissing_heart = 0x1F618, yum = 0x1F60B, stuck_out_tongue = 0x1F61B, stuck_out_tongue_winking_eye = 0x1F61C,
	zany = 0x1F92A, money_mouth = 0x1F911, hugging = 0x1F917, thinking = 0x1F914, shushing = 0x1F92B,
	zipper_mouth = 0x1F910, neutral_face = 0x1F610, expressionless = 0x1F611, unamused = 0x1F612,
	rolling_eyes = 0x1F644, smirk = 0x1F60F, grimacing = 0x1F62C, pensive = 0x1F614, sleepy = 0x1F62A,
	sleeping = 0x1F634, mask = 0x1F637, nauseated = 0x1F922, vomiting = 0x1F92E, hot_face = 0x1F975,
	cold_face = 0x1F976, dizzy_face = 0x1F635, exploding_head = 0x1F92F, cowboy = 0x1F920,
	partying_face = 0x1F973, sunglasses = 0x1F60E, nerd = 0x1F913, monocle = 0x1F9D0, confused = 0x1F615,
	worried = 0x1F61F, open_mouth = 0x1F62E, hushed = 0x1F62F, astonished = 0x1F632, flushed = 0x1F633,
	pleading = 0x1F97A, cry = 0x1F622, sob = 0x1F62D, scream = 0x1F631, fearful = 0x1F628, weary = 0x1F629,
	tired_face = 0x1F62B, triumph = 0x1F624, angry = 0x1F620, rage = 0x1F621, disappointed = 0x1F61E,
	sweat = 0x1F613, yawning = 0x1F971, melting_face = 0x1FAE0, salute = 0x1FAE1, face_holding_back_tears = 0x1F979,
	skull = 0x1F480, skull_crossbones = { 0x2620, 0xFE0F }, ghost = 0x1F47B, alien = 0x1F47D, robot = 0x1F916,
	poop = 0x1F4A9, clown = 0x1F921, smiling_imp = 0x1F608, imp = 0x1F47F, angel = 0x1F47C,
	see_no_evil = 0x1F648, hear_no_evil = 0x1F649, speak_no_evil = 0x1F64A,
	["+1"] = 0x1F44D, thumbsup = 0x1F44D, ["-1"] = 0x1F44E, thumbsdown = 0x1F44E, clap = 0x1F44F,
	raised_hands = 0x1F64C, pray = 0x1F64F, wave = 0x1F44B, ok_hand = 0x1F44C, muscle = 0x1F4AA,
	handshake = 0x1F91D, v = { 0x270C, 0xFE0F }, crossed_fingers = 0x1F91E, fist = 0x270A, punch = 0x1F44A,
	point_up = { 0x261D, 0xFE0F }, point_right = 0x1F449, point_left = 0x1F448, point_down = 0x1F447,
	middle_finger = 0x1F595, facepalm = 0x1F926, shrug = 0x1F937, eyes = 0x1F440, brain = 0x1F9E0,
	nail_care = 0x1F485, lips = 0x1F444, kiss = 0x1F48B,
	heart = { 0x2764, 0xFE0F }, broken_heart = 0x1F494, blue_heart = 0x1F499, green_heart = 0x1F49A,
	yellow_heart = 0x1F49B, purple_heart = 0x1F49C, black_heart = 0x1F5A4, orange_heart = 0x1F9E1,
	white_heart = 0x1F90D, sparkling_heart = 0x1F496,
	fire = 0x1F525, ["100"] = 0x1F4AF, sparkles = 0x2728, star = 0x2B50, boom = 0x1F4A5, zap = 0x26A1,
	tada = 0x1F389, balloon = 0x1F388, gift = 0x1F381, cake = 0x1F382, trophy = 0x1F3C6, crown = 0x1F451,
	gem = 0x1F48E, rocket = 0x1F680, bulb = 0x1F4A1, bomb = 0x1F4A3, anger = 0x1F4A2, zzz = 0x1F4A4,
	sweat_drops = 0x1F4A6, dash = 0x1F4A8, moyai = 0x1F5FF, cap = 0x1F9E2,
	sun = { 0x2600, 0xFE0F }, moon = 0x1F319, cloud = { 0x2601, 0xFE0F }, rainbow = 0x1F308,
	snowflake = { 0x2744, 0xFE0F },
	dog = 0x1F436, cat = 0x1F431, frog = 0x1F438, monkey = 0x1F435, unicorn = 0x1F984, snake = 0x1F40D,
	bug = 0x1F41B, skull_dog = 0x1F415,
	pizza = 0x1F355, hamburger = 0x1F354, fries = 0x1F35F, taco = 0x1F32E, beer = 0x1F37A, coffee = 0x2615,
	popcorn = 0x1F37F, cookie = 0x1F36A, apple = 0x1F34E, banana = 0x1F34C, strawberry = 0x1F353,
	watermelon = 0x1F349, cherries = 0x1F352, peach = 0x1F351, eggplant = 0x1F346,
	video_game = 0x1F3AE, game_die = 0x1F3B2, computer = 0x1F4BB, iphone = 0x1F4F1, headphones = 0x1F3A7,
	microphone = 0x1F3A4, musical_note = 0x1F3B5, key = 0x1F511, lock = 0x1F512, bell = 0x1F514,
	mute = 0x1F507, speaker = 0x1F50A, crossed_swords = { 0x2694, 0xFE0F }, shield = { 0x1F6E1, 0xFE0F },
	moneybag = 0x1F4B0, dollar = 0x1F4B5, chart_up = 0x1F4C8,
	white_check_mark = 0x2705, check = { 0x2714, 0xFE0F }, x = 0x274C, warning = { 0x26A0, 0xFE0F },
	question = 0x2753, exclamation = 0x2757, no_entry = 0x26D4, arrow_right = { 0x27A1, 0xFE0F },
	sos = 0x1F198, cool = 0x1F192, new = 0x1F195, ok = 0x1F197,
}
local EMOJI = {}
for k, v in pairs(EMOJI_RAW) do
	EMOJI[k] = type(v) == "table" and utf8.char(table.unpack(v)) or utf8.char(v)
end

local function emojify(s)
	local out, i = {}, 1
	while true do
		local a, b, name = s:find(":([%w_%+%-]+):", i)
		if not a then break end
		local e = EMOJI[name:lower()]
		if e then
			out[#out + 1] = s:sub(i, a - 1)
			out[#out + 1] = e
			i = b + 1
		else
			-- not a known shortcode: keep text, let the closing colon start the next match
			out[#out + 1] = s:sub(i, b - 1)
			i = b
		end
	end
	out[#out + 1] = s:sub(i)
	return table.concat(out)
end

-- character-aware clip (never cuts an emoji in half)
local function clip(s, n)
	local len = utf8.len(s)
	if not len then return s:sub(1, n) end
	if len <= n then return s end
	return s:sub(1, utf8.offset(s, n + 1) - 1)
end

-- ---------- http ----------
local function api(method, path, body)
	if not req then return nil end
	local ok, res = pcall(req, {
		Url = SERVER .. path,
		Method = method,
		Headers = {
			["Content-Type"] = "application/json",
			["x-uid"] = tostring(lp.UserId),
			["x-user"] = lp.Name,
			["x-hwid"] = HWID,
		},
		Body = body and HttpService:JSONEncode(body) or nil,
	})
	if not ok or type(res) ~= "table" then return nil end
	local dok, data = pcall(HttpService.JSONDecode, HttpService, res.Body or "")
	return res.StatusCode, dok and data or nil
end

-- ---------- interface ----------
local C = {
    bg = Color3.fromRGB(24, 24, 24),
    bar = Color3.fromRGB(24, 24, 24),
    panel = Color3.fromRGB(31, 31, 31),
    input = Color3.fromRGB(36, 36, 36),
    accent = Color3.fromRGB(44, 103, 197),
    accentHover = Color3.fromRGB(58, 117, 207),
    accentSoft = Color3.fromRGB(34, 48, 70),
    btn = Color3.fromRGB(37, 37, 37),
    btnHover = Color3.fromRGB(45, 45, 45),
    divider = Color3.fromRGB(49, 49, 49),
    danger = Color3.fromRGB(213, 89, 89),
    text = Color3.fromRGB(242, 242, 242),
    mine = Color3.fromRGB(143, 185, 246),
    sys = Color3.fromRGB(191, 183, 162),
    dim = Color3.fromRGB(145, 145, 145),
    good = Color3.fromRGB(112, 199, 142),
    warn = Color3.fromRGB(229, 177, 101),
    bad = Color3.fromRGB(213, 89, 89),
}

local function new(class, props, parent)
    local object = Instance.new(class)
    for key, value in pairs(props) do object[key] = value end
    object.Parent = parent
    return object
end

local function round(object, radius)
    return new("UICorner", {CornerRadius = UDim.new(0, radius)}, object)
end

local function tween(object, duration, props)
    local motion = TweenService:Create(object,
        TweenInfo.new(duration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), props)
    motion:Play()
    return motion
end

local function esc(value)
    return (tostring(value):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
        :gsub('"', "&quot;"):gsub("'", "&apos;"))
end

local function nameColor(id)
    return Color3.fromHSV(((tonumber(id) or 0) * 47 % 360) / 360, 0.34, 0.95)
end

local function line(parent, x, y, width, height, color, z, rotation)
    return new("Frame", {
        Position = UDim2.fromOffset(x, y),
        Size = UDim2.fromOffset(width, height),
        BackgroundColor3 = color, BorderSizePixel = 0,
        Rotation = rotation or 0, ZIndex = z or 1,
    }, parent)
end

local parentGui = (gethui and gethui()) or game:GetService("CoreGui")
local gui = new("ScreenGui", {
    Name = HttpService:GenerateGUID(false), ResetOnSpawn = false,
    IgnoreGuiInset = true, DisplayOrder = 999,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, parentGui)
if syn and syn.protect_gui then pcall(syn.protect_gui, gui) end

local camera = workspace.CurrentCamera
local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
local initialWidth = math.min(WIN_W, math.max(320, viewport.X - 28))
local initialHeight = math.min(WIN_H, math.max(245, viewport.Y - 28))
local win = new("Frame", {
    Name = "ChatWindow",
    Size = UDim2.fromOffset(initialWidth, initialHeight),
    Position = UDim2.fromOffset(
        math.max(0, math.floor((viewport.X - initialWidth) / 2)),
        math.max(0, math.floor((viewport.Y - initialHeight) / 2))),
    BackgroundColor3 = C.bg, BorderSizePixel = 0,
    ClipsDescendants = true,
}, gui)
-- The shell itself is rounded; all contrasting surfaces are inset from its edges.
round(win, 14)

local titleBar = new("Frame", {
    Name = "WindowBar", Size = UDim2.new(1, 0, 0, TITLE_H),
    BackgroundTransparency = 1, BorderSizePixel = 0,
    ZIndex = 3,
}, win)
local titleDrag = new("Frame", {
    Name = "DragArea", Position = UDim2.fromOffset(8, 0),
    Size = UDim2.new(1, -98, 1, 0),
    BackgroundTransparency = 1, Active = true, ZIndex = 6,
}, titleBar)

local dot = new("Frame", {
    Name = "ConnectionDot", Position = UDim2.fromOffset(18, 18),
    Size = UDim2.fromOffset(7, 7), BackgroundColor3 = C.warn,
    BorderSizePixel = 0, ZIndex = 4,
}, titleBar)
round(dot, 4)
local status = new("TextLabel", {
    Name = "Connection", Position = UDim2.fromOffset(33, 0),
    Size = UDim2.new(1, -142, 1, 0), BackgroundTransparency = 1,
    Text = "Connecting", TextColor3 = C.dim, TextSize = 11,
    Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 4,
}, titleBar)
new("Frame", {
    Position = UDim2.fromOffset(14, TITLE_H - 1),
    Size = UDim2.new(1, -28, 0, 1), BackgroundColor3 = C.divider,
    BackgroundTransparency = 0.24, BorderSizePixel = 0, ZIndex = 3,
}, titleBar)

local function control(name, offset)
    local button = new("TextButton", {
        Name = name, AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, offset, 0.5, 0),
        Size = UDim2.fromOffset(30, 28),
        BackgroundColor3 = C.btnHover, BackgroundTransparency = 1,
        BorderSizePixel = 0, AutoButtonColor = false,
        Text = "", ZIndex = 5,
    }, titleBar)
    round(button, 8)
    bind(button.MouseEnter, function()
        tween(button, 0.15, {BackgroundTransparency = 0})
    end)
    bind(button.MouseLeave, function()
        tween(button, 0.15, {BackgroundTransparency = 1})
    end)
    return button
end

local minBtn = control("Minimize", -47)
local closeBtn = control("Close", -13)
local minIcon = line(minBtn, 10, 13, 11, 1.6, C.text, 6)
local restoreMark = line(minBtn, 15, 8, 1.6, 11, C.text, 6)
restoreMark.Visible = false
line(closeBtn, 9, 13, 13, 1.6, C.text, 6, 45)
line(closeBtn, 9, 13, 13, 1.6, C.text, 6, -45)

local body = new("Frame", {
    Name = "ChatWorkspace", Position = UDim2.fromOffset(0, TITLE_H),
    Size = UDim2.new(1, 0, 1, -TITLE_H),
    BackgroundTransparency = 1, BorderSizePixel = 0,
}, win)

-- The channel surface is a separate rounded panel, not a pasted-on sidebar.
local side = new("Frame", {
    Name = "Channels", Position = UDim2.fromOffset(10, 8),
    Size = UDim2.new(0, SIDE_W - 19, 1, -19),
    BackgroundColor3 = C.panel, BorderSizePixel = 0,
    ZIndex = 7,
}, body)
round(side, 11)
local closeSidebar = new("TextButton", {
    Name = "CloseChannels", AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -9, 0, 9), Size = UDim2.fromOffset(25, 25),
    BackgroundColor3 = C.btnHover, BackgroundTransparency = 1,
    BorderSizePixel = 0, AutoButtonColor = false, Text = "", ZIndex = 9,
}, side)
round(closeSidebar, 6)
line(closeSidebar, 8, 12, 10, 1.4, C.dim, 10, 45)
line(closeSidebar, 8, 12, 10, 1.4, C.dim, 10, -45)
new("TextLabel", {
    Name = "Section", Position = UDim2.fromOffset(14, 16),
    Size = UDim2.new(1, -28, 0, 16),
    BackgroundTransparency = 1, Text = "CHANNELS",
    Font = Enum.Font.GothamBold, TextSize = 10,
    TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 8,
}, side)

local current = "main"
local drafts, unread, chBtns, chanName, lists = {}, {}, {}, {}, {}

for index, channel in ipairs(CHANNELS) do
    chanName[channel.id] = channel.name
    unread[channel.id] = 0
    local button = new("TextButton", {
        Name = channel.id, Position = UDim2.fromOffset(8, 45 + (index - 1) * 40),
        Size = UDim2.new(1, -16, 0, 35),
        BackgroundColor3 = C.btnHover, BackgroundTransparency = 1,
        BorderSizePixel = 0, AutoButtonColor = false,
        Text = "", ZIndex = 8,
    }, side)
    round(button, 8)
    local symbol = new("TextLabel", {
        Name = "Symbol", Position = UDim2.fromOffset(11, 0),
        Size = UDim2.fromOffset(18, 35), BackgroundTransparency = 1,
        Text = "#", TextColor3 = C.dim, TextSize = 17,
        Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 9,
    }, button)
    local name = new("TextLabel", {
        Name = "Name", Position = UDim2.fromOffset(36, 0),
        Size = UDim2.new(1, -64, 1, 0), BackgroundTransparency = 1,
        Text = channel.name, Font = Enum.Font.GothamMedium, TextSize = 12,
        TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 9,
    }, button)
    local badge = new("TextLabel", {
        Name = "Unread", AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -7, 0.5, 0),
        Size = UDim2.fromOffset(20, 17),
        BackgroundColor3 = C.accent, BorderSizePixel = 0, Visible = false,
        Text = "0", Font = Enum.Font.GothamBold, TextSize = 10,
        TextColor3 = C.text, ZIndex = 9,
    }, button)
    round(badge, 8)
    chBtns[channel.id] = {btn = button, badge = badge, nameLabel = name, hashLabel = symbol}
end

local identity = new("Frame", {
    Name = "Identity", Position = UDim2.new(0, 9, 1, -55),
    Size = UDim2.new(1, -18, 0, 45), BackgroundColor3 = C.bg,
    BorderSizePixel = 0, ZIndex = 8,
}, side)
round(identity, 9)
local avatar = new("ImageLabel", {
    Name = "SelfAvatar", Position = UDim2.fromOffset(8, 8),
    Size = UDim2.fromOffset(29, 29),
    BackgroundColor3 = C.btn, BorderSizePixel = 0,
    ScaleType = Enum.ScaleType.Crop,
    Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(lp.UserId) .. "&w=150&h=150",
    ZIndex = 9,
}, identity)
round(avatar, 15)
new("TextLabel", {
    Name = "Username", Position = UDim2.fromOffset(44, 6),
    Size = UDim2.new(1, -53, 0, 18), BackgroundTransparency = 1,
    Text = lp.Name, Font = Enum.Font.GothamMedium,
    TextSize = 11, TextColor3 = C.text,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 9,
}, identity)
new("TextLabel", {
    Name = "Caption", Position = UDim2.fromOffset(44, 23),
    Size = UDim2.new(1, -53, 0, 15), BackgroundTransparency = 1,
    Text = "Your account", Font = Enum.Font.Gotham,
    TextSize = 10, TextColor3 = C.dim,
    TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 9,
}, identity)

-- Conversation heading, presence and local search.
local roomHead = new("Frame", {
    Name = "ConversationHeader", Position = UDim2.fromOffset(SIDE_W, 0),
    Size = UDim2.new(1, -SIDE_W, 0, 66),
    BackgroundTransparency = 1, BorderSizePixel = 0,
    ZIndex = 2,
}, body)
local sidebarButton = new("TextButton", {
    Name = "ToggleChannels", Position = UDim2.fromOffset(12, 18),
    Size = UDim2.fromOffset(31, 30),
    BackgroundColor3 = C.btnHover, BackgroundTransparency = 1,
    BorderSizePixel = 0, AutoButtonColor = false, Text = "", ZIndex = 3,
}, roomHead)
round(sidebarButton, 8)
for _, y in ipairs({10, 15, 20}) do
    line(sidebarButton, 9, y, 13, 1.5, C.text, 4)
end
local roomName = new("TextLabel", {
    Name = "ChannelName", Position = UDim2.fromOffset(54, 11),
    Size = UDim2.new(1, -198, 0, 23), BackgroundTransparency = 1,
    Text = "# Main Chat", Font = Enum.Font.GothamBold,
    TextSize = 15, TextColor3 = C.text,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 3,
}, roomHead)
local roomSubtitle = new("TextLabel", {
    Name = "ChannelSubtitle", Position = UDim2.fromOffset(54, 34),
    Size = UDim2.new(1, -198, 0, 18), BackgroundTransparency = 1,
    Text = "General discussion", Font = Enum.Font.Gotham,
    TextSize = 11, TextColor3 = C.dim,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 3,
}, roomHead)
local presencePill = new("Frame", {
    Name = "OnlineCount", AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -15, 0.5, 0),
    Size = UDim2.fromOffset(94, 27),
    BackgroundColor3 = C.btn, BorderSizePixel = 0,
    ZIndex = 3,
}, roomHead)
round(presencePill, 13)
local presenceDot = new("Frame", {
    Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(7, 7),
    BackgroundColor3 = C.good, BorderSizePixel = 0, ZIndex = 4,
}, presencePill)
round(presenceDot, 4)
local countLbl = new("TextLabel", {
    Name = "Count", Position = UDim2.fromOffset(23, 0),
    Size = UDim2.new(1, -28, 1, 0), BackgroundTransparency = 1,
    Text = "-- online", Font = Enum.Font.GothamMedium,
    TextSize = 11, TextColor3 = C.text,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 4,
}, presencePill)
local findButton = new("TextButton", {
    Name = "FindMessages", AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -119, 0.5, 0),
    Size = UDim2.fromOffset(30, 29), BackgroundColor3 = C.btnHover,
    BackgroundTransparency = 1, BorderSizePixel = 0,
    AutoButtonColor = false, Text = "", ZIndex = 3,
}, roomHead)
round(findButton, 8)
local searchCircle = new("Frame", {
    Position = UDim2.fromOffset(7, 7),
    Size = UDim2.fromOffset(11, 11),
    BackgroundTransparency = 1, ZIndex = 4,
}, findButton)
round(searchCircle, 6)
new("UIStroke", {Color = C.text, Thickness = 1.6}, searchCircle)
line(findButton, 19, 18, 8, 1.6, C.text, 4, 45)
new("Frame", {
    Name = "Divider", Position = UDim2.new(0, 15, 1, -1),
    Size = UDim2.new(1, -30, 0, 1),
    BackgroundColor3 = C.divider, BorderSizePixel = 0,
    ZIndex = 2,
}, roomHead)

local findPanel = new("Frame", {
    Name = "FindPanel", Position = UDim2.fromOffset(54, 12),
    Size = UDim2.new(1, -69, 0, 41),
    BackgroundColor3 = C.input, BorderSizePixel = 0,
    ZIndex = 9, Visible = false,
}, roomHead)
round(findPanel, 9)
local findInput = new("TextBox", {
    Name = "FindInput", Position = UDim2.fromOffset(12, 0),
    Size = UDim2.new(1, -122, 1, 0), BackgroundTransparency = 1,
    ClearTextOnFocus = false, Text = "", PlaceholderText = "Find messages",
    PlaceholderColor3 = C.dim, TextColor3 = C.text,
    Font = Enum.Font.Gotham, TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 10,
}, findPanel)
local findResult = new("TextLabel", {
    Name = "Matches", AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -39, 0.5, 0),
    Size = UDim2.fromOffset(72, 20), BackgroundTransparency = 1,
    Text = "", Font = Enum.Font.Gotham,
    TextSize = 10, TextColor3 = C.dim,
    TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 10,
}, findPanel)
local exitFind = new("TextButton", {
    Name = "CloseFind", AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -6, 0.5, 0),
    Size = UDim2.fromOffset(28, 28),
    BackgroundTransparency = 1, BorderSizePixel = 0,
    AutoButtonColor = false, Text = "", ZIndex = 10,
}, findPanel)
line(exitFind, 9, 13, 12, 1.5, C.dim, 11, 45)
line(exitFind, 9, 13, 12, 1.5, C.dim, 11, -45)
local searchOpen = false
local updateSearch, updateJump

-- Chat history is not clipped into cards; it uses the full conversation width.
for _, channel in ipairs(CHANNELS) do
    local list = new("ScrollingFrame", {
        Name = "Messages_" .. channel.id,
        Position = UDim2.fromOffset(SIDE_W + 4, 67),
        Size = UDim2.new(1, -SIDE_W - 8, 1, -149),
        BackgroundTransparency = 1, BorderSizePixel = 0,
        CanvasSize = UDim2.fromOffset(0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ScrollBarThickness = 3, ScrollBarImageColor3 = C.divider,
        VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
        Visible = channel.id == current, ZIndex = 2,
    }, body)
    new("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 7),
    }, list)
    new("UIPadding", {
        PaddingLeft = UDim.new(0, 13), PaddingRight = UDim.new(0, 15),
        PaddingTop = UDim.new(0, 15), PaddingBottom = UDim.new(0, 15),
    }, list)
    lists[channel.id] = list
end

local row = new("Frame", {
    Name = "Composer", Position = UDim2.new(0, SIDE_W, 1, -82),
    Size = UDim2.new(1, -SIDE_W, 0, 75),
    BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 3,
}, body)
new("Frame", {
    Position = UDim2.fromOffset(13, 1),
    Size = UDim2.new(1, -26, 0, 1),
    BackgroundColor3 = C.divider, BorderSizePixel = 0, ZIndex = 3,
}, row)
local boxBg = new("Frame", {
    Name = "InputSurface", Position = UDim2.fromOffset(14, 14),
    Size = UDim2.new(1, -85, 0, 43),
    BackgroundColor3 = C.input, BorderSizePixel = 0, ZIndex = 4,
}, row)
round(boxBg, 10)
local boxStroke = new("UIStroke", {
    Color = C.accent, Thickness = 1, Transparency = 1,
}, boxBg)
local box = new("TextBox", {
    Name = "Message", Position = UDim2.fromOffset(14, 0),
    Size = UDim2.new(1, -64, 1, 0), BackgroundTransparency = 1,
    Text = "", PlaceholderText = "Message #main", PlaceholderColor3 = C.dim,
    ClearTextOnFocus = false, Font = Enum.Font.Gotham, TextSize = 13,
    TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 5,
}, boxBg)
local counter = new("TextLabel", {
    Name = "CharacterCount", AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -11, 0.5, 0), Size = UDim2.fromOffset(42, 22),
    BackgroundTransparency = 1, Text = "",
    Font = Enum.Font.Gotham, TextSize = 10,
    TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Right,
    ZIndex = 5,
}, boxBg)
local sendBtn = new("TextButton", {
    Name = "Send", AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -14, 0, 14),
    Size = UDim2.fromOffset(43, 43),
    BackgroundColor3 = C.accent, BackgroundTransparency = 0.42,
    BorderSizePixel = 0, AutoButtonColor = false, Text = "", ZIndex = 4,
}, row)
round(sendBtn, 10)
local sendIcon = new("TextLabel", {
    Name = "Arrow", Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1, Text = "↑",
    Font = Enum.Font.GothamBold, TextSize = 23,
    TextColor3 = C.text, TextTransparency = 0.22, ZIndex = 5,
}, sendBtn)

local grip = new("TextButton", {
    Name = "ResizeHandle", AnchorPoint = Vector2.new(1, 1),
    Position = UDim2.new(1, -5, 1, -5),
    Size = UDim2.fromOffset(19, 19), BackgroundTransparency = 1,
    AutoButtonColor = false, Text = "", ZIndex = 12,
}, win)
line(grip, 4, 11, 10, 1.4, C.dim, 13, -45)
line(grip, 10, 12, 6, 1.4, C.dim, 13, -45)

local sidebarCollapsed = initialWidth < 610
local function layoutWorkspace()
    local narrow = win.AbsoluteSize.X < 610
    local offset = (sidebarCollapsed or narrow) and 0 or SIDE_W
    side.Visible = not sidebarCollapsed
    side.ZIndex = narrow and 12 or 7
    roomHead.Position = UDim2.fromOffset(offset, 0)
    roomHead.Size = UDim2.new(1, -offset, 0, 66)
    row.Position = UDim2.new(0, offset, 1, -82)
    row.Size = UDim2.new(1, -offset, 0, 75)
    for _, list in pairs(lists) do
        list.Position = UDim2.fromOffset(offset + 4, 67)
        list.Size = UDim2.new(1, -offset - 8, 1, -149)
    end
    local roomWidth = win.AbsoluteSize.X - offset
    roomSubtitle.Visible = not searchOpen and roomWidth >= 365
    roomName.Position = UDim2.fromOffset(54, roomWidth >= 365 and 11 or 22)
    roomName.Size = UDim2.new(1, roomWidth < 355 and -166 or -198, 0, 23)
    if roomWidth < 355 then
        presencePill.Visible = false
        findButton.Position = UDim2.new(1, -15, 0.5, 0)
    else
        presencePill.Visible = not searchOpen
        findButton.Position = UDim2.new(1, -119, 0.5, 0)
    end
    if updateJump then updateJump() end
end
bind(sidebarButton.Activated, function()
    sidebarCollapsed = not sidebarCollapsed
    layoutWorkspace()
end)
bind(closeSidebar.Activated, function()
    sidebarCollapsed = true
    layoutWorkspace()
end)
bind(closeSidebar.MouseEnter, function()
    tween(closeSidebar, 0.14, {BackgroundTransparency = 0})
end)
bind(closeSidebar.MouseLeave, function()
    tween(closeSidebar, 0.14, {BackgroundTransparency = 1})
end)
bind(win:GetPropertyChangedSignal("AbsoluteSize"), layoutWorkspace)
layoutWorkspace()

local jumpButton = new("TextButton", {
    Name = "JumpToLatest", AnchorPoint = Vector2.new(1, 1),
    Position = UDim2.new(1, -20, 1, -93),
    Size = UDim2.fromOffset(112, 29),
    BackgroundColor3 = C.accentSoft, BorderSizePixel = 0,
    AutoButtonColor = false, Text = "↓  Latest",
    Font = Enum.Font.GothamMedium, TextSize = 11,
    TextColor3 = C.text, ZIndex = 5, Visible = false,
}, body)
round(jumpButton, 8)
updateJump = function()
    local list = lists[current]
    if not list or not alive then return end
    local remaining = list.AbsoluteCanvasSize.Y - list.CanvasPosition.Y - list.AbsoluteWindowSize.Y
    jumpButton.Visible = not searchOpen and remaining > 70
end
bind(jumpButton.Activated, function()
    local list = lists[current]
    if list then list.CanvasPosition = Vector2.new(0, 1e7) end
    updateJump()
end)
for _, list in pairs(lists) do
    bind(list:GetPropertyChangedSignal("CanvasPosition"), updateJump)
    bind(list:GetPropertyChangedSignal("AbsoluteCanvasSize"), updateJump)
    bind(list:GetPropertyChangedSignal("AbsoluteWindowSize"), updateJump)
end

local function hover(button, normal, over)
    bind(button.MouseEnter, function()
        tween(button, 0.14, {BackgroundColor3 = over})
    end)
    bind(button.MouseLeave, function()
        tween(button, 0.14, {BackgroundColor3 = normal})
    end)
end
hover(sendBtn, C.accent, C.accentHover)
bind(box.Focused, function()
    tween(boxStroke, 0.16, {Transparency = 0})
end)
bind(box.FocusLost, function()
    tween(boxStroke, 0.16, {Transparency = 1})
end)
for _, button in ipairs({sidebarButton, findButton}) do
    bind(button.MouseEnter, function()
        tween(button, 0.16, {BackgroundTransparency = 0})
    end)
    bind(button.MouseLeave, function()
        tween(button, 0.16, {BackgroundTransparency = 1})
    end)
end

local function refreshChannels()
    for id, entry in pairs(chBtns) do
        local active = id == current
        entry.btn.BackgroundColor3 = C.btnHover
        tween(entry.btn, 0.16, {BackgroundTransparency = active and 0 or 1})
        entry.nameLabel.TextColor3 = active and C.text or C.dim
        entry.hashLabel.TextColor3 = active and C.mine or C.dim
        local count = unread[id] or 0
        entry.badge.Visible = not active and count > 0
        entry.badge.Text = count > 99 and "99+" or tostring(count)
    end
end

local function setChannel(id)
    if not lists[id] then return end
    drafts[current] = box.Text
    current = id
    box.Text = drafts[id] or ""
    unread[id] = 0
    for other, list in pairs(lists) do list.Visible = other == id end
    roomName.Text = "# " .. chanName[id]
    roomSubtitle.Text = id == "main" and "Everyone, all in one place"
        or id == "lounge" and "The place to unwind" or "Conversations beyond the usual"
    box.PlaceholderText = "Message #" .. id
    findInput.PlaceholderText = "Find in #" .. id
    if win.AbsoluteSize.X < 610 and not sidebarCollapsed then
        sidebarCollapsed = true
        layoutWorkspace()
    end
    refreshChannels()
    if updateSearch then updateSearch() end
    if updateJump then updateJump() end
    task.defer(function()
        if alive and current == id and not searchOpen and lists[id] then
            lists[id].CanvasPosition = Vector2.new(0, 1e7)
        end
    end)
end

for id, entry in pairs(chBtns) do
    bind(entry.btn.Activated, function() setChannel(id) end)
    bind(entry.btn.MouseEnter, function()
        if current ~= id then
            tween(entry.btn, 0.14, {BackgroundTransparency = 0.52})
        end
    end)
    bind(entry.btn.MouseLeave, function()
        if current ~= id then
            tween(entry.btn, 0.14, {BackgroundTransparency = 1})
        end
    end)
end

-- A single tracked gesture controls drag/resize and disconnects on cleanup.
local dragAction
local function makeDrag(handle, capture, apply)
    bind(handle.InputBegan, function(input)
        if not alive or dragAction or not win.Visible then return end
        local kind = input.UserInputType
        if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then return end
        dragAction = {
            input = input, touch = kind == Enum.UserInputType.Touch,
            origin = input.Position, state = capture(), apply = apply,
        }
    end)
end
bind(UIS.InputChanged, function(input)
    local action = dragAction
    if not alive or not action then return end
    if action.touch then
        if input ~= action.input then return end
    elseif input.UserInputType ~= Enum.UserInputType.MouseMovement then
        return
    end
    local delta = input.Position - action.origin
    action.apply(action.state, delta.X, delta.Y)
end)
bind(UIS.InputEnded, function(input)
    if dragAction and (input == dragAction.input or
        (not dragAction.touch and input.UserInputType == Enum.UserInputType.MouseButton1)) then
        dragAction = nil
    end
end)
makeDrag(titleDrag, function() return win.Position end, function(start, dx, dy)
    local cameraNow = workspace.CurrentCamera
    local screen = cameraNow and cameraNow.ViewportSize or Vector2.new(1280, 720)
    local width = win.AbsoluteSize.X
    win.Position = UDim2.fromOffset(
        math.clamp(start.X.Offset + dx, 54 - width, screen.X - 54),
        math.clamp(start.Y.Offset + dy, 0, screen.Y - TITLE_H))
end)
makeDrag(grip, function() return win.Size end, function(start, dx, dy)
    if not body.Visible then return end
    local cameraNow = workspace.CurrentCamera
    local screen = cameraNow and cameraNow.ViewportSize or Vector2.new(1280, 720)
    local maxW = math.max(320, screen.X - win.AbsolutePosition.X - 8)
    local maxH = math.max(245, screen.Y - win.AbsolutePosition.Y - 8)
    win.Size = UDim2.fromOffset(
        math.clamp(start.X.Offset + dx, math.min(MIN_W, maxW), maxW),
        math.clamp(start.Y.Offset + dy, math.min(MIN_H, maxH), maxH))
end)
local minimized, savedSize = false, win.Size
bind(minBtn.Activated, function()
    minimized = not minimized
    if minimized then
        savedSize = win.Size
        body.Visible = false
        grip.Visible = false
        win.Size = UDim2.fromOffset(win.AbsoluteSize.X, TITLE_H)
        restoreMark.Visible = true
    else
        win.Size = savedSize
        body.Visible = true
        grip.Visible = true
        restoreMark.Visible = false
        layoutWorkspace()
    end
end)

-- ---------- message presentation ----------
local seen, queues = {}, {}
local seenOrder = {}
local indexed = {}
for _, channel in ipairs(CHANNELS) do
    queues[channel.id] = {}
    indexed[channel.id] = {}
end
local function indexMessage(channelId, node, contents)
    local entries = indexed[channelId]
    entries[#entries + 1] = {node = node, text = tostring(contents):lower()}
    if #entries > 200 then table.remove(entries, 1) end
    if searchOpen and updateSearch then updateSearch() end
end
updateSearch = function()
    local query = searchOpen and findInput.Text:lower():sub(1, 80) or ""
    local hits = 0
    for id, entries in pairs(indexed) do
        for _, entry in ipairs(entries) do
            local match = query == "" or entry.text:find(query, 1, true) ~= nil
            entry.node.Visible = id ~= current or match
            if id == current and match then hits += 1 end
        end
    end
    findResult.Text = query == "" and "" or tostring(hits) .. " found"
    if updateJump then updateJump() end
end
local function toggleSearch(open)
    searchOpen = open
    findPanel.Visible = open
    findButton.Visible = not open
    roomName.Visible = not open
    roomSubtitle.Visible = not open
    presencePill.Visible = not open
    if not open then findInput.Text = "" end
    layoutWorkspace()
    updateSearch()
    if open then
        task.defer(function()
            if alive and searchOpen then findInput:CaptureFocus() end
        end)
    end
end
bind(findButton.Activated, function() toggleSearch(true) end)
bind(exitFind.Activated, function() toggleSearch(false) end)
bind(findInput:GetPropertyChangedSignal("Text"), function()
    if updateSearch then updateSearch() end
end)
local lastId, order = 0, 0
local grouped = {}

local function insertMessage(channelId, node)
    local id = lists[channelId] and channelId or "main"
    local list, queue = lists[id], queues[id]
    local atBottom = list.CanvasPosition.Y + list.AbsoluteWindowSize.Y >= list.AbsoluteCanvasSize.Y - 45
    order += 1
    node.LayoutOrder = order
    queue[#queue + 1] = node
    if #queue > 200 then table.remove(queue, 1):Destroy() end
    if atBottom and not searchOpen then
        task.delay(0.06, function()
            if alive and list.Parent and not searchOpen
                and list.CanvasPosition.Y + list.AbsoluteWindowSize.Y >= list.AbsoluteCanvasSize.Y - 100 then
                list.CanvasPosition = Vector2.new(0, 1e6)
            end
        end)
    end
end

local function addLabel(channelId, richText, color)
    local id = lists[channelId] and channelId or "main"
    grouped[id] = nil
    local frame = new("Frame", {
        Name = "Notice", Size = UDim2.new(1, -4, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, BorderSizePixel = 0,
    }, lists[id])
    new("UIPadding", {
        PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 6),
    }, frame)
    new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, RichText = true, Text = richText,
        TextWrapped = true, Font = Enum.Font.Gotham,
        TextSize = 11, TextColor3 = color,
        TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Top,
    }, frame)
    insertMessage(id, frame)
    indexMessage(id, frame, richText)
    return frame
end

local function sys(text)
    addLabel(current, esc(text), C.sys)
end

local function addMessage(message, silent)
    if type(message) ~= "table" or type(message.id) ~= "number" or seen[message.id] then
        return
    end
    seen[message.id] = true
    seenOrder[#seenOrder + 1] = message.id
    if #seenOrder > 2000 then
        seen[table.remove(seenOrder, 1)] = nil
    end
    if message.id > lastId then lastId = message.id end

    local channelId = lists[message.ch] and message.ch or "main"
    local mine = message.userId == lp.UserId
    local user = clip(type(message.user) == "string" and message.user or "Unknown", 48)
    local contents = clip(type(message.text) == "string" and message.text or "", MAX_LEN + 20)
    local timestamp = tonumber(message.ts)
    if not timestamp or timestamp ~= timestamp or timestamp <= 0 or timestamp > 9999999999999 then
        timestamp = os.time() * 1000
    end
    timestamp = math.floor(timestamp)
    local shortTime = os.date("%I:%M %p", math.floor(timestamp / 1000))
    local previous = grouped[channelId]
    local compact = previous and previous.id == message.userId
        and timestamp >= previous.ts and timestamp - previous.ts <= 180000
    grouped[channelId] = {id = message.userId, ts = timestamp}
    local mentioned = not mine and contents:lower():find("@" .. lp.Name:lower(), 1, true) ~= nil

    local node = new("Frame", {
        Name = mine and "OwnMessage" or "Message",
        Size = UDim2.new(1, -4, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, BorderSizePixel = 0,
    }, lists[channelId])

    if not mine and not compact then
        local picture = new("ImageLabel", {
            Name = "Avatar", Position = UDim2.fromOffset(2, 5),
            Size = UDim2.fromOffset(31, 31),
            BackgroundColor3 = C.btn, BorderSizePixel = 0,
            ScaleType = Enum.ScaleType.Crop,
            Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(message.userId or 0) .. "&w=150&h=150",
        }, node)
        round(picture, 16)
    end

    local bubble = new("Frame", {
        Name = mentioned and "Mention" or mine and "Outgoing" or "Incoming",
        AnchorPoint = mine and Vector2.new(1, 0) or Vector2.new(0, 0),
        Position = mine and UDim2.new(1, -6, 0, 2) or UDim2.fromOffset(42, 2),
        Size = UDim2.new(mine and 0.78 or 0.79, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = (mine or mentioned) and C.accentSoft or C.panel,
        BorderSizePixel = 0, ZIndex = 2,
    }, node)
    round(bubble, 10)
    new("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, compact and 0 or 4),
    }, bubble)
    new("UIPadding", {
        PaddingLeft = UDim.new(0, 13), PaddingRight = UDim.new(0, 13),
        PaddingTop = UDim.new(0, compact and 8 or 10),
        PaddingBottom = UDim.new(0, 9),
    }, bubble)

    if not compact then
        local name = new("TextLabel", {
            Name = "Author", LayoutOrder = 1,
            Size = UDim2.new(1, -49, 0, 18),
            BackgroundTransparency = 1, RichText = true,
            Text = "", Font = Enum.Font.GothamMedium,
            TextSize = 12, TextColor3 = C.text,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 3,
        }, bubble)
        local tone = mine and C.mine or nameColor(message.userId)
        name.Text = '<font color="#' .. tone:ToHex() .. '">' .. esc(mine and "You" or user)
            .. '</font> <font color="#' .. C.dim:ToHex() .. '" size="10">'
            .. esc(shortTime) .. '</font>'
    end

    new("TextLabel", {
        Name = "Content", LayoutOrder = 2,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, Text = contents,
        RichText = false, TextWrapped = true,
        Font = Enum.Font.Gotham, TextSize = 13,
        TextColor3 = C.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 3,
    }, bubble)

    local clipboard = type(setclipboard) == "function" and setclipboard
        or (type(toclipboard) == "function" and toclipboard)
    if clipboard then
        local copy = new("TextButton", {
            Name = "Copy", AnchorPoint = Vector2.new(1, 0),
            Position = mine and UDim2.new(1, -13, 0, 8)
                or UDim2.new(0.79, 34, 0, 8),
            Size = UDim2.fromOffset(40, 21),
            BackgroundColor3 = C.btnHover, BorderSizePixel = 0,
            AutoButtonColor = false, Text = "Copy",
            TextColor3 = C.text, Font = Enum.Font.GothamMedium,
            TextSize = 10, ZIndex = 5, Visible = UIS.TouchEnabled,
        }, node)
        round(copy, 6)
        node.MouseEnter:Connect(function()
            if alive and copy.Parent then copy.Visible = true end
        end)
        node.MouseLeave:Connect(function()
            if alive and copy.Parent and not UIS.TouchEnabled then copy.Visible = false end
        end)
        copy.Activated:Connect(function()
            local ok = pcall(clipboard, contents)
            copy.Text = ok and "Copied" or "Failed"
            task.delay(1.2, function()
                if alive and copy.Parent then copy.Text = "Copy" end
            end)
        end)
    end

    insertMessage(channelId, node)
    indexMessage(channelId, node, user .. " " .. contents)
    if not silent and not mine and channelId ~= current then
        unread[channelId] = (unread[channelId] or 0) + 1
        refreshChannels()
    end
end

-- status: connecting | online (websocket) | fallback (http polling) | offline | banned
local STATUS = {
	connecting = { "Connecting...", C.warn },
	online = { "Live · WebSocket", C.good },
	fallback = { "Live · Polling", C.warn },
	offline = { "Offline", C.bad },
	banned = { "Banned", C.bad },
}
local function setStatus(s)
	local info = STATUS[s] or STATUS.connecting
	status.Text = info[1]
	status.TextColor3 = info[2]
	tween(dot, 0.2, { BackgroundColor3 = info[2] })
end

local function setCount(n)
	if type(n) == "number" then countLbl.Text = n .. " online" end
end

-- ---------- network ----------
local ws, wsLive = nil, false

local function onBanned(msg)
	if banned then return end
	banned = true
	setStatus("banned")
	sys(msg or "you are banned")
	if ws then pcall(function() ws:Close() end) end
end

local function handle(raw)
    if not alive or banned then return end
	local ok, d = pcall(HttpService.JSONDecode, HttpService, raw)
	if not ok or type(d) ~= "table" then return end
	if d.t == "hist" then
		for _, m in ipairs(d.msgs or {}) do addMessage(m, true) end
		setCount(d.n)
	elseif d.t == "msg" then
		addMessage(d.m)
	elseif d.t == "count" then
		setCount(d.n)
	elseif d.t == "sys" then
		sys(d.text)
	elseif d.t == "err" then
		sys(d.error)
	elseif d.t == "banned" then
		onBanned(d.error)
	end
end

local function wsSend(tbl)
	if wsLive and ws then
		return pcall(function() ws:Send(HttpService:JSONEncode(tbl)) end)
	end
	return false
end

local function sendCommand(text)
	local payload = { t = "cmd", token = ADMIN_TOKEN, text = text }
	if wsSend(payload) then return end
	task.spawn(function()
		local code, data = api("POST", "/cmd", payload)
		sys((data and (data.text or data.error)) or ("command failed (" .. tostring(code) .. ")"))
	end)
end

local function send(text)
	local t = tostring(text):match("^%s*(.-)%s*$")
	if t == "" then return false end
	if banned then sys("you are banned"); return false end

	if t:sub(1, 1) == "/" then
		if ADMIN_TOKEN == "" then
			sys("commands are admin-only")
		else
			sendCommand(t)
		end
		return true
	end

	t = clip(emojify(t), MAX_LEN)
    local channel = current
	local payload = { t = "send", ch = channel, user = lp.Name, userId = lp.UserId, text = t }
	if wsSend(payload) then return true end
	task.spawn(function()
		local code, data = api("POST", "/send", payload)
        if not alive then return end
		if code == 200 and data and data.m then
			addMessage(data.m)
		else
			if code == 403 and data and data.error == "you are banned" then onBanned(data.error) end
            if not banned then
                if drafts[channel] == "" or drafts[channel] == nil then
                    drafts[channel] = t
                    if current == channel and box.Text == "" then box.Text = t end
                end
            end
			sys((data and data.error) or ("send failed (" .. tostring(code) .. ")"))
		end
	end)
    return true
end

-- websocket loop (reconnects)
if hasWS then
	task.spawn(function()
		while alive and not banned do
			local ok, sock = pcall(WebSocket.connect, WS_URL)
			if ok and sock then
				local closed = false
				sock.OnMessage:Connect(function(raw)
                    if alive and ws == sock then handle(raw) end
                end)
				sock.OnClose:Connect(function() closed = true end)
				ws, wsLive = sock, true
				setStatus("online")
				pcall(function()
					sock:Send(HttpService:JSONEncode({ t = "hello", user = lp.Name, userId = lp.UserId, hwid = HWID }))
				end)
				while alive and not closed do task.wait(1) end
				wsLive, ws = false, nil
				pcall(function() sock:Close() end)
			end
			if banned then break end
			task.wait(8)
		end
	end)

	-- keep-alive + refreshes the online count
	task.spawn(function()
		while alive do
			task.wait(20)
			if wsLive then wsSend({ t = "ping" }) end
		end
	end)
end

-- poll loop (only runs while the websocket isn't live)
task.spawn(function()
	while alive and not banned do
		if not wsLive then
			local first = lastId == 0
			local code, data = api("GET", "/poll?since=" .. lastId)
            if not alive then break end
			if wsLive then
                -- A WebSocket connected while the HTTP poll was in flight.
			elseif code == 200 and data then
				setStatus("fallback")
				for _, m in ipairs(data.msgs or {}) do addMessage(m, first) end
				setCount(data.n)
			elseif code == 403 and data and data.banned then
				onBanned(data.error)
			else
				setStatus("offline")
			end
		end
		task.wait(1.5)
	end
end)

-- ---------- input ----------
bind(box:GetPropertyChangedSignal("Text"), function()
	local txt = box.Text
	-- Discord-style: :sob: turns into the emoji as soon as you close the colon
	if box.CursorPosition == #txt + 1 then txt = emojify(txt) end
	txt = clip(txt, MAX_LEN)
	if txt ~= box.Text then
		box.Text = txt
		box.CursorPosition = #txt + 1
	end
	drafts[current] = txt
	local n = utf8.len(txt) or #txt
	counter.Text = n >= 160 and (n .. "/" .. MAX_LEN) or ""
	sendBtn.BackgroundTransparency = n > 0 and 0 or 0.45
	sendIcon.TextTransparency = n > 0 and 0 or 0.22
	counter.TextColor3 = n >= MAX_LEN and C.bad or C.dim
end)
bind(box.FocusLost, function(enter)
	if enter then
		if send(box.Text) then box.Text = "" end
		task.defer(function() if alive then box:CaptureFocus() end end)
	end
end)
bind(sendBtn.Activated, function()
    if send(box.Text) then box.Text = "" end
end)
bind(UIS.InputBegan, function(i, gp)
	if not gp and i.KeyCode == Enum.KeyCode.RightShift then
        win.Visible = not win.Visible
    elseif i.KeyCode == Enum.KeyCode.F and win.Visible
        and (UIS:IsKeyDown(Enum.KeyCode.LeftControl) or UIS:IsKeyDown(Enum.KeyCode.RightControl)) then
        toggleSearch(true)
    elseif i.KeyCode == Enum.KeyCode.Escape and searchOpen then
        toggleSearch(false)
    end
end)

local function cleanup()
	alive = false
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	if ws then pcall(function() ws:Close() end) end
	gui:Destroy()
	env.__ChatCleanup = nil
end
env.__ChatCleanup = cleanup
bind(closeBtn.Activated, cleanup)

setChannel("main")
setStatus("connecting")
if not req then sys("your executor has no request function; chat can't connect") end
sys("RightShift toggles the window")
if ADMIN_TOKEN ~= "" then sys("admin mode on. Type /help for commands") end
