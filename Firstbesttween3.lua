--[[
    FIRST BEST TWEEN — v4
    Mobile / Delta / universal
    Loadstring: loadstring(game:HttpGet("https://raw.githubusercontent.com/supercaptain1233/Firstbesttween/main/Firstbesttween3.lua"))()
]]

--============ PROTECTION ============
local cloneref = cloneref or function(o) return o end
local typeof = typeof or type

if typeof(setthreadidentity) == "function" then pcall(setthreadidentity, 7) end
if typeof(setidentity) == "function" then pcall(setidentity, 7) end
if typeof(setfpscap) == "function" then pcall(setfpscap, 60) end

local RAW_URL = "https://raw.githubusercontent.com/supercaptain1233/Firstbesttween/main/Firstbesttween3.lua"
local PATCH_URL = "https://raw.githubusercontent.com/supercaptain1233/Firstbesttween/main/patches/%s.lua"
local FOLDER = "FirstBestTween"
local STORE = FOLDER .. "/saves.json"
local TAG = "FBT_" .. tostring(math.random(100000, 999999))

if getgenv and getgenv().FirstBestTween and getgenv().FirstBestTween.destroy then
    pcall(getgenv().FirstBestTween.destroy)
end

local bootCount = (getgenv and getgenv().FirstBestTweenBoot or 0) + 1
if getgenv then getgenv().FirstBestTweenBoot = bootCount end

local function boot()

local Players = cloneref(game:GetService("Players"))
local RunService = cloneref(game:GetService("RunService"))
local UIS = cloneref(game:GetService("UserInputService"))
local VU = cloneref(game:GetService("VirtualUser"))
local TweenService = cloneref(game:GetService("TweenService"))
local Http = cloneref(game:GetService("HttpService"))
local TPS = cloneref(game:GetService("TeleportService"))
local SG = cloneref(game:GetService("StarterGui"))
local PFS = cloneref(game:GetService("PathfindingService"))

local LP = Players.LocalPlayer
if not LP then return end

local SPEED = 420
local MIN_T = 0.14
local MAX_T = 0.95

--============ FILE ============
local function safeRead(p)
    if typeof(readfile) ~= "function" then return nil end
    local ok, d = pcall(readfile, p)
    if ok and typeof(d) == "string" then return d end
    return nil
end

local function safeWrite(p, d)
    if typeof(writefile) ~= "function" then return false end
    if typeof(makefolder) == "function" then pcall(makefolder, FOLDER) end
    return (pcall(writefile, p, d))
end

--============ STORE ============
local store = {}
do
    local raw = safeRead(STORE)
    if raw then
        local ok, tbl = pcall(function() return Http:JSONDecode(raw) end)
        if ok and typeof(tbl) == "table" then store = tbl end
    end
end

local placeKey = tostring(game.PlaceId)
store[placeKey] = store[placeKey] or { saves = {}, picked = 0, learn = {}, trips = 0 }
local data = store[placeKey]
data.learn = data.learn or {}

local function persist()
    pcall(function() safeWrite(STORE, Http:JSONEncode(store)) end)
end

local function packCF(cf)
    return {
        x = cf.X, y = cf.Y, z = cf.Z,
        lx = cf.LookVector.X, ly = cf.LookVector.Y, lz = cf.LookVector.Z,
    }
end

local function unpackCF(t)
    local p = Vector3.new(t.x, t.y, t.z)
    local l = Vector3.new(t.lx, t.ly, t.lz)
    return CFrame.lookAt(p, p + l)
end

local function learnUp(style)
    data.learn[style] = (data.learn[style] or 0) + 1
    data.trips = (data.trips or 0) + 1
    data.lastStyle = style
    persist()
end

--============ ANTI-AFK / ANTI-KICK ============
local conns = {}
local function track(c) conns[#conns + 1] = c return c end

pcall(function()
    track(LP.Idled:Connect(function()
        pcall(function()
            VU:CaptureController()
            VU:ClickButton2(Vector2.new())
        end)
    end))
end)

pcall(function()
    if typeof(queue_on_teleport) == "function" then
        queue_on_teleport(string.format(
            'pcall(function() loadstring(game:HttpGet("%s"))() end)', RAW_URL))
    elseif typeof(syn) == "table" and typeof(syn.queue_on_teleport) == "function" then
        pcall(syn.queue_on_teleport, string.format(
            'pcall(function() loadstring(game:HttpGet("%s"))() end)', RAW_URL))
    end
end)

pcall(function()
    track(LP.OnTeleport:Connect(function(s)
        if s == Enum.TeleportState.Failed then
            pcall(function() TPS:Teleport(game.PlaceId, LP) end)
        end
    end))
end)

pcall(function() SG:SetCore("ResetButtonCallback", true) end)

--============ COLLISION / NOCLIP ============
local noclipOn = false
local noclipConns = {}
local forced = setmetatable({}, { __mode = "k" })
local baseSpeed = nil

local function forcePart(part)
    if noclipOn then return end
    if not part:IsA("BasePart") then return end
    if forced[part] then
        if not part.CanCollide then
            forced[part] = nil
            pcall(function() part.CanCollide = true end)
            forced[part] = true
        end
        return
    end
    forced[part] = true
    pcall(function() part.CanCollide = true end)
end

local function armGuard(part)
    if not part:IsA("BasePart") then return end
    noclipConns[#noclipConns + 1] =
        part:GetPropertyChangedSignal("CanCollide"):Connect(function()
            if noclipOn and part.CanCollide then
                pcall(function() part.CanCollide = false end)
            elseif not noclipOn and not part.CanCollide then
                pcall(function() part.CanCollide = true end)
            end
        end)
end

local function installCollision(char)
    if not char then return end
    for _, d in ipairs(char:GetDescendants()) do
        forcePart(d)
        armGuard(d)
    end
    track(char.DescendantAdded:Connect(function(d)
        task.defer(function()
            forcePart(d)
            armGuard(d)
        end)
    end))
end

-- three sweeps per frame plus per-part guards: nothing gets the property back
local function noclipSweep()
    local char = LP.Character
    if not char then return end
    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("BasePart") and d.CanCollide then
            pcall(function() d.CanCollide = false end)
        end
    end
end

local function setNoclip(on)
    local char = LP.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")

    if on then
        noclipOn = true
        if hum then
            baseSpeed = hum.WalkSpeed
            pcall(function()
                hum.PlatformStand = true
                hum.WalkSpeed = 0
                hum.AutoRotate = false
                hum:ChangeState(Enum.HumanoidStateType.Physics)
                hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
                hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
            end)
        end
        noclipSweep()
    else
        noclipOn = false
        if char then
            for _, d in ipairs(char:GetDescendants()) do
                if d:IsA("BasePart") then pcall(function() d.CanCollide = true end) end
            end
        end
        if hum then
            pcall(function()
                hum.PlatformStand = false
                hum.AutoRotate = true
                hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
                hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
                if baseSpeed then hum.WalkSpeed = baseSpeed end
                hum:ChangeState(Enum.HumanoidStateType.Running)
            end)
        end
    end
end

installCollision(LP.Character)
track(LP.CharacterAdded:Connect(function(c)
    installCollision(c)
    c:WaitForChild("HumanoidRootPart", 10)
end))

track(RunService.Heartbeat:Connect(function()
    local char = LP.Character
    if not char then return end
    if noclipOn then noclipSweep() return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp and not hrp.CanCollide then
        pcall(function() hrp.CanCollide = true end)
    end
end))

track(RunService.RenderStepped:Connect(function()
    if noclipOn then noclipSweep() end
end))

--============ STATE ============
local busy = false
local token = 0
local bannerBusy = false

local function hrpOf()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function alive()
    local c = LP.Character
    local h = c and c:FindFirstChildOfClass("Humanoid")
    return h and h.Health > 0 and hrpOf() ~= nil
end

--============ GUI ============
local gui = Instance.new("ScreenGui")
gui.Name = TAG
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 9999
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
if typeof(protectgui) == "function" then pcall(protectgui, gui) end
if typeof(syn) == "table" and typeof(syn.protect_gui) == "function" then
    pcall(syn.protect_gui, gui)
end

local parented = false
if typeof(gethui) == "function" then
    local ok, h = pcall(gethui)
    if ok and h then gui.Parent = h parented = true end
end
if not parented then
    local ok = pcall(function() gui.Parent = cloneref(game:GetService("CoreGui")) end)
    if not ok then gui.Parent = LP:WaitForChild("PlayerGui") end
end

local main = Instance.new("Frame")
main.Name = TAG .. "_main"
main.Size = UDim2.fromOffset(250, 352)
main.Position = UDim2.new(0, 22, 0.5, -176)
main.BackgroundColor3 = Color3.fromRGB(15, 16, 20)
main.BorderSizePixel = 0
main.Active = true
main.Parent = gui

local uiscale = Instance.new("UIScale")
uiscale.Parent = main

local function refreshScale()
    local cam = workspace.CurrentCamera
    local vp = cam and cam.ViewportSize or Vector2.new(800, 600)
    uiscale.Scale = math.clamp(math.min(vp.X, vp.Y) / 420, 0.70, 1.05)
end
refreshScale()
track((function()
    local c = workspace.CurrentCamera
    if not c then return Instance.new("BindableEvent").Event end
    return c:GetPropertyChangedSignal("ViewportSize"):Connect(refreshScale)
end)())

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = main

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(56, 58, 70)
stroke.Thickness = 1.5
stroke.Parent = main

local bar = Instance.new("Frame")
bar.Size = UDim2.new(1, 0, 0, 26)
bar.BackgroundTransparency = 1
bar.Parent = main

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -128, 1, 0)
title.Position = UDim2.fromOffset(9, 0)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.Text = "FIRST BEST TWEEN"
title.TextSize = 12
title.TextColor3 = Color3.fromRGB(140, 205, 255)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = bar

local function topButton(xOffset, w)
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(w, 21)
    b.Position = UDim2.new(1, xOffset, 0, 3)
    b.BackgroundColor3 = Color3.fromRGB(34, 36, 44)
    b.TextColor3 = Color3.fromRGB(220, 220, 230)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.AutoButtonColor = true
    b.Parent = bar
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 5)
    c.Parent = b
    return b
end

local moveBtn = topButton(-94, 30)
moveBtn.TextSize = 9
moveBtn.Text = " ↑ \n← →\n ↓ "
moveBtn.TextYAlignment = Enum.TextYAlignment.Center
local shrinkBtn = topButton(-62, 30)
shrinkBtn.Text = "▽"
shrinkBtn.TextSize = 10
local closeBtn = topButton(-28, 24)
closeBtn.Text = "✕"

local dragging, dragStart, startPos
moveBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = main.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
track(UIS.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
        local d = input.Position - dragStart
        main.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + d.X,
            startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end))

local function bigButton(text, y, h, color)
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(110, h)
    b.Position = UDim2.new(0.5, -55, 0, y)
    b.BackgroundColor3 = color
    b.Text = text
    b.TextColor3 = Color3.fromRGB(238, 238, 244)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.Parent = main
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 7)
    c.Parent = b
    return b
end

local playBtn = bigButton("PLAY", 31, 26, Color3.fromRGB(38, 120, 76))
local saveBtn = bigButton("SAVE", 61, 26, Color3.fromRGB(40, 52, 78))
local clearAllBtn = bigButton("CLEAR ALL", 91, 22, Color3.fromRGB(60, 40, 44))
clearAllBtn.TextSize = 11

local list = Instance.new("ScrollingFrame")
list.Position = UDim2.new(0, 10, 0, 120)
list.Size = UDim2.new(1, -20, 1, -130)
list.BackgroundColor3 = Color3.fromRGB(22, 23, 29)
list.BorderSizePixel = 0
list.ScrollBarThickness = 4
list.ScrollingDirection = Enum.ScrollingDirection.Y
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.CanvasSize = UDim2.new(0, 0, 0, 0)
list.ElasticBehavior = Enum.ElasticBehavior.Always
list.Parent = main

local lc = Instance.new("UICorner")
lc.CornerRadius = UDim.new(0, 8)
lc.Parent = list

local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 6)
pad.PaddingLeft = UDim.new(0, 6)
pad.PaddingRight = UDim.new(0, 6)
pad.PaddingBottom = UDim.new(0, 6)
pad.Parent = list

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 4)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list

--============ MINI (draggable) ============
local mini = Instance.new("TextButton")
mini.Size = UDim2.fromOffset(58, 58)
mini.BackgroundColor3 = Color3.fromRGB(18, 38, 56)
mini.Text = "first\nbest"
mini.TextWrapped = true
mini.TextColor3 = Color3.fromRGB(150, 215, 255)
mini.Font = Enum.Font.GothamBold
mini.TextSize = 10
mini.Visible = false
mini.Active = true
mini.AutoButtonColor = true
mini.Parent = gui
local mc = Instance.new("UICorner")
mc.CornerRadius = UDim.new(1, 0)
mc.Parent = mini
local ms = Instance.new("UIStroke")
ms.Color = Color3.fromRGB(90, 160, 220)
ms.Thickness = 2
ms.Parent = mini

local miniDrag = false
local miniStart, miniPos0, miniMoved = nil, nil, 0

mini.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        miniDrag = true
        miniMoved = 0
        miniStart = input.Position
        miniPos0 = mini.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                miniDrag = false
                if miniMoved < 12 then
                    mini.Visible = false
                    main.Position = mini.Position
                    main.Visible = true
                end
            end
        end)
    end
end)

track(UIS.InputChanged:Connect(function(input)
    if miniDrag and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
        local d = input.Position - miniStart
        miniMoved = math.max(miniMoved, math.abs(d.X) + math.abs(d.Y))
        mini.Position = UDim2.new(
            miniPos0.X.Scale, miniPos0.X.Offset + d.X,
            miniPos0.Y.Scale, miniPos0.Y.Offset + d.Y)
    end
end))

shrinkBtn.Activated:Connect(function()
    mini.Position = main.Position
    main.Visible = false
    mini.Visible = true
end)

--============ LIST ============
local rows = {}

local function rebuild()
    for _, r in ipairs(rows) do
        if r.parent then pcall(function() r.parent:Destroy() end) end
    end
    rows = {}

    for i, _ in ipairs(data.saves) do
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -4, 0, 26)
        row.BackgroundColor3 = Color3.fromRGB(31, 33, 41)
        row.BorderSizePixel = 0
        row.LayoutOrder = i
        row.Parent = list
        local rc = Instance.new("UICorner")
        rc.CornerRadius = UDim.new(0, 6)
        rc.Parent = row

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -98, 1, 0)
        label.Position = UDim2.fromOffset(8, 0)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamMedium
        label.TextSize = 11
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Text = "Save " .. i
        label.Parent = row

        local pick = Instance.new("TextButton")
        pick.Size = UDim2.fromOffset(42, 19)
        pick.Position = UDim2.new(1, -90, 0, 3)
        pick.Text = "PICK"
        pick.Font = Enum.Font.GothamBold
        pick.TextSize = 10
        pick.Parent = row
        local pc = Instance.new("UICorner")
        pc.CornerRadius = UDim.new(0, 5)
        pc.Parent = pick

        local clr = Instance.new("TextButton")
        clr.Size = UDim2.fromOffset(42, 19)
        clr.Position = UDim2.new(1, -45, 0, 3)
        clr.BackgroundColor3 = Color3.fromRGB(64, 42, 46)
        clr.TextColor3 = Color3.fromRGB(240, 200, 200)
        clr.Text = "CLEAR"
        clr.Font = Enum.Font.GothamBold
        clr.TextSize = 10
        clr.Parent = row
        local cc = Instance.new("UICorner")
        cc.CornerRadius = UDim.new(0, 5)
        cc.Parent = clr

        local picked = (data.picked == i)
        pick.BackgroundColor3 = picked and Color3.fromRGB(38, 130, 78) or Color3.fromRGB(46, 48, 58)
        pick.TextColor3 = picked and Color3.fromRGB(200, 255, 220) or Color3.fromRGB(180, 182, 192)
        label.TextColor3 = picked and Color3.fromRGB(140, 235, 180) or Color3.fromRGB(210, 212, 220)

        pick.Activated:Connect(function()
            data.picked = (data.picked == i) and 0 or i
            persist()
            rebuild()
        end)

        clr.Activated:Connect(function()
            table.remove(data.saves, i)
            if data.picked == i then
                data.picked = 0
            elseif data.picked > i then
                data.picked = data.picked - 1
            end
            persist()
            rebuild()
        end)

        rows[#rows + 1] = { parent = row }
    end

    if #data.saves == 1 and data.picked == 0 then
        data.picked = 1
        persist()
        rebuild()
        return
    end

    if data.picked > #data.saves then data.picked = 0 end
end

saveBtn.Activated:Connect(function()
    local hrp = hrpOf()
    if not hrp then return end
    data.saves[#data.saves + 1] = packCF(hrp.CFrame)
    if #data.saves == 1 then data.picked = 1 end
    persist()
    rebuild()
    task.defer(function()
        pcall(function() list.CanvasPosition = Vector2.new(0, list.AbsoluteCanvasSize.Y) end)
    end)
end)

clearAllBtn.Activated:Connect(function()
    data.saves = {}
    data.picked = 0
    persist()
    rebuild()
end)

--============ ROUTE ============
local function rayHit(a, b)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { LP.Character }
    params.IgnoreWater = true
    return workspace:Raycast(a, b - a, params)
end

local function canSee(a, b)
    return rayHit(a, b) == nil
end

local function pathOnce(from, to, radius, budget)
    local ok, out = pcall(function()
        local path = PFS:CreatePath({
            AgentRadius = radius,
            AgentHeight = 5,
            AgentCanJump = true,
            AgentJumpHeight = 12,
            AgentMaxSlope = 70,
            WaypointSpacing = 4,
        })

        local done, failed = false, false
        task.spawn(function()
            if not pcall(function() path:ComputeAsync(from, to) end) then failed = true end
            done = true
        end)

        local t0 = os.clock()
        while not done and (os.clock() - t0) < budget do
            RunService.Heartbeat:Wait()
        end
        if failed or not done then return nil end
        if path.Status ~= Enum.PathStatus.Success then return nil end

        local wps = path:GetWaypoints()
        if #wps < 2 then return nil end

        local list = {}
        for i = 2, #wps do list[#list + 1] = wps[i].Position end
        list[#list + 1] = to
        return list
    end)
    if ok and out then return out end
    return nil
end

-- two passes: a thin agent threads narrow gaps, a fat one ignores clutter
local function findPath(from, to)
    local a = pathOnce(from, to, 1.6, 1.6)
    if a then return a end
    local b = pathOnce(from, to, 4.5, 1.2)
    if b then return b end
    return nil
end

local function pushThrough(p, n, from, to)
    for _, s in ipairs({ 2, 4, 7, 12, 20, 32, 50, 75, 110, 160, 230, 320 }) do
        local beyond = p + n * s
        if canSee(from, p) and canSee(p, beyond) and canSee(beyond, to) then
            return beyond
        end
    end
    return nil
end

local function scanWall(hit, from, to)
    local n = hit.Normal
    local t1 = n:Cross(Vector3.new(0, 1, 0))
    if t1.Magnitude < 0.1 then t1 = n:Cross(Vector3.new(1, 0, 0)) end
    t1 = t1.Unit
    local t2 = n:Cross(t1).Unit
    local base = hit.Position

    for _, r in ipairs({ 3, 6, 10, 16, 24, 34, 46, 62, 82, 106, 136, 172, 216, 270, 335, 410 }) do
        for a = 0, 345, 15 do
            local rad = math.rad(a)
            local p = base + t1 * (math.cos(rad) * r) + t2 * (math.sin(rad) * r)
            local beyond = pushThrough(p, n, from, to)
            if beyond then return beyond end
        end
    end
    return nil
end

-- probe several faces of the blockage, not just the nearest one
local function scanBlock(from, to)
    local dir = to - from
    for _, t in ipairs({ 0.3, 0.5, 0.7, 0.88 }) do
        local probeFrom = from + dir * t
        local hit = rayHit(probeFrom, to)
        if hit then
            local beyond = scanWall(hit, probeFrom, to)
            if beyond then
                if canSee(from, beyond) then return beyond end
                local via = scanWall(rayHit(from, probeFrom) or hit, from, probeFrom)
                if via and canSee(via, beyond) then return via end
                if canSee(from, probeFrom) then return beyond end
            end
        end
    end
    return nil
end

local function findSide(from, to)
    local dir = to - from
    local dist = dir.Magnitude
    local flat = Vector3.new(dir.X, 0, dir.Z)
    if flat.Magnitude < 1 then flat = Vector3.new(1, 0, 0) end
    flat = flat.Unit
    local side = Vector3.new(-flat.Z, 0, flat.X)
    for _, off in ipairs({ 8, 16, 26, 40, 58, 82, 112, 150 }) do
        for _, s in ipairs({ 1, -1 }) do
            local mid = from + flat * (dist * 0.5) + side * (off * s) + Vector3.new(0, 4, 0)
            if canSee(from, mid) and canSee(mid, to) then
                return mid
            end
        end
    end
    return nil
end

local function findClimb(from, to)
    local h = 12
    for _ = 1, 5 do
        local u1 = from + Vector3.new(0, h, 0)
        local u2 = to + Vector3.new(0, h, 0)
        if canSee(from, u1) and canSee(u1, u2) and canSee(u2, to) then
            return { u1, u2 }
        end
        h = h * 1.9
    end
    return nil
end

-- drop corners that are already visible from the previous kept point
local function smooth(from, route)
    local out, last = {}, from
    for i = 1, #route do
        local p = route[i]
        local nxt = route[i + 1]
        if not nxt or not canSee(last, nxt) then
            out[#out + 1] = p
            last = p
        end
    end
    return out
end

local function buildRoute(from, to, depth)
    if canSee(from, to) then return { to }, "direct" end

    local dist = (to - from).Magnitude
    if dist > 8 then
        local path = findPath(from, to)
        if path and #path > 0 then return smooth(from, path), "path" end
    end

    local beyond = scanBlock(from, to)
    if beyond then
        if depth < 1 then
            local rest = buildRoute(beyond, to, depth + 1)
            if rest then
                local list = { beyond }
                for _, p in ipairs(rest) do list[#list + 1] = p end
                return smooth(from, list), "hole"
            end
        end
        return { beyond, to }, "hole"
    end

    local s = findSide(from, to)
    if s then return { s, to }, "side" end

    local c = findClimb(from, to)
    if c then return { c[1], c[2], to }, "climb" end

    return nil, "noclip"
end

--============ TRAVEL ============
local function tweenLeg(dest, myToken)
    local hrp = hrpOf()
    if not hrp then return false end
    local dist = (dest.Position - hrp.Position).Magnitude
    local dur = math.clamp(dist / SPEED, MIN_T, MAX_T)
    dur = dur * (0.94 + math.random() * 0.12)

    hrp.Anchored = true
    local tw = TweenService:Create(
        hrp,
        TweenInfo.new(dur, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
        { CFrame = dest }
    )
    local done = false
    local c = tw.Completed:Connect(function() done = true end)
    tw:Play()

    local t0 = os.clock()
    while not done and (os.clock() - t0) < (dur + 0.6) do
        if token ~= myToken or not alive() then break end
        RunService.Heartbeat:Wait()
    end

    if c then pcall(function() c:Disconnect() end) end
    local me = hrpOf()
    if me then
        pcall(function()
            me.Anchored = false
            me.AssemblyLinearVelocity = Vector3.zero
        end)
    end
    return token == myToken and alive()
end

local function travel(target)
    if busy then return end
    local hrp = hrpOf()
    if not hrp then return end

    busy = true
    token = token + 1
    local myToken = token
    playBtn.Text = "ROUTING"
    playBtn.BackgroundColor3 = Color3.fromRGB(70, 110, 60)

    setNoclip(true)

    local route, style = buildRoute(hrp.Position, target.Position, 0)

    if route then
        for _, point in ipairs(route) do
            if token ~= myToken or not alive() then break end
            if not tweenLeg(CFrame.lookAt(point, point + target.LookVector), myToken) then break end
        end
    else
        tweenLeg(target, myToken)
    end

    local me = hrpOf()
    if me and token == myToken then pcall(function() me.CFrame = target end) end

    setNoclip(false)
    busy = false
    playBtn.Text = string.upper(style)
    playBtn.BackgroundColor3 = Color3.fromRGB(38, 120, 76)
    task.delay(1.4, function()
        if not busy then playBtn.Text = "PLAY" end
    end)

    if token == myToken then
        learnUp(style)
        celebrate()
    end
end

--============ CELEBRATE ============
function celebrate()
    if bannerBusy then return end
    bannerBusy = true

    local cam = workspace.CurrentCamera
    local vp = cam and cam.ViewportSize or Vector2.new(800, 600)
    local cx, cy = vp.X / 2, vp.Y / 2

    local txt = Instance.new("TextLabel")
    txt.Size = UDim2.fromOffset(260, 42)
    txt.Position = UDim2.fromOffset(cx - 130, cy - 21)
    txt.BackgroundTransparency = 1
    txt.Font = Enum.Font.GothamBlack
    txt.Text = "first best tween"
    txt.TextSize = 26
    txt.TextColor3 = Color3.fromRGB(255, 255, 255)
    txt.TextTransparency = 1
    txt.Parent = gui
    local tst = Instance.new("UIStroke")
    tst.Color = Color3.fromRGB(90, 180, 255)
    tst.Thickness = 2
    tst.Transparency = 1
    tst.Parent = txt

    TweenService:Create(txt, TweenInfo.new(0.12), { TextTransparency = 0 }):Play()
    TweenService:Create(tst, TweenInfo.new(0.12), { Transparency = 0 }):Play()

    for i = 1, 12 do
        local dot = Instance.new("Frame")
        dot.Size = UDim2.fromOffset(6, 6)
        dot.Position = UDim2.fromOffset(cx - 3, cy - 3)
        dot.BackgroundColor3 = Color3.fromHSV((i * 0.083) % 1, 0.65, 1)
        dot.BorderSizePixel = 0
        dot.Parent = gui
        local dc = Instance.new("UICorner")
        dc.CornerRadius = UDim.new(1, 0)
        dc.Parent = dot

        local ang = math.rad(i * 30 + math.random(-12, 12))
        local d = math.random(65, 145)
        TweenService:Create(
            dot,
            TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {
                Position = UDim2.fromOffset(cx + math.cos(ang) * d - 2, cy + math.sin(ang) * d - 2),
                Size = UDim2.fromOffset(2, 2),
                BackgroundTransparency = 1,
            }
        ):Play()
        task.delay(0.55, function() if dot then dot:Destroy() end end)
    end

    task.delay(0.55, function()
        TweenService:Create(txt, TweenInfo.new(0.22), { TextTransparency = 1 }):Play()
        TweenService:Create(tst, TweenInfo.new(0.22), { Transparency = 1 }):Play()
    end)

    task.delay(0.85, function()
        if txt then txt:Destroy() end
        bannerBusy = false
    end)
end

playBtn.Activated:Connect(function()
    if busy then return end
    local i = data.picked
    if i == 0 or not data.saves[i] then
        playBtn.Text = "NO PICK"
        task.delay(1, function() if not busy then playBtn.Text = "PLAY" end end)
        return
    end
    travel(unpackCF(data.saves[i]))
end)

--============ API / WATCHDOG ============
local function destroy()
    busy = false
    token = token + 1
    setNoclip(false)
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    pcall(function() gui:Destroy() end)
    if getgenv then getgenv().FirstBestTween = nil end
end

local api = { destroy = destroy, version = "4.0", data = data, celebrate = celebrate }
if getgenv then getgenv().FirstBestTween = api end

task.spawn(function()
    pcall(function()
        local body = game:HttpGet(string.format(PATCH_URL, placeKey))
        if typeof(body) == "string" and #body > 20 and not body:find("404: Not Found") then
            local fn = typeof(loadstring) == "function" and loadstring(body)
            if fn then pcall(fn, api) end
        end
    end)
end)

task.spawn(function()
    while getgenv and getgenv().FirstBestTween == api do
        task.wait(1.5)
        pcall(function()
            if not gui.Parent then
                if typeof(gethui) == "function" then
                    local ok, h = pcall(gethui)
                    if ok and h then gui.Parent = h end
                else
                    gui.Parent = cloneref(game:GetService("CoreGui"))
                end
            end
        end)
    end
end)

closeBtn.Activated:Connect(destroy)
rebuild()

end

--============ BOOT ============
local ok, err = xpcall(boot, function(e) return e end)

if not ok then
    warn("[FirstBestTween] " .. tostring(err))
    if bootCount < 2 and typeof(loadstring) == "function" then
        task.wait(1)
        pcall(function()
            loadstring(game:HttpGet(RAW_URL .. "?retry=" .. tostring(os.time())))()
        end)
    end
end
