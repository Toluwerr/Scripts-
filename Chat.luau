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
local WIN_W, WIN_H = 670, 450
local MIN_W, MIN_H = 540, 320
local TITLE_H = 42
local SIDE_W = 158

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

-- ---------- visual system ----------
local C = {
    bg = Color3.fromRGB(23, 23, 23),
    bar = Color3.fromRGB(27, 27, 27),
    panel = Color3.fromRGB(29, 29, 29),
    input = Color3.fromRGB(39, 39, 39),
    accent = Color3.fromRGB(44, 103, 197),
    accentHover = Color3.fromRGB(58, 119, 211),
    accentSoft = Color3.fromRGB(43, 55, 75),
    btn = Color3.fromRGB(38, 38, 38),
    btnHover = Color3.fromRGB(49, 49, 49),
    divider = Color3.fromRGB(46, 46, 46),
    danger = Color3.fromRGB(215, 78, 79),
    text = Color3.fromRGB(240, 240, 240),
    mine = Color3.fromRGB(139, 180, 240),
    sys = Color3.fromRGB(198, 175, 123),
    dim = Color3.fromRGB(145, 145, 145),
    good = Color3.fromRGB(82, 188, 126),
    warn = Color3.fromRGB(227, 174, 93),
    bad = Color3.fromRGB(215, 78, 79),
}

local function new(class, props, parent)
    local o = Instance.new(class)
    for key, value in pairs(props) do o[key] = value end
    o.Parent = parent
    return o
end

local function round(obj, radius)
    return new("UICorner", {CornerRadius = UDim.new(0, radius or 8)}, obj)
end

local function tween(obj, duration, props)
    local motion = TweenService:Create(obj, TweenInfo.new(duration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), props)
    motion:Play()
    return motion
end

local function esc(value)
    return (tostring(value):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"):gsub("'", "&apos;"))
end

local function nameColor(userId)
    return Color3.fromHSV(((tonumber(userId) or 0) * 47 % 360) / 360, 0.34, 0.95)
end

-- Shared icon sprites are used only for controls, not for the application layout.
local icons = {
    minus = {"rbxassetid://16898613613", Vector2.new(771, 196)},
    close = {"rbxassetid://16898613869", Vector2.new(869, 906)},
    send = {"rbxassetid://16898612629", Vector2.new(453, 820)},
}
local function icon(parent, kind, size, tint, layer)
    local asset = icons[kind]
    return new("ImageLabel", {
        Name = "Icon", AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(size, size),
        BackgroundTransparency = 1, Image = asset[1], ImageRectOffset = asset[2],
        ImageRectSize = Vector2.new(48, 48), ImageColor3 = tint or C.text,
        ScaleType = Enum.ScaleType.Fit, ZIndex = layer or 5,
    }, parent)
end

-- ---------- window ----------
local parentGui = (gethui and gethui()) or game:GetService("CoreGui")
local gui = new("ScreenGui", {
    Name = HttpService:GenerateGUID(false), ResetOnSpawn = false,
    IgnoreGuiInset = true, DisplayOrder = 999,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, parentGui)
if syn and syn.protect_gui then pcall(syn.protect_gui, gui) end

local cam = workspace.CurrentCamera
local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
local initialWidth = math.min(WIN_W, math.max(320, vp.X - 24))
local initialHeight = math.min(WIN_H, math.max(230, vp.Y - 24))
local win = new("Frame", {
    Name = "ChatWindow", Size = UDim2.fromOffset(initialWidth, initialHeight),
    Position = UDim2.fromOffset(math.max(0, math.floor((vp.X - initialWidth) / 2)),
        math.max(0, math.floor((vp.Y - initialHeight) / 2))),
    BackgroundColor3 = C.bg, BorderSizePixel = 0, ClipsDescendants = true,
}, gui)
round(win, 11)

local titleBar = new("Frame", {
    Name = "TitleBar", Size = UDim2.new(1, 0, 0, TITLE_H),
    BackgroundColor3 = C.bar, BorderSizePixel = 0, ZIndex = 3,
}, win)
new("Frame", {
    Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1),
    BackgroundColor3 = C.divider, BorderSizePixel = 0, ZIndex = 3,
}, titleBar)

local titleDrag = new("Frame", {
    Name = "DragRegion", Size = UDim2.new(1, -82, 1, 0),
    BackgroundTransparency = 1, Active = true, ZIndex = 6,
}, titleBar)
local dot = new("Frame", {
    Name = "ConnectionDot", Position = UDim2.fromOffset(16, math.floor((TITLE_H - 7) / 2)),
    Size = UDim2.fromOffset(7, 7), BackgroundColor3 = C.warn,
    BorderSizePixel = 0, ZIndex = 5,
}, titleBar)
round(dot, 4)
local status = new("TextLabel", {
    Name = "ConnectionStatus", Position = UDim2.fromOffset(31, 0),
    Size = UDim2.fromOffset(165, TITLE_H), BackgroundTransparency = 1,
    Text = "Connecting", TextColor3 = C.dim, TextSize = 11,
    Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5,
}, titleBar)

local function titleButton(kind, right)
    local button = new("TextButton", {
        Name = kind, AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, right, 0.5, 0), Size = UDim2.fromOffset(29, 28),
        BackgroundColor3 = C.btnHover, BackgroundTransparency = 1,
        BorderSizePixel = 0, AutoButtonColor = false, Text = "", ZIndex = 6,
    }, titleBar)
    round(button, 8)
    local glyph = icon(button, kind == "Close" and "close" or "minus", 15, C.text, 7)
    bind(button.MouseEnter, function() tween(button, 0.16, {BackgroundTransparency = 0}) end)
    bind(button.MouseLeave, function() tween(button, 0.16, {BackgroundTransparency = 1}) end)
    return button, glyph
end
local minBtn, minIcon = titleButton("Minimize", -42)
local closeBtn = titleButton("Close", -10)

local body = new("Frame", {
    Name = "Workspace", Position = UDim2.fromOffset(0, TITLE_H),
    Size = UDim2.new(1, 0, 1, -TITLE_H), BackgroundTransparency = 1,
    BorderSizePixel = 0,
}, win)

-- ---------- channel rail ----------
local side = new("Frame", {
    Name = "Channels", Size = UDim2.new(0, SIDE_W, 1, 0),
    BackgroundColor3 = C.panel, BorderSizePixel = 0,
}, body)
new("Frame", {
    Position = UDim2.new(1, -1, 0, 0), Size = UDim2.new(0, 1, 1, 0),
    BackgroundColor3 = C.divider, BorderSizePixel = 0,
}, side)
new("TextLabel", {
    Name = "Heading", Position = UDim2.fromOffset(15, 17),
    Size = UDim2.new(1, -25, 0, 18), BackgroundTransparency = 1,
    Text = "CHANNELS", Font = Enum.Font.GothamBold, TextSize = 10,
    TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left,
}, side)

local current = "main"
local drafts = {}
local unread, chBtns, chanName = {}, {}, {}
local lists = {}
local CONTENT_X = SIDE_W

for i, ch in ipairs(CHANNELS) do
    chanName[ch.id] = ch.name
    local button = new("TextButton", {
        Name = ch.id, Position = UDim2.fromOffset(10, 43 + (i - 1) * 37),
        Size = UDim2.new(1, -20, 0, 33),
        BackgroundColor3 = C.btnHover, BackgroundTransparency = 1,
        BorderSizePixel = 0, AutoButtonColor = false, Text = "",
    }, side)
    round(button, 7)
    local hashLabel = new("TextLabel", {
        Name = "Hash", Position = UDim2.fromOffset(13, 0),
        Size = UDim2.fromOffset(16, 33), BackgroundTransparency = 1,
        Text = "#", Font = Enum.Font.GothamBold, TextSize = 16,
        TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Center,
    }, button)
    local nameLabel = new("TextLabel", {
        Name = "ChannelLabel", Position = UDim2.fromOffset(34, 0),
        Size = UDim2.new(1, -62, 0, 33), BackgroundTransparency = 1,
        Text = ch.name, Font = Enum.Font.GothamMedium, TextSize = 12,
        TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, button)
    local badge = new("TextLabel", {
        Name = "Unread", AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(22, 17),
        BackgroundColor3 = C.accent, BorderSizePixel = 0,
        Text = "0", Font = Enum.Font.GothamBold, TextSize = 10,
        TextColor3 = C.text, Visible = false,
    }, button)
    round(badge, 8)
    chBtns[ch.id] = {btn = button, badge = badge, nameLabel = nameLabel, hashLabel = hashLabel}
    unread[ch.id] = 0
end

local userChip = new("Frame", {
    Name = "Identity", Position = UDim2.new(0, 10, 1, -53),
    Size = UDim2.new(1, -20, 0, 43), BackgroundColor3 = C.bg,
    BorderSizePixel = 0,
}, side)
round(userChip, 8)
local userAvatar = new("ImageLabel", {
    Name = "Avatar", Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(27, 27),
    BackgroundColor3 = C.btn, BorderSizePixel = 0, ScaleType = Enum.ScaleType.Crop,
    Image = "rbxthumb://type=AvatarHeadShot&id=" .. lp.UserId .. "&w=150&h=150",
}, userChip)
round(userAvatar, 14)
new("TextLabel", {
    Name = "Username", Position = UDim2.fromOffset(42, 7),
    Size = UDim2.new(1, -50, 0, 17), BackgroundTransparency = 1,
    Text = lp.Name, Font = Enum.Font.GothamMedium, TextSize = 11,
    TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
}, userChip)
new("TextLabel", {
    Name = "IdentityLabel", Position = UDim2.fromOffset(42, 23),
    Size = UDim2.new(1, -50, 0, 13), BackgroundTransparency = 1,
    Text = "Local player", Font = Enum.Font.Gotham, TextSize = 10,
    TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left,
}, userChip)

-- ---------- conversation header ----------
local roomHead = new("Frame", {
    Name = "RoomHeader", Position = UDim2.fromOffset(CONTENT_X, 0),
    Size = UDim2.new(1, -CONTENT_X, 0, 54),
    BackgroundColor3 = C.bg, BorderSizePixel = 0,
}, body)
new("Frame", {
    Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1),
    BackgroundColor3 = C.divider, BorderSizePixel = 0,
}, roomHead)
local roomName = new("TextLabel", {
    Name = "ChannelName", Position = UDim2.fromOffset(55, 8),
    Size = UDim2.new(1, -255, 0, 23), BackgroundTransparency = 1,
    Text = "# Main Chat", Font = Enum.Font.GothamBold, TextSize = 15,
    TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
}, roomHead)
local roomSubtitle = new("TextLabel", {
    Name = "ChannelSubtitle", Position = UDim2.fromOffset(55, 30),
    Size = UDim2.new(1, -255, 0, 15), BackgroundTransparency = 1,
    Text = "Public conversation", Font = Enum.Font.Gotham, TextSize = 11,
    TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
}, roomHead)
local presencePill = new("Frame", {
    Name = "OnlineCount", AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -17, 0.5, 0),
    Size = UDim2.fromOffset(91, 25), BackgroundColor3 = C.btn,
    BorderSizePixel = 0,
}, roomHead)
round(presencePill, 12)
local onlineDot = new("Frame", {
    Position = UDim2.fromOffset(9, 9), Size = UDim2.fromOffset(7, 7),
    BackgroundColor3 = C.good, BorderSizePixel = 0,
}, presencePill)
round(onlineDot, 4)
local countLbl = new("TextLabel", {
    Name = "Count", Position = UDim2.fromOffset(21, 0),
    Size = UDim2.new(1, -27, 1, 0), BackgroundTransparency = 1,
    Text = "-- online", Font = Enum.Font.GothamMedium, TextSize = 11,
    TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
}, presencePill)

local sidebarButton = new("TextButton", {
    Name = "ToggleChannels", Position = UDim2.fromOffset(15, 13),
    Size = UDim2.fromOffset(29, 28),
    BackgroundColor3 = C.btnHover, BackgroundTransparency = 1,
    BorderSizePixel = 0, AutoButtonColor = false, Text = "",
}, roomHead)
round(sidebarButton, 7)
for _, y in ipairs({8, 13, 18}) do
    new("Frame", {
        Position = UDim2.fromOffset(8, y), Size = UDim2.fromOffset(13, 1.4),
        BackgroundColor3 = C.text, BorderSizePixel = 0,
    }, sidebarButton)
end

local findButton = new("TextButton", {
    Name = "FindMessages", AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -116, 0.5, 0), Size = UDim2.fromOffset(46, 25),
    BackgroundColor3 = C.btn, BorderSizePixel = 0,
    AutoButtonColor = false, Text = "Find", Font = Enum.Font.GothamMedium,
    TextSize = 11, TextColor3 = C.dim,
}, roomHead)
round(findButton, 7)
local findPanel = new("Frame", {
    Name = "FindPanel", Position = UDim2.fromOffset(55, 8),
    Size = UDim2.new(1, -70, 0, 38), BackgroundColor3 = C.input,
    BorderSizePixel = 0, ZIndex = 4, Visible = false,
}, roomHead)
round(findPanel, 8)
local findInput = new("TextBox", {
    Name = "FindInput", Position = UDim2.fromOffset(11, 0),
    Size = UDim2.new(1, -103, 1, 0), BackgroundTransparency = 1,
    ClearTextOnFocus = false, Text = "", PlaceholderText = "Find in #main",
    PlaceholderColor3 = C.dim, TextColor3 = C.text,
    Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 5,
}, findPanel)
local findResult = new("TextLabel", {
    Name = "ResultCount", AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -35, 0.5, 0), Size = UDim2.fromOffset(61, 20),
    BackgroundTransparency = 1, Text = "", Font = Enum.Font.Gotham,
    TextSize = 10, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Right,
    ZIndex = 5,
}, findPanel)
local exitFind = new("TextButton", {
    Name = "CloseFind", AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -5, 0.5, 0), Size = UDim2.fromOffset(28, 28),
    BackgroundTransparency = 1, BorderSizePixel = 0, Text = "×",
    AutoButtonColor = false, TextColor3 = C.dim, Font = Enum.Font.Gotham,
    TextSize = 21, ZIndex = 5,
}, findPanel)
local searchOpen = false
local updateSearch
local updateJump

-- ---------- message area ----------
for _, ch in ipairs(CHANNELS) do
    local list = new("ScrollingFrame", {
        Name = "Messages_" .. ch.id,
        Position = UDim2.fromOffset(CONTENT_X + 2, 55),
        Size = UDim2.new(1, -CONTENT_X - 4, 1, -125),
        BackgroundTransparency = 1, BorderSizePixel = 0,
        CanvasSize = UDim2.fromOffset(0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ScrollBarThickness = 3, ScrollBarImageColor3 = C.divider,
        VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
        Visible = ch.id == current,
    }, body)
    new("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 1),
    }, list)
    new("UIPadding", {
        PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 13),
        PaddingTop = UDim.new(0, 13), PaddingBottom = UDim.new(0, 13),
    }, list)
    lists[ch.id] = list
end

-- ---------- message composer ----------
local row = new("Frame", {
    Name = "Composer", Position = UDim2.new(0, CONTENT_X, 1, -69),
    Size = UDim2.new(1, -CONTENT_X, 0, 69),
    BackgroundColor3 = C.bg, BorderSizePixel = 0,
}, body)
new("Frame", {
    Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = C.divider,
    BorderSizePixel = 0,
}, row)
local boxBg = new("Frame", {
    Name = "InputSurface", Position = UDim2.fromOffset(15, 13),
    Size = UDim2.new(1, -79, 0, 42),
    BackgroundColor3 = C.input, BorderSizePixel = 0,
}, row)
round(boxBg, 9)
local boxStroke = new("UIStroke", {
    Color = C.divider, Transparency = 1, Thickness = 1,
}, boxBg)
local box = new("TextBox", {
    Name = "Message", Position = UDim2.fromOffset(12, 0),
    Size = UDim2.new(1, -53, 1, 0), BackgroundTransparency = 1,
    Text = "", PlaceholderText = "Message #main-chat",
    PlaceholderColor3 = C.dim, ClearTextOnFocus = false,
    Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = C.text,
    TextXAlignment = Enum.TextXAlignment.Left,
}, boxBg)
local counter = new("TextLabel", {
    Name = "CharacterCount", AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -10, 0.5, 0),
    Size = UDim2.fromOffset(42, 22), BackgroundTransparency = 1,
    Text = "", Font = Enum.Font.Gotham, TextSize = 10,
    TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Right,
}, boxBg)
local sendBtn = new("TextButton", {
    Name = "Send", AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -15, 0, 15),
    Size = UDim2.fromOffset(39, 39), BackgroundColor3 = C.accent,
    BackgroundTransparency = 0.45, BorderSizePixel = 0,
    Text = "", AutoButtonColor = false,
}, row)
round(sendBtn, 9)
local sendIcon = icon(sendBtn, "send", 19, Color3.new(1, 1, 1), 4)

local grip = new("TextButton", {
    Name = "ResizeHandle", AnchorPoint = Vector2.new(1, 1),
    Position = UDim2.new(1, -2, 1, -2), Size = UDim2.fromOffset(19, 19),
    BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 9,
}, win)
for _, lineData in ipairs({{3, 12, 12}, {9, 12, 6}}) do
    new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromOffset(lineData[1] + lineData[3] / 2, lineData[2] - lineData[3] / 2),
        Size = UDim2.fromOffset(lineData[3], 1.5), Rotation = -45,
        BackgroundColor3 = C.dim, BorderSizePixel = 0, ZIndex = 10,
    }, grip)
end

local sidebarCollapsed = initialWidth < 600
local function layoutWorkspace()
    local offset = sidebarCollapsed and 0 or SIDE_W
    side.Visible = not sidebarCollapsed
    roomHead.Position = UDim2.fromOffset(offset, 0)
    roomHead.Size = UDim2.new(1, -offset, 0, 54)
    row.Position = UDim2.new(0, offset, 1, -69)
    row.Size = UDim2.new(1, -offset, 0, 69)
    for _, list in pairs(lists) do
        list.Position = UDim2.fromOffset(offset + 2, 55)
        list.Size = UDim2.new(1, -offset - 4, 1, -125)
    end
end
bind(sidebarButton.Activated, function()
    sidebarCollapsed = not sidebarCollapsed
    layoutWorkspace()
end)
bind(win:GetPropertyChangedSignal("AbsoluteSize"), layoutWorkspace)
layoutWorkspace()

local jumpButton = new("TextButton", {
    Name = "JumpToLatest", AnchorPoint = Vector2.new(1, 1),
    Position = UDim2.new(1, -22, 1, -84), Size = UDim2.fromOffset(117, 29),
    BackgroundColor3 = C.accentSoft, BorderSizePixel = 0,
    AutoButtonColor = false, Text = "Latest messages ↓",
    Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = C.text,
    ZIndex = 5, Visible = false,
}, body)
round(jumpButton, 7)
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

-- ---------- interaction styling ----------
local function hover(button, normal, over)
    bind(button.MouseEnter, function() tween(button, 0.14, {BackgroundColor3 = over}) end)
    bind(button.MouseLeave, function() tween(button, 0.14, {BackgroundColor3 = normal}) end)
end
hover(sendBtn, C.accent, C.accentHover)
hover(findButton, C.btn, C.btnHover)
hover(sidebarButton, C.btnHover, C.btn)
bind(box.Focused, function() tween(boxStroke, 0.15, {Color = C.accent, Transparency = 0}) end)
bind(box.FocusLost, function() tween(boxStroke, 0.15, {Color = C.divider, Transparency = 1}) end)

-- ---------- channel switching ----------
local function refreshChannels()
    for id, entry in pairs(chBtns) do
        local active = id == current
        entry.btn.BackgroundColor3 = C.btnHover
        tween(entry.btn, 0.14, {BackgroundTransparency = active and 0 or 1})
        local count = unread[id] or 0
        entry.badge.Visible = count > 0 and not active
        entry.badge.Text = count > 99 and "99+" or tostring(count)
        entry.nameLabel.TextColor3 = active and C.text or C.dim
        entry.hashLabel.TextColor3 = active and C.mine or C.dim
    end
end

local function setChannel(id)
    if not lists[id] then return end
    drafts[current] = box.Text
    current = id
    box.Text = drafts[id] or ""
    unread[id] = 0
    for otherId, list in pairs(lists) do list.Visible = otherId == id end
    roomName.Text = "# " .. chanName[id]
    roomSubtitle.Text = id == "main" and "General discussion" or id == "lounge" and "Casual conversation" or "Everything else"
    box.PlaceholderText = "Message #" .. (id == "offtopic" and "off-topic" or id)
    findInput.PlaceholderText = "Find in #" .. id
    refreshChannels()
    if updateSearch then updateSearch() end
    if updateJump then updateJump() end
    task.defer(function()
        if alive and current == id and not searchOpen and lists[id] then
            lists[id].CanvasPosition = Vector2.new(0, 1e6)
        end
    end)
end

for id, entry in pairs(chBtns) do
    bind(entry.btn.Activated, function() setChannel(id) end)
    bind(entry.btn.MouseEnter, function()
        if current ~= id then tween(entry.btn, 0.14, {BackgroundTransparency = 0.5}) end
    end)
    bind(entry.btn.MouseLeave, function()
        if current ~= id then tween(entry.btn, 0.14, {BackgroundTransparency = 1}) end
    end)
end

-- ---------- drag / resize ----------
-- A single tracked gesture avoids accumulating temporary input connections.
local dragAction
local function makeDrag(handle, getStart, apply)
    bind(handle.InputBegan, function(input)
        if not alive or dragAction or not win.Visible then return end
        local kind = input.UserInputType
        if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then return end
        dragAction = {
            input = input, touch = kind == Enum.UserInputType.Touch,
            origin = input.Position, state = getStart(), apply = apply,
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
    if dragAction and (input == dragAction.input or (not dragAction.touch
        and input.UserInputType == Enum.UserInputType.MouseButton1)) then
        dragAction = nil
    end
end)

makeDrag(titleDrag, function() return win.Position end, function(start, dx, dy)
    local v = (workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize) or Vector2.new(1280, 720)
    local width = win.AbsoluteSize.X
    win.Position = UDim2.new(start.X.Scale, math.clamp(start.X.Offset + dx, 60 - width, v.X - 60),
        start.Y.Scale, math.clamp(start.Y.Offset + dy, 0, v.Y - TITLE_H))
end)
makeDrag(grip, function() return win.Size end, function(start, dx, dy)
    if not body.Visible then return end
    local v = (workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize) or Vector2.new(1280, 720)
    local maxWidth = math.max(320, v.X - win.AbsolutePosition.X - 8)
    local maxHeight = math.max(230, v.Y - win.AbsolutePosition.Y - 8)
    win.Size = UDim2.fromOffset(math.clamp(start.X.Offset + dx, math.min(MIN_W, maxWidth), maxWidth),
        math.clamp(start.Y.Offset + dy, math.min(MIN_H, maxHeight), maxHeight))
end)

local minimized, savedSize = false, win.Size
bind(minBtn.Activated, function()
    minimized = not minimized
    if minimized then
        savedSize = win.Size
        body.Visible = false
        grip.Visible = false
        win.Size = UDim2.fromOffset(win.AbsoluteSize.X, TITLE_H)
        minIcon.ImageTransparency = 0.35
    else
        win.Size = savedSize
        body.Visible = true
        grip.Visible = true
        minIcon.ImageTransparency = 0
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
    if type(message) ~= "table" or type(message.id) ~= "number" or seen[message.id] then return end
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
    if not timestamp or timestamp ~= timestamp or timestamp < 0 or timestamp > 9999999999999 then
        timestamp = os.time() * 1000
    end
    timestamp = math.floor(timestamp)
    local shortTime = os.date("%I:%M %p", math.floor(timestamp / 1000))
    local previous = grouped[channelId]
    local compact = previous and previous.id == message.userId
        and timestamp >= previous.ts and timestamp - previous.ts <= 180000
    grouped[channelId] = {id = message.userId, ts = timestamp}
    local mentioned = contents:lower():find("@" .. lp.Name:lower(), 1, true) ~= nil

    local node = new("Frame", {
        Name = mine and "OwnMessage" or "Message",
        Size = UDim2.new(1, -4, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = C.accentSoft, BackgroundTransparency = mentioned and 0.72 or 1,
        BorderSizePixel = 0, Active = true,
    }, lists[channelId])
    if mentioned then round(node, 7) end
    new("UIPadding", {
        PaddingTop = UDim.new(0, compact and 1 or 7),
        PaddingBottom = UDim.new(0, 3),
    }, node)

    if not compact then
        local avatar = new("ImageLabel", {
            Name = "Avatar", Size = UDim2.fromOffset(30, 30),
            Position = UDim2.fromOffset(0, 5),
            BackgroundColor3 = C.btn, BorderSizePixel = 0,
            ScaleType = Enum.ScaleType.Crop,
            Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(message.userId or 0) .. "&w=150&h=150",
        }, node)
        round(avatar, 15)
    end
    local textColumn = new("Frame", {
        Name = "TextColumn", Position = UDim2.fromOffset(40, 0),
        Size = UDim2.new(1, -40, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
    }, node)
    new("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2),
    }, textColumn)
    if not compact then
        local name = new("TextLabel", {
            Name = "Author", LayoutOrder = 1,
            Size = UDim2.new(1, 0, 0, 17), BackgroundTransparency = 1,
            Text = "", RichText = true, Font = Enum.Font.GothamMedium,
            TextSize = 12, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
        }, textColumn)
        local tone = mine and C.mine or nameColor(message.userId)
        name.Text = '<font color="#' .. tone:ToHex() .. '">' .. esc(user)
            .. '</font>  <font color="#' .. C.dim:ToHex() .. '" size="10">' .. esc(shortTime) .. '</font>'
    end
    new("TextLabel", {
        Name = "Content", LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, Text = contents,
        RichText = false, TextWrapped = true,
        Font = Enum.Font.Gotham, TextSize = 13,
        TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
    }, textColumn)
    local copyText = type(setclipboard) == "function" and setclipboard
        or (type(toclipboard) == "function" and toclipboard)
    if copyText then
        local copyButton = new("TextButton", {
            Name = "CopyMessage", AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -5, 0, compact and 0 or 6),
            Size = UDim2.fromOffset(43, 20), BackgroundColor3 = C.btnHover,
            BorderSizePixel = 0, AutoButtonColor = false,
            Text = "Copy", TextColor3 = C.text, Font = Enum.Font.GothamMedium,
            TextSize = 10, ZIndex = 4, Visible = UIS.TouchEnabled,
        }, node)
        round(copyButton, 5)
        node.MouseEnter:Connect(function()
            if alive and copyButton.Parent then copyButton.Visible = true end
        end)
        node.MouseLeave:Connect(function()
            if alive and copyButton.Parent and not UIS.TouchEnabled then copyButton.Visible = false end
        end)
        copyButton.Activated:Connect(function()
            local ok = pcall(copyText, contents)
            copyButton.Text = ok and "Copied" or "Failed"
            task.delay(1.2, function()
                if alive and copyButton.Parent then copyButton.Text = "Copy" end
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
	sendIcon.ImageTransparency = n > 0 and 0 or 0.25
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
