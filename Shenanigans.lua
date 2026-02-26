--[[
    Imp Hub X - V4 (Mobile/Delta Friendly)
    Full script (single paste)
    Notes:
    - Responsive + centered on mobile
    - Drag + minimize
    - Scrollable sidebar + tab pages
    - Real UI controls (toggles, sliders, mode buttons)
    - Mechanics included (targeting, aimlock, autoblock, autofarm scaffold)
    - Remote hooks are isolated in one section (wire your game remotes there)
]]

--// Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

pcall(function() StarterGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeRight end)
pcall(function() LocalPlayer.PlayerGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeRight end)

--// Parent GUI
local ParentGui = (type(gethui) == "function" and gethui())
    or (pcall(function() return game:GetService("CoreGui") end) and game:GetService("CoreGui"))
    or LocalPlayer:WaitForChild("PlayerGui")

if not ParentGui then return end

if ParentGui:FindFirstChild("ImpHubX_V4") then
    ParentGui.ImpHubX_V4:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ImpHubX_V4"
ScreenGui.IgnoreGuiInset = true
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = ParentGui

--// Theme + State
local Theme = {
    BG = Color3.fromRGB(18, 19, 25),
    Sidebar = Color3.fromRGB(15, 16, 21),
    Panel = Color3.fromRGB(23, 24, 31),
    Stroke = Color3.fromRGB(63, 64, 80),
    Accent = Color3.fromRGB(170, 72, 255),
    Text = Color3.fromRGB(239, 240, 244),
    SubText = Color3.fromRGB(160, 161, 176),
    Success = Color3.fromRGB(83, 210, 120),
    Danger = Color3.fromRGB(255, 90, 90)
}

local State = {
    Toggles = {
        Farming = false,
        EnableFarm = false,
        FastAttack = true,
        UseSkills = true,
        FaceAtTarget = true,

        Blocking = true,
        AutoBlock = true,
        AutoPunish = true,
        FaceAttacker = true,
        ShowRange = false,

        Aimlock = false,
        ESP = false,
        Boxes = true,
        Tracers = true,
        HealthBar = true,
        Distance = true,
        Names = true,
        TeamCheck = false,
    },
    Farming = {
        TargetMethod = "Closest", -- Closest / Lowest Health / Camera
        DetectionRange = 20,
        BlockDelay = 0,
    },
    Aim = {
        Mode = "Camera", -- Camera / Silent
        TargetPart = "Head", -- Head / HumanoidRootPart / UpperTorso
        Prediction = 0.135,
        Smoothness = 0.17,
    },
    Runtime = {
        Target = nil,
        LastBlock = 0,
        LastAttack = 0,
        Status = "[ DISABLED ]",
    }
}

--// Utility
local function getCharacter(player) return player and player.Character end
local function getHumanoid(player)
    local c = getCharacter(player)
    return c and c:FindFirstChildOfClass("Humanoid")
end
local function getRoot(player)
    local c = getCharacter(player)
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function isValidTarget(player)
    if not player or player == LocalPlayer then return false end
    if State.Toggles.TeamCheck and LocalPlayer.Team and player.Team == LocalPlayer.Team then return false end
    local hum, root = getHumanoid(player), getRoot(player)
    return hum and root and hum.Health > 0
end

local function distanceTo(player)
    local localRoot, targetRoot = getRoot(LocalPlayer), getRoot(player)
    if not localRoot or not targetRoot then return math.huge end
    return (localRoot.Position - targetRoot.Position).Magnitude
end

local function chooseTarget(method)
    local candidates = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if isValidTarget(plr) then
            local dist = distanceTo(plr)
            if dist <= State.Farming.DetectionRange then
                table.insert(candidates, {Player = plr, Distance = dist})
            end
        end
    end
    if #candidates == 0 then return nil end

    if method == "Closest" then
        table.sort(candidates, function(a,b) return a.Distance < b.Distance end)
        return candidates[1].Player
    elseif method == "Lowest Health" then
        table.sort(candidates, function(a,b)
            return getHumanoid(a.Player).Health < getHumanoid(b.Player).Health
        end)
        return candidates[1].Player
    else
        local center = Camera.ViewportSize / 2
        local best, bestScore = nil, math.huge
        for _, entry in ipairs(candidates) do
            local root = getRoot(entry.Player)
            if root then
                local p, onScreen = Camera:WorldToViewportPoint(root.Position)
                if onScreen then
                    local delta = (Vector2.new(p.X, p.Y) - center).Magnitude
                    local score = delta + (entry.Distance * 0.35)
                    if score < bestScore then
                        bestScore = score
                        best = entry.Player
                    end
                end
            end
        end
        return best
    end
end

local function predictedPosition(part)
    local t = State.Aim.Prediction
    local pos = part.Position + part.AssemblyLinearVelocity * t
    if State.Aim.TargetPart ~= "HumanoidRootPart" then
        pos += Vector3.new(0, -0.5 * Workspace.Gravity * (t*t) * 0.06, 0)
    end
    return pos
end

--// Remote hooks (wire your game remotes here)
local function doAttack(target)
    -- EXAMPLE:
    -- game.ReplicatedStorage.Remotes.Attack:FireServer(target)
end
local function doSkill(target)
    -- EXAMPLE:
    -- game.ReplicatedStorage.Remotes.Skill:FireServer("SkillName", target)
end
local function doBlock()
    -- EXAMPLE:
    -- game.ReplicatedStorage.Remotes.Block:FireServer(true)
end

--// Responsive window
local function getWindowSize()
    local v = Camera.ViewportSize
    local width = math.clamp(math.floor(v.X * 0.90), 680, 1150)
    local height = math.clamp(math.floor(v.Y * 0.82), 410, 720)
    return width, height
end

local W, H = getWindowSize()

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.fromOffset(W, H)
Main.Position = UDim2.new(0.5, -W/2, 0.5, -H/2)
Main.BackgroundColor3 = Theme.BG
Main.BackgroundTransparency = 0.07
Main.Active = true
Main.Parent = ScreenGui
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 10)
local MainStroke = Instance.new("UIStroke", Main)
MainStroke.Color = Theme.Stroke
MainStroke.Transparency = 0.3

local UIScale = Instance.new("UIScale", Main)
local function refreshScale()
    local sx = Camera.ViewportSize.X / 1280
    local sy = Camera.ViewportSize.Y / 720
    UIScale.Scale = math.clamp(math.min(sx, sy), 0.75, 1)
end
refreshScale()

Camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
    local newW, newH = getWindowSize()
    Main.Size = UDim2.fromOffset(newW, newH)
    if Main.Visible then
        Main.Position = UDim2.new(0.5, -newW/2, 0.5, -newH/2)
    end
    refreshScale()
end)

--// Topbar
local Topbar = Instance.new("Frame")
Topbar.Size = UDim2.new(1, 0, 0, 38)
Topbar.BackgroundTransparency = 1
Topbar.Parent = Main

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -120, 1, 0)
Title.Position = UDim2.fromOffset(14, 0)
Title.BackgroundTransparency = 1
Title.Text = "Imp Hub X"
Title.Font = Enum.Font.GothamSemibold
Title.TextSize = 15
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.TextColor3 = Theme.Text
Title.Parent = Topbar

local Subtitle = Instance.new("TextLabel")
Subtitle.Size = UDim2.new(1, -120, 0, 14)
Subtitle.Position = UDim2.fromOffset(14, 22)
Subtitle.BackgroundTransparency = 1
Subtitle.Text = "Jujutsu Shenanigans - Version 4"
Subtitle.Font = Enum.Font.Gotham
Subtitle.TextSize = 11
Subtitle.TextXAlignment = Enum.TextXAlignment.Left
Subtitle.TextColor3 = Theme.SubText
Subtitle.Parent = Topbar

local Mini = Instance.new("TextButton")
Mini.Size = UDim2.fromOffset(46, 46)
Mini.Position = UDim2.new(0.5, -23, 0.04, 0)
Mini.BackgroundColor3 = Theme.BG
Mini.Text = "🜲"
Mini.TextColor3 = Theme.Text
Mini.TextSize = 22
Mini.Visible = false
Mini.Parent = ScreenGui
Instance.new("UICorner", Mini).CornerRadius = UDim.new(1,0)
Instance.new("UIStroke", Mini).Color = Theme.Accent

local function topBtn(txt, x, col, cb)
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(30, 24)
    b.Position = UDim2.new(1, x, 0.5, -12)
    b.BackgroundColor3 = Theme.Panel
    b.Text = txt
    b.TextColor3 = col
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.Parent = Topbar
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    b.MouseButton1Click:Connect(cb)
end

topBtn("✕", -40, Theme.Danger, function() ScreenGui:Destroy() end)
topBtn("—", -76, Theme.Text, function()
    Main.Visible = false
    Mini.Visible = true
end)

Mini.MouseButton1Click:Connect(function()
    local ww, hh = getWindowSize()
    Main.Position = UDim2.new(0.5, -ww/2, 0.5, -hh/2)
    Main.Visible = true
    Mini.Visible = false
end)

-- drag
local function enableDrag(frame, handle)
    local dragging, dragStart, startPos, dragInput = false, nil, nil, nil
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragInput = input
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input == dragInput then
            local d = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end
enableDrag(Main, Topbar)
enableDrag(Mini, Mini)

--// Layout: sidebar + body
local Sidebar = Instance.new("ScrollingFrame")
Sidebar.Size = UDim2.new(0, 220, 1, -48)
Sidebar.Position = UDim2.fromOffset(10, 38)
Sidebar.BackgroundColor3 = Theme.Sidebar
Sidebar.BackgroundTransparency = 0.30
Sidebar.ScrollBarThickness = 2
Sidebar.AutomaticCanvasSize = Enum.AutomaticSize.Y
Sidebar.CanvasSize = UDim2.new()
Sidebar.BorderSizePixel = 0
Sidebar.Parent = Main
Instance.new("UICorner", Sidebar).CornerRadius = UDim.new(0, 8)

local SidePad = Instance.new("UIPadding", Sidebar)
SidePad.PaddingTop = UDim.new(0, 8)
SidePad.PaddingBottom = UDim.new(0, 10)
SidePad.PaddingLeft = UDim.new(0, 8)
SidePad.PaddingRight = UDim.new(0, 8)

local SideList = Instance.new("UIListLayout", Sidebar)
SideList.Padding = UDim.new(0, 7)
SideList.HorizontalAlignment = Enum.HorizontalAlignment.Center

local Body = Instance.new("Frame")
Body.Size = UDim2.new(1, -240, 1, -48)
Body.Position = UDim2.fromOffset(230, 38)
Body.BackgroundTransparency = 1
Body.Parent = Main

local Tabs, TabButtons = {}, {}

local function createTab(name, icon)
    local frame = Instance.new("ScrollingFrame")
    frame.Size = UDim2.new(1,0,1,0)
    frame.BackgroundTransparency = 1
    frame.ScrollBarThickness = 2
    frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    frame.CanvasSize = UDim2.new()
    frame.Visible = false
    frame.BorderSizePixel = 0
    frame.Parent = Body

    local p = Instance.new("UIPadding", frame)
    p.PaddingTop = UDim.new(0, 6)
    p.PaddingBottom = UDim.new(0, 8)
    p.PaddingLeft = UDim.new(0, 2)
    p.PaddingRight = UDim.new(0, 4)

    local l = Instance.new("UIListLayout", frame)
    l.Padding = UDim.new(0, 9)

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1,0,0,34)
    btn.BackgroundColor3 = Theme.Panel
    btn.BackgroundTransparency = 1
    btn.Text = ("  %s  %s"):format(icon, name)
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 13
    btn.TextColor3 = Theme.SubText
    btn.Parent = Sidebar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,6)

    local marker = Instance.new("Frame")
    marker.Size = UDim2.new(0,4,0.6,0)
    marker.Position = UDim2.new(0,2,0.2,0)
    marker.BackgroundColor3 = Theme.Accent
    marker.Visible = false
    marker.Parent = btn
    Instance.new("UICorner", marker).CornerRadius = UDim.new(1,0)

    btn.MouseButton1Click:Connect(function()
        for _, t in ipairs(Tabs) do t.Frame.Visible = false end
        for _, b in ipairs(TabButtons) do
            b.Button.BackgroundTransparency = 1
            b.Button.TextColor3 = Theme.SubText
            b.Marker.Visible = false
        end
        frame.Visible = true
        btn.BackgroundTransparency = 0.35
        btn.TextColor3 = Theme.Text
        marker.Visible = true
    end)

    table.insert(Tabs, {Frame = frame})
    table.insert(TabButtons, {Button = btn, Marker = marker})
    return frame
end

--// Controls
local function createPanel(parent, title, toggleKey)
    local panel = Instance.new("Frame")
    panel.Size = UDim2.new(1, -6, 0, 44)
    panel.BackgroundColor3 = Theme.Panel
    panel.BackgroundTransparency = 0.10
    panel.Parent = parent
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 7)
    Instance.new("UIStroke", panel).Color = Theme.Stroke

    local header = Instance.new("TextLabel")
    header.Size = UDim2.new(1, -20, 0, 30)
    header.Position = UDim2.fromOffset(12, 4)
    header.BackgroundTransparency = 1
    header.Text = title
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.Font = Enum.Font.GothamSemibold
    header.TextSize = 15
    header.TextColor3 = Theme.Text
    header.Parent = panel

    local contentY = 36

    local function addLabel(text, color, size)
        local t = Instance.new("TextLabel")
        t.Size = UDim2.new(1, -18, 0, size or 20)
        t.Position = UDim2.fromOffset(10, contentY)
        t.BackgroundTransparency = 1
        t.Text = text
        t.TextXAlignment = Enum.TextXAlignment.Left
        t.Font = Enum.Font.Gotham
        t.TextSize = 13
        t.TextColor3 = color or Theme.SubText
        t.Parent = panel
        contentY += (size or 20)
        panel.Size = UDim2.new(1, -6, 0, contentY + 8)
        return t
    end

    local function addToggleLine(text, key)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -18, 0, 24)
        row.Position = UDim2.fromOffset(10, contentY)
        row.BackgroundTransparency = 1
        row.Parent = panel

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -54, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = text
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 13
        lbl.TextColor3 = Theme.Text
        lbl.Parent = row

        local tgl = Instance.new("TextButton")
        tgl.Size = UDim2.fromOffset(44, 20)
        tgl.Position = UDim2.new(1, -44, 0.5, -10)
        tgl.Text = ""
        tgl.AutoButtonColor = false
        tgl.BackgroundColor3 = Color3.fromRGB(58,58,68)
        tgl.Parent = row
        Instance.new("UICorner", tgl).CornerRadius = UDim.new(1,0)

        local knob = Instance.new("Frame")
        knob.Size = UDim2.fromOffset(16,16)
        knob.Position = UDim2.new(0,2,0.5,-8)
        knob.BackgroundColor3 = Theme.Text
        knob.Parent = tgl
        Instance.new("UICorner", knob).CornerRadius = UDim.new(1,0)

        local function sync()
            local on = State.Toggles[key]
            tgl.BackgroundColor3 = on and Theme.Accent or Color3.fromRGB(58,58,68)
            knob.Position = on and UDim2.new(1,-18,0.5,-8) or UDim2.new(0,2,0.5,-8)
        end
        sync()
        tgl.MouseButton1Click:Connect(function()
            State.Toggles[key] = not State.Toggles[key]
            sync()
        end)

        contentY += 24
        panel.Size = UDim2.new(1, -6, 0, contentY + 8)
    end

    local function addCycleLine(text, getter, setter, values)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -18, 0, 24)
        row.Position = UDim2.fromOffset(10, contentY)
        row.BackgroundTransparency = 1
        row.Parent = panel

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.55, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = text
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 13
        lbl.TextColor3 = Theme.Text
        lbl.Parent = row

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0.45, -4, 1, -2)
        btn.Position = UDim2.new(0.55, 4, 0, 1)
        btn.BackgroundColor3 = Color3.fromRGB(30,31,40)
        btn.TextColor3 = Theme.Text
        btn.Font = Enum.Font.GothamSemibold
        btn.TextSize = 12
        btn.Parent = row
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0,5)

        local function sync() btn.Text = tostring(getter()) end
        sync()
        btn.MouseButton1Click:Connect(function()
            local now = getter()
            local idx = 1
            for i,v in ipairs(values) do if v == now then idx = i break end end
            idx += 1
            if idx > #values then idx = 1 end
            setter(values[idx])
            sync()
        end)

        contentY += 24
        panel.Size = UDim2.new(1, -6, 0, contentY + 8)
    end

    local function addSliderLine(text, getter, setter, minv, maxv, step)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -18, 0, 34)
        row.Position = UDim2.fromOffset(10, contentY)
        row.BackgroundTransparency = 1
        row.Parent = panel

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 0, 14)
        lbl.BackgroundTransparency = 1
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 12
        lbl.TextColor3 = Theme.Text
        lbl.Parent = row

        local bar = Instance.new("Frame")
        bar.Size = UDim2.new(1, 0, 0, 10)
        bar.Position = UDim2.fromOffset(0, 18)
        bar.BackgroundColor3 = Color3.fromRGB(53,54,65)
        bar.Parent = row
        Instance.new("UICorner", bar).CornerRadius = UDim.new(1,0)

        local fill = Instance.new("Frame")
        fill.Size = UDim2.new(0,0,1,0)
        fill.BackgroundColor3 = Theme.Accent
        fill.Parent = bar
        Instance.new("UICorner", fill).CornerRadius = UDim.new(1,0)

        local dragging = false
        local function clampSet(v)
            v = math.clamp(v, minv, maxv)
            local snapped = math.floor((v - minv)/step + 0.5)*step + minv
            setter(snapped)
        end
        local function sync()
            local val = getter()
            local alpha = (val - minv) / (maxv - minv)
            fill.Size = UDim2.new(alpha,0,1,0)
            lbl.Text = ("%s: %s"):format(text, tostring(val))
        end
        sync()

        local function fromX(x)
            local rel = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
            clampSet(minv + (maxv - minv)*rel)
            sync()
        end

        bar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                fromX(input.Position.X)
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                fromX(input.Position.X)
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)

        contentY += 34
        panel.Size = UDim2.new(1, -6, 0, contentY + 8)
    end

    if toggleKey then
        local topToggle = Instance.new("TextButton")
        topToggle.Size = UDim2.fromOffset(44, 20)
        topToggle.Position = UDim2.new(1, -54, 0.5, -10)
        topToggle.Text = ""
        topToggle.AutoButtonColor = false
        topToggle.BackgroundColor3 = Color3.fromRGB(58,58,68)
        topToggle.Parent = panel
        Instance.new("UICorner", topToggle).CornerRadius = UDim.new(1,0)

        local knob = Instance.new("Frame")
        knob.Size = UDim2.fromOffset(16,16)
        knob.Position = UDim2.new(0,2,0.5,-8)
        knob.BackgroundColor3 = Theme.Text
        knob.Parent = topToggle
        Instance.new("UICorner", knob).CornerRadius = UDim.new(1,0)

        local function syncTop()
            local on = State.Toggles[toggleKey]
            topToggle.BackgroundColor3 = on and Theme.Accent or Color3.fromRGB(58,58,68)
            knob.Position = on and UDim2.new(1,-18,0.5,-8) or UDim2.new(0,2,0.5,-8)
        end
        syncTop()
        topToggle.MouseButton1Click:Connect(function()
            State.Toggles[toggleKey] = not State.Toggles[toggleKey]
            syncTop()
        end)
    end

    return {
        Panel = panel,
        AddLabel = addLabel,
        AddToggle = addToggleLine,
        AddCycle = addCycleLine,
        AddSlider = addSliderLine,
    }
end

--// Tabs
local TabCombat = createTab("Combat & Auto Farm", "⚔️")
local TabVisual = createTab("ESP Engine", "👁️")
local TabMisc = createTab("Miscellaneous", "🧩")
local TabSet = createTab("Credits & Settings", "⚙️")

-- Combat panels
local Farm = createPanel(TabCombat, "Farming", "Farming")
Farm.AddCycle("Select Target Method", function() return State.Farming.TargetMethod end, function(v) State.Farming.TargetMethod = v end, {"Closest","Lowest Health","Camera"})
Farm.AddToggle("Face At Target", "FaceAtTarget")
Farm.AddToggle("Fast Attack", "FastAttack")
Farm.AddToggle("Use Skills", "UseSkills")
Farm.AddToggle("Enable Farm", "EnableFarm")
Farm.AddSlider("Detection Range", function() return State.Farming.DetectionRange end, function(v) State.Farming.DetectionRange = v end, 5, 60, 1)

local Block = createPanel(TabCombat, "Blocking", "Blocking")
Block.AddToggle("Enable Auto Block", "AutoBlock")
Block.AddToggle("Auto Punish (Attack Back)", "AutoPunish")
Block.AddToggle("Face Attacker", "FaceAttacker")
Block.AddToggle("Show Range", "ShowRange")
Block.AddSlider("Block Delay", function() return State.Farming.BlockDelay end, function(v) State.Farming.BlockDelay = v end, 0, 2, 0.05)

local Aim = createPanel(TabCombat, "Aimlock", "Aimlock")
Aim.AddCycle("Aimlock Mode", function() return State.Aim.Mode end, function(v) State.Aim.Mode = v end, {"Camera","Silent"})
Aim.AddCycle("Target Part", function() return State.Aim.TargetPart end, function(v) State.Aim.TargetPart = v end, {"Head","HumanoidRootPart","UpperTorso"})
Aim.AddSlider("Prediction", function() return State.Aim.Prediction end, function(v) State.Aim.Prediction = v end, 0, 0.35, 0.005)
Aim.AddSlider("Smoothness", function() return State.Aim.Smoothness end, function(v) State.Aim.Smoothness = v end, 0.01, 1, 0.01)

local Status = createPanel(TabCombat, "Status", nil)
Status.AddLabel("System Status", Theme.Text, 20)
local statusText = Status.AddLabel(State.Runtime.Status, Theme.Danger, 24)
statusText.Font = Enum.Font.GothamBold
Status.AddLabel("Wait for activation...", Theme.SubText, 20)

-- ESP
local ESP = createPanel(TabVisual, "Configurations", "ESP")
ESP.AddToggle("Box", "Boxes")
ESP.AddToggle("Tracers", "Tracers")
ESP.AddToggle("Health Bar", "HealthBar")
ESP.AddToggle("Distance", "Distance")
ESP.AddToggle("Name", "Names")
ESP.AddToggle("Team Check", "TeamCheck")

local Misc = createPanel(TabMisc, "Misc", nil)
Misc.AddLabel("Mobile centered layout fixed.")
Misc.AddLabel("Scrollable groups fixed.")
Misc.AddLabel("Drag topbar to move UI.", Theme.Text)

local Set = createPanel(TabSet, "Credits", nil)
Set.AddLabel("Imp Hub X - V4")
Set.AddLabel("Android / Delta Friendly")
Set.AddLabel("Wire remotes in doAttack/doSkill/doBlock", Theme.Text)

--// Runtime loop
local function setStatus(on)
    State.Runtime.Status = on and "[ ENABLED ]" or "[ DISABLED ]"
    statusText.Text = State.Runtime.Status
    statusText.TextColor3 = on and Theme.Success or Theme.Danger
end

RunService.Heartbeat:Connect(function(dt)
    local target = chooseTarget(State.Farming.TargetMethod)
    State.Runtime.Target = target

    local active = State.Toggles.Farming or State.Toggles.Blocking or State.Toggles.Aimlock
    setStatus(active)

    -- Autofarm
    if target and State.Toggles.Farming and State.Toggles.EnableFarm then
        local localRoot = getRoot(LocalPlayer)
        local targetRoot = getRoot(target)

        if localRoot and targetRoot and State.Toggles.FaceAtTarget then
            local desired = CFrame.lookAt(localRoot.Position, targetRoot.Position)
            localRoot.CFrame = localRoot.CFrame:Lerp(desired, math.clamp(7 * dt, 0, 1))
        end

        if State.Toggles.FastAttack then
            if tick() - State.Runtime.LastAttack >= 0.08 then
                State.Runtime.LastAttack = tick()
                doAttack(target)
            end
        end

        if State.Toggles.UseSkills then
            -- tune cooldown as needed
            if tick() % 1.2 < dt then
                doSkill(target)
            end
        end
    end

    -- Aimlock
    if target and State.Toggles.Aimlock then
        local ch = target.Character
        local part = ch and ch:FindFirstChild(State.Aim.TargetPart)
        if part and State.Aim.Mode == "Camera" then
            local pred = predictedPosition(part)
            local cam = Camera.CFrame
            local goal = CFrame.lookAt(cam.Position, pred)
            Camera.CFrame = cam:Lerp(goal, State.Aim.Smoothness)
        end
    end

    -- AutoBlock
    if target and State.Toggles.Blocking and State.Toggles.AutoBlock then
        local now = tick()
        if (now - State.Runtime.LastBlock) >= State.Farming.BlockDelay then
            if distanceTo(target) <= State.Farming.DetectionRange then
                State.Runtime.LastBlock = now
                doBlock()
                if State.Toggles.AutoPunish then
                    doAttack(target)
                end
            end
        end
    end
end)

-- open first tab
if TabButtons[1] then
    TabButtons[1].Button.MouseButton1Click:Fire()
end
