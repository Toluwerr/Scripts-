
local SERVER = "https://nonfq-chat.doorplayz123.workers.dev"

local env = (getgenv and getgenv()) or _G
if env.__ChatCleanup then pcall(env.__ChatCleanup) end


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


local CHANNELS = {
	{ id = "main", name = "Main Chat" },
	{ id = "lounge", name = "Lounge" },
	{ id = "offtopic", name = "Off-Topic" },
}

local WS_URL = (SERVER:gsub("^http", "ws")) .. "/ws"
local MAX_LEN = 200
local WIN_W, WIN_H = 760, 480
local MIN_W, MIN_H = 570, 365
local TITLE_H = 46
local SIDE_W = 172

local req = request or http_request or (syn and syn.request) or (http and http.request) or (fluxus and fluxus.request)
local hasWS = (WebSocket and WebSocket.connect) and true or false


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

			out[#out + 1] = s:sub(i, b - 1)
			i = b
		end
	end
	out[#out + 1] = s:sub(i)
	return table.concat(out)
end


local function clip(s, n)
	local len = utf8.len(s)
	if not len then return s:sub(1, n) end
	if len <= n then return s end
	return s:sub(1, utf8.offset(s, n + 1) - 1)
end


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


local C = {
    bg = Color3.fromRGB(24, 24, 24),
    bar = Color3.fromRGB(24, 24, 24),
    panel = Color3.fromRGB(36, 36, 36),
    input = Color3.fromRGB(36, 36, 36),
    accent = Color3.fromRGB(44, 103, 197),
    accentHover = Color3.fromRGB(53, 111, 204),
    accentSoft = Color3.fromRGB(35, 45, 62),
    btn = Color3.fromRGB(36, 36, 36),
    btnHover = Color3.fromRGB(46, 46, 46),
    divider = Color3.fromRGB(56, 56, 56),
    danger = Color3.fromRGB(215, 89, 89),
    text = Color3.fromRGB(255, 255, 255),
    mine = Color3.fromRGB(139, 181, 239),
    sys = Color3.fromRGB(192, 188, 174),
    dim = Color3.fromRGB(155, 155, 155),
    good = Color3.fromRGB(218, 218, 218),
    warn = Color3.fromRGB(180, 180, 180),
    bad = Color3.fromRGB(220, 130, 130),
}
local UiFont = Font.fromId(12187365364, Enum.FontWeight.SemiBold)
local BodyFont = Font.fromId(12187365364, Enum.FontWeight.Regular)

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
    return (tostring(value):gsub("&", "&amp;"):gsub("<", "&lt;")
        :gsub(">", "&gt;"):gsub('"', "&quot;"):gsub("'", "&apos;"))
end
local function nameColor(id)
    return Color3.fromHSV(((tonumber(id) or 0) * 47 % 360) / 360, 0.34, 0.94)
end


local Lucide48 = table.freeze({
    ["arrow-left"] = {Image = "rbxassetid://16898612629", Offset = Vector2.new(98, 918)},
    ["arrow-right"] = {Image = "rbxassetid://16898612629", Offset = Vector2.new(453, 820)},
    ["search"] = {Image = "rbxassetid://16898613699", Offset = Vector2.new(918, 857)},
    ["x"] = {Image = "rbxassetid://16898613869", Offset = Vector2.new(869, 906)},
    ["copy"] = {Image = "rbxassetid://16898613044", Offset = Vector2.new(918, 612)},
    ["check"] = {Image = "rbxassetid://16898612819", Offset = Vector2.new(710, 869)},
    ["minus"] = {Image = "rbxassetid://16898613613", Offset = Vector2.new(771, 196)},
    ["square"] = {Image = "rbxassetid://16898613777", Offset = Vector2.new(869, 710)},
    ["chevron-down"] = {Image = "rbxassetid://16898612819", Offset = Vector2.new(196, 918)},
    ["code"] = {Image = "rbxassetid://16898613044", Offset = Vector2.new(355, 869)},
    ["link"] = {Image = "rbxassetid://16898613509", Offset = Vector2.new(918, 453)},
    ["reply"] = {Image = "rbxassetid://16898613699", Offset = Vector2.new(612, 918)},
    ["maximize"] = {Image = "rbxassetid://16898613613", Offset = Vector2.new(771, 563)},
    ["minimize"] = {Image = "rbxassetid://16898613613", Offset = Vector2.new(918, 49)},
})
local function lucideIcon(parent, name, size, color, zIndex)
    local data = Lucide48[name]
    assert(data, "Unknown Lucide icon: " .. tostring(name))
    return new("ImageLabel", {
        Name = "Icon", AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1,
        BorderSizePixel = 0, Image = data.Image,
        ImageRectOffset = data.Offset, ImageRectSize = Vector2.new(48, 48),
        ImageColor3 = color or C.text, ScaleType = Enum.ScaleType.Fit,
        ZIndex = zIndex or parent.ZIndex + 1,
    }, parent)
end

local function hover(button, amount)
    tween(button, 0.17, {BackgroundTransparency = amount})
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
local initialWidth = math.min(WIN_W, math.max(340, viewport.X - 28))
local initialHeight = math.min(WIN_H, math.max(260, viewport.Y - 28))
local win = new("Frame", {
    Name = "ChatWindow", Active = true,
    Size = UDim2.fromOffset(initialWidth, initialHeight),
    Position = UDim2.fromOffset(
        math.max(0, math.floor((viewport.X - initialWidth) / 2)),
        math.max(0, math.floor((viewport.Y - initialHeight) / 2))),
    BackgroundColor3 = C.bg, BorderSizePixel = 0,
    ClipsDescendants = true,
}, gui)
round(win, 8)

local titleBar = new("Frame", {
    Name = "Header", Size = UDim2.new(1, 0, 0, TITLE_H),
    BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 3,
}, win)
local titleDrag = new("Frame", {
    Name = "DragRegion", Position = UDim2.fromOffset(0, 0),
    Size = UDim2.new(1, -116, 1, 0),
    BackgroundTransparency = 1, Active = true, ZIndex = 3,
}, titleBar)
new("Frame", {
    Name = "Divider", Position = UDim2.new(0, 0, 1, -1),
    Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = C.divider,
    BackgroundTransparency = 0.35, BorderSizePixel = 0, ZIndex = 4,
}, titleBar)


local status = new("TextLabel", {
    Name = "ConnectionStatus", Position = UDim2.fromOffset(15, 0),
    Size = UDim2.new(1, -152, 1, 0),
    BackgroundTransparency = 1, Text = "Connecting",
    FontFace = UiFont, TextSize = 12, TextColor3 = C.dim,
    TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4,
}, titleBar)

local controls = new("Frame", {
    Name = "Controls", AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -9, 0.5, 0),
    Size = UDim2.fromOffset(93, 30),
    BackgroundTransparency = 1, ZIndex = 5,
}, titleBar)
new("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    HorizontalAlignment = Enum.HorizontalAlignment.Right,
    VerticalAlignment = Enum.VerticalAlignment.Center,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 3),
}, controls)
local function windowControl(name, order, glyph)
    local button = new("TextButton", {
        Name = name, LayoutOrder = order,
        Size = UDim2.fromOffset(29, 28),
        BackgroundColor3 = C.panel, BackgroundTransparency = 1,
        BorderSizePixel = 0, AutoButtonColor = false, Text = "",
        ZIndex = 6,
    }, controls)
    round(button, 14)
    local image = lucideIcon(button, glyph, 18, C.text, 7)
    bind(button.MouseEnter, function() hover(button, 0) end)
    bind(button.MouseLeave, function() hover(button, 1) end)
    bind(button.MouseButton1Down, function() hover(button, 0.24) end)
    bind(button.MouseButton1Up, function() hover(button, 0) end)
    return button, image
end
local minBtn, minIcon = windowControl("Minimize", 1, "minus")
local maximizeBtn, maximizeIcon = windowControl("Maximize", 2, "maximize")
local closeBtn = windowControl("Close", 3, "x")

local body = new("Frame", {
    Name = "Content", Position = UDim2.fromOffset(0, TITLE_H),
    Size = UDim2.new(1, 0, 1, -TITLE_H),
    BackgroundTransparency = 1, BorderSizePixel = 0,
    ClipsDescendants = true,
}, win)


local side = new("Frame", {
    Name = "Channels", Position = UDim2.fromOffset(0, 0),
    Size = UDim2.new(0, SIDE_W, 1, 0),
    BackgroundColor3 = C.bg, BorderSizePixel = 0,
    ZIndex = 6,
}, body)
new("Frame", {
    Name = "Divider", Position = UDim2.new(1, -1, 0, 0),
    Size = UDim2.new(0, 1, 1, 0),
    BackgroundColor3 = C.divider, BackgroundTransparency = 0.45,
    BorderSizePixel = 0, ZIndex = 7,
}, side)
new("TextLabel", {
    Name = "Heading", Position = UDim2.fromOffset(14, 16),
    Size = UDim2.new(1, -28, 0, 18),
    BackgroundTransparency = 1, Text = "Channels",
    FontFace = UiFont, TextSize = 13, TextColor3 = C.text,
    TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7,
}, side)
local current = "main"
local drafts, unread, chBtns, chanName, lists = {}, {}, {}, {}, {}
local mentionsUnread = {}
for index, channel in ipairs(CHANNELS) do
    chanName[channel.id] = channel.name
    unread[channel.id] = 0
    local button = new("TextButton", {
        Name = channel.id, Position = UDim2.fromOffset(9, 49 + (index - 1) * 38),
        Size = UDim2.new(1, -18, 0, 34),
        BackgroundColor3 = C.panel, BackgroundTransparency = 1,
        BorderSizePixel = 0, AutoButtonColor = false, Text = "", ZIndex = 7,
    }, side)
    round(button, 8)
    local hash = new("TextLabel", {
        Name = "Hash", Position = UDim2.fromOffset(11, 0),
        Size = UDim2.fromOffset(17, 34), BackgroundTransparency = 1,
        Text = "#", FontFace = UiFont, TextSize = 16,
        TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 8,
    }, button)
    local name = new("TextLabel", {
        Name = "ChannelName", Position = UDim2.fromOffset(35, 0),
        Size = UDim2.new(1, -67, 1, 0), BackgroundTransparency = 1,
        Text = channel.name, FontFace = UiFont, TextSize = 12,
        TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 8,
    }, button)
    local badge = new("TextLabel", {
        Name = "Unread", AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -7, 0.5, 0),
        Size = UDim2.fromOffset(22, 17),
        BackgroundColor3 = C.accent, BorderSizePixel = 0,
        Text = "0", Visible = false,
        FontFace = UiFont, TextSize = 10,
        TextColor3 = C.text, ZIndex = 8,
    }, button)
    round(badge, 8)
    chBtns[channel.id] = {btn = button, badge = badge, nameLabel = name, hashLabel = hash}
end

local identity = new("Frame", {
    Name = "Identity", Position = UDim2.new(0, 9, 1, -56),
    Size = UDim2.new(1, -18, 0, 45),
    BackgroundColor3 = C.panel, BorderSizePixel = 0, ZIndex = 7,
}, side)
round(identity, 8)
local avatar = new("ImageLabel", {
    Name = "Avatar", Position = UDim2.fromOffset(8, 7),
    Size = UDim2.fromOffset(30, 30),
    BackgroundColor3 = C.btn, BorderSizePixel = 0,
    ScaleType = Enum.ScaleType.Crop,
    Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(lp.UserId) .. "&w=150&h=150",
    ZIndex = 8,
}, identity)
round(avatar, 7)
new("TextLabel", {
    Name = "Username", Position = UDim2.fromOffset(46, 0),
    Size = UDim2.new(1, -54, 1, 0),
    BackgroundTransparency = 1, Text = lp.Name,
    FontFace = UiFont, TextSize = 12, TextColor3 = C.text,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 8,
}, identity)


local roomHead = new("Frame", {
    Name = "ConversationHeader", Position = UDim2.fromOffset(SIDE_W, 0),
    Size = UDim2.new(1, -SIDE_W, 0, 53),
    BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 2,
}, body)
local sidebarButton = new("TextButton", {
    Name = "ExpandChannels", Position = UDim2.fromOffset(13, 12),
    Size = UDim2.fromOffset(29, 28),
    BackgroundColor3 = C.panel, BackgroundTransparency = 1,
    BorderSizePixel = 0, AutoButtonColor = false, Text = "", ZIndex = 3,
}, roomHead)
round(sidebarButton, 14)
local sidebarIcon = lucideIcon(sidebarButton, "arrow-left", 16, C.text, 4)
bind(sidebarButton.MouseEnter, function() hover(sidebarButton, 0) end)
bind(sidebarButton.MouseLeave, function() hover(sidebarButton, 1) end)

local roomName = new("TextLabel", {
    Name = "ChannelTitle", Position = UDim2.fromOffset(51, 0),
    Size = UDim2.new(1, -215, 1, 0),
    BackgroundTransparency = 1, Text = "Main Chat",
    FontFace = UiFont, TextSize = 15, TextColor3 = C.text,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 3,
}, roomHead)
local roomSubtitle = new("TextLabel", {
    Name = "ChannelSubtitle", Visible = false,
    BackgroundTransparency = 1, Text = "",
    Size = UDim2.fromOffset(0, 0), ZIndex = 3,
}, roomHead)

local presencePill = new("Frame", {
    Name = "Presence", AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -51, 0.5, 0),
    Size = UDim2.fromOffset(82, 25),
    BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 3,
}, roomHead)
local countLbl = new("TextLabel", {
    Name = "Count", Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1, Text = "-- online",
    FontFace = BodyFont, TextSize = 11, TextColor3 = C.dim,
    TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 4,
}, presencePill)
local findButton = new("TextButton", {
    Name = "FindMessages", AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -11, 0.5, 0),
    Size = UDim2.fromOffset(29, 28),
    BackgroundColor3 = C.panel, BackgroundTransparency = 1,
    BorderSizePixel = 0, AutoButtonColor = false, Text = "", ZIndex = 3,
}, roomHead)
round(findButton, 14)
lucideIcon(findButton, "search", 15, C.text, 4)
bind(findButton.MouseEnter, function() hover(findButton, 0) end)
bind(findButton.MouseLeave, function() hover(findButton, 1) end)
new("Frame", {
    Name = "Divider", Position = UDim2.new(0, 0, 1, -1),
    Size = UDim2.new(1, 0, 0, 1),
    BackgroundColor3 = C.divider, BackgroundTransparency = 0.5,
    BorderSizePixel = 0, ZIndex = 2,
}, roomHead)

local findPanel = new("Frame", {
    Name = "FindPanel", Position = UDim2.fromOffset(49, 7),
    Size = UDim2.new(1, -61, 0, 37),
    BackgroundColor3 = C.panel, BorderSizePixel = 0,
    ZIndex = 9, Visible = false,
}, roomHead)
round(findPanel, 8)
local findInput = new("TextBox", {
    Name = "FindInput", Position = UDim2.fromOffset(11, 0),
    Size = UDim2.new(1, -107, 1, 0),
    BackgroundTransparency = 1, ClearTextOnFocus = false,
    Text = "", PlaceholderText = "Search messages",
    PlaceholderColor3 = C.dim, FontFace = BodyFont,
    TextSize = 12, TextColor3 = C.text,
    TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 10,
}, findPanel)
local findResult = new("TextLabel", {
    Name = "ResultCount", AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -35, 0.5, 0),
    Size = UDim2.fromOffset(52, 20),
    BackgroundTransparency = 1, Text = "",
    FontFace = BodyFont, TextSize = 10,
    TextColor3 = C.dim,
    TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 10,
}, findPanel)
local exitFind = new("TextButton", {
    Name = "CloseFind", AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -5, 0.5, 0),
    Size = UDim2.fromOffset(27, 27),
    BackgroundColor3 = C.panel, BackgroundTransparency = 1,
    BorderSizePixel = 0, AutoButtonColor = false,
    Text = "", ZIndex = 10,
}, findPanel)
round(exitFind, 13)
lucideIcon(exitFind, "x", 14, C.text, 11)
local searchOpen = false
local updateSearch, updateJump

for _, channel in ipairs(CHANNELS) do
    local list = new("ScrollingFrame", {
        Name = "Messages_" .. channel.id,
        Position = UDim2.fromOffset(SIDE_W + 1, 53),
        Size = UDim2.new(1, -SIDE_W - 1, 1, -116),
        BackgroundTransparency = 1, BorderSizePixel = 0,
        CanvasSize = UDim2.fromOffset(0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ScrollBarThickness = 3, ScrollBarImageColor3 = C.divider,
        VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
        Visible = channel.id == current, ZIndex = 2,
    }, body)
    new("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 5),
    }, list)
    new("UIPadding", {
        PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 12),
        PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12),
    }, list)
    lists[channel.id] = list
end

local row = new("Frame", {
    Name = "Composer", Position = UDim2.new(0, SIDE_W, 1, -62),
    Size = UDim2.new(1, -SIDE_W, 0, 61),
    BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 3,
}, body)
new("Frame", {
    Name = "Divider", Size = UDim2.new(1, 0, 0, 1),
    BackgroundColor3 = C.divider, BackgroundTransparency = 0.5,
    BorderSizePixel = 0, ZIndex = 3,
}, row)
local boxBg = new("Frame", {
    Name = "InputSurface", Position = UDim2.fromOffset(14, 10),
    Size = UDim2.new(1, -73, 0, 40),
    BackgroundColor3 = C.panel, BorderSizePixel = 0, ZIndex = 4,
}, row)
round(boxBg, 8)
local boxStroke = new("UIStroke", {
    Color = C.accent, Thickness = 1, Transparency = 1,
    ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
}, boxBg)
local box = new("TextBox", {
    Name = "Message", Position = UDim2.fromOffset(12, 0),
    Size = UDim2.new(1, -66, 1, 0),
    BackgroundTransparency = 1,
    Text = "", PlaceholderText = "Message #main",
    PlaceholderColor3 = C.dim, ClearTextOnFocus = false,
    FontFace = BodyFont, TextSize = 13, TextColor3 = C.text,
    TextWrapped = true, MultiLine = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 5,
}, boxBg)
local counter = new("TextLabel", {
    Name = "CharacterCount", AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -9, 0.5, 0),
    Size = UDim2.fromOffset(44, 22),
    BackgroundTransparency = 1, Text = "",
    FontFace = BodyFont, TextSize = 10,
    TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 5,
}, boxBg)
local sendBtn = new("TextButton", {
    Name = "Send", AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -12, 0, 10),
    Size = UDim2.fromOffset(40, 40),
    BackgroundColor3 = C.accent, BackgroundTransparency = 0.5,
    BorderSizePixel = 0, AutoButtonColor = false, Text = "", ZIndex = 4,
}, row)
round(sendBtn, 8)
local sendIcon = lucideIcon(sendBtn, "arrow-right", 18, C.text, 5)

local pendingReplies = {}
local composerHeight = 61
local refreshInput
local replyBanner = new("Frame", {
    Name = "ReplyPreview", Position = UDim2.fromOffset(14, -33),
    Size = UDim2.new(1, -26, 0, 30),
    BackgroundColor3 = C.panel, BorderSizePixel = 0, Visible = false, ZIndex = 10,
}, row)
round(replyBanner, 8)
local replyLabel = new("TextLabel", {
    Name = "ReplyText", Position = UDim2.fromOffset(10, 0),
    Size = UDim2.new(1, -44, 1, 0),
    BackgroundTransparency = 1, Text = "", TextTruncate = Enum.TextTruncate.AtEnd,
    FontFace = BodyFont, TextColor3 = C.text, TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 11,
}, replyBanner)
local replyCancel = new("TextButton", {
    Name = "CancelReply", AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -4, 0.5, 0),
    Size = UDim2.fromOffset(25, 25), BackgroundTransparency = 1,
    BorderSizePixel = 0, AutoButtonColor = false, Text = "", ZIndex = 11,
}, replyBanner)
lucideIcon(replyCancel, "x", 14, C.dim, 12)
local function refreshReply()
    local selected = pendingReplies[current]
    replyBanner.Visible = selected ~= nil
    replyLabel.Text = selected and ("Replying to " .. selected.user .. "  ·  " .. selected.text) or ""
    if refreshInput then refreshInput() end
end
bind(replyCancel.Activated, function()
    pendingReplies[current] = nil
    refreshReply()
end)

local function codeEncode(value)
    value = value:gsub("\r\n", "\n"):gsub("\r", "\n")
    return (value:gsub("\\", "\\\\"):gsub("\n", "\\n"))
end
local function codeDecode(value)
    return (value:gsub("\\(.)", function(char)
        if char == "n" then return "\n" end
        if char == "\\" then return "\\" end
        return "\\" .. char
    end))
end
local function parseMessage(raw)
    local meta = {body = raw}
    local id, author, excerpt, rest = raw:match("^~r:(%d+):([%w_]+):([^|]*)|(.+)$")
    if not id then
        id, author, rest = raw:match("^~r:(%d+):([%w_]+)|(.+)$")
    end
    if id and tonumber(id) then
        meta.replyId = tonumber(id)
        meta.replyAuthor = author
        meta.replyExcerpt = excerpt
        meta.body = rest
    end
    local language, encoded = meta.body:match("^~c:([%w_%-]+):(.+)$")
    if language then
        meta.code = codeDecode(encoded)
        meta.language = language
    else
        local fence = string.rep(string.char(96), 3)
        local lang, content = meta.body:match("^" .. fence .. "([%w%-]*)\n(.-)\n?" .. fence .. "$")
        if content then
            meta.code, meta.language = content, lang ~= "" and lang or "luau"
        end
    end
    if not meta.replyId then
        local older, rest = meta.body:match("^> ([^\n]+)\n(.*)$")
        if older then
            meta.legacyReply = older
            meta.body = rest
        end
    end
    return meta
end
local function prepareMessage(raw, reply)
    local trimmed = tostring(raw):gsub("\r\n", "\n"):match("^%s*(.-)%s*$")
    local fence = string.rep(string.char(96), 3)
    local language, code = trimmed:match("^" .. fence .. "([%w%-]*)\n(.-)\n?" .. fence .. "$")
    if not code and trimmed:find("\n", 1, true)
        and (trimmed:match("^local%s") or trimmed:match("^function%s")
            or trimmed:match("^print%(") or trimmed:match("^if%s")
            or trimmed:match("^for%s") or trimmed:match("^while%s")
            or trimmed:match("^return%s")) then
        language, code = "luau", trimmed
    end
    local content
    if code then
        content = "~c:" .. (language ~= "" and language or "luau") .. ":" .. codeEncode(code)
    else
        content = emojify(trimmed)
    end
    if reply then
        local excerpt = reply.text:gsub("[|\r\n]+", " "):sub(1, 36)
        content = "~r:" .. tostring(reply.id) .. ":" .. reply.user
            .. ":" .. excerpt .. "|" .. content
    end
    return content
end

local grip = new("TextButton", {
    Name = "ResizeHandle", AnchorPoint = Vector2.new(1, 1),
    Position = UDim2.new(1, -3, 1, -3),
    Size = UDim2.fromOffset(18, 18),
    BackgroundTransparency = 1, BorderSizePixel = 0,
    AutoButtonColor = false, Text = "", ZIndex = 12,
}, win)
local function resizeLine(ax, ay, bx, by)
    local dx, dy = bx - ax, by - ay
    new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromOffset((ax + bx) / 2, (ay + by) / 2),
        Size = UDim2.fromOffset(math.sqrt(dx * dx + dy * dy), 1.2),
        Rotation = math.deg(math.atan2(dy, dx)),
        BackgroundColor3 = C.dim, BorderSizePixel = 0, ZIndex = 13,
    }, grip)
end
resizeLine(9, 15, 15, 9)
resizeLine(13, 15, 15, 13)

local sidebarCollapsed = initialWidth < 600
local function layoutWorkspace()
    local narrow = win.AbsoluteSize.X < 580
    local offset = sidebarCollapsed and 0 or SIDE_W
    if narrow then offset = 0 end
    side.Visible = not sidebarCollapsed
    side.ZIndex = narrow and 9 or 6
    sidebarIcon.ImageRectOffset = Lucide48[sidebarCollapsed and "arrow-right" or "arrow-left"].Offset
    roomHead.Position = UDim2.fromOffset(offset, 0)
    roomHead.Size = UDim2.new(1, -offset, 0, 53)
    row.Position = UDim2.new(0, offset, 1, -composerHeight - 1)
    row.Size = UDim2.new(1, -offset, 0, composerHeight)
    boxBg.Size = UDim2.new(1, -73, 0, composerHeight - 21)
    sendBtn.Position = UDim2.new(1, -12, 1, -51)
    for _, list in pairs(lists) do
        list.Position = UDim2.fromOffset(offset + 1, 53)
        list.Size = UDim2.new(1, -offset - 1, 1, -55 - composerHeight)
    end
    local available = win.AbsoluteSize.X - offset
    roomName.Size = UDim2.new(1, available < 365 and -105 or -215, 1, 0)
    presencePill.Visible = not searchOpen and available >= 365
    if available < 365 then
        findButton.Position = UDim2.new(1, -11, 0.5, 0)
    else
        findButton.Position = UDim2.new(1, -11, 0.5, 0)
    end
    if updateJump then updateJump() end
end
bind(sidebarButton.Activated, function()
    sidebarCollapsed = not sidebarCollapsed
    layoutWorkspace()
end)
bind(win:GetPropertyChangedSignal("AbsoluteSize"), layoutWorkspace)
layoutWorkspace()

local followLatest, autoScrolling, userScrolling, settleUntil, scrollTicket = {}, {}, {}, {}, {}
for _, channel in ipairs(CHANNELS) do
    followLatest[channel.id] = true
    scrollTicket[channel.id] = 0
end

local function bottomY(list)
    return math.max(0, list.AbsoluteCanvasSize.Y - list.AbsoluteWindowSize.Y)
end

local function atBottom(list)
    return bottomY(list) - list.CanvasPosition.Y <= 12
end

local function scheduleLatest(id)
    local list = lists[id]
    if not alive or not list or not followLatest[id] or searchOpen then return end
    scrollTicket[id] = scrollTicket[id] + 1
    local ticket = scrollTicket[id]
    local function sync()
        if not alive or not list.Parent or not followLatest[id] or searchOpen
            or scrollTicket[id] ~= ticket then return end
        autoScrolling[id] = true
        list.CanvasPosition = Vector2.new(0, bottomY(list))
        task.defer(function() autoScrolling[id] = false end)
    end
    task.defer(sync)
    task.delay(0.05, sync)
    task.delay(0.16, sync)
end

local jumpButton = new("TextButton", {
    Name = "JumpToLatest", AnchorPoint = Vector2.new(1, 1),
    Position = UDim2.new(1, -14, 1, -70),
    Size = UDim2.fromOffset(100, 29),
    BackgroundColor3 = C.panel, BorderSizePixel = 0,
    AutoButtonColor = false, Text = "", Visible = false, ZIndex = 7,
}, body)
round(jumpButton, 8)
local jumpIcon = lucideIcon(jumpButton, "chevron-down", 15, C.text, 8)
jumpIcon.AnchorPoint = Vector2.new(0, 0.5)
jumpIcon.Position = UDim2.new(0, 10, 0.5, 0)
new("TextLabel", {
    Position = UDim2.fromOffset(32, 0),
    Size = UDim2.new(1, -36, 1, 0),
    BackgroundTransparency = 1, Text = "Latest",
    FontFace = UiFont, TextSize = 11, TextColor3 = C.text,
    TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 8,
}, jumpButton)
updateJump = function()
    local list = lists[current]
    if not list or not alive then return end
    jumpButton.Visible = not searchOpen and not followLatest[current] and not atBottom(list)
end
bind(jumpButton.Activated, function()
    followLatest[current] = true
    scheduleLatest(current)
    updateJump()
end)
for id, list in pairs(lists) do
    bind(list:GetPropertyChangedSignal("CanvasPosition"), function()
        if not alive then return end
        if not autoScrolling[id] and not searchOpen
            and (userScrolling[id] or os.clock() >= (settleUntil[id] or 0)) then
            followLatest[id] = atBottom(list)
        end
        if id == current then updateJump() end
    end)
    bind(list:GetPropertyChangedSignal("AbsoluteCanvasSize"), function()
        if followLatest[id] then scheduleLatest(id) end
        if id == current then updateJump() end
    end)
    bind(list:GetPropertyChangedSignal("AbsoluteWindowSize"), function()
        if followLatest[id] then scheduleLatest(id) end
        if id == current then updateJump() end
    end)
    bind(list.InputChanged, function(input)
        if input.UserInputType == Enum.UserInputType.MouseWheel then
            if input.Position.Z > 0 then
                followLatest[id] = false
            else
                task.defer(function()
                    if alive and atBottom(list) then
                        followLatest[id] = true
                        scheduleLatest(id)
                    end
                end)
            end
            if id == current then updateJump() end
        end
    end)
    bind(list.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1 then
            userScrolling[id] = true
        end
    end)
    bind(list.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1 then
            task.defer(function()
                userScrolling[id] = false
                if alive and atBottom(list) then
                    followLatest[id] = true
                    scheduleLatest(id)
                end
                if id == current then updateJump() end
            end)
        end
    end)
end
bind(box.Focused, function() tween(boxStroke, 0.17, {Transparency = 0}) end)
bind(box.FocusLost, function() tween(boxStroke, 0.17, {Transparency = 1}) end)

local function refreshChannels()
    for id, entry in pairs(chBtns) do
        local active = id == current
        entry.btn.BackgroundColor3 = C.panel
        hover(entry.btn, active and 0 or 1)
        entry.nameLabel.TextColor3 = active and C.text or C.dim
        entry.hashLabel.TextColor3 = active and C.accent or C.dim
        local count = unread[id] or 0
        entry.badge.Visible = not active and count > 0
        local pings = mentionsUnread[id] or 0
        entry.badge.Text = pings > 0 and ("@" .. tostring(math.min(pings, 9)))
            or count > 99 and "99+" or tostring(count)
    end
end

local function setChannel(id)
    if not lists[id] then return end
    drafts[current] = box.Text
    current = id
    box.Text = drafts[id] or ""
    unread[id] = 0
    mentionsUnread[id] = 0
    for other, list in pairs(lists) do list.Visible = other == id end
    roomName.Text = chanName[id]
    refreshReply()
    box.PlaceholderText = "Message #" .. id
    findInput.PlaceholderText = "Find in #" .. id
    if win.AbsoluteSize.X < 580 and not sidebarCollapsed then
        sidebarCollapsed = true
        layoutWorkspace()
    end
    refreshChannels()
    if updateSearch then updateSearch() end
    if updateJump then updateJump() end
    if followLatest[id] then scheduleLatest(id) end
end

for id, entry in pairs(chBtns) do
    bind(entry.btn.Activated, function() setChannel(id) end)
    bind(entry.btn.MouseEnter, function()
        if current ~= id then hover(entry.btn, 0.48) end
    end)
    bind(entry.btn.MouseLeave, function()
        if current ~= id then hover(entry.btn, 1) end
    end)
end


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
    local currentCamera = workspace.CurrentCamera
    local screen = currentCamera and currentCamera.ViewportSize or Vector2.new(1280, 720)
    local width = win.AbsoluteSize.X
    win.Position = UDim2.fromOffset(
        math.clamp(start.X.Offset + dx, 54 - width, screen.X - 54),
        math.clamp(start.Y.Offset + dy, 0, screen.Y - TITLE_H))
end)
makeDrag(grip, function() return win.Size end, function(start, dx, dy)
    if not body.Visible then return end
    local currentCamera = workspace.CurrentCamera
    local screen = currentCamera and currentCamera.ViewportSize or Vector2.new(1280, 720)
    local maxW = math.max(340, screen.X - win.AbsolutePosition.X - 8)
    local maxH = math.max(260, screen.Y - win.AbsolutePosition.Y - 8)
    win.Size = UDim2.fromOffset(
        math.clamp(start.X.Offset + dx, math.min(MIN_W, maxW), maxW),
        math.clamp(start.Y.Offset + dy, math.min(MIN_H, maxH), maxH))
end)

local maximized, fullSize, fullPosition = false, nil, nil
bind(maximizeBtn.Activated, function()
    if not body.Visible then return end
    local currentCamera = workspace.CurrentCamera
    local screen = currentCamera and currentCamera.ViewportSize or Vector2.new(1280, 720)
    if not maximized then
        fullSize, fullPosition = win.Size, win.Position
        win.Size = UDim2.fromOffset(math.max(340, screen.X - 14), math.max(260, screen.Y - 14))
        win.Position = UDim2.fromOffset(7, 7)
        maximized = true
        grip.Visible = false
        maximizeIcon.ImageRectOffset = Lucide48.minimize.Offset
        maximizeIcon.Image = Lucide48.minimize.Image
    else
        maximized = false
        win.Size, win.Position = fullSize, fullPosition
        grip.Visible = true
        maximizeIcon.ImageRectOffset = Lucide48.maximize.Offset
        maximizeIcon.Image = Lucide48.maximize.Image
    end
    layoutWorkspace()
end)
local minimized, savedSize = false, win.Size
bind(minBtn.Activated, function()
    minimized = not minimized
    if minimized then
        savedSize = win.Size
        body.Visible = false
        grip.Visible = false
        win.Size = UDim2.fromOffset(win.AbsoluteSize.X, TITLE_H)
        minIcon.ImageRectOffset = Lucide48.square.Offset
        minIcon.Image = Lucide48.square.Image
    else
        win.Size = savedSize
        body.Visible = true
        grip.Visible = not maximized
        minIcon.ImageRectOffset = Lucide48.minus.Offset
        minIcon.Image = Lucide48.minus.Image
        layoutWorkspace()
    end
end)


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
    if not open and followLatest[current] then scheduleLatest(current) end
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
    settleUntil[id] = os.clock() + 0.2
    order += 1
    node.LayoutOrder = order
    queue[#queue + 1] = node
    if #queue > 200 then table.remove(queue, 1):Destroy() end
    if followLatest[id] then scheduleLatest(id) end
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

local messageViews = {}
local knownUsers = {}
local refreshMentions
knownUsers[lp.Name:lower()] = lp.Name
for _, channel in ipairs(CHANNELS) do
    messageViews[channel.id] = {}
    mentionsUnread[channel.id] = 0
end

local function containsOwnMention(value)
    for name in value:gmatch("@([%w_]+)") do
        if name:lower() == lp.Name:lower() then return true end
    end
    return false
end

local function formatText(value)
    local parts, i = {}, 1
    local tick = string.char(96)
    while i <= #value do
        local char = value:sub(i, i)
        if char == tick and value:sub(i, i + 2) ~= tick .. tick .. tick then
            local finish = value:find(tick, i + 1, true)
            if finish and finish - i < 180 then
                parts[#parts + 1] = '<font color="#ACCBFA">'
                    .. esc(value:sub(i + 1, finish - 1)) .. '</font>'
                i = finish + 1
            else
                parts[#parts + 1] = esc(char)
                i += 1
            end
        elseif char == "@" then
            local handle = value:sub(i + 1):match("^([%w_]+)")
            if handle and knownUsers[handle:lower()] then
                parts[#parts + 1] = '<font color="#' .. C.mine:ToHex()
                    .. '"><b>@' .. esc(handle) .. '</b></font>'
                i += #handle + 1
            else
                parts[#parts + 1] = esc(char)
                i += 1
            end
        else
            parts[#parts + 1] = esc(char)
            i += 1
        end
    end
    return table.concat(parts)
end

local keyWords = {
    ["and"] = true, ["break"] = true, ["continue"] = true, ["do"] = true,
    ["else"] = true, ["elseif"] = true, ["end"] = true, ["false"] = true,
    ["for"] = true, ["function"] = true, ["if"] = true, ["in"] = true,
    ["local"] = true, ["nil"] = true, ["not"] = true, ["or"] = true,
    ["repeat"] = true, ["return"] = true, ["then"] = true, ["true"] = true,
    ["until"] = true, ["while"] = true, ["type"] = true,
}
local function codeHighlight(value)
    local parts, i = {}, 1
    local function color(part, hex)
        parts[#parts + 1] = '<font color="' .. hex .. '">' .. esc(part) .. '</font>'
    end
    while i <= #value do
        local ch = value:sub(i, i)
        if ch == "-" and value:sub(i, i + 1) == "--" then
            local finish = value:find("\n", i, true) or (#value + 1)
            color(value:sub(i, finish - 1), "#929292")
            i = finish
        elseif ch == '"' or ch == "'" then
            local finish, escaped = i + 1, false
            while finish <= #value do
                local nextChar = value:sub(finish, finish)
                if nextChar == ch and not escaped then break end
                if nextChar == "\\" then escaped = not escaped else escaped = false end
                finish += 1
            end
            finish = math.min(finish, #value)
            color(value:sub(i, finish), "#A1D4AE")
            i = finish + 1
        elseif ch:match("[%a_]") then
            local word = value:sub(i):match("^[%a_][%w_]*")
            if word then
                if keyWords[word] then color(word, "#91BAFF")
                else parts[#parts + 1] = esc(word) end
                i += #word
            else
                parts[#parts + 1] = esc(ch)
                i += 1
            end
        elseif ch:match("%d") then
            local number = value:sub(i):match("^%d+%.?%d*")
            if number then color(number, "#F4C68C"); i += #number
            else parts[#parts + 1] = esc(ch); i += 1 end
        else
            parts[#parts + 1] = esc(ch)
            i += 1
        end
    end
    return table.concat(parts)
end

local function findSharedUrl(value)
    local candidate = value:match("https?://[^%s<>]+")
    if not candidate then return nil end
    candidate = candidate:gsub("[,%.!%?%)%]]+$", "")
    local host = candidate:match("^https?://([%w%.%-]+)")
    if not host or not host:find("%.", 1, true) or #candidate > 250 then
        return nil
    end
    return candidate, host
end

local function jumpToMessage(channelId, id)
    local target = messageViews[channelId] and messageViews[channelId][id]
    if not target or not target.node or not target.node.Parent then return false end
    if current ~= channelId then setChannel(channelId) end
    if searchOpen then toggleSearch(false) end
    followLatest[channelId] = false
    scrollTicket[channelId] += 1
    local list = lists[channelId]
    task.defer(function()
        if not alive or not target.node.Parent then return end
        local y = list.CanvasPosition.Y + target.node.AbsolutePosition.Y
            - list.AbsolutePosition.Y - 24
        list.CanvasPosition = Vector2.new(0, math.clamp(y, 0, math.max(0,
            list.AbsoluteCanvasSize.Y - list.AbsoluteWindowSize.Y)))
        local highlight = new("UIStroke", {
            Color = C.accent, Thickness = 1.5, Transparency = 0,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        }, target.bubble)
        tween(highlight, 0.9, {Transparency = 1})
        task.delay(0.95, function()
            if highlight.Parent then highlight:Destroy() end
        end)
        if updateJump then updateJump() end
    end)
    return true
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
    local raw = clip(type(message.text) == "string" and message.text or "", MAX_LEN + 24)
    local parsed = parseMessage(raw)
    local displayed = parsed.code or parsed.body
    local timestamp = tonumber(message.ts)
    if not timestamp or timestamp ~= timestamp or timestamp <= 0
        or timestamp > 9999999999999 then
        timestamp = os.time() * 1000
    end
    timestamp = math.floor(timestamp)
    local shortTime = os.date("%I:%M %p", math.floor(timestamp / 1000))
    local previous = grouped[channelId]
    local compact = previous and previous.id == message.userId
        and timestamp >= previous.ts and timestamp - previous.ts <= 180000
        and not parsed.replyId and not parsed.code and not parsed.legacyReply
    grouped[channelId] = {id = message.userId, ts = timestamp}

    local safeName = user:match("^[%w_]+$")
    if safeName and #safeName <= 28 then
        knownUsers[safeName:lower()] = safeName
    end
    if refreshMentions then refreshMentions() end
    local mentioned = not mine and not parsed.code and containsOwnMention(parsed.body)
    local node = new("Frame", {
        Name = mine and "OwnMessage" or "Message",
        Size = UDim2.new(1, -4, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, BorderSizePixel = 0,
    }, lists[channelId])
    if not mine and not compact then
        local avatar = new("ImageLabel", {
            Name = "Avatar", Position = UDim2.fromOffset(2, 5),
            Size = UDim2.fromOffset(31, 31), BackgroundColor3 = C.btn,
            BorderSizePixel = 0, ScaleType = Enum.ScaleType.Crop,
            Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(message.userId or 0)
                .. "&w=150&h=150",
        }, node)
        round(avatar, 8)
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
    round(bubble, 8)
    new("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 5),
    }, bubble)
    new("UIPadding", {
        PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12),
        PaddingTop = UDim.new(0, 9), PaddingBottom = UDim.new(0, 9),
    }, bubble)

    if not compact then
        local author = new("TextButton", {
            Name = "Author", LayoutOrder = 1,
            Size = UDim2.new(1, -44, 0, 18),
            BackgroundTransparency = 1, RichText = true,
            Text = "", FontFace = UiFont,
            TextSize = 12, TextColor3 = C.text,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            AutoButtonColor = false, ZIndex = 3,
        }, bubble)
        local tone = mine and C.mine or nameColor(message.userId)
        author.Text = '<font color="#' .. tone:ToHex() .. '">'
            .. esc(mine and "You" or user)
            .. '</font>  <font color="#' .. C.dim:ToHex() .. '" size="10">'
            .. esc(shortTime) .. '</font>'
        author.Activated:Connect(function()
            if not alive or mine or not safeName then return end
            local suffix = box.Text ~= "" and " " or ""
            box.Text = box.Text .. suffix .. "@" .. safeName .. " "
            box.CursorPosition = #box.Text + 1
            box:CaptureFocus()
        end)
    end

    if parsed.replyId or parsed.legacyReply then
        local original = parsed.replyId and messageViews[channelId][parsed.replyId]
        local toAuthor = original and original.user or parsed.replyAuthor or "Unknown"
        local toBody = original and original.text or parsed.replyExcerpt or "Original message unavailable"
        if parsed.legacyReply then
            toAuthor, toBody = "Reply", parsed.legacyReply
        end
        local quote = new("TextButton", {
            Name = "ReplyReference", LayoutOrder = 2,
            Size = UDim2.new(1, 0, 0, 44),
            BackgroundColor3 = C.btn, BorderSizePixel = 0,
            AutoButtonColor = false, Text = "", ZIndex = 3,
        }, bubble)
        round(quote, 7)
        new("Frame", {
            Position = UDim2.fromOffset(0, 5), Size = UDim2.fromOffset(2, 34),
            BorderSizePixel = 0, BackgroundColor3 = C.accent, ZIndex = 4,
        }, quote)
        new("TextLabel", {
            Position = UDim2.fromOffset(10, 5), Size = UDim2.new(1, -18, 0, 17),
            BackgroundTransparency = 1, Text = toAuthor,
            TextColor3 = C.mine, FontFace = UiFont, TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 4,
        }, quote)
        new("TextLabel", {
            Position = UDim2.fromOffset(10, 22), Size = UDim2.new(1, -18, 0, 16),
            BackgroundTransparency = 1, Text = toBody,
            TextColor3 = C.dim, FontFace = BodyFont, TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 4,
        }, quote)
        if parsed.replyId then
            local originalId = parsed.replyId
            quote.Activated:Connect(function()
                if not jumpToMessage(channelId, originalId) then
                    sys("That message is no longer in the loaded history")
                end
            end)
        end
    end

    if parsed.code then
        local source = parsed.code
        local codePanel = new("Frame", {
            Name = "CodeBlock", LayoutOrder = 3,
            Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = C.bg, BorderSizePixel = 0, ZIndex = 3,
        }, bubble)
        round(codePanel, 7)
        new("UIPadding", {
            PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 10),
            PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10),
        }, codePanel)
        new("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 5),
        }, codePanel)
        local codeHead = new("Frame", {
            LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 19),
            BackgroundTransparency = 1, ZIndex = 4,
        }, codePanel)
        new("TextLabel", {
            Size = UDim2.new(1, -40, 1, 0),
            BackgroundTransparency = 1, Text = parsed.language or "Luau",
            FontFace = UiFont, TextSize = 10, TextColor3 = C.dim,
            TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5,
        }, codeHead)
        new("TextLabel", {
            Name = "Source", LayoutOrder = 2,
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
            Text = codeHighlight(source), RichText = true, TextWrapped = true,
            Font = Enum.Font.Code, TextSize = 12, TextColor3 = C.text,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 4,
        }, codePanel)
        local copy = type(setclipboard) == "function" and setclipboard
            or (type(toclipboard) == "function" and toclipboard)
        if copy then
            local button = new("TextButton", {
                Name = "CopyCode", AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, 0, 0, -4),
                Size = UDim2.fromOffset(29, 27),
                BackgroundColor3 = C.btn, BorderSizePixel = 0,
                AutoButtonColor = false, Text = "", ZIndex = 5,
            }, codeHead)
            round(button, 7)
            local glyph = lucideIcon(button, "copy", 14, C.text, 6)
            button.Activated:Connect(function()
                if alive and pcall(copy, source) then
                    glyph.Image = Lucide48.check.Image
                    glyph.ImageRectOffset = Lucide48.check.Offset
                    task.delay(1, function()
                        if alive and glyph.Parent then
                            glyph.Image = Lucide48.copy.Image
                            glyph.ImageRectOffset = Lucide48.copy.Offset
                        end
                    end)
                end
            end)
        end
    else
        new("TextLabel", {
            Name = "Content", LayoutOrder = 3,
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
            Text = formatText(parsed.body), RichText = true, TextWrapped = true,
            FontFace = BodyFont, TextSize = 13, TextColor3 = C.text,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 3,
        }, bubble)
        local url, domain = findSharedUrl(parsed.body)
        if url then
            local card = new("TextButton", {
                Name = "SharedLink", LayoutOrder = 4,
                Size = UDim2.new(1, 0, 0, 44),
                BackgroundColor3 = C.bg, BorderSizePixel = 0,
                AutoButtonColor = false, Text = "", ZIndex = 3,
            }, bubble)
            round(card, 7)
            local linkIcon = lucideIcon(card, "link", 15, C.mine, 4)
            linkIcon.AnchorPoint = Vector2.new(0, 0.5)
            linkIcon.Position = UDim2.new(0, 10, 0.5, 0)
            new("TextLabel", {
                Position = UDim2.fromOffset(34, 4),
                Size = UDim2.new(1, -43, 0, 17),
                BackgroundTransparency = 1, Text = domain,
                TextTruncate = Enum.TextTruncate.AtEnd,
                FontFace = UiFont, TextSize = 11, TextColor3 = C.text,
                TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4,
            }, card)
            new("TextLabel", {
                Position = UDim2.fromOffset(34, 21),
                Size = UDim2.new(1, -43, 0, 17),
                BackgroundTransparency = 1, Text = url,
                TextTruncate = Enum.TextTruncate.AtEnd,
                FontFace = BodyFont, TextSize = 10, TextColor3 = C.dim,
                TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4,
            }, card)
            card.Activated:Connect(function()
                if not alive then return end
                local ok = pcall(function()
                    game:GetService("GuiService"):OpenBrowserWindow(url)
                end)
                if not ok then
                    local clipboard = type(setclipboard) == "function" and setclipboard
                        or (type(toclipboard) == "function" and toclipboard)
                    if clipboard and pcall(clipboard, url) then
                        sys("Link copied to clipboard")
                    else
                        sys("Could not open or copy the link")
                    end
                end
            end)
        end
    end

    local actions = new("Frame", {
        Name = "MessageActions", AnchorPoint = Vector2.new(1, 0),
        Position = mine and UDim2.new(1, -8, 0, 5)
            or UDim2.new(0.79, 30, 0, 5),
        Size = UDim2.fromOffset(62, 28),
        BackgroundTransparency = 1, Visible = UIS.TouchEnabled, ZIndex = 5,
    }, node)
    local actionList = new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 3),
    }, actions)
    local function actionButton(name, order, iconName)
        local button = new("TextButton", {
            Name = name, LayoutOrder = order,
            Size = UDim2.fromOffset(28, 27), BackgroundColor3 = C.btnHover,
            BorderSizePixel = 0, AutoButtonColor = false, Text = "", ZIndex = 6,
        }, actions)
        round(button, 8)
        local glyph = lucideIcon(button, iconName, 14, C.text, 7)
        return button, glyph
    end
    local reply = actionButton("Reply", 1, "reply")
    reply.Activated:Connect(function()
        if not alive then return end
        pendingReplies[channelId] = {
            id = message.id,
            user = safeName or "Unknown",
            text = clip(displayed:gsub("[\r\n|]+", " "), 48),
        }
        if current ~= channelId then setChannel(channelId) end
        if searchOpen then toggleSearch(false) end
        refreshReply()
        box:CaptureFocus()
    end)
    local clipboard = type(setclipboard) == "function" and setclipboard
        or (type(toclipboard) == "function" and toclipboard)
    if clipboard then
        local copy, glyph = actionButton("Copy", 2, "copy")
        copy.Activated:Connect(function()
            if alive and pcall(clipboard, displayed) then
                glyph.Image = Lucide48.check.Image
                glyph.ImageRectOffset = Lucide48.check.Offset
                task.delay(1, function()
                    if alive and glyph.Parent then
                        glyph.Image = Lucide48.copy.Image
                        glyph.ImageRectOffset = Lucide48.copy.Offset
                    end
                end)
            end
        end)
    end
    node.MouseEnter:Connect(function()
        if alive and actions.Parent then actions.Visible = true end
    end)
    node.MouseLeave:Connect(function()
        if alive and actions.Parent and not UIS.TouchEnabled then
            actions.Visible = false
        end
    end)
    insertMessage(channelId, node)
    indexMessage(channelId, node, user .. " " .. displayed)
    messageViews[channelId][message.id] = {
        node = node, bubble = bubble, user = user,
        text = clip(displayed:gsub("[\r\n]+", " "), 110),
    }
    node.Destroying:Connect(function()
        if messageViews[channelId][message.id] and
            messageViews[channelId][message.id].node == node then
            messageViews[channelId][message.id] = nil
        end
    end)
    if not silent and not mine then
        if mentioned and channelId ~= current then
            mentionsUnread[channelId] += 1
        end
        if channelId ~= current then
            unread[channelId] = (unread[channelId] or 0) + 1
            refreshChannels()
        elseif mentioned then
            refreshChannels()
        end
    end
end

local STATUS = {
    connecting = {"Connecting", C.dim},
    online = {"Connected", C.text},
    fallback = {"Connected · HTTP", C.dim},
    offline = {"Disconnected", C.dim},
    banned = {"Access restricted", C.bad},
}
local function setStatus(state)
    local info = STATUS[state] or STATUS.connecting
    status.Text, status.TextColor3 = info[1], info[2]
end
local function setCount(n)
    if type(n) == "number" then countLbl.Text = tostring(n) .. " online" end
end


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

local function send(text, channelOverride)
    local channel = channelOverride or current
    if not lists[channel] then return false end
    local original = tostring(text)
    local trimmed = original:match("^%s*(.-)%s*$")
    if trimmed == "" then return false end
    if banned then sys("You are banned"); return false end
    local reply = pendingReplies[channel]
    if trimmed:sub(1, 1) == "/" and not reply then
        if ADMIN_TOKEN == "" then
            sys("Commands are admin-only")
        else
            sendCommand(trimmed)
        end
        return true
    end
    local encoded = prepareMessage(trimmed, reply)
    local length = utf8.len(encoded) or #encoded
    if length > MAX_LEN then
        sys("Message is too long (" .. tostring(length) .. "/" .. MAX_LEN .. ")")
        return false
    end
    if not req and not wsLive then
        sys("Not connected: cannot send")
        return false
    end
    local payload = {
        t = "send", ch = channel, user = lp.Name,
        userId = lp.UserId, text = encoded,
    }
    local function finishReply()
        if reply and pendingReplies[channel] == reply then
            pendingReplies[channel] = nil
            if current == channel then refreshReply() end
        end
    end
    if wsSend(payload) then
        finishReply()
        return true
    end
    if not req then
        sys("Unable to send while disconnected")
        return false
    end
    finishReply()
    task.spawn(function()
        local code, data = api("POST", "/send", payload)
        if not alive then return end
        if code == 200 and data and data.m then
            addMessage(data.m)
        else
            if code == 403 and data and data.error == "you are banned" then
                onBanned(data.error)
            end
            if not banned then
                if reply and not pendingReplies[channel] then
                    pendingReplies[channel] = reply
                    if current == channel then refreshReply() end
                end
                if drafts[channel] == nil or drafts[channel] == "" then
                    drafts[channel] = original
                    if current == channel and box.Text == "" then box.Text = original end
                end
            end
            sys((data and data.error) or ("Send failed (" .. tostring(code) .. ")"))
        end
    end)
    return true
end

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


	task.spawn(function()
		while alive do
			task.wait(20)
			if wsLive then wsSend({ t = "ping" }) end
		end
	end)
end


task.spawn(function()
	while alive and not banned do
		if not wsLive then
			local first = lastId == 0
			local code, data = api("GET", "/poll?since=" .. lastId)
            if not alive then break end
			if wsLive then

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


local mentionPanel = new("Frame", {
    Name = "MentionSuggestions", Position = UDim2.fromOffset(14, -40),
    Size = UDim2.new(1, -87, 0, 35),
    BackgroundColor3 = C.panel, BorderSizePixel = 0,
    Visible = false, ZIndex = 12,
}, row)
round(mentionPanel, 8)
local suggestionButtons = {}
local mentionCandidates = {}
local completingMention = false
local hoveringSuggestions = false
local lastMention
bind(mentionPanel.MouseEnter, function() hoveringSuggestions = true end)
bind(mentionPanel.MouseLeave, function() hoveringSuggestions = false end)

local function mentionAtCursor()
    local caret = box.CursorPosition
    if caret < 1 then return nil end
    local before = box.Text:sub(1, caret - 1)
    local index, query = before:match("()@([%w_]*)$")
    if not index then return nil end
    if index > 1 and before:sub(index - 1, index - 1):match("[%w_@]") then
        return nil
    end
    return index, query, caret
end

local function insertMention(name)
    local startAt, _, caret = mentionAtCursor()
    if not startAt and lastMention and lastMention.text == box.Text then
        startAt, caret = lastMention.startAt, lastMention.caret
    end
    if not startAt then return end
    local replacement = "@" .. name .. " "
    box.Text = box.Text:sub(1, startAt - 1)
        .. replacement .. box.Text:sub(caret)
    box.CursorPosition = startAt + #replacement
    mentionPanel.Visible = false
    lastMention = nil
    completingMention = false
    box:CaptureFocus()
end

for i = 1, 5 do
    local choice = new("TextButton", {
        Name = "Suggestion" .. tostring(i),
        Position = UDim2.fromOffset(5, 5 + (i - 1) * 30),
        Size = UDim2.new(1, -10, 0, 28),
        BackgroundColor3 = C.btn, BackgroundTransparency = 1,
        BorderSizePixel = 0, AutoButtonColor = false,
        Text = "", Visible = false, ZIndex = 13,
    }, mentionPanel)
    round(choice, 6)
    local handle = new("TextLabel", {
        Name = "Username", Position = UDim2.fromOffset(9, 0),
        Size = UDim2.new(1, -18, 1, 0),
        BackgroundTransparency = 1, Text = "",
        FontFace = UiFont, TextSize = 12, TextColor3 = C.text,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 14,
    }, choice)
    bind(choice.MouseEnter, function() hover(choice, 0) end)
    bind(choice.MouseLeave, function() hover(choice, 1) end)
    bind(choice.Activated, function()
        local name = mentionCandidates[i]
        if name then insertMention(name) end
    end)
    suggestionButtons[i] = {button = choice, label = handle}
end

refreshMentions = function()
    if not alive or UIS:GetFocusedTextBox() ~= box then
        if not hoveringSuggestions then mentionPanel.Visible = false end
        return
    end
    local startAt, query = mentionAtCursor()
    if not startAt then
        mentionPanel.Visible = false
        lastMention = nil
        return
    end
    lastMention = {startAt = startAt, caret = box.CursorPosition, text = box.Text}
    local matches = {}
    local needle = query:lower()
    for key, name in pairs(knownUsers) do
        if key:sub(1, #needle) == needle and name:lower() ~= lp.Name:lower() then
            matches[#matches + 1] = name
        end
    end
    table.sort(matches, function(a, b) return a:lower() < b:lower() end)
    local count = math.min(#matches, 5)
    mentionPanel.Visible = count > 0
    if count > 0 then
        local height = count * 30 + 10
        mentionPanel.Position = UDim2.fromOffset(14, -height - 3)
        mentionPanel.Size = UDim2.new(1, -87, 0, height)
    end
    for i, entry in ipairs(suggestionButtons) do
        local name = matches[i]
        mentionCandidates[i] = name
        entry.button.Visible = i <= count
        entry.label.Text = name and ("@" .. name) or ""
    end
end

refreshInput = function()
    if not alive then return end
    local text = box.Text
    local wire = prepareMessage(text, pendingReplies[current])
    local length = utf8.len(wire) or #wire
    local lines = select(2, text:gsub("\n", "")) + 1
    local newHeight = 61 + math.min(3, math.max(0, lines - 1)) * 18
    if composerHeight ~= newHeight then
        composerHeight = newHeight
        box.TextYAlignment = lines > 1 and Enum.TextYAlignment.Top
            or Enum.TextYAlignment.Center
        layoutWorkspace()
        if followLatest[current] then scheduleLatest(current) end
    end
    local nonempty = text:match("%S") ~= nil
    counter.Text = length >= 150 and (tostring(length) .. "/" .. MAX_LEN) or ""
    counter.TextColor3 = length > MAX_LEN and C.bad or C.dim
    sendBtn.BackgroundTransparency = nonempty and length <= MAX_LEN and 0 or 0.5
    sendIcon.ImageTransparency = nonempty and length <= MAX_LEN and 0 or 0.22
    if not completingMention then refreshMentions() end
end

bind(box:GetPropertyChangedSignal("Text"), function()
    if box.CursorPosition == #box.Text + 1
        and not box.Text:find(string.rep(string.char(96), 3), 1, true) then
        local replaced = emojify(box.Text)
        if replaced ~= box.Text then
            box.Text = replaced
            box.CursorPosition = #replaced + 1
        end
    end
    drafts[current] = box.Text
    refreshInput()
end)
bind(box:GetPropertyChangedSignal("CursorPosition"), function()
    if not completingMention then refreshMentions() end
end)
bind(box.Focused, function()
    refreshMentions()
end)
bind(box.FocusLost, function(enter)
    if not hoveringSuggestions then mentionPanel.Visible = false end
    if enter and not UIS:IsKeyDown(Enum.KeyCode.LeftShift)
        and not UIS:IsKeyDown(Enum.KeyCode.RightShift) then
        local content = box.Text:gsub("\n+$", "")
        if send(content) then box.Text = "" end
    end
end)
local function sendCurrent()
    local content = box.Text:gsub("\n+$", "")
    if send(content) then box.Text = "" end
end
bind(sendBtn.Activated, sendCurrent)
bind(UIS.InputBegan, function(input, processed)
    if UIS:GetFocusedTextBox() == box then
        if input.KeyCode == Enum.KeyCode.Tab and mentionPanel.Visible then
            local name = mentionCandidates[1]
            if name then
                completingMention = true
                insertMention(name)
            end
            return
        end
        if input.KeyCode == Enum.KeyCode.Return
            or input.KeyCode == Enum.KeyCode.KeypadEnter then
            if UIS:IsKeyDown(Enum.KeyCode.LeftShift)
                or UIS:IsKeyDown(Enum.KeyCode.RightShift) then
                return
            end
            task.defer(function()
                if alive then sendCurrent() end
            end)
            return
        end
        if input.KeyCode == Enum.KeyCode.Escape then
            if pendingReplies[current] then
                pendingReplies[current] = nil
                refreshReply()
            end
            mentionPanel.Visible = false
            return
        end
    end
    if not processed and input.KeyCode == Enum.KeyCode.RightShift then
        win.Visible = not win.Visible
    elseif input.KeyCode == Enum.KeyCode.F and win.Visible
        and (UIS:IsKeyDown(Enum.KeyCode.LeftControl)
            or UIS:IsKeyDown(Enum.KeyCode.RightControl)) then
        toggleSearch(true)
    elseif input.KeyCode == Enum.KeyCode.Escape and searchOpen then
        toggleSearch(false)
    end
end)
refreshInput()

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
