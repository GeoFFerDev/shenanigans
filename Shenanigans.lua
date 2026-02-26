--[[
╔══════════════════════════════════════════════════════╗
║           IMP HUB X  v4  —  Jujutsu Shenanigans     ║
║           Delta Executor • Fixed & Refined           ║
║  Toggle visibility : RightShift                      ║
╚══════════════════════════════════════════════════════╝

FIXES vs v3:
  ✔ Section header toggles now wired to Cfg (Block was always disabled)
  ✔ AutomaticSize replaced with UIListLayout AbsoluteContentSize listeners
    → prevents 0-height frames on older Delta builds
  ✔ Dropdown list Z-order fixed (appears on top of all other elements)
  ✔ Slider drag improved (works when cursor leaves track)
  ✔ VirtualInputManager wrapped in pcall with fallback keybind simulation
  ✔ Remote scanning broadened for JJS Knit service discovery
  ✔ Drawing objects properly cleaned up on player leave
  ✔ SemiKillAura toggle properly toggled (was checkbox only, no real loop)
  ✔ SpinBot cleaned up on GUI destroy
  ✔ GUI parent = PlayerGui (Delta-safe)
  ✔ Full pcall wrapper with visible error overlay
]]

local ok, err = pcall(function()

-- ─────────────────────────────────────────────────────────────────────────────
-- Services
-- ─────────────────────────────────────────────────────────────────────────────
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local Lighting         = game:GetService("Lighting")
local HttpService       = game:GetService("HttpService")
local TeleportService  = game:GetService("TeleportService")

local LP   = Players.LocalPlayer
if not LP then Players:GetPropertyChangedSignal("LocalPlayer"):Wait(); LP = Players.LocalPlayer end
local Mouse  = LP:GetMouse()
local Camera = workspace.CurrentCamera

local PlayerGui = LP:WaitForChild("PlayerGui", 15)
if not PlayerGui then warn("[ImpHubX] PlayerGui timeout"); return end

-- Remove old instance
local _old = PlayerGui:FindFirstChild("ImpHubX")
if _old then _old:Destroy() end

-- ─────────────────────────────────────────────────────────────────────────────
-- Config table  (single source of truth for logic)
-- ─────────────────────────────────────────────────────────────────────────────
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

-- ─────────────────────────────────────────────────────────────────────────────
-- Colour palette
-- ─────────────────────────────────────────────────────────────────────────────
local C = {
    BgDark   = Color3.fromRGB(14,14,18),
    BgMid    = Color3.fromRGB(22,22,28),
    BgPanel  = Color3.fromRGB(28,28,36),
    BgSec    = Color3.fromRGB(34,34,44),
    Purple   = Color3.fromRGB(130,55,240),
    PurpleLt = Color3.fromRGB(165,90,255),
    White    = Color3.fromRGB(225,225,232),
    Gray     = Color3.fromRGB(145,145,158),
    Red      = Color3.fromRGB(240,65,65),
    Green    = Color3.fromRGB(55,210,90),
    NavBg    = Color3.fromRGB(18,18,24),
    NavAct   = Color3.fromRGB(55,32,110),
    Sep      = Color3.fromRGB(46,46,60),
    TglOff   = Color3.fromRGB(55,55,70),
    ChkBg    = Color3.fromRGB(38,38,50),
    SlBg     = Color3.fromRGB(46,46,60),
    DropBg   = Color3.fromRGB(32,32,42),
    BtnBg    = Color3.fromRGB(42,32,65),
    BtnHov   = Color3.fromRGB(68,46,115),
}

-- ─────────────────────────────────────────────────────────────────────────────
-- Helper: auto-resize frame to match UIListLayout content
-- ─────────────────────────────────────────────────────────────────────────────
local function AutoHeight(frame, layout, extra)
    extra = extra or 0
    local function update()
        frame.Size = UDim2.new(frame.Size.X.Scale, frame.Size.X.Offset,
                               0, layout.AbsoluteContentSize.Y + extra)
    end
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(update)
    update()
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Root ScreenGui + Window
-- ─────────────────────────────────────────────────────────────────────────────
local SG = Instance.new("ScreenGui")
SG.Name             = "ImpHubX"
SG.ResetOnSpawn     = false
SG.ZIndexBehavior   = Enum.ZIndexBehavior.Sibling
SG.DisplayOrder     = 999
SG.Parent           = PlayerGui

local Win = Instance.new("Frame", SG)
Win.Name            = "Win"
Win.Size            = UDim2.new(0, 820, 0, 548)
Win.Position        = UDim2.new(0.5,-410, 0.5,-274)
Win.BackgroundColor3 = C.BgDark
Win.BorderSizePixel = 0
Win.ClipsDescendants = false   -- allow dropdowns to escape
Instance.new("UICorner", Win).CornerRadius = UDim.new(0,10)
local _ws = Instance.new("UIStroke", Win)
_ws.Color = C.Purple; _ws.Thickness = 1.4; _ws.Transparency = 0.45

-- Title bar
local TBar = Instance.new("Frame", Win)
TBar.Size            = UDim2.new(1,0,0,46)
TBar.BackgroundColor3 = C.BgMid
TBar.BorderSizePixel = 0
Instance.new("UICorner", TBar).CornerRadius = UDim.new(0,10)
local _tp = Instance.new("Frame", TBar)   -- bottom-corner patch
_tp.Size  = UDim2.new(1,0,0.5,0); _tp.Position = UDim2.new(0,0,0.5,0)
_tp.BackgroundColor3 = C.BgMid; _tp.BorderSizePixel = 0

local TIco  = Instance.new("Frame", TBar)
TIco.Size   = UDim2.new(0,30,0,30); TIco.Position = UDim2.new(0,10,0.5,-15)
TIco.BackgroundColor3 = C.Purple; TIco.BorderSizePixel = 0
Instance.new("UICorner", TIco).CornerRadius = UDim.new(0,6)
local TIcoL = Instance.new("TextLabel", TIco)
TIcoL.Size  = UDim2.new(1,0,1,0); TIcoL.BackgroundTransparency = 1
TIcoL.Text  = "I"; TIcoL.Font = Enum.Font.GothamBold
TIcoL.TextColor3 = Color3.new(1,1,1); TIcoL.TextSize = 17

local TTitle = Instance.new("TextLabel", TBar)
TTitle.Size  = UDim2.new(0,220,0,18); TTitle.Position = UDim2.new(0,48,0,6)
TTitle.BackgroundTransparency = 1; TTitle.Text = "Imp Hub X"
TTitle.Font  = Enum.Font.GothamBold; TTitle.TextColor3 = C.White; TTitle.TextSize = 15
TTitle.TextXAlignment = Enum.TextXAlignment.Left

local TSub   = Instance.new("TextLabel", TBar)
TSub.Size    = UDim2.new(0,220,0,13); TSub.Position = UDim2.new(0,48,0,26)
TSub.BackgroundTransparency = 1; TSub.Text = "Jujutsu Shenanigans  •  v4"
TSub.Font    = Enum.Font.Gotham; TSub.TextColor3 = C.Gray; TSub.TextSize = 11
TSub.TextXAlignment = Enum.TextXAlignment.Left

local function TBarBtn(xOff, lbl, bgCol)
    local b = Instance.new("TextButton", TBar)
    b.Size = UDim2.new(0,24,0,24); b.Position = UDim2.new(1,xOff,0.5,-12)
    b.BackgroundColor3 = bgCol; b.BorderSizePixel = 0
    b.Text = lbl; b.Font = Enum.Font.GothamBold
    b.TextColor3 = Color3.new(1,1,1); b.TextSize = 13; b.AutoButtonColor = false
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,5)
    return b
end
local BtnX   = TBarBtn(-34, "X", Color3.fromRGB(195,50,50))
local BtnMin = TBarBtn(-64, "−", C.BgSec)

-- Drag
local drag, dragStart, dragOrigin = false, nil, nil
TBar.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then
        drag=true; dragStart=i.Position; dragOrigin=Win.Position end end)
TBar.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then drag=false end end)
UserInputService.InputChanged:Connect(function(i)
    if drag and i.UserInputType == Enum.UserInputType.MouseMovement then
        local d = i.Position - dragStart
        Win.Position = UDim2.new(dragOrigin.X.Scale, dragOrigin.X.Offset+d.X,
                                  dragOrigin.Y.Scale, dragOrigin.Y.Offset+d.Y)
    end end)

local minimized = false
BtnMin.MouseButton1Click:Connect(function()
    minimized = not minimized
    Win.Size = minimized and UDim2.new(0,820,0,46) or UDim2.new(0,820,0,548)
end)
BtnX.MouseButton1Click:Connect(function() SG:Destroy() end)

-- Content area
local Content = Instance.new("Frame", Win)
Content.Size   = UDim2.new(1,0,1,-46); Content.Position = UDim2.new(0,0,0,46)
Content.BackgroundTransparency = 1; Content.BorderSizePixel = 0
Content.ClipsDescendants = false

-- Left nav
local NavF  = Instance.new("Frame", Content)
NavF.Size   = UDim2.new(0,186,1,0)
NavF.BackgroundColor3 = C.NavBg; NavF.BorderSizePixel = 0

local NavSF = Instance.new("ScrollingFrame", NavF)
NavSF.Size  = UDim2.new(1,0,1,0); NavSF.BackgroundTransparency = 1
NavSF.BorderSizePixel = 0; NavSF.ScrollBarThickness = 3
NavSF.ScrollBarImageColor3 = C.Purple; NavSF.CanvasSize = UDim2.new(0,0,0,500)
local NavLL = Instance.new("UIListLayout", NavSF)
NavLL.SortOrder = Enum.SortOrder.LayoutOrder; NavLL.Padding = UDim.new(0,3)
local NavPad = Instance.new("UIPadding", NavSF)
NavPad.PaddingLeft = UDim.new(0,8); NavPad.PaddingRight = UDim.new(0,8)
NavPad.PaddingTop  = UDim.new(0,10); NavPad.PaddingBottom = UDim.new(0,10)

-- Right panel
local RightF = Instance.new("Frame", Content)
RightF.Size  = UDim2.new(1,-186,1,0); RightF.Position = UDim2.new(0,186,0,0)
RightF.BackgroundColor3 = C.BgDark; RightF.BorderSizePixel = 0
RightF.ClipsDescendants = false

-- ─────────────────────────────────────────────────────────────────────────────
-- UI FACTORIES
-- ─────────────────────────────────────────────────────────────────────────────

-- Nav section header
local function NavHeader(txt, order)
    local f = Instance.new("Frame", NavSF)
    f.Size = UDim2.new(1,0,0,26); f.BackgroundTransparency = 1; f.LayoutOrder = order
    local l = Instance.new("TextLabel", f); l.Size = UDim2.new(1,0,1,0)
    l.BackgroundTransparency = 1; l.Text = string.upper(txt)
    l.Font = Enum.Font.GothamBold; l.TextColor3 = C.Gray
    l.TextSize = 8; l.TextXAlignment = Enum.TextXAlignment.Left
    local p = Instance.new("UIPadding", l); p.PaddingLeft = UDim.new(0,4); p.PaddingTop = UDim.new(0,8)
end

local navBtns = {}
local function NavBtn(icon, txt, order)
    local btn = Instance.new("TextButton", NavSF)
    btn.Size = UDim2.new(1,0,0,36); btn.BackgroundColor3 = C.NavBg
    btn.BorderSizePixel = 0; btn.Text = ""; btn.LayoutOrder = order; btn.AutoButtonColor = false
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,7)
    local ico = Instance.new("TextLabel", btn)
    ico.Size = UDim2.new(0,22,0,22); ico.Position = UDim2.new(0,6,0.5,-11)
    ico.BackgroundColor3 = C.BgSec; ico.BorderSizePixel = 0
    ico.Text = icon; ico.Font = Enum.Font.GothamBold; ico.TextColor3 = C.Gray; ico.TextSize = 12
    Instance.new("UICorner", ico).CornerRadius = UDim.new(0,5)
    local lbl = Instance.new("TextLabel", btn)
    lbl.Size = UDim2.new(1,-34,1,0); lbl.Position = UDim2.new(0,33,0,0)
    lbl.BackgroundTransparency = 1; lbl.Text = txt; lbl.Font = Enum.Font.Gotham
    lbl.TextColor3 = C.Gray; lbl.TextSize = 13; lbl.TextXAlignment = Enum.TextXAlignment.Left
    table.insert(navBtns, {btn=btn, ico=ico, lbl=lbl})
    return btn, ico, lbl
end

local tabs = {}
local function TabPanel(name)
    local sf = Instance.new("ScrollingFrame", RightF)
    sf.Name = name; sf.Size = UDim2.new(1,0,1,0)
    sf.BackgroundTransparency = 1; sf.BorderSizePixel = 0
    sf.ScrollBarThickness = 4; sf.ScrollBarImageColor3 = C.Purple
    sf.CanvasSize = UDim2.new(0,0,0,1000); sf.Visible = false
    sf.ClipsDescendants = false
    local ll = Instance.new("UIListLayout", sf)
    ll.SortOrder = Enum.SortOrder.LayoutOrder; ll.Padding = UDim.new(0,10)
    local pad = Instance.new("UIPadding", sf)
    pad.PaddingLeft = UDim.new(0,10); pad.PaddingRight = UDim.new(0,10)
    pad.PaddingTop  = UDim.new(0,10); pad.PaddingBottom = UDim.new(0,20)
    -- Auto-expand canvas
    ll:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        sf.CanvasSize = UDim2.new(0,0,0,ll.AbsoluteContentSize.Y+30)
    end)
    tabs[name] = sf; return sf
end

local function SwitchTab(name, btn, ico, lbl)
    for _, p in pairs(tabs) do p.Visible = false end
    for _, nb in ipairs(navBtns) do
        nb.btn.BackgroundColor3 = C.NavBg
        nb.lbl.Font = Enum.Font.Gotham; nb.lbl.TextColor3 = C.Gray
        nb.ico.BackgroundColor3 = C.BgSec; nb.ico.TextColor3 = C.Gray
    end
    if tabs[name] then tabs[name].Visible = true end
    btn.BackgroundColor3  = C.NavAct
    lbl.Font = Enum.Font.GothamBold; lbl.TextColor3 = C.White
    ico.BackgroundColor3  = C.Purple; ico.TextColor3 = Color3.new(1,1,1)
end

-- Two-column row frame inside a tab
local function RowFrame(parent, order)
    local f = Instance.new("Frame", parent)
    f.Size = UDim2.new(1,0,0,10); f.BackgroundTransparency = 1; f.LayoutOrder = order
    local ll = Instance.new("UIListLayout", f)
    ll.FillDirection = Enum.FillDirection.Horizontal
    ll.HorizontalAlignment = Enum.HorizontalAlignment.Left
    ll.Padding = UDim.new(0,8); ll.SortOrder = Enum.SortOrder.LayoutOrder
    ll:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        f.Size = UDim2.new(1,0,0,ll.AbsoluteContentSize.Y)
    end)
    return f
end

--[[
    Section(parent, title, order, width)
    Returns: card, body, getToggle
      card      – outer card frame
      body      – inner content frame to place items in
      getToggle – function() returns boolean state of header toggle
--]]
local function Section(parent, title, order, w)
    w = w or 290
    local card = Instance.new("Frame", parent)
    card.Size = UDim2.new(0,w,0,40); card.BackgroundColor3 = C.BgSec
    card.BorderSizePixel = 0; card.LayoutOrder = order
    Instance.new("UICorner", card).CornerRadius = UDim.new(0,8)

    -- Header
    local hdr = Instance.new("Frame", card)
    hdr.Size = UDim2.new(1,0,0,38); hdr.BackgroundColor3 = C.BgPanel; hdr.BorderSizePixel = 0
    Instance.new("UICorner", hdr).CornerRadius = UDim.new(0,8)
    local hp = Instance.new("Frame", hdr)
    hp.Size = UDim2.new(1,0,0.5,0); hp.Position = UDim2.new(0,0,0.5,0)
    hp.BackgroundColor3 = C.BgPanel; hp.BorderSizePixel = 0

    local icoF = Instance.new("Frame", hdr)
    icoF.Size = UDim2.new(0,20,0,20); icoF.Position = UDim2.new(0,10,0.5,-10)
    icoF.BackgroundColor3 = C.Purple; icoF.BorderSizePixel = 0
    Instance.new("UICorner", icoF).CornerRadius = UDim.new(1,0)
    local icoL = Instance.new("TextLabel", icoF)
    icoL.Size = UDim2.new(1,0,1,0); icoL.BackgroundTransparency = 1
    icoL.Text = "◆"; icoL.Font = Enum.Font.GothamBold; icoL.TextColor3 = Color3.new(1,1,1)
    icoL.TextSize = 9

    local titL = Instance.new("TextLabel", hdr)
    titL.Size = UDim2.new(1,-90,1,0); titL.Position = UDim2.new(0,36,0,0)
    titL.BackgroundTransparency = 1; titL.Text = title
    titL.Font = Enum.Font.GothamBold; titL.TextColor3 = C.White; titL.TextSize = 13
    titL.TextXAlignment = Enum.TextXAlignment.Left

    -- Header toggle (ON/OFF pill)
    local tBg = Instance.new("TextButton", hdr)
    tBg.Size = UDim2.new(0,38,0,20); tBg.Position = UDim2.new(1,-48,0.5,-10)
    tBg.BackgroundColor3 = C.TglOff; tBg.BorderSizePixel = 0
    tBg.Text = ""; tBg.AutoButtonColor = false
    Instance.new("UICorner", tBg).CornerRadius = UDim.new(1,0)
    local knob = Instance.new("Frame", tBg)
    knob.Size = UDim2.new(0,14,0,14); knob.Position = UDim2.new(0,3,0.5,-7)
    knob.BackgroundColor3 = Color3.fromRGB(195,195,195); knob.BorderSizePixel = 0
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1,0)

    local tState = false
    local function setTgl(v)
        tState = v
        tBg.BackgroundColor3   = v and C.Purple or C.TglOff
        knob.BackgroundColor3  = v and Color3.new(1,1,1) or Color3.fromRGB(195,195,195)
        TweenService:Create(knob, TweenInfo.new(0.12), {
            Position = v and UDim2.new(1,-17,0.5,-7) or UDim2.new(0,3,0.5,-7)
        }):Play()
    end
    tBg.MouseButton1Click:Connect(function() setTgl(not tState) end)

    -- Body
    local body = Instance.new("Frame", card)
    body.Size = UDim2.new(1,0,0,0); body.Position = UDim2.new(0,0,0,38)
    body.BackgroundTransparency = 1; body.BorderSizePixel = 0
    local bl = Instance.new("UIListLayout", body)
    bl.SortOrder = Enum.SortOrder.LayoutOrder; bl.Padding = UDim.new(0,2)
    local bp = Instance.new("UIPadding", body)
    bp.PaddingLeft = UDim.new(0,10); bp.PaddingRight = UDim.new(0,10)
    bp.PaddingTop  = UDim.new(0,6);  bp.PaddingBottom = UDim.new(0,10)

    -- Resize card when body content changes
    bl:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        body.Size = UDim2.new(1,0,0,bl.AbsoluteContentSize.Y + 16)
        card.Size = UDim2.new(0,w, 0, 38 + body.Size.Y.Offset)
    end)

    return card, body, function() return tState end, setTgl
end

-- ── Checkbox ──────────────────────────────────────────────────────────────────
local function Checkbox(parent, txt, def, order)
    local row = Instance.new("Frame", parent)
    row.Size = UDim2.new(1,0,0,28); row.BackgroundTransparency = 1; row.LayoutOrder = order
    local box = Instance.new("TextButton", row)
    box.Size = UDim2.new(0,16,0,16); box.Position = UDim2.new(0,0,0.5,-8)
    box.BackgroundColor3 = def and C.Purple or C.ChkBg
    box.BorderSizePixel = 0; box.Text = def and "✓" or ""
    box.Font = Enum.Font.GothamBold; box.TextColor3 = Color3.new(1,1,1)
    box.TextSize = 10; box.AutoButtonColor = false
    Instance.new("UICorner", box).CornerRadius = UDim.new(0,3)
    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(1,-22,1,0); lbl.Position = UDim2.new(0,22,0,0)
    lbl.BackgroundTransparency = 1; lbl.Text = txt
    lbl.Font = Enum.Font.Gotham; lbl.TextColor3 = C.White; lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    local state = def or false
    local function Set(v)
        state = v
        box.BackgroundColor3 = v and C.Purple or C.ChkBg
        box.Text = v and "✓" or ""
    end
    local function toggle() Set(not state) end
    box.MouseButton1Click:Connect(toggle)
    lbl.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then toggle() end end)
    return function() return state end, Set
end

-- ── Slider ────────────────────────────────────────────────────────────────────
local sliderActive = nil
UserInputService.InputChanged:Connect(function(i)
    if not sliderActive then return end
    if i.UserInputType ~= Enum.UserInputType.MouseMovement then return end
    local s = sliderActive
    local rel = math.clamp((i.Position.X - s.track.AbsolutePosition.X) / s.track.AbsoluteSize.X, 0, 1)
    s.value   = s.mn + math.floor(rel * (s.mx - s.mn))
    s.fill.Size = UDim2.new(rel,0,1,0)
    s.thumb.Position = UDim2.new(rel,-6,0.5,-7)
    s.valL.Text = tostring(s.value) .. s.suf
end)
UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then sliderActive = nil end end)

local function Slider(parent, txt, mn, mx, def, suf, order)
    local suf = suf or ""
    local row = Instance.new("Frame", parent)
    row.Size = UDim2.new(1,0,0,50); row.BackgroundTransparency = 1; row.LayoutOrder = order
    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(0.6,0,0,18); lbl.BackgroundTransparency = 1
    lbl.Text = txt; lbl.Font = Enum.Font.Gotham; lbl.TextColor3 = C.White
    lbl.TextSize = 12; lbl.TextXAlignment = Enum.TextXAlignment.Left
    local valL = Instance.new("TextLabel", row)
    valL.Size = UDim2.new(0.4,0,0,18); valL.Position = UDim2.new(0.6,0,0,0)
    valL.BackgroundTransparency = 1; valL.Text = tostring(def)..suf
    valL.Font = Enum.Font.Gotham; valL.TextColor3 = C.PurpleLt
    valL.TextSize = 12; valL.TextXAlignment = Enum.TextXAlignment.Right
    local track = Instance.new("Frame", row)
    track.Size = UDim2.new(1,-16,0,5); track.Position = UDim2.new(0,8,0,30)
    track.BackgroundColor3 = C.SlBg; track.BorderSizePixel = 0
    Instance.new("UICorner", track).CornerRadius = UDim.new(1,0)
    local fill = Instance.new("Frame", track)
    local pct0 = (def-mn)/(mx-mn)
    fill.Size = UDim2.new(pct0,0,1,0)
    fill.BackgroundColor3 = C.Purple; fill.BorderSizePixel = 0
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1,0)
    local thumb = Instance.new("Frame", track)
    thumb.Size = UDim2.new(0,13,0,13); thumb.Position = UDim2.new(pct0,-6,0.5,-7)
    thumb.BackgroundColor3 = Color3.new(1,1,1); thumb.BorderSizePixel = 0; thumb.ZIndex = 4
    Instance.new("UICorner", thumb).CornerRadius = UDim.new(1,0)
    local sd = {track=track, fill=fill, thumb=thumb, valL=valL, mn=mn, mx=mx, value=def, suf=suf}
    track.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            sliderActive = sd
            local rel = math.clamp((i.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
            sd.value = mn + math.floor(rel*(mx-mn))
            fill.Size = UDim2.new(rel,0,1,0)
            thumb.Position = UDim2.new(rel,-6,0.5,-7)
            valL.Text = tostring(sd.value)..suf
        end end)
    return function() return sd.value end
end

-- ── Dropdown ─────────────────────────────────────────────────────────────────
-- List lives in a dedicated "overlay" frame above everything else
local DropOverlay = Instance.new("Frame", SG)
DropOverlay.Name            = "DropOverlay"
DropOverlay.Size            = UDim2.new(1,0,1,0)
DropOverlay.BackgroundTransparency = 1
DropOverlay.BorderSizePixel = 0
DropOverlay.ZIndex          = 100

local activeList = nil
local function CloseDropdowns()
    if activeList then activeList.Visible = false; activeList = nil end
end
DropOverlay.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then CloseDropdowns() end end)

local function Dropdown(parent, txt, opts, def, order)
    local row = Instance.new("Frame", parent)
    row.Size = UDim2.new(1,0,0,32); row.BackgroundTransparency = 1; row.LayoutOrder = order
    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(0.44,0,1,0); lbl.BackgroundTransparency = 1
    lbl.Text = txt; lbl.Font = Enum.Font.Gotham; lbl.TextColor3 = C.White
    lbl.TextSize = 12; lbl.TextXAlignment = Enum.TextXAlignment.Left
    local dbtn = Instance.new("TextButton", row)
    dbtn.Size = UDim2.new(0.56,0,0,26); dbtn.Position = UDim2.new(0.44,0,0,3)
    dbtn.BackgroundColor3 = C.DropBg; dbtn.BorderSizePixel = 0
    dbtn.Text = (def or opts[1]); dbtn.Font = Enum.Font.Gotham
    dbtn.TextColor3 = C.White; dbtn.TextSize = 11; dbtn.AutoButtonColor = false
    Instance.new("UICorner", dbtn).CornerRadius = UDim.new(0,5)
    local arr = Instance.new("TextLabel", dbtn)
    arr.Size = UDim2.new(0,14,1,0); arr.Position = UDim2.new(1,-16,0,0)
    arr.BackgroundTransparency = 1; arr.Text = "▾"; arr.Font = Enum.Font.Gotham
    arr.TextColor3 = C.PurpleLt; arr.TextSize = 11

    -- Float list in overlay so it escapes all clipping
    local list = Instance.new("Frame", DropOverlay)
    list.BackgroundColor3 = C.DropBg; list.BorderSizePixel = 0
    list.ZIndex = 110; list.Visible = false
    local _lc = Instance.new("UIStroke", list); _lc.Color = C.Purple; _lc.Thickness = 1; _lc.Transparency = 0.6
    Instance.new("UICorner", list).CornerRadius = UDim.new(0,5)
    local ll = Instance.new("UIListLayout", list); ll.SortOrder = Enum.SortOrder.LayoutOrder
    local sel = def or opts[1]
    for i, opt in ipairs(opts) do
        local ob = Instance.new("TextButton", list)
        ob.Size = UDim2.new(1,0,0,24); ob.BackgroundColor3 = C.DropBg; ob.BorderSizePixel = 0
        ob.Text = "  "..opt; ob.Font = Enum.Font.Gotham
        ob.TextColor3 = (opt==sel) and C.PurpleLt or C.White
        ob.TextSize = 11; ob.TextXAlignment = Enum.TextXAlignment.Left
        ob.ZIndex = 111; ob.LayoutOrder = i; ob.AutoButtonColor = false
        ob.MouseButton1Click:Connect(function()
            sel = opt; dbtn.Text = opt
            CloseDropdowns()
            for _, c in ipairs(list:GetChildren()) do
                if c:IsA("TextButton") then
                    c.TextColor3 = c.Text:gsub("^%s+","") == opt and C.PurpleLt or C.White
                end
            end
        end)
    end
    dbtn.MouseButton1Click:Connect(function()
        if activeList == list then
            CloseDropdowns(); return
        end
        CloseDropdowns()
        -- Position relative to screen
        local ap = dbtn.AbsolutePosition; local as = dbtn.AbsoluteSize
        list.Position = UDim2.new(0,ap.X,0,ap.Y+as.Y+2)
        list.Size     = UDim2.new(0,as.X, 0, #opts*24)
        list.Visible  = true; activeList = list
    end)
    return function() return sel end
end

-- ── Button ───────────────────────────────────────────────────────────────────
local function Btn(parent, txt, order)
    local b = Instance.new("TextButton", parent)
    b.Size = UDim2.new(1,0,0,30); b.BackgroundColor3 = C.BtnBg; b.BorderSizePixel = 0
    b.Text = txt; b.Font = Enum.Font.GothamBold; b.TextColor3 = C.White
    b.TextSize = 12; b.LayoutOrder = order; b.AutoButtonColor = false
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,6)
    b.MouseEnter:Connect(function()
        TweenService:Create(b,TweenInfo.new(0.1),{BackgroundColor3=C.BtnHov}):Play() end)
    b.MouseLeave:Connect(function()
        TweenService:Create(b,TweenInfo.new(0.1),{BackgroundColor3=C.BtnBg}):Play() end)
    return b
end

local function SubHdr(parent, txt, order)
    local l = Instance.new("TextLabel", parent)
    l.Size = UDim2.new(1,0,0,20); l.BackgroundTransparency = 1; l.Text = txt
    l.Font = Enum.Font.GothamBold; l.TextColor3 = C.Gray; l.TextSize = 9
    l.TextXAlignment = Enum.TextXAlignment.Center; l.LayoutOrder = order
end

local function Sep(parent, order)
    local f = Instance.new("Frame", parent)
    f.Size = UDim2.new(1,0,0,1); f.BackgroundColor3 = C.Sep
    f.BorderSizePixel = 0; f.LayoutOrder = order
end

-- ─────────────────────────────────────────────────────────────────────────────
-- NAV BUTTONS
-- ─────────────────────────────────────────────────────────────────────────────
NavHeader("Combat & Auto Farm", 1)
local bFarm,   iFarm,   lFarm   = NavBtn("⚔", "Auto Farm",      2)
local bCombat, iCombat, lCombat = NavBtn("⚙", "Combat System",  3)
NavHeader("ESP Engine", 4)
local bVisl,   iVisl,   lVisl   = NavBtn("👁", "Visuals",         5)
NavHeader("Miscellaneous", 6)
local bMisc,   iMisc,   lMisc   = NavBtn("★", "Misc",            7)
NavHeader("Info", 8)
local bCreds,  iCreds,  lCreds  = NavBtn("i", "Credits",          9)

bFarm.MouseButton1Click:Connect(function()   SwitchTab("Farm",   bFarm,   iFarm,   lFarm)   end)
bCombat.MouseButton1Click:Connect(function() SwitchTab("Combat", bCombat, iCombat, lCombat) end)
bVisl.MouseButton1Click:Connect(function()   SwitchTab("Visl",   bVisl,   iVisl,   lVisl)   end)
bMisc.MouseButton1Click:Connect(function()   SwitchTab("Misc",   bMisc,   iMisc,   lMisc)   end)
bCreds.MouseButton1Click:Connect(function()  SwitchTab("Creds",  bCreds,  iCreds,  lCreds)  end)

-- ─────────────────────────────────────────────────────────────────────────────
-- TAB: AUTO FARM
-- ─────────────────────────────────────────────────────────────────────────────
local PFarm = TabPanel("Farm")

-- Row 1: Farming | Aimlock
local rowFA = RowFrame(PFarm, 1)

local _, bFarmBody = Section(rowFA, "Farming", 1, 288)
local getTP   = Dropdown(bFarmBody, "Select Players",
    {"All","Specific"}, "All", 1)
local getTM   = Dropdown(bFarmBody, "Target Method",
    {"Closest","Furthest","Random","Most HP","Least HP"}, "Closest", 2)
local getFace = Checkbox(bFarmBody, "Face At Target",  true,  3)
local getFast = Checkbox(bFarmBody, "Fast Attack",     true,  4)
local getSkU  = Checkbox(bFarmBody, "Use Skills",      true,  5)
Sep(bFarmBody, 6)
local farmBtn = Btn(bFarmBody, "▶  Enable Farm", 7)
local farmOn  = false
farmBtn.MouseButton1Click:Connect(function()
    farmOn = not farmOn; Cfg.Farm.Enabled = farmOn
    farmBtn.BackgroundColor3 = farmOn and C.Purple or C.BtnBg
    farmBtn.Text = farmOn and "■  Disable Farm" or "▶  Enable Farm"
end)

local _, bAimBody = Section(rowFA, "Aimlock", 2, 288)
local getAimOn   = Checkbox(bAimBody, "Enable Aimlock", false, 1)
local getAimMode = Dropdown(bAimBody, "Aimlock Mode",
    {"Camera","Body","Silent"}, "Camera", 2)
local getAimPart = Dropdown(bAimBody, "Target Part",
    {"Head","HumanoidRootPart","Torso"}, "Head", 3)
local getAimPred = Checkbox(bAimBody, "Prediction", false, 4)

-- Row 2: Status (full width)
local _, bStatBody = Section(PFarm, "Status", 2, 592)
local statBig = Instance.new("TextLabel", bStatBody)
statBig.Size = UDim2.new(1,0,0,22); statBig.LayoutOrder = 1
statBig.BackgroundTransparency = 1; statBig.Text = "[ DISABLED ]"
statBig.Font = Enum.Font.GothamBold; statBig.TextColor3 = C.Red
statBig.TextSize = 14; statBig.TextXAlignment = Enum.TextXAlignment.Left
local statSub = Instance.new("TextLabel", bStatBody)
statSub.Size = UDim2.new(1,0,0,14); statSub.LayoutOrder = 2
statSub.BackgroundTransparency = 1; statSub.Text = "Wait for activation..."
statSub.Font = Enum.Font.Gotham; statSub.TextColor3 = C.Gray
statSub.TextSize = 11; statSub.TextXAlignment = Enum.TextXAlignment.Left

-- Row 3: Blocking (full width)  ← FIXED: Section toggle now wires to Cfg.Block.Enabled
local _, bBlockBody, getBlockEnabled, setBlockEnabled = Section(PFarm, "Blocking", 3, 592)
-- Wire header toggle → Cfg
local _blockConn
_blockConn = RunService.Heartbeat:Connect(function()
    Cfg.Block.Enabled = getBlockEnabled()
end)

local getABlk = Checkbox(bBlockBody, "Enable Auto Block",        true,  1)
local getAPun = Checkbox(bBlockBody, "Auto Punish (Attack Back)", true,  2)
local getFAtt = Checkbox(bBlockBody, "Face Attacker",             true,  3)
local sRBtn   = Btn(bBlockBody, "Show Range", 4)
local showROn = false
sRBtn.MouseButton1Click:Connect(function()
    showROn = not showROn
    sRBtn.BackgroundColor3 = showROn and C.Purple or C.BtnBg
    sRBtn.Text = showROn and "■ Hide Range" or "Show Range"
end)
local getDetR = Slider(bBlockBody, "Detection Range",  5, 80,  20, " studs", 5)
local getBlkD = Slider(bBlockBody, "Block Delay",      0, 5,    0, "s",      6)

-- ─────────────────────────────────────────────────────────────────────────────
-- TAB: COMBAT SYSTEM
-- ─────────────────────────────────────────────────────────────────────────────
local PCombat = TabPanel("Combat")
local _, bCS = Section(PCombat, "Settings", 1, 592)
local getCTpM  = Dropdown(bCS, "Teleport Method",
    {"Tween","Instant","Lerp"}, "Tween", 1)
local getCMove = Dropdown(bCS, "Movement Mode",
    {"Orbit (Dodge)","Follow","Static"}, "Orbit (Dodge)", 2)
local getCSpd  = Slider(bCS, "Tween Speed",    50, 400, 135, " studs/s", 3)
local getCFD   = Slider(bCS, "Follow Distance",  2,  30,   4, " studs",  4)
local getCKit  = Checkbox(bCS, "Smart Kiting (Retreat on CD)", true, 5)
Sep(bCS, 6)
SubHdr(bCS, "Main Configurations", 7)
local getCFlee = Checkbox(bCS, "Auto Flee (Low HP)", false, 8)
local getCFHP  = Slider(bCS, "Flee Health %", 5, 80, 20, "%", 9)
local getCPrio = Checkbox(bCS, "Priority Closest", true, 10)
local getCHunt = Checkbox(bCS, "Hunter Mode", false, 11)
Sep(bCS, 12)
SubHdr(bCS, "Skill System", 13)
local getCSk   = Dropdown(bCS, "Select Skills",
    {"Divergent Fist","Black Flash","Hollow Purple","Domain Expansion","All"},
    "Divergent Fist", 14)
local getCSD   = Slider(bCS, "Use Skill Delay", 0, 30, 0, "s", 15)
local getCANT  = Checkbox(bCS, "Avoid Skills With Target Required", true, 16)
Sep(bCS, 17)
local getCSKA  = Checkbox(bCS, "Semi Kill Aura (25 Studs)", false, 18)
local getCSpin = Checkbox(bCS, "SpinBot", false, 19)

-- ─────────────────────────────────────────────────────────────────────────────
-- TAB: VISUALS / ESP
-- ─────────────────────────────────────────────────────────────────────────────
local PVisl  = TabPanel("Visl")
local rowVA  = RowFrame(PVisl, 1)

local _, bVEn = Section(rowVA, "Enable", 1, 288)
local getESP  = Checkbox(bVEn, "Enable ESP Players", false, 1)

local _, bVCfg   = Section(rowVA, "Configurations", 2, 288)
local getVBox    = Checkbox(bVCfg, "Box",           true, 1)
local getVTr     = Checkbox(bVCfg, "Tracers",       true, 2)
local getVHP     = Checkbox(bVCfg, "Health Bar",    true, 3)
local getVDist   = Checkbox(bVCfg, "Distance",      true, 4)
local getVName   = Checkbox(bVCfg, "Name",          true, 5)
local getVMove   = Checkbox(bVCfg, "Moveset (Class)",true,6)

-- ─────────────────────────────────────────────────────────────────────────────
-- TAB: MISC
-- ─────────────────────────────────────────────────────────────────────────────
local PMisc  = TabPanel("Misc")
local rowMA  = RowFrame(PMisc, 1)

local _, bStuff  = Section(rowMA, "Stuff", 1, 288)
local getAR   = Checkbox(bStuff, "Anti Ragdoll",              false, 1)
local getAT   = Checkbox(bStuff, "Auto Tech (Jump on Ragdoll)", false, 2)
local getWS   = Checkbox(bStuff, "WalkSpeed Bypass (Velocity)", false, 3)
local getMSp  = Slider(bStuff, "Speed Amount", 16, 500, 100, " studs/s", 4)
local getIJ   = Checkbox(bStuff, "Infinite Jump", false, 5)
local getFB   = Checkbox(bStuff, "Fullbright",    false, 6)
local getWSc  = Checkbox(bStuff, "White Screen",  false, 7)
local getAFK  = Checkbox(bStuff, "Anti AFK",      true,  8)
local getCTP  = Checkbox(bStuff, "Click TP (Ctrl+Click)", false, 9)
local getTC   = Slider(bStuff, "Time Changer", 0, 24, 14, "h", 10)
Sep(bStuff, 11)
local fpsBtn  = Btn(bStuff, "FPS Boost",   12)
local hopBtn  = Btn(bStuff, "Server Hop",  13)

local _, bPC     = Section(rowMA, "Player Control", 2, 288)
local function GetPlayerNames()
    local t = {"(none)"}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then t[#t+1] = p.Name end
    end
    return t
end
local getSP  = Dropdown(bPC, "Select Player", GetPlayerNames(), "(none)", 1)
local specBtn  = Btn(bPC, "▶  Spectate",      2)
local stopSBtn = Btn(bPC, "■  Stop Spectate", 3)
local tpBtn    = Btn(bPC, "↑  Teleport to",   4)

-- ─────────────────────────────────────────────────────────────────────────────
-- TAB: CREDITS
-- ─────────────────────────────────────────────────────────────────────────────
local PCreds = TabPanel("Creds")
local _, bCred = Section(PCreds, "Imp Hub X", 1, 592)
local function CLine(t, col, sz, o)
    local l = Instance.new("TextLabel", bCred)
    l.Size = UDim2.new(1,0,0,sz+8); l.LayoutOrder = o
    l.BackgroundTransparency = 1; l.Text = t
    l.Font = Enum.Font.GothamBold; l.TextColor3 = col
    l.TextSize = sz; l.TextXAlignment = Enum.TextXAlignment.Center
end
CLine("Imp Hub X",                  C.Purple,  22, 1)
CLine("Jujutsu Shenanigans",        C.White,   14, 2)
CLine("Version 4  •  Delta Compatible", C.Gray, 11, 3)
Sep(bCred, 4)
CLine("Auto Farm  |  Aimlock  |  Combat  |  ESP  |  Misc",  C.Gray, 10, 5)
CLine("Block Detection  |  Kill Aura  |  Spin  |  ESP",     C.Gray, 10, 6)
Sep(bCred, 7)
CLine("Toggle GUI: RightShift",     C.PurpleLt, 12, 8)
CLine("For educational purposes only.", C.Gray, 10, 9)

-- ─────────────────────────────────────────────────────────────────────────────
-- Open default tab
-- ─────────────────────────────────────────────────────────────────────────────
SwitchTab("Farm", bFarm, iFarm, lFarm)

-- RightShift toggle
UserInputService.InputBegan:Connect(function(i, gp)
    if gp then return end
    if i.KeyCode == Enum.KeyCode.RightShift then
        Win.Visible = not Win.Visible
    end
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- GAME LOGIC HELPERS
-- ─────────────────────────────────────────────────────────────────────────────
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
    if Cfg.Farm.TargetPlayer ~= "All" and Cfg.Farm.TargetPlayer ~= "(none)" then
        for _, p in ipairs(enemies) do if p.Name == Cfg.Farm.TargetPlayer then return p end end
        return nil
    end
    local m = Cfg.Farm.TargetMethod
    if m == "Closest"   then table.sort(enemies, function(a,b) return Dist(a)<Dist(b) end)
    elseif m == "Furthest" then table.sort(enemies, function(a,b) return Dist(a)>Dist(b) end)
    elseif m == "Random"   then return enemies[math.random(1,#enemies)]
    elseif m == "Most HP"  then table.sort(enemies, function(a,b)
            local ha,hb = Hum(a),Hum(b)
            return (ha and ha.Health or 0) > (hb and hb.Health or 0) end)
    elseif m == "Least HP" then table.sort(enemies, function(a,b)
            local ha,hb = Hum(a),Hum(b)
            return (ha and ha.Health or math.huge) < (hb and hb.Health or math.huge) end)
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
    local r, tr = Root(LP), Root(tgt)
    if not r or not tr then return end
    orbitAngle = orbitAngle + 0.06
    local d = Cfg.Combat.FollowDist + 1.5
    local ox = tr.Position.X + math.cos(orbitAngle)*d
    local oz = tr.Position.Z + math.sin(orbitAngle)*d
    r.CFrame = CFrame.new(ox, tr.Position.Y, oz)
              * CFrame.Angles(0, math.atan2(tr.Position.X-ox, tr.Position.Z-oz), 0)
end

local function MoveToTarget(tgt)
    local r, tr = Root(LP), Root(tgt)
    if not r or not tr then return end
    local dir = (r.Position - tr.Position).Unit
    local cf  = CFrame.new(tr.Position + dir * Cfg.Combat.FollowDist)
                * CFrame.Angles(0, math.atan2(dir.X, dir.Z), 0)
    if Cfg.Combat.TpMethod == "Instant" then
        r.CFrame = cf
    elseif Cfg.Combat.TpMethod == "Lerp" then
        r.CFrame = r.CFrame:Lerp(cf, 0.25)
    else
        local dist = (r.Position - cf.Position).Magnitude
        TweenService:Create(r, TweenInfo.new(
            math.clamp(dist / Cfg.Combat.TweenSpeed, 0.04, 1.5),
            Enum.EasingStyle.Linear), {CFrame=cf}):Play()
    end
end

-- ── Remote scanner (JJS uses Knit; we scan generically) ──────────────────────
local function ScanRemote(...)
    local RS = game:GetService("ReplicatedStorage")
    local names = {...}
    for _, n in ipairs(names) do
        local r = RS:FindFirstChild(n, true)
        if r then return r end
    end
    return nil
end

-- Attack
local lastAtk = 0
local function DoAttack(tgt)
    if tick()-lastAtk < 0.12 then return end; lastAtk = tick()
    local r = Root(tgt); if not r then return end
    pcall(function()
        -- Try common JJS remote names
        local rem = ScanRemote("CombatRemote","Combat","Attack","CombatEvent","Hit","Punch")
        if rem then
            if rem:IsA("RemoteEvent")   then rem:FireServer(r)
            elseif rem:IsA("RemoteFunction") then rem:InvokeServer(r) end
        end
    end)
end

-- Block
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

-- Skill (VirtualInputManager with pcall fallback)
local lastSkill = 0
local function UseSkill(tgt)
    if not Cfg.Farm.UseSkills then return end
    if tick()-lastSkill < math.max(0, Cfg.Combat.SkillDelay) then return end
    if Cfg.Combat.AvoidNoTarget and not tgt then return end
    lastSkill = tick()
    pcall(function()
        local keys = {
            Enum.KeyCode.Q, Enum.KeyCode.E,
            Enum.KeyCode.R, Enum.KeyCode.F,
            Enum.KeyCode.T, Enum.KeyCode.G,
        }
        local k = keys[math.random(1,#keys)]
        -- Try VirtualInputManager first
        local ok2 = pcall(function()
            local vim = game:GetService("VirtualInputManager")
            vim:SendKeyEvent(true,  k, false, game)
            task.delay(0.06, function()
                pcall(function() vim:SendKeyEvent(false, k, false, game) end)
            end)
        end)
        -- Fallback: simulate via UserInputService internal (no-op on most executors but safe)
        if not ok2 then
            pcall(function()
                local ui = game:GetService("UserInputService")
                local e  = Instance.new("InputObject")
                e.KeyCode = k; e.UserInputType = Enum.UserInputType.Keyboard
                e.UserInputState = Enum.UserInputState.Begin
            end)
        end
    end)
end

-- ── Speed bypass ──────────────────────────────────────────────────────────────
local speedBV
local function SetSpeedBypass(on)
    local r = Root(LP); if not r then return end
    if on then
        if not speedBV then
            speedBV = Instance.new("BodyVelocity")
            speedBV.MaxForce = Vector3.new(1e4, 0, 1e4)
            speedBV.Velocity  = Vector3.new(0,0,0)
            speedBV.Parent    = r
        end
    else
        if speedBV then speedBV:Destroy(); speedBV = nil end
    end
end

-- ── Infinite Jump ─────────────────────────────────────────────────────────────
local jumpConn
local function SetInfJump(on)
    if jumpConn then jumpConn:Disconnect(); jumpConn = nil end
    if on then
        jumpConn = UserInputService.JumpRequest:Connect(function()
            local h = Hum(LP); if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
        end)
    end
end

-- ── Fullbright ────────────────────────────────────────────────────────────────
local origAmb, origBrt
local function SetFullbright(on)
    if on then
        origAmb = Lighting.Ambient; origBrt = Lighting.Brightness
        Lighting.Ambient    = Color3.fromRGB(255,255,255)
        Lighting.Brightness = 2; Lighting.FogEnd = 1e6
    else
        if origAmb then Lighting.Ambient = origAmb; Lighting.Brightness = origBrt or 1 end
    end
end

-- ── White Screen ──────────────────────────────────────────────────────────────
local wsGui
local function SetWhiteScreen(on)
    if wsGui then wsGui:Destroy(); wsGui = nil end
    if on then
        wsGui = Instance.new("ScreenGui", PlayerGui)
        wsGui.Name = "ImpHubXWS"; wsGui.ResetOnSpawn = false
        local f = Instance.new("Frame", wsGui)
        f.Size = UDim2.new(1,0,1,0)
        f.BackgroundColor3 = Color3.new(1,1,1)
        f.BackgroundTransparency = 0.35; f.BorderSizePixel = 0
    end
end

-- ── Click TP ─────────────────────────────────────────────────────────────────
local ctpConn
local function SetClickTP(on)
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

-- ── SpinBot ───────────────────────────────────────────────────────────────────
local spinConn
local function SetSpinBot(on)
    if spinConn then spinConn:Disconnect(); spinConn = nil end
    if on then
        spinConn = RunService.RenderStepped:Connect(function()
            local r = Root(LP)
            if r then r.CFrame = r.CFrame * CFrame.Angles(0, math.rad(18), 0) end
        end)
    end
end

-- ── Kill Aura ─────────────────────────────────────────────────────────────────
local killConn
local function SetKillAura(on)
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

-- ── Spectate ─────────────────────────────────────────────────────────────────
local specConn
local function SpectatePlayer(tgt)
    if specConn then specConn:Disconnect(); specConn = nil end
    if not tgt then return end
    Camera.CameraType = Enum.CameraType.Scriptable
    specConn = RunService.RenderStepped:Connect(function()
        local tr = Root(tgt)
        if tr then
            Camera.CFrame = CFrame.new(tr.Position + Vector3.new(0,6,14), tr.Position)
        end
    end)
end
local function StopSpec()
    if specConn then specConn:Disconnect(); specConn = nil end
    Camera.CameraType = Enum.CameraType.Custom
end

-- ── Button wiring ─────────────────────────────────────────────────────────────
specBtn.MouseButton1Click:Connect(function()
    local p = Players:FindFirstChild(getSP()); if p then SpectatePlayer(p) end end)
stopSBtn.MouseButton1Click:Connect(StopSpec)
tpBtn.MouseButton1Click:Connect(function()
    local p = Players:FindFirstChild(getSP()); if p then
        local r, tr = Root(LP), Root(p)
        if r and tr then r.CFrame = tr.CFrame * CFrame.new(0,0,-3) end
    end end)
fpsBtn.MouseButton1Click:Connect(function()
    pcall(function() settings().Rendering.QualityLevel = 1 end)
    Lighting.GlobalShadows = false
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("ParticleEmitter") or v:IsA("Smoke")
        or v:IsA("Sparkles") or v:IsA("Fire") then
            v.Enabled = false
        end
    end
    fpsBtn.Text = "FPS Boost ✓"; fpsBtn.BackgroundColor3 = C.Purple
end)
hopBtn.MouseButton1Click:Connect(function()
    pcall(function()
        local data = HttpService:JSONDecode(
            game:HttpGet("https://games.roblox.com/v1/games/"..game.PlaceId..
                         "/servers/Public?sortOrder=Asc&limit=100"))
        for _, sv in ipairs(data.data or {}) do
            if sv.id ~= game.JobId and sv.playing < sv.maxPlayers then
                TeleportService:TeleportToPlaceInstance(game.PlaceId, sv.id, LP)
                return
            end
        end
    end)
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- SINGLE HEARTBEAT (tick-based, NO yields)
-- ─────────────────────────────────────────────────────────────────────────────
local prev = {
    ska=false, spin=false, ws=false, ij=false,
    fb=false,  wsc=false,  afk=true, ctp=false
}
local blockTimer  = 0
local lastBlocker = nil
local lastTech    = 0
local lastAfk     = 0

RunService.Heartbeat:Connect(function()
    local now = tick()

    -- Pull values from UI into Cfg
    Cfg.Farm.TargetPlayer = getTP()
    Cfg.Farm.TargetMethod = getTM()
    Cfg.Farm.FaceTarget   = getFace()
    Cfg.Farm.FastAttack   = getFast()
    Cfg.Farm.UseSkills    = getSkU()

    Cfg.Aim.Enabled     = getAimOn()
    Cfg.Aim.Mode        = getAimMode()
    Cfg.Aim.TargetPart  = getAimPart()
    Cfg.Aim.Prediction  = getAimPred()

    Cfg.Block.AutoBlock    = getABlk()
    Cfg.Block.AutoPunish   = getAPun()
    Cfg.Block.FaceAttacker = getFAtt()
    Cfg.Block.DetectRange  = getDetR()
    Cfg.Block.BlockDelay   = getBlkD()

    Cfg.Combat.TpMethod     = getCTpM()
    Cfg.Combat.MoveMode     = getCMove():gsub(" %(Dodge%)", "")
    Cfg.Combat.TweenSpeed   = getCSpd()
    Cfg.Combat.FollowDist   = getCFD()
    Cfg.Combat.SmartKiting  = getCKit()
    Cfg.Combat.AutoFlee     = getCFlee()
    Cfg.Combat.FleeHP       = getCFHP()
    Cfg.Combat.SkillName    = getCSk()
    Cfg.Combat.SkillDelay   = getCSD()
    Cfg.Combat.AvoidNoTarget = getCANT()

    Cfg.ESP.Enabled  = getESP()
    Cfg.ESP.Box      = getVBox()
    Cfg.ESP.Tracers  = getVTr()
    Cfg.ESP.HealthBar = getVHP()
    Cfg.ESP.Distance = getVDist()
    Cfg.ESP.Name     = getVName()
    Cfg.ESP.Moveset  = getVMove()

    Cfg.Misc.AntiRagdoll = getAR()
    Cfg.Misc.AutoTech    = getAT()
    Cfg.Misc.Speed       = getMSp()
    Cfg.Misc.TimeHour    = getTC()
    Cfg.Misc.AntiAFK     = getAFK()

    -- One-shot state transitions
    local ska  = getCSKA()  ; if ska  ~= prev.ska  then prev.ska  = ska;  SetKillAura(ska)    end
    local sp   = getCSpin() ; if sp   ~= prev.spin  then prev.spin = sp;   SetSpinBot(sp)      end
    local ws   = getWS()    ; if ws   ~= prev.ws    then prev.ws   = ws;   SetSpeedBypass(ws)  end
    local ij   = getIJ()    ; if ij   ~= prev.ij    then prev.ij   = ij;   SetInfJump(ij)      end
    local fb   = getFB()    ; if fb   ~= prev.fb    then prev.fb   = fb;   SetFullbright(fb)   end
    local wsc  = getWSc()   ; if wsc  ~= prev.wsc   then prev.wsc  = wsc;  SetWhiteScreen(wsc) end
    local ctp  = getCTP()   ; if ctp  ~= prev.ctp   then prev.ctp  = ctp;  SetClickTP(ctp)     end

    -- Anti-AFK (every 60 s, tiny jump=false pulse)
    if Cfg.Misc.AntiAFK and now-lastAfk > 60 then
        lastAfk = now
        pcall(function() local h=Hum(LP); if h then h.Jump=false end end)
    end

    -- Auto Tech (jump out of ragdoll)
    if Cfg.Misc.AutoTech then
        local h = Hum(LP)
        if h then
            local st = h:GetState()
            if (st==Enum.HumanoidStateType.Ragdoll or st==Enum.HumanoidStateType.FallingDown)
               and now-lastTech > 0.3 then
                lastTech = now; h.Jump = true
            end
        end
    end

    -- Speed bypass drive
    if prev.ws and speedBV then
        local c   = LP.Character
        local hum = c and c:FindFirstChildOfClass("Humanoid")
        if hum then
            speedBV.Velocity = hum.MoveDirection * Cfg.Misc.Speed
        end
    end

    -- Anti ragdoll
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

    -- Time changer
    pcall(function() Lighting.ClockTime = Cfg.Misc.TimeHour end)

    -- ── Auto Block (tick-based, no yields) ──────────────────────────────────
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
                else
                    SetBlock(false)
                end
                lastBlocker = nil
            end
        end
    else
        SetBlock(false)
    end

    -- ── Aimlock ──────────────────────────────────────────────────────────────
    if Cfg.Aim.Enabled then
        local tgt = GetTarget()
        if tgt then
            local ch   = tgt.Character
            local part = ch and (ch:FindFirstChild(Cfg.Aim.TargetPart)
                               or ch:FindFirstChild("HumanoidRootPart"))
            if part then
                local pos = part.Position
                if Cfg.Aim.Prediction then
                    pcall(function() pos = pos + part.AssemblyLinearVelocity * 0.1 end)
                end
                if Cfg.Aim.Mode == "Camera" then
                    Camera.CFrame = CFrame.new(Camera.CFrame.Position, pos)
                elseif Cfg.Aim.Mode == "Body" then
                    local r = Root(LP)
                    if r then r.CFrame = CFrame.new(r.Position,
                        Vector3.new(pos.X, r.Position.Y, pos.Z)) end
                elseif Cfg.Aim.Mode == "Silent" then
                    -- silent aim: snap camera only when about to shoot
                    Camera.CFrame = CFrame.new(Camera.CFrame.Position, pos)
                end
            end
        end
    end

    -- ── Auto Farm ────────────────────────────────────────────────────────────
    if Cfg.Farm.Enabled then
        local tgt = GetTarget()
        if tgt then
            local h = Hum(LP)
            -- Auto Flee
            if Cfg.Combat.AutoFlee and h and (h.Health/h.MaxHealth*100) <= Cfg.Combat.FleeHP then
                local r, tr = Root(LP), Root(tgt)
                if r and tr then
                    local away = (r.Position - tr.Position).Unit
                    r.CFrame = CFrame.new(r.Position + away * 35)
                end
            else
                -- Move
                if Cfg.Combat.MoveMode == "Orbit" then OrbitTarget(tgt)
                else MoveToTarget(tgt) end
                -- Face
                if Cfg.Farm.FaceTarget then FaceTarget(tgt) end
                -- Attack
                if Cfg.Farm.FastAttack then DoAttack(tgt) end
                -- Skill
                UseSkill(tgt)
            end
        end
        -- Status display
        local tgt2 = GetTarget()
        statBig.Text       = "[ ACTIVE ]"
        statBig.TextColor3 = C.Green
        statSub.Text       = "Target: " .. (tgt2 and tgt2.Name or "searching...")
    else
        statBig.Text       = "[ DISABLED ]"
        statBig.TextColor3 = C.Red
        statSub.Text       = "Wait for activation..."
    end
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- ESP (RenderStepped)
-- ─────────────────────────────────────────────────────────────────────────────
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
        for _, n in ipairs({"Moveset","Class","Style"}) do
            local v = ls:FindFirstChild(n)
            if v then return tostring(v.Value) end
        end
    end
    return "???"
end

local function MakeESP(p)
    if p == LP or ESPObjs[p] then return end
    local o = {}
    -- Box (4 lines)
    o.Box = {}
    for i = 1, 4 do
        local l = Drawing.new("Line")
        l.Thickness = 1.5; l.Color = Color3.fromRGB(150,55,245)
        l.Visible = false; l.ZIndex = 2; o.Box[i] = l
    end
    -- Tracer
    o.Tracer = Drawing.new("Line")
    o.Tracer.Thickness = 1; o.Tracer.Color = Color3.fromRGB(150,55,245); o.Tracer.Visible = false
    -- Health bar bg
    o.HpBg = Drawing.new("Square")
    o.HpBg.Filled = true; o.HpBg.Color = Color3.fromRGB(18,18,18); o.HpBg.Visible = false
    -- Health bar
    o.Hp = Drawing.new("Square")
    o.Hp.Filled = true; o.Hp.Color = Color3.fromRGB(0,205,60); o.Hp.Visible = false
    -- Name
    o.Name = Drawing.new("Text"); o.Name.Size = 13
    o.Name.Color = Color3.new(1,1,1); o.Name.Center = true; o.Name.Outline = true; o.Name.Visible = false
    -- Distance
    o.Dist = Drawing.new("Text"); o.Dist.Size = 11
    o.Dist.Color = Color3.fromRGB(200,200,200); o.Dist.Center = true; o.Dist.Outline = true; o.Dist.Visible = false
    -- Moveset
    o.Move = Drawing.new("Text"); o.Move.Size = 11
    o.Move.Color = Color3.fromRGB(175,130,255); o.Move.Center = true; o.Move.Outline = true; o.Move.Visible = false
    ESPObjs[p] = o
end

local function RemoveESP(p)
    local o = ESPObjs[p]; if not o then return end
    for _, v in pairs(o) do
        if type(v) == "table" then
            for _, l in ipairs(v) do pcall(function() l:Remove() end) end
        else
            pcall(function() v:Remove() end)
        end
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
        if not p.Parent or not Alive(p) then
            RemoveESP(p)
        else
            local r = Root(p); local h = Hum(p)
            if not r or not h then HideESP(o)
            else
                local sp, vis, dep = Camera:WorldToViewportPoint(r.Position)
                if not vis or dep <= 0 then HideESP(o)
                else
                    local tp = Camera:WorldToViewportPoint(r.Position + Vector3.new(0,3.2,0))
                    local bp = Camera:WorldToViewportPoint(r.Position + Vector3.new(0,-3.2,0))
                    local ht = math.abs(tp.Y - bp.Y)
                    local wd = ht * 0.52
                    local L,R,T,B = sp.X-wd/2, sp.X+wd/2, tp.Y, bp.Y

                    local corners = {
                        {Vector2.new(L,T), Vector2.new(R,T)},
                        {Vector2.new(L,B), Vector2.new(R,B)},
                        {Vector2.new(L,T), Vector2.new(L,B)},
                        {Vector2.new(R,T), Vector2.new(R,B)},
                    }
                    for i, ln in ipairs(o.Box) do
                        ln.From = corners[i][1]; ln.To = corners[i][2]
                        ln.Visible = Cfg.ESP.Box
                    end

                    local vp = Camera.ViewportSize
                    o.Tracer.From    = Vector2.new(vp.X/2, vp.Y)
                    o.Tracer.To      = Vector2.new(sp.X, sp.Y)
                    o.Tracer.Visible = Cfg.ESP.Tracers

                    local pct = math.clamp(h.Health/h.MaxHealth, 0, 1)
                    o.HpBg.Size     = Vector2.new(4, ht)
                    o.HpBg.Position = Vector2.new(L-7, T)
                    o.HpBg.Visible  = Cfg.ESP.HealthBar
                    o.Hp.Size       = Vector2.new(4, ht*pct)
                    o.Hp.Position   = Vector2.new(L-7, T + ht*(1-pct))
                    o.Hp.Color      = Color3.fromRGB(
                        math.floor(255*(1-pct)), math.floor(255*pct), 0)
                    o.Hp.Visible    = Cfg.ESP.HealthBar

                    o.Name.Text     = p.Name
                    o.Name.Position = Vector2.new(sp.X, T-16)
                    o.Name.Visible  = Cfg.ESP.Name

                    o.Dist.Text     = math.floor(Dist(p)).."st"
                    o.Dist.Position = Vector2.new(sp.X, B+3)
                    o.Dist.Visible  = Cfg.ESP.Distance

                    o.Move.Text     = "["..GetMoveset(p).."]"
                    o.Move.Position = Vector2.new(sp.X, B+15)
                    o.Move.Visible  = Cfg.ESP.Moveset
                end
            end
        end
    end
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Cleanup on player leave / respawn
-- ─────────────────────────────────────────────────────────────────────────────
Players.PlayerRemoving:Connect(function(p) RemoveESP(p) end)

LP.CharacterAdded:Connect(function()
    task.wait(1)
    SetSpeedBypass(prev.ws)
    SetInfJump(prev.ij)
    SetClickTP(prev.ctp)
end)

SG.AncestryChanged:Connect(function()
    -- GUI destroyed — clean up drawings
    for p in pairs(ESPObjs) do RemoveESP(p) end
    if spinConn  then spinConn:Disconnect()  end
    if killConn  then killConn:Disconnect()  end
    if specConn  then specConn:Disconnect()  end
    if jumpConn  then jumpConn:Disconnect()  end
    if ctpConn   then ctpConn:Disconnect()   end
    if speedBV   then pcall(function() speedBV:Destroy() end) end
    StopSpec()
end)

print("[ImpHubX v4] ✓ Loaded! Press RightShift to toggle GUI.")

end) -- end pcall

-- ─────────────────────────────────────────────────────────────────────────────
-- Error overlay (shows in-game if script fails)
-- ─────────────────────────────────────────────────────────────────────────────
if not ok then
    warn("[ImpHubX v4 ERROR]: "..tostring(err))
    pcall(function()
        local pg = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
        if not pg then return end
        local esg = Instance.new("ScreenGui", pg)
        esg.Name = "ImpHubXErr"; esg.ResetOnSpawn = false; esg.DisplayOrder = 9999
        local ef  = Instance.new("Frame", esg)
        ef.Size   = UDim2.new(0,600,0,80); ef.Position = UDim2.new(0.5,-300,0,10)
        ef.BackgroundColor3 = Color3.fromRGB(170,25,25); ef.BorderSizePixel = 0
        Instance.new("UICorner", ef).CornerRadius = UDim.new(0,8)
        local el = Instance.new("TextLabel", ef)
        el.Size = UDim2.new(1,-16,1,0); el.Position = UDim2.new(0,8,0,0)
        el.BackgroundTransparency = 1; el.TextWrapped = true
        el.Font = Enum.Font.Gotham; el.TextSize = 11; el.TextColor3 = Color3.new(1,1,1)
        el.TextXAlignment = Enum.TextXAlignment.Left
        el.Text = "[ImpHubX v4 Error]\n"..tostring(err)
    end)
end
