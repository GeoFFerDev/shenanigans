--[[
╔══════════════════════════════════════════════════════════════╗
║        IMP HUB X  v5  —  Jujutsu Shenanigans                ║
║        Built on Fluent Local UI Framework                    ║
║        Delta / Mobile / PC Compatible                        ║
║        Toggle GUI: RightShift                                ║
╚══════════════════════════════════════════════════════════════╝
]]

-- ─────────────────────────────────────────────────────────────
-- Services
-- ─────────────────────────────────────────────────────────────
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local Lighting         = game:GetService("Lighting")
local HttpService      = game:GetService("HttpService")
local TeleportService  = game:GetService("TeleportService")
local StarterGui       = game:GetService("StarterGui")

local LP     = Players.LocalPlayer
local Mouse  = LP:GetMouse()
local Camera = workspace.CurrentCamera

-- ─────────────────────────────────────────────────────────────
-- Mount (matches template exactly – gethui > CoreGui > PlayerGui)
-- ─────────────────────────────────────────────────────────────
pcall(function() StarterGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeRight end)
pcall(function() LP.PlayerGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeRight end)

local TargetParent = (type(gethui) == "function" and gethui())
    or (pcall(function() return game:GetService("CoreGui") end) and game:GetService("CoreGui"))
    or LP:WaitForChild("PlayerGui")

if not TargetParent then return end

local _old = TargetParent:FindFirstChild("ImpHubXv5")
if _old then _old:Destroy() end

local ScreenGui = Instance.new("ScreenGui", TargetParent)
ScreenGui.Name           = "ImpHubXv5"
ScreenGui.ResetOnSpawn   = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder   = 999

-- ─────────────────────────────────────────────────────────────
-- Fluent Theme (matches template, accent changed to purple)
-- ─────────────────────────────────────────────────────────────
local Theme = {
    Background  = Color3.fromRGB(22, 22, 28),
    Sidebar     = Color3.fromRGB(15, 15, 20),
    Accent      = Color3.fromRGB(120, 50, 230),
    AccentLight = Color3.fromRGB(155, 85, 255),
    Text        = Color3.fromRGB(240, 240, 240),
    SubText     = Color3.fromRGB(145, 145, 158),
    Button      = Color3.fromRGB(32, 32, 40),
    ButtonHov   = Color3.fromRGB(42, 38, 58),
    Stroke      = Color3.fromRGB(55, 55, 65),
    Green       = Color3.fromRGB(50, 210, 90),
    Red         = Color3.fromRGB(235, 60, 60),
    DropBg      = Color3.fromRGB(28, 28, 36),
}

-- ─────────────────────────────────────────────────────────────
-- Config (single source of truth)
-- ─────────────────────────────────────────────────────────────
local Cfg = {
    Farm    = { Enabled=false, TargetPlayer="All", TargetMethod="Closest",
                FaceTarget=true, FastAttack=true, UseSkills=true },
    Block   = { Enabled=false, AutoBlock=true, AutoPunish=true, FaceAttacker=true,
                ShowRange=false, DetectRange=20, BlockDelay=0 },
    Aim     = { Enabled=false, Mode="Camera", TargetPart="Head", Prediction=false },
    Combat  = { TpMethod="Tween", MoveMode="Orbit", TweenSpeed=135, FollowDist=4,
                SmartKiting=true, AutoFlee=false, FleeHP=20, PriorClosest=true,
                HunterMode=false, SkillName="Divergent Fist", SkillDelay=0,
                AvoidNoTarget=true, SemiKillAura=false, SpinBot=false },
    ESP     = { Enabled=false, Box=true, Tracers=true, HealthBar=true,
                Distance=true, Name=true, Moveset=true },
    Misc    = { AntiRagdoll=false, AutoTech=false, WsBypass=false, Speed=100,
                InfJump=false, Fullbright=false, WhiteScreen=false,
                AntiAFK=true, ClickTP=false, TimeHour=14 },
}

-- ─────────────────────────────────────────────────────────────
-- 1. Minimise Toggle Icon (same as template)
-- ─────────────────────────────────────────────────────────────
local ToggleIcon = Instance.new("TextButton", ScreenGui)
ToggleIcon.Size                  = UDim2.new(0, 46, 0, 46)
ToggleIcon.Position              = UDim2.new(0.5, -23, 0.05, 0)
ToggleIcon.BackgroundColor3      = Theme.Background
ToggleIcon.BackgroundTransparency = 0.08
ToggleIcon.Text                  = "⚔"
ToggleIcon.TextSize              = 22
ToggleIcon.TextColor3            = Theme.Text
ToggleIcon.Font                  = Enum.Font.GothamBold
ToggleIcon.Visible               = false
ToggleIcon.ZIndex                = 10
Instance.new("UICorner", ToggleIcon).CornerRadius = UDim.new(1, 0)
local _is = Instance.new("UIStroke", ToggleIcon)
_is.Color = Theme.Accent; _is.Thickness = 2

-- ─────────────────────────────────────────────────────────────
-- 2. Main Window (wider than template to fit two panels)
-- ─────────────────────────────────────────────────────────────
local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size               = UDim2.new(0, 680, 0, 500)
MainFrame.Position           = UDim2.new(0.5, -340, 0.5, -250)
MainFrame.BackgroundColor3   = Theme.Background
MainFrame.BackgroundTransparency = 0.06
MainFrame.Active             = true
MainFrame.BorderSizePixel    = 0
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)
local _ms = Instance.new("UIStroke", MainFrame)
_ms.Color = Theme.Accent; _ms.Thickness = 1.2; _ms.Transparency = 0.55

-- ─────────────────────────────────────────────────────────────
-- 3. Top Bar
-- ─────────────────────────────────────────────────────────────
local TopBar = Instance.new("Frame", MainFrame)
TopBar.Size               = UDim2.new(1, 0, 0, 36)
TopBar.BackgroundColor3   = Theme.Sidebar
TopBar.BackgroundTransparency = 0.1
TopBar.BorderSizePixel    = 0
Instance.new("UICorner", TopBar).CornerRadius = UDim.new(0, 10)
local _tp = Instance.new("Frame", TopBar)
_tp.Size = UDim2.new(1,0,0.5,0); _tp.Position = UDim2.new(0,0,0.5,0)
_tp.BackgroundColor3 = TopBar.BackgroundColor3; _tp.BackgroundTransparency = 0.1; _tp.BorderSizePixel = 0

-- Icon dot
local TitleDot = Instance.new("Frame", TopBar)
TitleDot.Size = UDim2.new(0,20,0,20); TitleDot.Position = UDim2.new(0,10,0.5,-10)
TitleDot.BackgroundColor3 = Theme.Accent; TitleDot.BorderSizePixel = 0
Instance.new("UICorner", TitleDot).CornerRadius = UDim.new(0,5)
local TitleDotL = Instance.new("TextLabel", TitleDot)
TitleDotL.Size = UDim2.new(1,0,1,0); TitleDotL.BackgroundTransparency = 1
TitleDotL.Text = "I"; TitleDotL.Font = Enum.Font.GothamBold
TitleDotL.TextColor3 = Color3.new(1,1,1); TitleDotL.TextSize = 12

local TitleLbl = Instance.new("TextLabel", TopBar)
TitleLbl.Size             = UDim2.new(0.5, 0, 1, 0)
TitleLbl.Position         = UDim2.new(0, 38, 0, 0)
TitleLbl.Text             = "Imp Hub X"
TitleLbl.Font             = Enum.Font.GothamBold
TitleLbl.TextColor3       = Theme.Text
TitleLbl.TextSize         = 14
TitleLbl.TextXAlignment   = Enum.TextXAlignment.Left
TitleLbl.BackgroundTransparency = 1

local SubLbl = Instance.new("TextLabel", TopBar)
SubLbl.Size               = UDim2.new(0.5, 0, 1, 0)
SubLbl.Position           = UDim2.new(0.22, 0, 0, 0)
SubLbl.Text               = "Jujutsu Shenanigans  •  v5"
SubLbl.Font               = Enum.Font.Gotham
SubLbl.TextColor3         = Theme.SubText
SubLbl.TextSize           = 10
SubLbl.TextXAlignment     = Enum.TextXAlignment.Left
SubLbl.Position           = UDim2.new(0, 38, 0.5, 1)
SubLbl.BackgroundTransparency = 1

-- Window controls (same pattern as template)
local function AddControl(txt, xOff, col, cb)
    local b = Instance.new("TextButton", TopBar)
    b.Size     = UDim2.new(0, 28, 0, 22)
    b.Position = UDim2.new(1, xOff, 0.5, -11)
    b.BackgroundColor3 = Theme.Button; b.BackgroundTransparency = 0.6
    b.Text = txt; b.TextColor3 = col
    b.Font = Enum.Font.GothamBold; b.TextSize = 12
    b.AutoButtonColor = false
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    b.MouseButton1Click:Connect(cb)
    return b
end
AddControl("✕", -36, Theme.Red,  function() ScreenGui:Destroy() end)
AddControl("—", -68, Theme.Text, function() MainFrame.Visible=false; ToggleIcon.Visible=true end)

ToggleIcon.MouseButton1Click:Connect(function()
    MainFrame.Visible = true; ToggleIcon.Visible = false
end)

-- ─────────────────────────────────────────────────────────────
-- 4. Native Dragging (exact copy from template)
-- ─────────────────────────────────────────────────────────────
local function EnableDrag(obj, handle)
    local drag, start, startPos
    handle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            drag = true; start = i.Position; startPos = obj.Position
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then drag = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if drag and (i.UserInputType == Enum.UserInputType.MouseMovement
                  or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - start
            obj.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                                      startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end
EnableDrag(MainFrame, TopBar)
EnableDrag(ToggleIcon, ToggleIcon)

-- ─────────────────────────────────────────────────────────────
-- 5. Sidebar (same as template)
-- ─────────────────────────────────────────────────────────────
local Sidebar = Instance.new("Frame", MainFrame)
Sidebar.Size               = UDim2.new(0, 118, 1, -36)
Sidebar.Position           = UDim2.new(0, 0, 0, 36)
Sidebar.BackgroundColor3   = Theme.Sidebar
Sidebar.BackgroundTransparency = 0.3
Sidebar.BorderSizePixel    = 0
Instance.new("UICorner", Sidebar).CornerRadius = UDim.new(0, 10)
local _sp = Instance.new("Frame", Sidebar)
_sp.Size = UDim2.new(0.5,0,1,0); _sp.Position = UDim2.new(0.5,0,0,0)
_sp.BackgroundColor3 = Sidebar.BackgroundColor3; _sp.BackgroundTransparency = 0.3; _sp.BorderSizePixel = 0

local SidebarLayout = Instance.new("UIListLayout", Sidebar)
SidebarLayout.Padding = UDim.new(0, 4)
SidebarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
local _sbp = Instance.new("UIPadding", Sidebar)
_sbp.PaddingTop = UDim.new(0, 10); _sbp.PaddingBottom = UDim.new(0, 10)

-- ─────────────────────────────────────────────────────────────
-- 6. Content Area + Tab System (same as template)
-- ─────────────────────────────────────────────────────────────
local ContentArea = Instance.new("Frame", MainFrame)
ContentArea.Size               = UDim2.new(1, -128, 1, -44)
ContentArea.Position           = UDim2.new(0, 124, 0, 40)
ContentArea.BackgroundTransparency = 1
ContentArea.BorderSizePixel    = 0
ContentArea.ClipsDescendants   = true

local Tabs       = {}
local TabButtons = {}

local function CreateTab(name, icon)
    -- Content scroll frame (same as template)
    local TabFrame = Instance.new("ScrollingFrame", ContentArea)
    TabFrame.Size               = UDim2.new(1, 0, 1, 0)
    TabFrame.BackgroundTransparency = 1
    TabFrame.ScrollBarThickness = 3
    TabFrame.ScrollBarImageColor3 = Theme.Accent
    TabFrame.Visible            = false
    TabFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    TabFrame.CanvasSize         = UDim2.new(0, 0, 0, 0)
    TabFrame.BorderSizePixel    = 0
    local Layout = Instance.new("UIListLayout", TabFrame)
    Layout.Padding              = UDim.new(0, 8)
    Layout.SortOrder            = Enum.SortOrder.LayoutOrder
    local _tfp = Instance.new("UIPadding", TabFrame)
    _tfp.PaddingTop = UDim.new(0,6); _tfp.PaddingBottom = UDim.new(0,10)
    _tfp.PaddingLeft = UDim.new(0,4); _tfp.PaddingRight = UDim.new(0,6)

    -- Sidebar button (same as template)
    local TabBtn = Instance.new("TextButton", Sidebar)
    TabBtn.Size               = UDim2.new(0.92, 0, 0, 34)
    TabBtn.BackgroundColor3   = Theme.Accent
    TabBtn.BackgroundTransparency = 1
    TabBtn.Text               = "  " .. icon .. " " .. name
    TabBtn.TextColor3         = Theme.SubText
    TabBtn.Font               = Enum.Font.GothamMedium
    TabBtn.TextSize           = 12
    TabBtn.TextXAlignment     = Enum.TextXAlignment.Left
    TabBtn.AutoButtonColor    = false
    Instance.new("UICorner", TabBtn).CornerRadius = UDim.new(0, 6)

    local Indicator = Instance.new("Frame", TabBtn)
    Indicator.Size            = UDim2.new(0, 3, 0.55, 0)
    Indicator.Position        = UDim2.new(0, 2, 0.225, 0)
    Indicator.BackgroundColor3 = Theme.Accent
    Indicator.Visible         = false
    Instance.new("UICorner", Indicator).CornerRadius = UDim.new(1, 0)

    TabBtn.MouseButton1Click:Connect(function()
        for _, t in pairs(Tabs)       do t.Frame.Visible = false end
        for _, b in pairs(TabButtons) do
            b.Btn.BackgroundTransparency = 1
            b.Btn.TextColor3 = Theme.SubText
            b.Indicator.Visible = false
        end
        TabFrame.Visible              = true
        TabBtn.BackgroundTransparency = 0.82
        TabBtn.TextColor3             = Theme.Text
        Indicator.Visible             = true
    end)

    table.insert(Tabs, { Frame = TabFrame })
    table.insert(TabButtons, { Btn = TabBtn, Indicator = Indicator })

    return TabFrame
end

-- ─────────────────────────────────────────────────────────────
-- 7. Section Header (visual grouping label inside a tab)
-- ─────────────────────────────────────────────────────────────
local function CreateSection(parent, title, order)
    local f = Instance.new("Frame", parent)
    f.Size = UDim2.new(0.98, 0, 0, 22)
    f.BackgroundTransparency = 1
    f.LayoutOrder = order
    local l = Instance.new("TextLabel", f)
    l.Size = UDim2.new(1, -4, 1, 0); l.Position = UDim2.new(0, 4, 0, 0)
    l.BackgroundTransparency = 1; l.Text = string.upper(title)
    l.Font = Enum.Font.GothamBold; l.TextSize = 9
    l.TextColor3 = Theme.Accent; l.TextXAlignment = Enum.TextXAlignment.Left
    -- Accent line
    local line = Instance.new("Frame", f)
    line.Size = UDim2.new(1, 0, 0, 1); line.Position = UDim2.new(0, 0, 1, -2)
    line.BackgroundColor3 = Theme.Accent; line.BackgroundTransparency = 0.7
    line.BorderSizePixel = 0
end

-- ─────────────────────────────────────────────────────────────
-- 8. Fluent Toggle (exact template style)
-- ─────────────────────────────────────────────────────────────
local function CreateToggle(parent, title, desc, default, order, callback)
    local state = default or false

    local card = Instance.new("TextButton", parent)
    card.Size             = UDim2.new(0.98, 0, 0, 48)
    card.BackgroundColor3 = Theme.Button
    card.BackgroundTransparency = 0
    card.Text             = ""
    card.AutoButtonColor  = false
    card.LayoutOrder      = order
    card.BorderSizePixel  = 0
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 7)
    local _cs = Instance.new("UIStroke", card); _cs.Color = Theme.Stroke; _cs.Transparency = 0.3

    local Txt = Instance.new("TextLabel", card)
    Txt.Size     = UDim2.new(1, -60, 0.5, 0); Txt.Position = UDim2.new(0, 12, 0, 5)
    Txt.Text     = title; Txt.Font = Enum.Font.GothamMedium; Txt.TextSize = 13
    Txt.TextColor3 = Theme.Text; Txt.TextXAlignment = Enum.TextXAlignment.Left
    Txt.BackgroundTransparency = 1

    local Sub = Instance.new("TextLabel", card)
    Sub.Size     = UDim2.new(1, -60, 0.5, 0); Sub.Position = UDim2.new(0, 12, 0.5, -1)
    Sub.Text     = desc or ""; Sub.Font = Enum.Font.Gotham; Sub.TextSize = 10
    Sub.TextColor3 = Theme.SubText; Sub.TextXAlignment = Enum.TextXAlignment.Left
    Sub.BackgroundTransparency = 1

    -- Pill (ON/OFF)
    local Pill = Instance.new("Frame", card)
    Pill.Size     = UDim2.new(0, 42, 0, 22)
    Pill.Position = UDim2.new(1, -52, 0.5, -11)
    Pill.BackgroundColor3 = state and Theme.Accent or Theme.Background
    Pill.BorderSizePixel  = 0
    Instance.new("UICorner", Pill).CornerRadius = UDim.new(1, 0)
    local PillStk = Instance.new("UIStroke", Pill)
    PillStk.Color = state and Theme.Accent or Theme.Stroke

    local PillTxt = Instance.new("TextLabel", Pill)
    PillTxt.Size = UDim2.new(1,0,1,0); PillTxt.BackgroundTransparency = 1
    PillTxt.Text = state and "ON" or "OFF"
    PillTxt.Font = Enum.Font.GothamBold; PillTxt.TextSize = 10
    PillTxt.TextColor3 = state and Color3.new(1,1,1) or Theme.SubText

    local function Refresh()
        PillTxt.Text      = state and "ON" or "OFF"
        PillTxt.TextColor3 = state and Color3.new(1,1,1) or Theme.SubText
        Pill.BackgroundColor3 = state and Theme.Accent or Theme.Background
        PillStk.Color         = state and Theme.Accent or Theme.Stroke
        card.BackgroundColor3 = state and Color3.fromRGB(38,32,55) or Theme.Button
    end

    Refresh()
    card.MouseButton1Click:Connect(function()
        state = not state; Refresh()
        pcall(callback, state)
    end)

    return function() return state end, function(v) state = v; Refresh(); pcall(callback, state) end
end

-- ─────────────────────────────────────────────────────────────
-- 9. Fluent Button (template style)
-- ─────────────────────────────────────────────────────────────
local function CreateButton(parent, title, order, callback)
    local b = Instance.new("TextButton", parent)
    b.Size             = UDim2.new(0.98, 0, 0, 36)
    b.BackgroundColor3 = Theme.Button
    b.Text             = "  " .. title
    b.TextColor3       = Theme.Text
    b.Font             = Enum.Font.GothamMedium
    b.TextSize         = 13
    b.TextXAlignment   = Enum.TextXAlignment.Left
    b.AutoButtonColor  = false
    b.LayoutOrder      = order
    b.BorderSizePixel  = 0
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 7)
    local _bs = Instance.new("UIStroke", b); _bs.Color = Theme.Stroke; _bs.Transparency = 0.3
    b.MouseEnter:Connect(function() b.BackgroundColor3 = Theme.ButtonHov end)
    b.MouseLeave:Connect(function() b.BackgroundColor3 = Theme.Button end)
    b.MouseButton1Click:Connect(function() pcall(callback) end)
    return b
end

-- ─────────────────────────────────────────────────────────────
-- 10. Fluent Slider
-- ─────────────────────────────────────────────────────────────
local sliderActive = nil
UserInputService.InputChanged:Connect(function(i)
    if not sliderActive then return end
    if i.UserInputType ~= Enum.UserInputType.MouseMovement
    and i.UserInputType ~= Enum.UserInputType.Touch then return end
    local s = sliderActive
    local rel = math.clamp(
        (i.Position.X - s.Track.AbsolutePosition.X) / s.Track.AbsoluteSize.X, 0, 1)
    s.Value = s.Min + math.floor(rel * (s.Max - s.Min))
    s.Fill.Size  = UDim2.new(rel, 0, 1, 0)
    s.Knob.Position = UDim2.new(rel, -7, 0.5, -7)
    s.ValLbl.Text = tostring(s.Value) .. s.Suffix
end)
UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1
    or i.UserInputType == Enum.UserInputType.Touch then
        sliderActive = nil
    end
end)

local function CreateSlider(parent, title, min, max, default, suffix, order, callback)
    suffix = suffix or ""
    local card = Instance.new("Frame", parent)
    card.Size             = UDim2.new(0.98, 0, 0, 58)
    card.BackgroundColor3 = Theme.Button
    card.BorderSizePixel  = 0
    card.LayoutOrder      = order
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 7)
    local _ss = Instance.new("UIStroke", card); _ss.Color = Theme.Stroke; _ss.Transparency = 0.3

    local TitleL = Instance.new("TextLabel", card)
    TitleL.Size     = UDim2.new(0.65, 0, 0, 20); TitleL.Position = UDim2.new(0, 12, 0, 8)
    TitleL.Text     = title; TitleL.Font = Enum.Font.GothamMedium; TitleL.TextSize = 12
    TitleL.TextColor3 = Theme.Text; TitleL.TextXAlignment = Enum.TextXAlignment.Left
    TitleL.BackgroundTransparency = 1

    local ValL = Instance.new("TextLabel", card)
    ValL.Size     = UDim2.new(0.35, -12, 0, 20); ValL.Position = UDim2.new(0.65, 0, 0, 8)
    ValL.Text     = tostring(default) .. suffix
    ValL.Font     = Enum.Font.GothamBold; ValL.TextSize = 12
    ValL.TextColor3 = Theme.AccentLight; ValL.TextXAlignment = Enum.TextXAlignment.Right
    ValL.BackgroundTransparency = 1

    local Track = Instance.new("Frame", card)
    Track.Size     = UDim2.new(1, -20, 0, 5); Track.Position = UDim2.new(0, 10, 0, 36)
    Track.BackgroundColor3 = Color3.fromRGB(45, 45, 55); Track.BorderSizePixel = 0
    Instance.new("UICorner", Track).CornerRadius = UDim.new(1, 0)

    local pct0 = (default - min) / (max - min)
    local Fill = Instance.new("Frame", Track)
    Fill.Size     = UDim2.new(pct0, 0, 1, 0)
    Fill.BackgroundColor3 = Theme.Accent; Fill.BorderSizePixel = 0
    Instance.new("UICorner", Fill).CornerRadius = UDim.new(1, 0)

    local Knob = Instance.new("Frame", Track)
    Knob.Size     = UDim2.new(0, 14, 0, 14); Knob.Position = UDim2.new(pct0, -7, 0.5, -7)
    Knob.BackgroundColor3 = Color3.new(1,1,1); Knob.BorderSizePixel = 0; Knob.ZIndex = 4
    Instance.new("UICorner", Knob).CornerRadius = UDim.new(1, 0)
    local _ks = Instance.new("UIStroke", Knob); _ks.Color = Theme.Accent; _ks.Thickness = 1.5

    local sd = {Track=Track, Fill=Fill, Knob=Knob, ValLbl=ValL,
                Min=min, Max=max, Value=default, Suffix=suffix}

    Track.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            sliderActive = sd
            local rel = math.clamp(
                (i.Position.X - Track.AbsolutePosition.X) / Track.AbsoluteSize.X, 0, 1)
            sd.Value = min + math.floor(rel * (max - min))
            Fill.Size = UDim2.new(rel, 0, 1, 0)
            Knob.Position = UDim2.new(rel, -7, 0.5, -7)
            ValL.Text = tostring(sd.Value) .. suffix
            pcall(callback, sd.Value)
        end
    end)

    return function() return sd.Value end
end

-- ─────────────────────────────────────────────────────────────
-- 11. Fluent Dropdown
-- ─────────────────────────────────────────────────────────────
-- Overlay so dropdown lists are never clipped
local DropLayer = Instance.new("Frame", ScreenGui)
DropLayer.Size = UDim2.new(1,0,1,0); DropLayer.BackgroundTransparency = 1
DropLayer.BorderSizePixel = 0; DropLayer.ZIndex = 200
DropLayer.Name = "DropLayer"

local openList = nil
DropLayer.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then
        if openList then openList.Visible = false; openList = nil end
    end
end)

local function CreateDropdown(parent, title, options, default, order, callback)
    local sel = default or options[1]

    local card = Instance.new("Frame", parent)
    card.Size             = UDim2.new(0.98, 0, 0, 52)
    card.BackgroundColor3 = Theme.Button
    card.BorderSizePixel  = 0; card.LayoutOrder = order
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 7)
    local _ds = Instance.new("UIStroke", card); _ds.Color = Theme.Stroke; _ds.Transparency = 0.3

    local TitleL = Instance.new("TextLabel", card)
    TitleL.Size     = UDim2.new(0.46, 0, 0, 20); TitleL.Position = UDim2.new(0, 12, 0.5, -10)
    TitleL.Text     = title; TitleL.Font = Enum.Font.GothamMedium; TitleL.TextSize = 12
    TitleL.TextColor3 = Theme.Text; TitleL.TextXAlignment = Enum.TextXAlignment.Left
    TitleL.BackgroundTransparency = 1

    local Btn = Instance.new("TextButton", card)
    Btn.Size     = UDim2.new(0.52, -4, 0, 28); Btn.Position = UDim2.new(0.48, 0, 0.5, -14)
    Btn.BackgroundColor3 = Theme.DropBg; Btn.BorderSizePixel = 0
    Btn.Text     = sel; Btn.Font = Enum.Font.Gotham; Btn.TextSize = 11
    Btn.TextColor3 = Theme.Text; Btn.AutoButtonColor = false
    Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 5)
    local _bs2 = Instance.new("UIStroke", Btn); _bs2.Color = Theme.Stroke
    local ArrL = Instance.new("TextLabel", Btn)
    ArrL.Size = UDim2.new(0,14,1,0); ArrL.Position = UDim2.new(1,-16,0,0)
    ArrL.BackgroundTransparency = 1; ArrL.Text = "▾"
    ArrL.TextColor3 = Theme.AccentLight; ArrL.TextSize = 11; ArrL.Font = Enum.Font.GothamBold

    -- Float list in overlay (never clipped)
    local List = Instance.new("Frame", DropLayer)
    List.BackgroundColor3 = Theme.DropBg; List.BorderSizePixel = 0
    List.ZIndex = 210; List.Visible = false
    Instance.new("UICorner", List).CornerRadius = UDim.new(0, 6)
    local _ls = Instance.new("UIStroke", List); _ls.Color = Theme.Accent; _ls.Transparency = 0.5; _ls.Thickness = 1
    local ListLL = Instance.new("UIListLayout", List); ListLL.SortOrder = Enum.SortOrder.LayoutOrder

    for idx, opt in ipairs(options) do
        local ob = Instance.new("TextButton", List)
        ob.Size     = UDim2.new(1, 0, 0, 26); ob.BackgroundColor3 = Theme.DropBg
        ob.BorderSizePixel = 0; ob.LayoutOrder = idx; ob.ZIndex = 211
        ob.Text     = "  " .. opt; ob.Font = Enum.Font.Gotham; ob.TextSize = 11
        ob.TextColor3 = (opt == sel) and Theme.AccentLight or Theme.Text
        ob.TextXAlignment = Enum.TextXAlignment.Left; ob.AutoButtonColor = false
        ob.MouseEnter:Connect(function() ob.BackgroundColor3 = Color3.fromRGB(38,38,50) end)
        ob.MouseLeave:Connect(function() ob.BackgroundColor3 = Theme.DropBg end)
        ob.MouseButton1Click:Connect(function()
            sel = opt; Btn.Text = opt
            if openList then openList.Visible = false; openList = nil end
            for _, c in ipairs(List:GetChildren()) do
                if c:IsA("TextButton") then
                    c.TextColor3 = c.Text:gsub("^%s+","") == opt and Theme.AccentLight or Theme.Text
                end
            end
            pcall(callback, sel)
        end)
    end

    Btn.MouseButton1Click:Connect(function()
        if openList == List then
            List.Visible = false; openList = nil; return
        end
        if openList then openList.Visible = false end
        local ap = Btn.AbsolutePosition; local as = Btn.AbsoluteSize
        List.Position = UDim2.new(0, ap.X, 0, ap.Y + as.Y + 3)
        List.Size     = UDim2.new(0, as.X, 0, #options * 26)
        List.Visible  = true; openList = List
    end)

    return function() return sel end
end

-- ─────────────────────────────────────────────────────────────
-- 12. Status Label (info display card)
-- ─────────────────────────────────────────────────────────────
local function CreateStatusCard(parent, order)
    local card = Instance.new("Frame", parent)
    card.Size             = UDim2.new(0.98, 0, 0, 52)
    card.BackgroundColor3 = Theme.Button
    card.BorderSizePixel  = 0; card.LayoutOrder = order
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 7)
    local _css = Instance.new("UIStroke", card); _css.Color = Theme.Stroke; _css.Transparency = 0.3

    local BigL = Instance.new("TextLabel", card)
    BigL.Size   = UDim2.new(1,-12, 0, 22); BigL.Position = UDim2.new(0, 12, 0, 6)
    BigL.BackgroundTransparency = 1; BigL.Text = "[ DISABLED ]"
    BigL.Font   = Enum.Font.GothamBold; BigL.TextSize = 14
    BigL.TextColor3 = Theme.Red; BigL.TextXAlignment = Enum.TextXAlignment.Left

    local SmL = Instance.new("TextLabel", card)
    SmL.Size   = UDim2.new(1,-12, 0, 16); SmL.Position = UDim2.new(0, 12, 0, 30)
    SmL.BackgroundTransparency = 1; SmL.Text = "Wait for activation..."
    SmL.Font   = Enum.Font.Gotham; SmL.TextSize = 10
    SmL.TextColor3 = Theme.SubText; SmL.TextXAlignment = Enum.TextXAlignment.Left

    return BigL, SmL
end

-- ─────────────────────────────────────────────────────────────
-- 13. Build All Tabs
-- ─────────────────────────────────────────────────────────────

-- ── TAB 1 — Auto Farm ────────────────────────────────────────
local TabFarm = CreateTab("Auto Farm", "⚔")

CreateSection(TabFarm, "Farming", 1)

local getTP   = CreateDropdown(TabFarm, "Select Players",
    {"All","Specific"}, "All", 2, function(v) Cfg.Farm.TargetPlayer = v end)

local getTM   = CreateDropdown(TabFarm, "Target Method",
    {"Closest","Furthest","Random","Most HP","Least HP"}, "Closest", 3,
    function(v) Cfg.Farm.TargetMethod = v end)

local getFace = CreateToggle(TabFarm, "Face At Target", "Rotate toward enemy",
    true, 4, function(v) Cfg.Farm.FaceTarget = v end)

local getFast = CreateToggle(TabFarm, "Fast Attack", "Spam attack remote",
    true, 5, function(v) Cfg.Farm.FastAttack = v end)

local getSkU  = CreateToggle(TabFarm, "Use Skills", "Fire skill keybinds",
    true, 6, function(v) Cfg.Farm.UseSkills = v end)

local farmBtn = CreateButton(TabFarm, "▶  Enable Farm", 7, function() end)
local farmOn  = false
farmBtn.MouseButton1Click:Connect(function()
    farmOn = not farmOn; Cfg.Farm.Enabled = farmOn
    farmBtn.Text = farmOn and "  ■  Disable Farm" or "  ▶  Enable Farm"
    farmBtn.BackgroundColor3 = farmOn and Color3.fromRGB(38,32,55) or Theme.Button
end)

CreateSection(TabFarm, "Blocking", 8)

local getABlk = CreateToggle(TabFarm, "Enable Auto Block", "Block when enemies nearby",
    true, 9, function(v) Cfg.Block.Enabled = v end)

local getAPun = CreateToggle(TabFarm, "Auto Punish (Attack Back)", "Counter after blocking",
    true, 10, function(v) Cfg.Block.AutoPunish = v end)

local getFAtt = CreateToggle(TabFarm, "Face Attacker", "Turn toward attacker",
    true, 11, function(v) Cfg.Block.FaceAttacker = v end)

local showRBtn = CreateButton(TabFarm, "Show Range", 12, function() end)
local showROn  = false
showRBtn.MouseButton1Click:Connect(function()
    showROn = not showROn; Cfg.Block.ShowRange = showROn
    showRBtn.Text = showROn and "  ■ Hide Range" or "  Show Range"
    showRBtn.BackgroundColor3 = showROn and Color3.fromRGB(38,32,55) or Theme.Button
end)

local getDetR = CreateSlider(TabFarm, "Detection Range", 5, 80, 20, " studs", 13,
    function(v) Cfg.Block.DetectRange = v end)

local getBlkD = CreateSlider(TabFarm, "Block Delay", 0, 5, 0, "s", 14,
    function(v) Cfg.Block.BlockDelay = v end)

CreateSection(TabFarm, "Aimlock", 15)

local getAimOn   = CreateToggle(TabFarm, "Enable Aimlock", "Aim assist toward target",
    false, 16, function(v) Cfg.Aim.Enabled = v end)

local getAimMode = CreateDropdown(TabFarm, "Aimlock Mode",
    {"Camera","Body","Silent"}, "Camera", 17,
    function(v) Cfg.Aim.Mode = v end)

local getAimPart = CreateDropdown(TabFarm, "Target Part",
    {"Head","HumanoidRootPart","Torso"}, "Head", 18,
    function(v) Cfg.Aim.TargetPart = v end)

local getAimPred = CreateToggle(TabFarm, "Prediction", "Lead moving targets",
    false, 19, function(v) Cfg.Aim.Prediction = v end)

CreateSection(TabFarm, "Status", 20)
local statBig, statSub = CreateStatusCard(TabFarm, 21)

-- ── TAB 2 — Combat System ─────────────────────────────────────
local TabCombat = CreateTab("Combat", "⚙")

CreateSection(TabCombat, "Settings", 1)

local getCTpM  = CreateDropdown(TabCombat, "Teleport Method",
    {"Tween","Instant","Lerp"}, "Tween", 2,
    function(v) Cfg.Combat.TpMethod = v end)

local getCMove = CreateDropdown(TabCombat, "Movement Mode",
    {"Orbit (Dodge)","Follow","Static"}, "Orbit (Dodge)", 3,
    function(v) Cfg.Combat.MoveMode = v:gsub(" %(Dodge%)","") end)

local getCSpd  = CreateSlider(TabCombat, "Tween Speed", 50, 400, 135, " studs/s", 4,
    function(v) Cfg.Combat.TweenSpeed = v end)

local getCFD   = CreateSlider(TabCombat, "Follow Distance", 2, 30, 4, " studs", 5,
    function(v) Cfg.Combat.FollowDist = v end)

local getCKit  = CreateToggle(TabCombat, "Smart Kiting (Retreat on CD)", "Dodge back when skill on CD",
    true, 6, function(v) Cfg.Combat.SmartKiting = v end)

CreateSection(TabCombat, "Main Configurations", 7)

local getCFlee = CreateToggle(TabCombat, "Auto Flee (Low HP)", "Retreat when health is low",
    false, 8, function(v) Cfg.Combat.AutoFlee = v end)

local getCFHP  = CreateSlider(TabCombat, "Flee Health %", 5, 80, 20, "%", 9,
    function(v) Cfg.Combat.FleeHP = v end)

local getCPrio = CreateToggle(TabCombat, "Priority Closest", "Always target nearest enemy",
    true, 10, function(v) Cfg.Combat.PriorClosest = v end)

local getCHunt = CreateToggle(TabCombat, "Hunter Mode", "Chase fleeing targets",
    false, 11, function(v) Cfg.Combat.HunterMode = v end)

CreateSection(TabCombat, "Skill System", 12)

local getCSk   = CreateDropdown(TabCombat, "Select Skills",
    {"Divergent Fist","Black Flash","Hollow Purple","Domain Expansion","All"},
    "Divergent Fist", 13, function(v) Cfg.Combat.SkillName = v end)

local getCSD   = CreateSlider(TabCombat, "Use Skill Delay", 0, 30, 0, "s", 14,
    function(v) Cfg.Combat.SkillDelay = v end)

local getCANT  = CreateToggle(TabCombat, "Avoid Skills With Target Required", "Skip skills needing a target",
    true, 15, function(v) Cfg.Combat.AvoidNoTarget = v end)

local getCSKA  = CreateToggle(TabCombat, "Semi Kill Aura (25 Studs)", "Auto-attack nearby enemies",
    false, 16, function(v)
        Cfg.Combat.SemiKillAura = v; SetKillAura(v)
    end)

local getCSpin = CreateToggle(TabCombat, "SpinBot", "Continuously rotate character",
    false, 17, function(v)
        Cfg.Combat.SpinBot = v; SetSpinBot(v)
    end)

-- ── TAB 3 — ESP Engine ───────────────────────────────────────
local TabESP = CreateTab("ESP", "👁")

CreateSection(TabESP, "Enable", 1)

local getESP = CreateToggle(TabESP, "Enable ESP Players", "Show enemy overlays",
    false, 2, function(v) Cfg.ESP.Enabled = v end)

CreateSection(TabESP, "Configurations", 3)

local getVBox  = CreateToggle(TabESP, "Box", "Draw bounding box",
    true, 4, function(v) Cfg.ESP.Box = v end)

local getVTr   = CreateToggle(TabESP, "Tracers", "Draw tracer lines",
    true, 5, function(v) Cfg.ESP.Tracers = v end)

local getVHP   = CreateToggle(TabESP, "Health Bar", "Show health bar",
    true, 6, function(v) Cfg.ESP.HealthBar = v end)

local getVDist = CreateToggle(TabESP, "Distance", "Show stud distance",
    true, 7, function(v) Cfg.ESP.Distance = v end)

local getVName = CreateToggle(TabESP, "Name", "Show player name",
    true, 8, function(v) Cfg.ESP.Name = v end)

local getVMove = CreateToggle(TabESP, "Moveset (Class)", "Show character moveset",
    true, 9, function(v) Cfg.ESP.Moveset = v end)

-- ── TAB 4 — Misc ─────────────────────────────────────────────
local TabMisc = CreateTab("Misc", "★")

CreateSection(TabMisc, "Stuff", 1)

local getAR   = CreateToggle(TabMisc, "Anti Ragdoll", "Disable ragdoll constraints",
    false, 2, function(v) Cfg.Misc.AntiRagdoll = v end)

local getAT   = CreateToggle(TabMisc, "Auto Tech (Jump on Ragdoll)", "Auto-jump when ragdolled",
    false, 3, function(v) Cfg.Misc.AutoTech = v end)

local getWS   = CreateToggle(TabMisc, "WalkSpeed Bypass (Velocity)", "Speed via BodyVelocity",
    false, 4, function(v) Cfg.Misc.WsBypass = v; SetSpeedBypass(v) end)

local getMSp  = CreateSlider(TabMisc, "Speed Amount", 16, 500, 100, " studs/s", 5,
    function(v) Cfg.Misc.Speed = v end)

local getIJ   = CreateToggle(TabMisc, "Infinite Jump", "Jump repeatedly in air",
    false, 6, function(v) Cfg.Misc.InfJump = v; SetInfJump(v) end)

local getFB   = CreateToggle(TabMisc, "Fullbright", "Max ambient lighting",
    false, 7, function(v) Cfg.Misc.Fullbright = v; SetFullbright(v) end)

local getWSc  = CreateToggle(TabMisc, "White Screen", "White overlay on screen",
    false, 8, function(v) Cfg.Misc.WhiteScreen = v; SetWhiteScreen(v) end)

local getAFK  = CreateToggle(TabMisc, "Anti AFK", "Prevent auto-kick",
    true, 9, function(v) Cfg.Misc.AntiAFK = v end)

local getCTP  = CreateToggle(TabMisc, "Click TP (Ctrl + Click)", "Teleport to clicked spot",
    false, 10, function(v) Cfg.Misc.ClickTP = v; SetClickTP(v) end)

local getTC   = CreateSlider(TabMisc, "Time Changer", 0, 24, 14, "h", 11,
    function(v) Cfg.Misc.TimeHour = v end)

CreateButton(TabMisc, "⚡  FPS Boost", 12, function()
    pcall(function() settings().Rendering.QualityLevel = 1 end)
    Lighting.GlobalShadows = false
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("ParticleEmitter") or v:IsA("Smoke")
        or v:IsA("Sparkles") or v:IsA("Fire") then v.Enabled = false end
    end
end)

CreateButton(TabMisc, "🌐  Server Hop", 13, function()
    pcall(function()
        local d = HttpService:JSONDecode(game:HttpGet(
            "https://games.roblox.com/v1/games/"..game.PlaceId..
            "/servers/Public?sortOrder=Asc&limit=100"))
        for _, sv in ipairs(d.data or {}) do
            if sv.id ~= game.JobId and sv.playing < sv.maxPlayers then
                TeleportService:TeleportToPlaceInstance(game.PlaceId, sv.id, LP)
                return
            end
        end
    end)
end)

CreateSection(TabMisc, "Player Control", 14)

local function PlayerList()
    local t = {"(none)"}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then t[#t+1] = p.Name end
    end
    return t
end

local getSP = CreateDropdown(TabMisc, "Select Player", PlayerList(), "(none)", 15,
    function() end)

CreateButton(TabMisc, "▶  Spectate Player", 16, function()
    local p = Players:FindFirstChild(getSP()); if p then SpectatePlayer(p) end
end)

CreateButton(TabMisc, "■  Stop Spectate", 17, function() StopSpec() end)

CreateButton(TabMisc, "↑  Teleport to Player", 18, function()
    local p = Players:FindFirstChild(getSP()); if not p then return end
    local r, tr = Root(LP), Root(p)
    if r and tr then r.CFrame = tr.CFrame * CFrame.new(0, 0, -3) end
end)

-- ── TAB 5 — Credits ──────────────────────────────────────────
local TabCreds = CreateTab("Credits", "ℹ")

local function InfoCard(parent, txt, col, order)
    local f = Instance.new("Frame", parent)
    f.Size = UDim2.new(0.98, 0, 0, 36); f.BackgroundColor3 = Theme.Button
    f.BorderSizePixel = 0; f.LayoutOrder = order
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 7)
    local l = Instance.new("TextLabel", f)
    l.Size = UDim2.new(1,0,1,0); l.BackgroundTransparency = 1
    l.Text = txt; l.Font = Enum.Font.GothamBold; l.TextSize = 12
    l.TextColor3 = col or Theme.Text; l.TextXAlignment = Enum.TextXAlignment.Center
end

InfoCard(TabCreds, "Imp Hub X",               Theme.AccentLight, 1)
InfoCard(TabCreds, "Jujutsu Shenanigans",     Theme.Text,        2)
InfoCard(TabCreds, "Version 5  •  Delta Compatible", Theme.SubText, 3)
InfoCard(TabCreds, "⚔ Auto Farm  |  ⚙ Combat  |  👁 ESP  |  ★ Misc", Theme.SubText, 4)
InfoCard(TabCreds, "Toggle GUI: RightShift",  Theme.AccentLight, 5)
InfoCard(TabCreds, "For educational purposes only.", Theme.SubText, 6)

-- ─────────────────────────────────────────────────────────────
-- 14. Open default tab (same pattern as template)
-- ─────────────────────────────────────────────────────────────
if TabButtons[1] then
    TabButtons[1].Btn.MouseButton1Click:Fire()
end

-- RightShift toggle
UserInputService.InputBegan:Connect(function(i, gp)
    if gp then return end
    if i.KeyCode == Enum.KeyCode.RightShift then
        MainFrame.Visible = not MainFrame.Visible
        ToggleIcon.Visible = not MainFrame.Visible
    end
end)

-- ═════════════════════════════════════════════════════════════
-- GAME LOGIC (unchanged from v4, just moved below UI build)
-- ═════════════════════════════════════════════════════════════

-- ─── Helpers ─────────────────────────────────────────────────
local function Char(p)  return p and p.Character end
local function Root(p)  local c=Char(p); return c and c:FindFirstChild("HumanoidRootPart") end
local function Hum(p)   local c=Char(p); return c and c:FindFirstChildOfClass("Humanoid") end
local function Alive(p) local h=Hum(p);  return h and h.Health > 0 end
local function Dist(p)
    local a, b = Root(LP), Root(p)
    return (a and b) and (a.Position-b.Position).Magnitude or math.huge
end

local function GetEnemies()
    local t = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and Alive(p) then t[#t+1] = p end
    end
    return t
end

local function GetTarget()
    local enemies = GetEnemies(); if #enemies == 0 then return nil end
    local tp = getTP()
    if tp ~= "All" then
        for _, p in ipairs(enemies) do if p.Name == tp then return p end end
        return nil
    end
    local m = getTM()
    if m == "Closest"  then table.sort(enemies, function(a,b) return Dist(a)<Dist(b) end)
    elseif m == "Furthest" then table.sort(enemies, function(a,b) return Dist(a)>Dist(b) end)
    elseif m == "Random"   then return enemies[math.random(1,#enemies)]
    elseif m == "Most HP"  then table.sort(enemies, function(a,b)
            local ha,hb = Hum(a),Hum(b)
            return (ha and ha.Health or 0) > (hb and hb.Health or 0) end)
    elseif m == "Least HP" then table.sort(enemies, function(a,b)
            local ha,hb = Hum(a),Hum(b)
            return (ha and ha.Health or 1e9) < (hb and hb.Health or 1e9) end)
    end
    return enemies[1]
end

local function FaceTarget(tgt)
    local r, tr = Root(LP), Root(tgt)
    if r and tr then
        r.CFrame = CFrame.new(r.Position, Vector3.new(tr.Position.X, r.Position.Y, tr.Position.Z))
    end
end

local orbitAngle = 0
local function OrbitTarget(tgt)
    local r, tr = Root(LP), Root(tgt); if not r or not tr then return end
    orbitAngle = orbitAngle + 0.06
    local d = Cfg.Combat.FollowDist + 1.5
    local ox = tr.Position.X + math.cos(orbitAngle)*d
    local oz = tr.Position.Z + math.sin(orbitAngle)*d
    r.CFrame = CFrame.new(ox, tr.Position.Y, oz)
             * CFrame.Angles(0, math.atan2(tr.Position.X-ox, tr.Position.Z-oz), 0)
end

local function MoveToTarget(tgt)
    local r, tr = Root(LP), Root(tgt); if not r or not tr then return end
    local dir = (r.Position - tr.Position).Unit
    local cf  = CFrame.new(tr.Position + dir * Cfg.Combat.FollowDist)
              * CFrame.Angles(0, math.atan2(dir.X, dir.Z), 0)
    local m = Cfg.Combat.TpMethod
    if m == "Instant" then r.CFrame = cf
    elseif m == "Lerp" then r.CFrame = r.CFrame:Lerp(cf, 0.25)
    else
        local dist = (r.Position - cf.Position).Magnitude
        TweenService:Create(r, TweenInfo.new(
            math.clamp(dist/Cfg.Combat.TweenSpeed, 0.04, 1.5),
            Enum.EasingStyle.Linear), {CFrame=cf}):Play()
    end
end

-- Remote scanner (Knit-compatible generic scan)
local function ScanRemote(...)
    local RS = game:GetService("ReplicatedStorage")
    for _, n in ipairs({...}) do
        local r = RS:FindFirstChild(n, true)
        if r then return r end
    end
end

local lastAtk = 0
local function DoAttack(tgt)
    if tick()-lastAtk < 0.12 then return end; lastAtk = tick()
    local r = Root(tgt); if not r then return end
    pcall(function()
        local rem = ScanRemote("CombatRemote","Combat","Attack","CombatEvent","Hit","Punch")
        if rem then
            if rem:IsA("RemoteEvent")    then rem:FireServer(r)
            elseif rem:IsA("RemoteFunction") then rem:InvokeServer(r) end
        end
    end)
end

local isBlocking = false
local function SetBlock(s)
    if isBlocking == s then return end; isBlocking = s
    pcall(function()
        local rem = ScanRemote("BlockRemote","Block","BlockEvent","Guard","Parry")
        if rem and rem:IsA("RemoteEvent") then
            rem:FireServer(s and "BlockStart" or "BlockEnd")
        end
    end)
end

local lastSkill = 0
local function UseSkill(tgt)
    if not Cfg.Farm.UseSkills then return end
    if tick()-lastSkill < math.max(0, Cfg.Combat.SkillDelay) then return end
    if Cfg.Combat.AvoidNoTarget and not tgt then return end
    lastSkill = tick()
    pcall(function()
        local keys = {Enum.KeyCode.Q,Enum.KeyCode.E,Enum.KeyCode.R,
                      Enum.KeyCode.F,Enum.KeyCode.T,Enum.KeyCode.G}
        local k = keys[math.random(1,#keys)]
        pcall(function()
            local vim = game:GetService("VirtualInputManager")
            vim:SendKeyEvent(true, k, false, game)
            task.delay(0.06, function()
                pcall(function() vim:SendKeyEvent(false, k, false, game) end)
            end)
        end)
    end)
end

-- ─── One-shot features ────────────────────────────────────────
local speedBV
function SetSpeedBypass(on)
    local r = Root(LP); if not r then return end
    if on then
        if not speedBV then
            speedBV = Instance.new("BodyVelocity")
            speedBV.MaxForce = Vector3.new(1e4,0,1e4)
            speedBV.Velocity  = Vector3.new(0,0,0)
            speedBV.Parent    = r
        end
    else
        if speedBV then speedBV:Destroy(); speedBV = nil end
    end
end

local jumpConn
function SetInfJump(on)
    if jumpConn then jumpConn:Disconnect(); jumpConn = nil end
    if on then
        jumpConn = UserInputService.JumpRequest:Connect(function()
            local h = Hum(LP); if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
        end)
    end
end

local origAmb, origBrt
function SetFullbright(on)
    if on then
        origAmb = Lighting.Ambient; origBrt = Lighting.Brightness
        Lighting.Ambient = Color3.fromRGB(255,255,255)
        Lighting.Brightness = 2; Lighting.FogEnd = 1e6
    else
        if origAmb then Lighting.Ambient = origAmb; Lighting.Brightness = origBrt or 1 end
    end
end

local wsGui
function SetWhiteScreen(on)
    if wsGui then wsGui:Destroy(); wsGui = nil end
    if on then
        wsGui = Instance.new("ScreenGui", LP.PlayerGui)
        wsGui.Name = "ImpHubXWS"; wsGui.ResetOnSpawn = false
        local f = Instance.new("Frame", wsGui)
        f.Size = UDim2.new(1,0,1,0)
        f.BackgroundColor3 = Color3.new(1,1,1)
        f.BackgroundTransparency = 0.35; f.BorderSizePixel = 0
    end
end

local ctpConn
function SetClickTP(on)
    if ctpConn then ctpConn:Disconnect(); ctpConn = nil end
    if on then
        ctpConn = UserInputService.InputBegan:Connect(function(inp, gp)
            if gp then return end
            if inp.UserInputType == Enum.UserInputType.MouseButton1
            and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
                local r = Root(LP)
                if r then r.CFrame = CFrame.new(Mouse.Hit.Position + Vector3.new(0,3,0)) end
            end
        end)
    end
end

local spinConn
function SetSpinBot(on)
    if spinConn then spinConn:Disconnect(); spinConn = nil end
    if on then
        spinConn = RunService.RenderStepped:Connect(function()
            local r = Root(LP)
            if r then r.CFrame = r.CFrame * CFrame.Angles(0, math.rad(18), 0) end
        end)
    end
end

local killConn
function SetKillAura(on)
    if killConn then killConn:Disconnect(); killConn = nil end
    if on then
        local lkA = 0
        killConn = RunService.Heartbeat:Connect(function()
            if tick()-lkA < 0.12 then return end; lkA = tick()
            for _, e in ipairs(GetEnemies()) do
                if Dist(e) <= 25 then DoAttack(e) end
            end
        end)
    end
end

local specConn
function SpectatePlayer(tgt)
    if specConn then specConn:Disconnect(); specConn = nil end
    if not tgt then return end
    Camera.CameraType = Enum.CameraType.Scriptable
    specConn = RunService.RenderStepped:Connect(function()
        local tr = Root(tgt)
        if tr then Camera.CFrame = CFrame.new(tr.Position+Vector3.new(0,6,14), tr.Position) end
    end)
end
function StopSpec()
    if specConn then specConn:Disconnect(); specConn = nil end
    Camera.CameraType = Enum.CameraType.Custom
end

-- ─────────────────────────────────────────────────────────────
-- 15. Main Heartbeat Loop
-- ─────────────────────────────────────────────────────────────
local blockTimer  = 0
local lastBlocker = nil
local lastTech    = 0
local lastAfk     = 0

RunService.Heartbeat:Connect(function()
    local now = tick()

    -- Time changer
    pcall(function() Lighting.ClockTime = Cfg.Misc.TimeHour end)

    -- Anti-AFK
    if Cfg.Misc.AntiAFK and now-lastAfk > 60 then
        lastAfk = now
        pcall(function() local h=Hum(LP); if h then h.Jump=false end end)
    end

    -- Auto Tech
    if Cfg.Misc.AutoTech then
        local h = Hum(LP)
        if h then
            local st = h:GetState()
            if (st==Enum.HumanoidStateType.Ragdoll or st==Enum.HumanoidStateType.FallingDown)
               and now-lastTech>0.3 then
                lastTech = now; h.Jump = true
            end
        end
    end

    -- Speed bypass drive
    if Cfg.Misc.WsBypass and speedBV then
        local c   = LP.Character
        local hum = c and c:FindFirstChildOfClass("Humanoid")
        if hum then speedBV.Velocity = hum.MoveDirection * Cfg.Misc.Speed end
    end

    -- Anti Ragdoll
    if Cfg.Misc.AntiRagdoll then
        local c = LP.Character
        if c then
            for _, v in ipairs(c:GetDescendants()) do
                if v:IsA("BallSocketConstraint") or v:IsA("HingeConstraint") then
                    v.Enabled = false
                end
            end
        end
    end

    -- ── Auto Block ───────────────────────────────────────────
    if Cfg.Block.Enabled and Cfg.Block.AutoBlock then
        local shouldBlock, attacker = false, nil
        for _, p in ipairs(GetEnemies()) do
            if Dist(p) <= Cfg.Block.DetectRange then
                shouldBlock = true; attacker = p; break
            end
        end
        if shouldBlock then
            if Cfg.Block.FaceAttacker and attacker then FaceTarget(attacker) end
            if now >= blockTimer then
                blockTimer = now + Cfg.Block.BlockDelay
                SetBlock(true); lastBlocker = attacker
            end
        else
            if isBlocking then
                if Cfg.Block.AutoPunish and lastBlocker then
                    SetBlock(false); DoAttack(lastBlocker)
                else SetBlock(false) end
                lastBlocker = nil
            end
        end
    else
        SetBlock(false)
    end

    -- ── Aimlock ──────────────────────────────────────────────
    if Cfg.Aim.Enabled then
        local tgt = GetTarget()
        if tgt then
            local ch   = tgt.Character
            local part = ch and (ch:FindFirstChild(Cfg.Aim.TargetPart)
                               or ch:FindFirstChild("HumanoidRootPart"))
            if part then
                local pos = part.Position
                if Cfg.Aim.Prediction then
                    pcall(function() pos = pos + part.AssemblyLinearVelocity*0.1 end)
                end
                if Cfg.Aim.Mode == "Camera" or Cfg.Aim.Mode == "Silent" then
                    Camera.CFrame = CFrame.new(Camera.CFrame.Position, pos)
                elseif Cfg.Aim.Mode == "Body" then
                    local r = Root(LP)
                    if r then r.CFrame = CFrame.new(r.Position,
                        Vector3.new(pos.X, r.Position.Y, pos.Z)) end
                end
            end
        end
    end

    -- ── Auto Farm ────────────────────────────────────────────
    if Cfg.Farm.Enabled then
        local tgt = GetTarget()
        if tgt then
            local h = Hum(LP)
            if Cfg.Combat.AutoFlee and h and (h.Health/h.MaxHealth*100) <= Cfg.Combat.FleeHP then
                local r, tr = Root(LP), Root(tgt)
                if r and tr then
                    local away = (r.Position - tr.Position).Unit
                    r.CFrame = CFrame.new(r.Position + away * 35)
                end
            else
                if Cfg.Combat.MoveMode == "Orbit" then OrbitTarget(tgt)
                else MoveToTarget(tgt) end
                if Cfg.Farm.FaceTarget then FaceTarget(tgt) end
                if Cfg.Farm.FastAttack then DoAttack(tgt) end
                UseSkill(tgt)
            end
        end
        local tgt2 = GetTarget()
        statBig.Text       = "[ ACTIVE ]"
        statBig.TextColor3 = Theme.Green
        statSub.Text       = "Target: " .. (tgt2 and tgt2.Name or "searching...")
    else
        statBig.Text       = "[ DISABLED ]"
        statBig.TextColor3 = Theme.Red
        statSub.Text       = "Wait for activation..."
    end
end)

-- ─────────────────────────────────────────────────────────────
-- 16. ESP (RenderStepped)
-- ─────────────────────────────────────────────────────────────
local ESPObjs = {}

local function GetMoveset(p)
    local ch = p.Character
    if ch then
        for _, n in ipairs({"Moveset","Class","Style","Weapon"}) do
            local v = ch:FindFirstChild(n)
            if v and v.Value then return tostring(v.Value) end
        end
    end
    local ls = p:FindFirstChild("leaderstats")
    if ls then
        for _, n in ipairs({"Moveset","Class"}) do
            local v = ls:FindFirstChild(n); if v then return tostring(v.Value) end
        end
    end
    return "???"
end

local function MakeESP(p)
    if p == LP or ESPObjs[p] then return end
    local o = {}
    o.Box = {}
    for i = 1, 4 do
        local l = Drawing.new("Line")
        l.Thickness = 1.5; l.Color = Color3.fromRGB(140,50,240)
        l.Visible = false; l.ZIndex = 2; o.Box[i] = l
    end
    o.Tracer = Drawing.new("Line")
    o.Tracer.Thickness = 1; o.Tracer.Color = Color3.fromRGB(140,50,240); o.Tracer.Visible = false

    o.HpBg = Drawing.new("Square")
    o.HpBg.Filled = true; o.HpBg.Color = Color3.fromRGB(18,18,18); o.HpBg.Visible = false
    o.Hp = Drawing.new("Square")
    o.Hp.Filled = true; o.Hp.Color = Color3.fromRGB(0,205,60); o.Hp.Visible = false

    o.Name = Drawing.new("Text"); o.Name.Size = 13
    o.Name.Color = Color3.new(1,1,1); o.Name.Center = true; o.Name.Outline = true; o.Name.Visible = false

    o.Dist = Drawing.new("Text"); o.Dist.Size = 11
    o.Dist.Color = Color3.fromRGB(200,200,200); o.Dist.Center = true; o.Dist.Outline = true; o.Dist.Visible = false

    o.Move = Drawing.new("Text"); o.Move.Size = 11
    o.Move.Color = Color3.fromRGB(175,130,255); o.Move.Center = true; o.Move.Outline = true; o.Move.Visible = false

    ESPObjs[p] = o
end

local function RemoveESP(p)
    local o = ESPObjs[p]; if not o then return end
    for _, v in pairs(o) do
        if type(v) == "table" then for _, l in ipairs(v) do pcall(function() l:Remove() end) end
        else pcall(function() v:Remove() end) end
    end
    ESPObjs[p] = nil
end

local function HideESP(o)
    for _, v in pairs(o) do
        if type(v) == "table" then for _, l in ipairs(v) do l.Visible = false end
        else v.Visible = false end
    end
end

RunService.RenderStepped:Connect(function()
    if not Cfg.ESP.Enabled then
        for _, o in pairs(ESPObjs) do HideESP(o) end; return
    end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then MakeESP(p) end
    end
    for p, o in pairs(ESPObjs) do
        if not p.Parent or not Alive(p) then RemoveESP(p)
        else
            local r = Root(p); local h = Hum(p)
            if not r or not h then HideESP(o)
            else
                local sp, vis, dep = Camera:WorldToViewportPoint(r.Position)
                if not vis or dep <= 0 then HideESP(o)
                else
                    local tp = Camera:WorldToViewportPoint(r.Position+Vector3.new(0,3.2,0))
                    local bp = Camera:WorldToViewportPoint(r.Position+Vector3.new(0,-3.2,0))
                    local ht = math.abs(tp.Y - bp.Y); local wd = ht*0.52
                    local L,R,T,B = sp.X-wd/2, sp.X+wd/2, tp.Y, bp.Y

                    local corners = {
                        {Vector2.new(L,T),Vector2.new(R,T)},
                        {Vector2.new(L,B),Vector2.new(R,B)},
                        {Vector2.new(L,T),Vector2.new(L,B)},
                        {Vector2.new(R,T),Vector2.new(R,B)},
                    }
                    for i, ln in ipairs(o.Box) do
                        ln.From=corners[i][1]; ln.To=corners[i][2]; ln.Visible=Cfg.ESP.Box
                    end

                    local vp = Camera.ViewportSize
                    o.Tracer.From=Vector2.new(vp.X/2,vp.Y)
                    o.Tracer.To=Vector2.new(sp.X,sp.Y); o.Tracer.Visible=Cfg.ESP.Tracers

                    local pct = math.clamp(h.Health/h.MaxHealth,0,1)
                    o.HpBg.Size=Vector2.new(4,ht); o.HpBg.Position=Vector2.new(L-7,T); o.HpBg.Visible=Cfg.ESP.HealthBar
                    o.Hp.Size=Vector2.new(4,ht*pct); o.Hp.Position=Vector2.new(L-7,T+ht*(1-pct))
                    o.Hp.Color=Color3.fromRGB(math.floor(255*(1-pct)),math.floor(255*pct),0); o.Hp.Visible=Cfg.ESP.HealthBar

                    o.Name.Text=p.Name; o.Name.Position=Vector2.new(sp.X,T-16); o.Name.Visible=Cfg.ESP.Name
                    o.Dist.Text=math.floor(Dist(p)).."st"; o.Dist.Position=Vector2.new(sp.X,B+3); o.Dist.Visible=Cfg.ESP.Distance
                    o.Move.Text="["..GetMoveset(p).."]"; o.Move.Position=Vector2.new(sp.X,B+15); o.Move.Visible=Cfg.ESP.Moveset
                end
            end
        end
    end
end)

-- ─────────────────────────────────────────────────────────────
-- 17. Cleanup
-- ─────────────────────────────────────────────────────────────
Players.PlayerRemoving:Connect(function(p) RemoveESP(p) end)

LP.CharacterAdded:Connect(function()
    task.wait(1)
    if Cfg.Misc.WsBypass then SetSpeedBypass(true) end
    if Cfg.Misc.InfJump   then SetInfJump(true) end
    if Cfg.Misc.ClickTP   then SetClickTP(true) end
end)

ScreenGui.AncestryChanged:Connect(function()
    for p in pairs(ESPObjs) do RemoveESP(p) end
    if spinConn  then spinConn:Disconnect() end
    if killConn  then killConn:Disconnect() end
    if specConn  then specConn:Disconnect() end
    if jumpConn  then jumpConn:Disconnect() end
    if ctpConn   then ctpConn:Disconnect() end
    if speedBV   then pcall(function() speedBV:Destroy() end) end
    StopSpec()
end)

print("[ImpHubX v5] ✓ GUI loaded via " .. tostring(TargetParent) .. " — RightShift to toggle")
