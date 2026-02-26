--[[
    Imp Hub X - Jujutsu Shenanigans v3
    Delta Executor Compatible
    Toggle visibility: RightShift
    All bugs fixed:
      - GUI built BEFORE any loops
      - No task.wait() inside Heartbeat
      - PlayerGui parent (not CoreGui/gethui)
      - Full pcall error catching
      - Single Heartbeat loop
      - Tick-based block delay (no yields)
]]

local ok, err = pcall(function()

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local Lighting         = game:GetService("Lighting")
local HttpService      = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    LocalPlayer = Players.LocalPlayer
end
local Mouse  = LocalPlayer:GetMouse()
local Camera = workspace.CurrentCamera

-- PlayerGui is most compatible with Delta executor
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 10)
if not PlayerGui then warn("[ImpHubX] PlayerGui not found") return end

local old = PlayerGui:FindFirstChild("ImpHubX")
if old then old:Destroy() end

local C = {
    BgDark=Color3.fromRGB(18,18,22),BgMid=Color3.fromRGB(25,25,32),
    BgPanel=Color3.fromRGB(30,30,38),BgSec=Color3.fromRGB(36,36,46),
    Purple=Color3.fromRGB(140,60,255),White=Color3.fromRGB(230,230,235),
    Gray=Color3.fromRGB(150,150,160),Red=Color3.fromRGB(255,70,70),
    Green=Color3.fromRGB(60,220,100),NavBg=Color3.fromRGB(22,22,28),
    NavAct=Color3.fromRGB(70,40,140),Sep=Color3.fromRGB(50,50,65),
    TglOff=Color3.fromRGB(60,60,75),TglOn=Color3.fromRGB(140,60,255),
    ChkBg=Color3.fromRGB(40,40,52),SlBg=Color3.fromRGB(50,50,65),
    SlFill=Color3.fromRGB(140,60,255),DropBg=Color3.fromRGB(35,35,45),
    BtnBg=Color3.fromRGB(45,35,70),BtnHov=Color3.fromRGB(70,50,120),
}

local Cfg = {
    Farm={Enabled=false,TargetPlayer="All",TargetMethod="Closest",FaceTarget=true,FastAttack=true,UseSkills=true},
    Block={Enabled=false,AutoBlock=true,AutoPunish=true,FaceAttacker=true,ShowRange=false,DetectRange=20,BlockDelay=0},
    Aim={Enabled=false,Mode="Camera",TargetPart="Head",Prediction=false},
    Combat={Enabled=false,TpMethod="Tween",MoveMode="Orbit",TweenSpeed=135,FollowDist=4,
            SmartKiting=true,AutoFlee=false,FleeHP=20,PriorClosest=true,HunterMode=false,
            SkillName="Divergent Fist",SkillDelay=6,AvoidNoTarget=true,SemiKillAura=false,SpinBot=false},
    ESP={Enabled=false,Box=true,Tracers=true,HealthBar=true,Distance=true,Name=true,Moveset=true},
    Misc={AntiRagdoll=false,AutoTech=false,WsBypass=false,Speed=100,InfJump=false,
          Fullbright=false,WhiteScreen=false,AntiAFK=true,ClickTP=false,TimeHour=14},
}

-- =====================================================================
-- GUI — Built FIRST before any game logic
-- =====================================================================
local SG = Instance.new("ScreenGui")
SG.Name="ImpHubX"; SG.ResetOnSpawn=false
SG.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
SG.DisplayOrder=999
SG.Parent=PlayerGui  -- PlayerGui, NOT CoreGui

local Win=Instance.new("Frame",SG)
Win.Name="Win"; Win.Size=UDim2.new(0,800,0,540)
Win.Position=UDim2.new(0.5,-400,0.5,-270)
Win.BackgroundColor3=C.BgDark; Win.BorderSizePixel=0; Win.ClipsDescendants=true
Instance.new("UICorner",Win).CornerRadius=UDim.new(0,10)
local ws2=Instance.new("UIStroke",Win); ws2.Color=C.Purple; ws2.Thickness=1.5; ws2.Transparency=0.5

-- Title bar
local TBar=Instance.new("Frame",Win)
TBar.Size=UDim2.new(1,0,0,46); TBar.BackgroundColor3=C.BgMid; TBar.BorderSizePixel=0
Instance.new("UICorner",TBar).CornerRadius=UDim.new(0,10)
local tpatch=Instance.new("Frame",TBar)
tpatch.Size=UDim2.new(1,0,0.5,0); tpatch.Position=UDim2.new(0,0,0.5,0)
tpatch.BackgroundColor3=C.BgMid; tpatch.BorderSizePixel=0

local TIco=Instance.new("Frame",TBar)
TIco.Size=UDim2.new(0,30,0,30); TIco.Position=UDim2.new(0,10,0.5,-15)
TIco.BackgroundColor3=C.Purple; TIco.BorderSizePixel=0
Instance.new("UICorner",TIco).CornerRadius=UDim.new(0,6)
local TIcoL=Instance.new("TextLabel",TIco)
TIcoL.Size=UDim2.new(1,0,1,0); TIcoL.BackgroundTransparency=1
TIcoL.Text="I"; TIcoL.Font=Enum.Font.GothamBold; TIcoL.TextColor3=Color3.new(1,1,1); TIcoL.TextSize=16

local TTitle=Instance.new("TextLabel",TBar)
TTitle.Size=UDim2.new(0,200,0,18); TTitle.Position=UDim2.new(0,48,0,6)
TTitle.BackgroundTransparency=1; TTitle.Text="Imp Hub X"
TTitle.Font=Enum.Font.GothamBold; TTitle.TextColor3=C.White; TTitle.TextSize=15
TTitle.TextXAlignment=Enum.TextXAlignment.Left

local TSub=Instance.new("TextLabel",TBar)
TSub.Size=UDim2.new(0,200,0,13); TSub.Position=UDim2.new(0,48,0,26)
TSub.BackgroundTransparency=1; TSub.Text="Jujutsu Shenanigans"
TSub.Font=Enum.Font.Gotham; TSub.TextColor3=C.Gray; TSub.TextSize=11
TSub.TextXAlignment=Enum.TextXAlignment.Left

local BtnX=Instance.new("TextButton",TBar)
BtnX.Size=UDim2.new(0,24,0,24); BtnX.Position=UDim2.new(1,-34,0.5,-12)
BtnX.BackgroundColor3=Color3.fromRGB(200,55,55); BtnX.BorderSizePixel=0
BtnX.Text="X"; BtnX.Font=Enum.Font.GothamBold; BtnX.TextColor3=Color3.new(1,1,1)
BtnX.TextSize=13; BtnX.AutoButtonColor=false
Instance.new("UICorner",BtnX).CornerRadius=UDim.new(0,5)

local BtnMin=Instance.new("TextButton",TBar)
BtnMin.Size=UDim2.new(0,24,0,24); BtnMin.Position=UDim2.new(1,-64,0.5,-12)
BtnMin.BackgroundColor3=C.BgSec; BtnMin.BorderSizePixel=0
BtnMin.Text="-"; BtnMin.Font=Enum.Font.GothamBold; BtnMin.TextColor3=C.Gray
BtnMin.TextSize=13; BtnMin.AutoButtonColor=false
Instance.new("UICorner",BtnMin).CornerRadius=UDim.new(0,5)

-- Drag logic
local drag,dragStart,dragOrigin=false,nil,nil
TBar.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 then
        drag=true; dragStart=i.Position; dragOrigin=Win.Position end end)
TBar.InputEnded:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end end)
UserInputService.InputChanged:Connect(function(i)
    if drag and i.UserInputType==Enum.UserInputType.MouseMovement then
        local d=i.Position-dragStart
        Win.Position=UDim2.new(dragOrigin.X.Scale,dragOrigin.X.Offset+d.X,
                                dragOrigin.Y.Scale,dragOrigin.Y.Offset+d.Y) end end)

local minimized=false
BtnMin.MouseButton1Click:Connect(function()
    minimized=not minimized
    Win.Size=minimized and UDim2.new(0,800,0,46) or UDim2.new(0,800,0,540)
end)
BtnX.MouseButton1Click:Connect(function() SG:Destroy() end)

-- Content area
local Content=Instance.new("Frame",Win)
Content.Size=UDim2.new(1,0,1,-46); Content.Position=UDim2.new(0,0,0,46)
Content.BackgroundTransparency=1; Content.BorderSizePixel=0

-- Left nav
local NavF=Instance.new("Frame",Content)
NavF.Size=UDim2.new(0,182,1,0); NavF.BackgroundColor3=C.NavBg; NavF.BorderSizePixel=0

local NavSF=Instance.new("ScrollingFrame",NavF)
NavSF.Size=UDim2.new(1,0,1,0); NavSF.BackgroundTransparency=1; NavSF.BorderSizePixel=0
NavSF.ScrollBarThickness=3; NavSF.ScrollBarImageColor3=C.Purple
NavSF.CanvasSize=UDim2.new(0,0,0,0); NavSF.AutomaticCanvasSize=Enum.AutomaticSize.Y
local NavLL=Instance.new("UIListLayout",NavSF)
NavLL.SortOrder=Enum.SortOrder.LayoutOrder; NavLL.Padding=UDim.new(0,3)
local NavPad=Instance.new("UIPadding",NavSF)
NavPad.PaddingLeft=UDim.new(0,8); NavPad.PaddingRight=UDim.new(0,8)
NavPad.PaddingTop=UDim.new(0,10); NavPad.PaddingBottom=UDim.new(0,10)

-- Right panel
local RightF=Instance.new("Frame",Content)
RightF.Size=UDim2.new(1,-182,1,0); RightF.Position=UDim2.new(0,182,0,0)
RightF.BackgroundColor3=C.BgDark; RightF.BorderSizePixel=0; RightF.ClipsDescendants=true

-- =====================================================================
-- UI FACTORIES
-- =====================================================================
local function NavHeader(txt,order)
    local f=Instance.new("Frame",NavSF); f.Size=UDim2.new(1,0,0,26)
    f.BackgroundTransparency=1; f.LayoutOrder=order
    local l=Instance.new("TextLabel",f); l.Size=UDim2.new(1,0,1,0)
    l.BackgroundTransparency=1; l.Text=txt; l.Font=Enum.Font.GothamBold
    l.TextColor3=C.Gray; l.TextSize=9; l.TextXAlignment=Enum.TextXAlignment.Left
    local p=Instance.new("UIPadding",l); p.PaddingLeft=UDim.new(0,4); p.PaddingTop=UDim.new(0,8)
end

local navBtns={}
local function NavBtn(icon,txt,order)
    local btn=Instance.new("TextButton",NavSF)
    btn.Size=UDim2.new(1,0,0,36); btn.BackgroundColor3=C.NavBg
    btn.BorderSizePixel=0; btn.Text=""; btn.LayoutOrder=order; btn.AutoButtonColor=false
    Instance.new("UICorner",btn).CornerRadius=UDim.new(0,7)
    local ico=Instance.new("TextLabel",btn)
    ico.Size=UDim2.new(0,22,0,22); ico.Position=UDim2.new(0,6,0.5,-11)
    ico.BackgroundColor3=C.BgSec; ico.BorderSizePixel=0
    ico.Text=icon; ico.Font=Enum.Font.GothamBold; ico.TextColor3=C.Gray; ico.TextSize=11
    Instance.new("UICorner",ico).CornerRadius=UDim.new(0,5)
    local lbl=Instance.new("TextLabel",btn)
    lbl.Size=UDim2.new(1,-34,1,0); lbl.Position=UDim2.new(0,33,0,0)
    lbl.BackgroundTransparency=1; lbl.Text=txt; lbl.Font=Enum.Font.Gotham
    lbl.TextColor3=C.Gray; lbl.TextSize=13; lbl.TextXAlignment=Enum.TextXAlignment.Left
    table.insert(navBtns,{btn=btn,ico=ico,lbl=lbl})
    return btn,ico,lbl
end

local tabs={}
local function TabPanel(name)
    local sf=Instance.new("ScrollingFrame",RightF); sf.Name=name
    sf.Size=UDim2.new(1,0,1,0); sf.BackgroundTransparency=1; sf.BorderSizePixel=0
    sf.ScrollBarThickness=4; sf.ScrollBarImageColor3=C.Purple
    sf.CanvasSize=UDim2.new(0,0,0,0); sf.AutomaticCanvasSize=Enum.AutomaticSize.Y; sf.Visible=false
    local ll=Instance.new("UIListLayout",sf); ll.SortOrder=Enum.SortOrder.LayoutOrder; ll.Padding=UDim.new(0,8)
    local pad=Instance.new("UIPadding",sf)
    pad.PaddingLeft=UDim.new(0,10); pad.PaddingRight=UDim.new(0,10)
    pad.PaddingTop=UDim.new(0,10); pad.PaddingBottom=UDim.new(0,20)
    tabs[name]=sf; return sf
end

local function SwitchTab(name,btn,ico,lbl)
    for _,p in pairs(tabs) do p.Visible=false end
    for _,nb in ipairs(navBtns) do
        nb.btn.BackgroundColor3=C.NavBg; nb.lbl.Font=Enum.Font.Gotham
        nb.lbl.TextColor3=C.Gray; nb.ico.BackgroundColor3=C.BgSec; nb.ico.TextColor3=C.Gray
    end
    if tabs[name] then tabs[name].Visible=true end
    btn.BackgroundColor3=C.NavAct; lbl.Font=Enum.Font.GothamBold
    lbl.TextColor3=C.White; ico.BackgroundColor3=C.Purple; ico.TextColor3=Color3.new(1,1,1)
end

local function RowFrame(parent,order)
    local f=Instance.new("Frame",parent); f.Size=UDim2.new(1,0,0,0)
    f.AutomaticSize=Enum.AutomaticSize.Y; f.BackgroundTransparency=1; f.LayoutOrder=order
    local ll=Instance.new("UIListLayout",f); ll.FillDirection=Enum.FillDirection.Horizontal
    ll.HorizontalAlignment=Enum.HorizontalAlignment.Left; ll.Padding=UDim.new(0,8)
    ll.SortOrder=Enum.SortOrder.LayoutOrder; return f
end

local function Section(parent,title,order,w)
    w=w or 288
    local card=Instance.new("Frame",parent); card.Size=UDim2.new(0,w,0,0)
    card.AutomaticSize=Enum.AutomaticSize.Y; card.BackgroundColor3=C.BgSec
    card.BorderSizePixel=0; card.LayoutOrder=order
    Instance.new("UICorner",card).CornerRadius=UDim.new(0,8)
    local hdr=Instance.new("Frame",card); hdr.Size=UDim2.new(1,0,0,38)
    hdr.BackgroundColor3=C.BgPanel; hdr.BorderSizePixel=0
    Instance.new("UICorner",hdr).CornerRadius=UDim.new(0,8)
    local hp=Instance.new("Frame",hdr); hp.Size=UDim2.new(1,0,0.5,0)
    hp.Position=UDim2.new(0,0,0.5,0); hp.BackgroundColor3=C.BgPanel; hp.BorderSizePixel=0
    local ico=Instance.new("Frame",hdr); ico.Size=UDim2.new(0,22,0,22)
    ico.Position=UDim2.new(0,10,0.5,-11); ico.BackgroundColor3=C.BgSec; ico.BorderSizePixel=0
    Instance.new("UICorner",ico).CornerRadius=UDim.new(1,0)
    local icoL=Instance.new("TextLabel",ico); icoL.Size=UDim2.new(1,0,1,0)
    icoL.BackgroundTransparency=1; icoL.Text="*"; icoL.Font=Enum.Font.GothamBold
    icoL.TextColor3=C.Purple; icoL.TextSize=11
    local titL=Instance.new("TextLabel",hdr); titL.Size=UDim2.new(1,-80,1,0)
    titL.Position=UDim2.new(0,38,0,0); titL.BackgroundTransparency=1; titL.Text=title
    titL.Font=Enum.Font.GothamBold; titL.TextColor3=C.White; titL.TextSize=13
    titL.TextXAlignment=Enum.TextXAlignment.Left
    local tBg=Instance.new("TextButton",hdr); tBg.Size=UDim2.new(0,36,0,20)
    tBg.Position=UDim2.new(1,-46,0.5,-10); tBg.BackgroundColor3=C.TglOff
    tBg.BorderSizePixel=0; tBg.Text=""; tBg.AutoButtonColor=false
    Instance.new("UICorner",tBg).CornerRadius=UDim.new(1,0)
    local knob=Instance.new("Frame",tBg); knob.Size=UDim2.new(0,14,0,14)
    knob.Position=UDim2.new(0,3,0.5,-7); knob.BackgroundColor3=Color3.fromRGB(200,200,200)
    knob.BorderSizePixel=0; Instance.new("UICorner",knob).CornerRadius=UDim.new(1,0)
    local body=Instance.new("Frame",card); body.Size=UDim2.new(1,0,0,0)
    body.AutomaticSize=Enum.AutomaticSize.Y; body.BackgroundTransparency=1
    local bl=Instance.new("UIListLayout",body); bl.SortOrder=Enum.SortOrder.LayoutOrder; bl.Padding=UDim.new(0,0)
    local bp=Instance.new("UIPadding",body)
    bp.PaddingLeft=UDim.new(0,10); bp.PaddingRight=UDim.new(0,10)
    bp.PaddingTop=UDim.new(0,6); bp.PaddingBottom=UDim.new(0,10)
    return card,body,tBg,knob
end

local function Checkbox(parent,txt,def,order)
    local row=Instance.new("Frame",parent); row.Size=UDim2.new(1,0,0,28)
    row.BackgroundTransparency=1; row.LayoutOrder=order
    local box=Instance.new("TextButton",row); box.Size=UDim2.new(0,16,0,16)
    box.Position=UDim2.new(0,0,0.5,-8); box.BackgroundColor3=def and C.Purple or C.ChkBg
    box.BorderSizePixel=0; box.Text=def and "v" or ""; box.Font=Enum.Font.GothamBold
    box.TextColor3=Color3.new(1,1,1); box.TextSize=10; box.AutoButtonColor=false
    Instance.new("UICorner",box).CornerRadius=UDim.new(0,3)
    local lbl=Instance.new("TextLabel",row); lbl.Size=UDim2.new(1,-22,1,0)
    lbl.Position=UDim2.new(0,22,0,0); lbl.BackgroundTransparency=1; lbl.Text=txt
    lbl.Font=Enum.Font.Gotham; lbl.TextColor3=C.White; lbl.TextSize=12
    lbl.TextXAlignment=Enum.TextXAlignment.Left
    local state=def or false
    local function Set(v) state=v; box.BackgroundColor3=v and C.Purple or C.ChkBg; box.Text=v and "v" or "" end
    box.MouseButton1Click:Connect(function() Set(not state) end)
    lbl.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then Set(not state) end end)
    return box,function() return state end,Set
end

-- Sliders use a shared InputChanged connection
local sliderList={}
UserInputService.InputChanged:Connect(function(i)
    if i.UserInputType~=Enum.UserInputType.MouseMovement then return end
    for _,s in ipairs(sliderList) do
        if s.active then
            local rel=math.clamp((i.Position.X-s.track.AbsolutePosition.X)/s.track.AbsoluteSize.X,0,1)
            s.value=math.floor(s.min+rel*(s.max-s.min))
            s.fill.Size=UDim2.new(rel,0,1,0); s.thumb.Position=UDim2.new(rel,-6,0.5,-7)
            s.valL.Text=tostring(s.value)..s.suf
        end
    end
end)

local function Slider(parent,txt,mn,mx,def,suf,order)
    local row=Instance.new("Frame",parent); row.Size=UDim2.new(1,0,0,48)
    row.BackgroundTransparency=1; row.LayoutOrder=order
    local top=Instance.new("Frame",row); top.Size=UDim2.new(1,0,0,18); top.BackgroundTransparency=1
    local lbl=Instance.new("TextLabel",top); lbl.Size=UDim2.new(0.6,0,1,0)
    lbl.BackgroundTransparency=1; lbl.Text=txt; lbl.Font=Enum.Font.Gotham
    lbl.TextColor3=C.White; lbl.TextSize=12; lbl.TextXAlignment=Enum.TextXAlignment.Left
    local valL=Instance.new("TextLabel",top); valL.Size=UDim2.new(0.4,0,1,0)
    valL.Position=UDim2.new(0.6,0,0,0); valL.BackgroundTransparency=1
    valL.Text=tostring(def)..(suf or ""); valL.Font=Enum.Font.Gotham
    valL.TextColor3=C.Purple; valL.TextSize=12; valL.TextXAlignment=Enum.TextXAlignment.Right
    local track=Instance.new("Frame",row); track.Size=UDim2.new(1,-20,0,5)
    track.Position=UDim2.new(0,10,0,30); track.BackgroundColor3=C.SlBg; track.BorderSizePixel=0
    Instance.new("UICorner",track).CornerRadius=UDim.new(1,0)
    local fill=Instance.new("Frame",track)
    fill.Size=UDim2.new((def-mn)/(mx-mn),0,1,0); fill.BackgroundColor3=C.SlFill; fill.BorderSizePixel=0
    Instance.new("UICorner",fill).CornerRadius=UDim.new(1,0)
    local thumb=Instance.new("Frame",track); thumb.Size=UDim2.new(0,13,0,13)
    thumb.Position=UDim2.new((def-mn)/(mx-mn),-6,0.5,-7); thumb.BackgroundColor3=Color3.new(1,1,1)
    thumb.BorderSizePixel=0; thumb.ZIndex=3
    Instance.new("UICorner",thumb).CornerRadius=UDim.new(1,0)
    local sd={track=track,fill=fill,thumb=thumb,valL=valL,min=mn,max=mx,value=def,suf=suf or "",active=false}
    table.insert(sliderList,sd)
    track.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then
            sd.active=true
            local rel=math.clamp((i.Position.X-track.AbsolutePosition.X)/track.AbsoluteSize.X,0,1)
            sd.value=math.floor(mn+rel*(mx-mn)); fill.Size=UDim2.new(rel,0,1,0)
            thumb.Position=UDim2.new(rel,-6,0.5,-7); valL.Text=tostring(sd.value)..sd.suf
        end
    end)
    track.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then sd.active=false end end)
    return row,function() return sd.value end
end

-- Dropdown — list rendered directly in RightF at high ZIndex to avoid clipping
local function Dropdown(parent,txt,opts,def,order)
    local row=Instance.new("Frame",parent); row.Size=UDim2.new(1,0,0,32)
    row.BackgroundTransparency=1; row.LayoutOrder=order; row.ClipsDescendants=false
    local lbl=Instance.new("TextLabel",row); lbl.Size=UDim2.new(0.44,0,1,0)
    lbl.BackgroundTransparency=1; lbl.Text=txt; lbl.Font=Enum.Font.Gotham
    lbl.TextColor3=C.White; lbl.TextSize=12; lbl.TextXAlignment=Enum.TextXAlignment.Left
    local dbtn=Instance.new("TextButton",row); dbtn.Size=UDim2.new(0.56,0,0,26)
    dbtn.Position=UDim2.new(0.44,0,0,3); dbtn.BackgroundColor3=C.DropBg; dbtn.BorderSizePixel=0
    dbtn.Text=def or opts[1]; dbtn.Font=Enum.Font.Gotham; dbtn.TextColor3=C.White
    dbtn.TextSize=11; dbtn.AutoButtonColor=false; dbtn.ClipsDescendants=false
    Instance.new("UICorner",dbtn).CornerRadius=UDim.new(0,5)
    local arr=Instance.new("TextLabel",dbtn); arr.Size=UDim2.new(0,14,1,0)
    arr.Position=UDim2.new(1,-16,0,0); arr.BackgroundTransparency=1; arr.Text="v"
    arr.Font=Enum.Font.Gotham; arr.TextColor3=C.Purple; arr.TextSize=10
    -- List in RightF so it isn't clipped by ScrollingFrames
    local list=Instance.new("Frame",RightF); list.BackgroundColor3=C.DropBg
    list.BorderSizePixel=0; list.ZIndex=50; list.Visible=false; list.Size=UDim2.new(0,1,0,1)
    Instance.new("UICorner",list).CornerRadius=UDim.new(0,5)
    local ll=Instance.new("UIListLayout",list); ll.SortOrder=Enum.SortOrder.LayoutOrder
    local sel=def or opts[1]; local isOpen=false
    for i,opt in ipairs(opts) do
        local ob=Instance.new("TextButton",list); ob.Size=UDim2.new(1,0,0,24)
        ob.BackgroundColor3=C.DropBg; ob.BorderSizePixel=0; ob.Text="  "..opt
        ob.Font=Enum.Font.Gotham; ob.TextColor3=opt==sel and C.Purple or C.White
        ob.TextSize=11; ob.TextXAlignment=Enum.TextXAlignment.Left
        ob.ZIndex=51; ob.LayoutOrder=i; ob.AutoButtonColor=false
        ob.MouseButton1Click:Connect(function()
            sel=opt; dbtn.Text=opt; isOpen=false; list.Visible=false
            for _,c in ipairs(list:GetChildren()) do
                if c:IsA("TextButton") then
                    c.TextColor3=c.Text:gsub("^%s+","")==opt and C.Purple or C.White end end
        end)
    end
    dbtn.MouseButton1Click:Connect(function()
        isOpen=not isOpen
        if isOpen then
            local ap=dbtn.AbsolutePosition; local rp=RightF.AbsolutePosition; local as=dbtn.AbsoluteSize
            list.Position=UDim2.new(0,ap.X-rp.X,0,ap.Y-rp.Y+as.Y+2)
            list.Size=UDim2.new(0,as.X,0,#opts*24); list.Visible=true
        else list.Visible=false end
    end)
    return row,function() return sel end
end

local function Btn(parent,txt,order)
    local b=Instance.new("TextButton",parent); b.Size=UDim2.new(1,0,0,30)
    b.BackgroundColor3=C.BtnBg; b.BorderSizePixel=0; b.Text=txt; b.Font=Enum.Font.GothamBold
    b.TextColor3=C.White; b.TextSize=12; b.LayoutOrder=order; b.AutoButtonColor=false
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,6)
    b.MouseEnter:Connect(function() TweenService:Create(b,TweenInfo.new(0.1),{BackgroundColor3=C.BtnHov}):Play() end)
    b.MouseLeave:Connect(function() TweenService:Create(b,TweenInfo.new(0.1),{BackgroundColor3=C.BtnBg}):Play() end)
    return b
end

local function SubHdr(parent,txt,order)
    local l=Instance.new("TextLabel",parent); l.Size=UDim2.new(1,0,0,20)
    l.BackgroundTransparency=1; l.Text=txt; l.Font=Enum.Font.GothamBold
    l.TextColor3=C.Gray; l.TextSize=9; l.TextXAlignment=Enum.TextXAlignment.Center; l.LayoutOrder=order
end

local function Sep(parent,order)
    local f=Instance.new("Frame",parent); f.Size=UDim2.new(1,0,0,1)
    f.BackgroundColor3=C.Sep; f.BorderSizePixel=0; f.LayoutOrder=order
end

-- =====================================================================
-- NAV
-- =====================================================================
NavHeader("Combat & Auto Farm",1)
local bFarm,iFarm,lFarm=NavBtn("!","Auto Farm",2)
local bCombat,iCombat,lCombat=NavBtn("+","Combat System",3)
NavHeader("ESP Engine",4)
local bVisl,iVisl,lVisl=NavBtn("o","Visuals",5)
NavHeader("Miscellaneous",6)
local bMisc,iMisc,lMisc=NavBtn("*","Misc",7)
NavHeader("Credits & Settings",8)
local bCreds,iCreds,lCreds=NavBtn("c","Credits",9)

bFarm.MouseButton1Click:Connect(function() SwitchTab("Farm",bFarm,iFarm,lFarm) end)
bCombat.MouseButton1Click:Connect(function() SwitchTab("Combat",bCombat,iCombat,lCombat) end)
bVisl.MouseButton1Click:Connect(function() SwitchTab("Visl",bVisl,iVisl,lVisl) end)
bMisc.MouseButton1Click:Connect(function() SwitchTab("Misc",bMisc,iMisc,lMisc) end)
bCreds.MouseButton1Click:Connect(function() SwitchTab("Credits",bCreds,iCreds,lCreds) end)

-- =====================================================================
-- TAB: AUTO FARM
-- =====================================================================
local PFarm=TabPanel("Farm")
local rowFA=RowFrame(PFarm,1)
local _,bFarmSec=Section(rowFA,"Farming",1,284)
local _,getTP=Dropdown(bFarmSec,"Select Players",{"All","Specific"},"All",1)
local _,getTM=Dropdown(bFarmSec,"Target Method",{"Closest","Furthest","Random","Most HP","Least HP"},"Closest",2)
local _,getFace,_=Checkbox(bFarmSec,"Face At Target",true,3)
local _,getFast,_=Checkbox(bFarmSec,"Fast Attack",true,4)
local _,getSkU,_=Checkbox(bFarmSec,"Use Skills",true,5)
SubHdr(bFarmSec,"Control",6)
local farmBtn=Btn(bFarmSec,"Enable Farm",7)
local farmOn=false
farmBtn.MouseButton1Click:Connect(function()
    farmOn=not farmOn; Cfg.Farm.Enabled=farmOn
    farmBtn.BackgroundColor3=farmOn and C.Purple or C.BtnBg
    farmBtn.Text=farmOn and "Disable Farm" or "Enable Farm"
end)

local _,bAimSec=Section(rowFA,"Aimlock",2,284)
local _,getAimOn,_=Checkbox(bAimSec,"Enable Aimlock",false,1)
local _,getAimMode=Dropdown(bAimSec,"Aimlock Mode",{"Camera","Silent","Body"},"Camera",2)
local _,getAimPart=Dropdown(bAimSec,"Target Part",{"Head","HumanoidRootPart","Torso"},"Head",3)
local _,getAimPred,_=Checkbox(bAimSec,"Prediction",false,4)

local _,bStat=Section(PFarm,"Status",2,576)
local statBig=Instance.new("TextLabel",bStat); statBig.Size=UDim2.new(1,0,0,22); statBig.LayoutOrder=1
statBig.BackgroundTransparency=1; statBig.Text="[ DISABLED ]"; statBig.Font=Enum.Font.GothamBold
statBig.TextColor3=C.Red; statBig.TextSize=14; statBig.TextXAlignment=Enum.TextXAlignment.Left
local statSub=Instance.new("TextLabel",bStat); statSub.Size=UDim2.new(1,0,0,14); statSub.LayoutOrder=2
statSub.BackgroundTransparency=1; statSub.Text="Wait for activation..."; statSub.Font=Enum.Font.Gotham
statSub.TextColor3=C.Gray; statSub.TextSize=11; statSub.TextXAlignment=Enum.TextXAlignment.Left

local _,bBlock=Section(PFarm,"Blocking",3,576)
local _,getABlk,_=Checkbox(bBlock,"Enable Auto Block",true,1)
local _,getAPun,_=Checkbox(bBlock,"Auto Punish (Attack Back)",true,2)
local _,getFAtt,_=Checkbox(bBlock,"Face Attacker",true,3)
local sRBtn=Btn(bBlock,"Show Range",4); local showROn=false
sRBtn.MouseButton1Click:Connect(function()
    showROn=not showROn; sRBtn.BackgroundColor3=showROn and C.Purple or C.BtnBg end)
local _,getDetR=Slider(bBlock,"Detection Range",5,60,20," studs",5)
local _,getBlkD=Slider(bBlock,"Block Delay",0,5,0,"s",6)

-- =====================================================================
-- TAB: COMBAT
-- =====================================================================
local PCombat=TabPanel("Combat")
local _,bCS=Section(PCombat,"Settings",1,576)
local _,getCTpM=Dropdown(bCS,"Teleport Method",{"Tween","Instant","Lerp"},"Tween",1)
local _,getCMove=Dropdown(bCS,"Movement Mode",{"Orbit (Dodge)","Follow","Static"},"Orbit (Dodge)",2)
local _,getCSpd=Slider(bCS,"Tween Speed",50,400,135," studs/s",3)
local _,getCFD=Slider(bCS,"Follow Distance",2,30,4," studs",4)
local _,getCKit,_=Checkbox(bCS,"Smart Kiting (Retreat on CD)",true,5)
SubHdr(bCS,"Main Configurations",6)
local _,getCFlee,_=Checkbox(bCS,"Auto Flee (Low HP)",false,7)
local _,getCFHP=Slider(bCS,"Flee Health %",5,80,20,"%",8)
local _,getCPrio,_=Checkbox(bCS,"Priority Closest",true,9)
local _,getCHunt,_=Checkbox(bCS,"Hunter Mode",false,10)
SubHdr(bCS,"Skill System",11)
local _,getCSk=Dropdown(bCS,"Select Skills",{"Divergent Fist","Black Flash","Hollow Purple","Domain Expansion","All"},"Divergent Fist",12)
local _,getCSD=Slider(bCS,"Use Skill Delay",0,30,6,"s",13)
local _,getCANT,_=Checkbox(bCS,"Avoid Skills With Target Required",true,14)
Sep(bCS,15)
local _,getCSKA,_=Checkbox(bCS,"Semi Kill Aura (25 Studs)",false,16)
local _,getCSpin,_=Checkbox(bCS,"SpinBot",false,17)

-- =====================================================================
-- TAB: VISUALS
-- =====================================================================
local PVisl=TabPanel("Visl")
local rowVA=RowFrame(PVisl,1)
local _,bVEn=Section(rowVA,"Enable",1,284)
local _,getESP,_=Checkbox(bVEn,"Enable Esp Players",false,1)
local _,bVCfg=Section(rowVA,"Configurations",2,284)
local _,getVBox,_=Checkbox(bVCfg,"Box",true,1)
local _,getVTr,_=Checkbox(bVCfg,"Tracers",true,2)
local _,getVHP,_=Checkbox(bVCfg,"Health Bar",true,3)
local _,getVDist,_=Checkbox(bVCfg,"Distance",true,4)
local _,getVName,_=Checkbox(bVCfg,"Name",true,5)
local _,getVMove,_=Checkbox(bVCfg,"Moveset (Class)",true,6)

-- =====================================================================
-- TAB: MISC
-- =====================================================================
local PMisc=TabPanel("Misc")
local rowMA=RowFrame(PMisc,1)
local _,bStuff=Section(rowMA,"Stuff",1,284)
local _,getAR,_=Checkbox(bStuff,"Anti Ragdoll",false,1)
local _,getAT,_=Checkbox(bStuff,"Auto Tech (Jump on Ragdoll)",false,2)
local _,getWS,_=Checkbox(bStuff,"WalkSpeed Bypass (Velocity)",false,3)
local _,getMSp=Slider(bStuff,"Speed Amount",16,500,100," studs/s",4)
local _,getIJ,_=Checkbox(bStuff,"Infinite Jump",false,5)
local _,getFB,_=Checkbox(bStuff,"Fullbright",false,6)
local _,getWSc,_=Checkbox(bStuff,"White Screen",false,7)
local _,getAFK,_=Checkbox(bStuff,"Anti AFK",true,8)
local _,getCTP,_=Checkbox(bStuff,"Click TP (Ctrl+Click)",false,9)
local _,getTC=Slider(bStuff,"Time Changer",0,24,14,"h",10)
Sep(bStuff,11)
local fpsBtn=Btn(bStuff,"FPS Boost",12)
local hopBtn=Btn(bStuff,"Server Hop",13)

local _,bPC=Section(rowMA,"Player Control",2,284)
local function GetPlayerNames() local t={"(none)"}
    for _,p in ipairs(Players:GetPlayers()) do if p~=LocalPlayer then t[#t+1]=p.Name end end return t end
local _,getSP=Dropdown(bPC,"Select Player",GetPlayerNames(),"(none)",1)
local specBtn=Btn(bPC,"Spectate Player",2)
local stopSBtn=Btn(bPC,"Stop Spectate",3)
local tpBtn=Btn(bPC,"Teleport to Player",4)

-- =====================================================================
-- TAB: CREDITS
-- =====================================================================
local PCreds2=TabPanel("Credits")
local _,bCred=Section(PCreds2,"Credits",1,576)
local function CLine(t,col,sz,o)
    local l=Instance.new("TextLabel",bCred); l.Size=UDim2.new(1,0,0,sz+8); l.LayoutOrder=o
    l.BackgroundTransparency=1; l.Text=t; l.Font=Enum.Font.GothamBold
    l.TextColor3=col; l.TextSize=sz; l.TextXAlignment=Enum.TextXAlignment.Center end
CLine("Imp Hub X",C.Purple,22,1); CLine("Jujutsu Shenanigans",C.White,14,2)
CLine("v3 - Delta Compatible",C.Gray,11,3); Sep(bCred,4)
CLine("Auto Farm  |  Combat  |  ESP  |  Misc  |  Aimlock",C.Gray,10,5); Sep(bCred,6)
CLine("For educational purposes only.",C.Gray,10,7)

-- =====================================================================
-- OPEN DEFAULT TAB
-- =====================================================================
SwitchTab("Farm",bFarm,iFarm,lFarm)

-- RightShift toggle
UserInputService.InputBegan:Connect(function(i,gp)
    if gp then return end
    if i.KeyCode==Enum.KeyCode.RightShift then Win.Visible=not Win.Visible end end)

-- =====================================================================
-- GAME HELPERS (after GUI)
-- =====================================================================
local function Char(p) return p and p.Character end
local function Root(p) local c=Char(p); return c and c:FindFirstChild("HumanoidRootPart") end
local function Hum(p) local c=Char(p); return c and c:FindFirstChildOfClass("Humanoid") end
local function Alive(p) local h=Hum(p); return h and h.Health>0 end
local function Dist(p) local a,b=Root(LocalPlayer),Root(p)
    return (a and b) and (a.Position-b.Position).Magnitude or math.huge end
local function GetEnemies() local t={}
    for _,p in ipairs(Players:GetPlayers()) do if p~=LocalPlayer and Alive(p) then t[#t+1]=p end end return t end
local function GetTarget()
    local enemies=GetEnemies(); if #enemies==0 then return nil end
    if Cfg.Farm.TargetPlayer~="All" then
        for _,p in ipairs(enemies) do if p.Name==Cfg.Farm.TargetPlayer then return p end end return nil end
    local m=Cfg.Farm.TargetMethod
    if m=="Closest" then table.sort(enemies,function(a,b) return Dist(a)<Dist(b) end)
    elseif m=="Furthest" then table.sort(enemies,function(a,b) return Dist(a)>Dist(b) end)
    elseif m=="Random" then return enemies[math.random(1,#enemies)] end
    return enemies[1]
end
local function FaceTarget(tgt) local r=Root(LocalPlayer); local tr=Root(tgt)
    if r and tr then r.CFrame=CFrame.new(r.Position,Vector3.new(tr.Position.X,r.Position.Y,tr.Position.Z)) end end
local orbitAngle=0
local function OrbitTarget(tgt) local r=Root(LocalPlayer); local tr=Root(tgt)
    if not r or not tr then return end; orbitAngle=orbitAngle+0.05
    local d=Cfg.Combat.FollowDist+2
    local x=tr.Position.X+math.cos(orbitAngle)*d; local z=tr.Position.Z+math.sin(orbitAngle)*d
    r.CFrame=CFrame.new(x,tr.Position.Y,z)*CFrame.Angles(0,math.atan2(tr.Position.X-x,tr.Position.Z-z),0) end
local function MoveToTarget(tgt) local r=Root(LocalPlayer); local tr=Root(tgt)
    if not r or not tr then return end
    local dir=(r.Position-tr.Position).Unit; local cf=tr.CFrame*CFrame.new(dir*Cfg.Combat.FollowDist)
    if Cfg.Combat.TpMethod=="Instant" then r.CFrame=cf
    elseif Cfg.Combat.TpMethod=="Lerp" then r.CFrame=r.CFrame:Lerp(cf,0.3)
    else local d=(r.Position-cf.Position).Magnitude
        TweenService:Create(r,TweenInfo.new(math.clamp(d/Cfg.Combat.TweenSpeed,0.05,1.2),Enum.EasingStyle.Linear),{CFrame=cf}):Play() end end
local lastAtk=0
local function DoAttack(tgt) if tick()-lastAtk<0.15 then return end; lastAtk=tick()
    local rs=game:GetService("ReplicatedStorage")
    local rem=rs:FindFirstChild("Combat") or rs:FindFirstChild("Attack") or rs:FindFirstChild("CombatEvent")
    if rem then pcall(function()
        if rem:IsA("RemoteEvent") then rem:FireServer("Attack",Root(tgt))
        else rem:InvokeServer("Attack",Root(tgt)) end end) end end
local lastSkill=0
local function UseSkill(tgt)
    if not Cfg.Farm.UseSkills then return end
    if tick()-lastSkill<Cfg.Combat.SkillDelay then return end
    if Cfg.Combat.AvoidNoTarget and not tgt then return end; lastSkill=tick()
    pcall(function()
        local vgi=game:GetService("VirtualInputManager")
        local keys={Enum.KeyCode.Q,Enum.KeyCode.E,Enum.KeyCode.R,Enum.KeyCode.F}
        local k=keys[math.random(1,#keys)]; vgi:SendKeyEvent(true,k,false,game)
        task.delay(0.05,function() vgi:SendKeyEvent(false,k,false,game) end) end) end
local isBlocking=false
local function SetBlock(s) if isBlocking==s then return end; isBlocking=s
    pcall(function() local rs=game:GetService("ReplicatedStorage")
        local rem=rs:FindFirstChild("Block") or rs:FindFirstChild("BlockEvent")
        if rem and rem:IsA("RemoteEvent") then rem:FireServer(s and "BlockStart" or "BlockEnd") end end) end
local speedBV
local function SetSpeedBypass(on) local r=Root(LocalPlayer); if not r then return end
    if on then if not speedBV then speedBV=Instance.new("BodyVelocity"); speedBV.MaxForce=Vector3.new(1e4,0,1e4)
        speedBV.Velocity=Vector3.new(0,0,0); speedBV.Parent=r end
    else if speedBV then speedBV:Destroy(); speedBV=nil end end end
local jumpConn
local function SetInfJump(on) if jumpConn then jumpConn:Disconnect(); jumpConn=nil end
    if on then jumpConn=UserInputService.JumpRequest:Connect(function()
        local h=Hum(LocalPlayer); if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end end) end end
local origAmb,origBrt
local function SetFullbright(on)
    if on then origAmb=Lighting.Ambient; origBrt=Lighting.Brightness
        Lighting.Ambient=Color3.fromRGB(255,255,255); Lighting.Brightness=2; Lighting.FogEnd=1e6
    else if origAmb then Lighting.Ambient=origAmb; Lighting.Brightness=origBrt or 1 end end end
local wsGui
local function SetWhiteScreen(on) if wsGui then wsGui:Destroy(); wsGui=nil end
    if on then wsGui=Instance.new("ScreenGui",PlayerGui); wsGui.Name="ImpHubXWS"; wsGui.ResetOnSpawn=false
        local f=Instance.new("Frame",wsGui); f.Size=UDim2.new(1,0,1,0)
        f.BackgroundColor3=Color3.new(1,1,1); f.BackgroundTransparency=0.4; f.BorderSizePixel=0 end end
local ctpConn
local function SetClickTP(on) if ctpConn then ctpConn:Disconnect(); ctpConn=nil end
    if on then ctpConn=UserInputService.InputBegan:Connect(function(inp,gp)
        if gp then return end
        if inp.UserInputType==Enum.UserInputType.MouseButton1
        and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            local r=Root(LocalPlayer); if r then r.CFrame=CFrame.new(Mouse.Hit.Position+Vector3.new(0,3,0)) end end end) end end
local spinConn
local function SetSpinBot(on) if spinConn then spinConn:Disconnect(); spinConn=nil end
    if on then spinConn=RunService.RenderStepped:Connect(function()
        local r=Root(LocalPlayer); if r then r.CFrame=r.CFrame*CFrame.Angles(0,math.rad(20),0) end end) end end
local killConn
local function SetKillAura(on) if killConn then killConn:Disconnect(); killConn=nil end
    if on then local lkA=0
        killConn=RunService.Heartbeat:Connect(function()
            if tick()-lkA<0.15 then return end; lkA=tick()
            for _,e in ipairs(GetEnemies()) do if Dist(e)<=25 then DoAttack(e) end end end) end end
local specConn
local function SpectatePlayer(tgt) if specConn then specConn:Disconnect(); specConn=nil end
    if not tgt then return end; Camera.CameraType=Enum.CameraType.Scriptable
    specConn=RunService.RenderStepped:Connect(function()
        local tr=Root(tgt); if tr then Camera.CFrame=CFrame.new(tr.Position+Vector3.new(0,5,12),tr.Position) end end) end
local function StopSpec() if specConn then specConn:Disconnect(); specConn=nil end
    Camera.CameraType=Enum.CameraType.Custom end

-- Button wiring
specBtn.MouseButton1Click:Connect(function()
    local p=Players:FindFirstChild(getSP()); if p then SpectatePlayer(p) end end)
stopSBtn.MouseButton1Click:Connect(StopSpec)
tpBtn.MouseButton1Click:Connect(function()
    local p=Players:FindFirstChild(getSP()); if p then
        local r=Root(LocalPlayer); local tr=Root(p)
        if r and tr then r.CFrame=tr.CFrame*CFrame.new(0,0,-3) end end end)
fpsBtn.MouseButton1Click:Connect(function()
    pcall(function() settings().Rendering.QualityLevel=1 end)
    Lighting.GlobalShadows=false
    for _,v in ipairs(workspace:GetDescendants()) do
        if v:IsA("ParticleEmitter") or v:IsA("Smoke") or v:IsA("Sparkles") or v:IsA("Fire") then
            v.Enabled=false end end end)
hopBtn.MouseButton1Click:Connect(function()
    pcall(function()
        local data=HttpService:JSONDecode(game:HttpGet(
            "https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Asc&limit=100"))
        for _,sv in ipairs(data.data or {}) do
            if sv.id~=game.JobId and sv.playing<sv.maxPlayers then
                game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId,sv.id,LocalPlayer); return end end end) end)

-- =====================================================================
-- SINGLE HEARTBEAT — tick-based, ZERO yields
-- =====================================================================
local prevCSKA=false; local prevCSpin=false; local prevWS=false; local prevIJ=false
local prevFB=false; local prevWSc=false; local prevAFK=true; local prevCTP=false
local prevESP=false; local blockTimer=0; local lastBlocker=nil; local lastTech=0; local lastAfk=0

RunService.Heartbeat:Connect(function()
    local now=tick()
    -- Read UI -> Cfg
    Cfg.Farm.TargetPlayer=getTP(); Cfg.Farm.TargetMethod=getTM()
    Cfg.Farm.FaceTarget=getFace(); Cfg.Farm.FastAttack=getFast(); Cfg.Farm.UseSkills=getSkU()
    Cfg.Aim.Enabled=getAimOn(); Cfg.Aim.Mode=getAimMode(); Cfg.Aim.TargetPart=getAimPart(); Cfg.Aim.Prediction=getAimPred()
    Cfg.Block.AutoBlock=getABlk(); Cfg.Block.AutoPunish=getAPun(); Cfg.Block.FaceAttacker=getFAtt()
    Cfg.Block.DetectRange=getDetR(); Cfg.Block.BlockDelay=getBlkD()
    Cfg.Combat.TpMethod=getCTpM(); Cfg.Combat.MoveMode=getCMove():gsub(" %(Dodge%)","")
    Cfg.Combat.TweenSpeed=getCSpd(); Cfg.Combat.FollowDist=getCFD(); Cfg.Combat.SmartKiting=getCKit()
    Cfg.Combat.AutoFlee=getCFlee(); Cfg.Combat.FleeHP=getCFHP()
    Cfg.Combat.SkillName=getCSk(); Cfg.Combat.SkillDelay=getCSD(); Cfg.Combat.AvoidNoTarget=getCANT()
    Cfg.ESP.Box=getVBox(); Cfg.ESP.Tracers=getVTr(); Cfg.ESP.HealthBar=getVHP()
    Cfg.ESP.Distance=getVDist(); Cfg.ESP.Name=getVName(); Cfg.ESP.Moveset=getVMove()
    Cfg.Misc.AntiRagdoll=getAR(); Cfg.Misc.AutoTech=getAT(); Cfg.Misc.Speed=getMSp(); Cfg.Misc.TimeHour=getTC()
    -- One-shot state changes
    local ska=getCSKA(); if ska~=prevCSKA then prevCSKA=ska; SetKillAura(ska) end
    local sp=getCSpin(); if sp~=prevCSpin then prevCSpin=sp; SetSpinBot(sp) end
    local ws=getWS(); if ws~=prevWS then prevWS=ws; SetSpeedBypass(ws) end
    local ij=getIJ(); if ij~=prevIJ then prevIJ=ij; SetInfJump(ij) end
    local fb=getFB(); if fb~=prevFB then prevFB=fb; SetFullbright(fb) end
    local wsc=getWSc(); if wsc~=prevWSc then prevWSc=wsc; SetWhiteScreen(wsc) end
    local afk=getAFK(); if afk~=prevAFK then prevAFK=afk end
    local ctp=getCTP(); if ctp~=prevCTP then prevCTP=ctp; SetClickTP(ctp) end
    local esp=getESP(); if esp~=prevESP then prevESP=esp; Cfg.ESP.Enabled=esp end
    -- Anti-AFK tick-based
    if prevAFK and now-lastAfk>60 then lastAfk=now
        local h=Hum(LocalPlayer); if h then h.Jump=false end end
    -- Auto Tech
    if Cfg.Misc.AutoTech then local h=Hum(LocalPlayer)
        if h and (h:GetState()==Enum.HumanoidStateType.Ragdoll or h:GetState()==Enum.HumanoidStateType.FallingDown) then
            if now-lastTech>0.3 then lastTech=now; h.Jump=true end end end
    -- Speed bypass
    if prevWS and speedBV then local c=LocalPlayer.Character
        local hum=c and c:FindFirstChildOfClass("Humanoid")
        if hum then speedBV.Velocity=hum.MoveDirection*Cfg.Misc.Speed end end
    -- Anti ragdoll
    local c=LocalPlayer.Character
    if c and Cfg.Misc.AntiRagdoll then
        for _,v in ipairs(c:GetDescendants()) do
            if v:IsA("BallSocketConstraint") or v:IsA("HingeConstraint") then v.Enabled=false end end end
    -- Time changer
    Lighting.ClockTime=Cfg.Misc.TimeHour
    -- Block (tick-based, no yields)
    if Cfg.Block.Enabled and Cfg.Block.AutoBlock then
        local shouldBlock,attacker=false,nil
        for _,p in ipairs(GetEnemies()) do
            if Dist(p)<=Cfg.Block.DetectRange then shouldBlock=true; attacker=p; break end end
        if shouldBlock then
            if Cfg.Block.FaceAttacker and attacker then FaceTarget(attacker) end
            if now>=blockTimer then blockTimer=now+Cfg.Block.BlockDelay; SetBlock(true); lastBlocker=attacker end
        else
            if isBlocking and Cfg.Block.AutoPunish and lastBlocker then SetBlock(false); DoAttack(lastBlocker)
            else SetBlock(false) end; lastBlocker=nil end
    else SetBlock(false) end
    -- Aimlock
    if Cfg.Aim.Enabled then local tgt=GetTarget()
        if tgt then local ch=tgt.Character
            local part=ch and (ch:FindFirstChild(Cfg.Aim.TargetPart) or ch:FindFirstChild("HumanoidRootPart"))
            if part then local pos=part.Position
                if Cfg.Aim.Prediction then pos=pos+part.AssemblyLinearVelocity*0.1 end
                if Cfg.Aim.Mode=="Camera" then Camera.CFrame=CFrame.new(Camera.CFrame.Position,pos)
                elseif Cfg.Aim.Mode=="Body" then local r=Root(LocalPlayer)
                    if r then r.CFrame=CFrame.new(r.Position,Vector3.new(pos.X,r.Position.Y,pos.Z)) end end end end end
    -- Auto Farm
    if Cfg.Farm.Enabled then
        local tgt=GetTarget()
        if tgt then
            local h=Hum(LocalPlayer)
            if Cfg.Combat.AutoFlee and h and (h.Health/h.MaxHealth*100)<=Cfg.Combat.FleeHP then
                local r=Root(LocalPlayer); local tr=Root(tgt)
                if r and tr then local away=(r.Position-tr.Position).Unit
                    r.CFrame=CFrame.new(r.Position+away*30) end
            else
                if Cfg.Combat.MoveMode=="Orbit" then OrbitTarget(tgt) else MoveToTarget(tgt) end
                if Cfg.Farm.FaceTarget then FaceTarget(tgt) end
                if Cfg.Farm.FastAttack then DoAttack(tgt) end
                UseSkill(tgt) end end
        local tgt2=GetTarget()
        statBig.Text="[ ACTIVE ]"; statBig.TextColor3=C.Green
        statSub.Text="Target: "..(tgt2 and tgt2.Name or "searching...")
    else statBig.Text="[ DISABLED ]"; statBig.TextColor3=C.Red; statSub.Text="Wait for activation..." end
end)

-- =====================================================================
-- ESP (RenderStepped)
-- =====================================================================
local ESPObjs={}
local function GetMoveset(p) local ch=p.Character
    if ch then for _,n in ipairs({"Moveset","Class","Style"}) do
        local v=ch:FindFirstChild(n); if v then return v.Value end end end
    local ls=p:FindFirstChild("leaderstats")
    if ls then for _,n in ipairs({"Moveset","Class"}) do
        local v=ls:FindFirstChild(n); if v then return v.Value end end end return "???" end
local function MakeESP(p) if p==LocalPlayer or ESPObjs[p] then return end
    local o={}; o.Box={}
    for i=1,4 do local l=Drawing.new("Line"); l.Thickness=1.5
        l.Color=Color3.fromRGB(160,60,255); l.Visible=false; l.ZIndex=2; o.Box[i]=l end
    o.Tracer=Drawing.new("Line"); o.Tracer.Thickness=1; o.Tracer.Color=Color3.fromRGB(160,60,255); o.Tracer.Visible=false
    o.HpBg=Drawing.new("Square"); o.HpBg.Filled=true; o.HpBg.Color=Color3.fromRGB(20,20,20); o.HpBg.Visible=false
    o.Hp=Drawing.new("Square"); o.Hp.Filled=true; o.Hp.Color=Color3.fromRGB(0,200,60); o.Hp.Visible=false
    o.Name=Drawing.new("Text"); o.Name.Size=13; o.Name.Color=Color3.new(1,1,1); o.Name.Center=true; o.Name.Outline=true; o.Name.Visible=false
    o.Dist=Drawing.new("Text"); o.Dist.Size=11; o.Dist.Color=Color3.fromRGB(200,200,200); o.Dist.Center=true; o.Dist.Outline=true; o.Dist.Visible=false
    o.Move=Drawing.new("Text"); o.Move.Size=11; o.Move.Color=Color3.fromRGB(180,140,255); o.Move.Center=true; o.Move.Outline=true; o.Move.Visible=false
    ESPObjs[p]=o end
local function KillESP(p) local o=ESPObjs[p]; if not o then return end
    for _,v in pairs(o) do if type(v)=="table" then for _,l in ipairs(v) do pcall(function() l:Remove() end) end
        elseif v then pcall(function() v:Remove() end) end end; ESPObjs[p]=nil end
local function HideESP(o) for _,v in pairs(o) do
    if type(v)=="table" then for _,l in ipairs(v) do l.Visible=false end elseif v then v.Visible=false end end end
RunService.RenderStepped:Connect(function()
    if not Cfg.ESP.Enabled then for _,o in pairs(ESPObjs) do HideESP(o) end; return end
    for _,p in ipairs(Players:GetPlayers()) do if p~=LocalPlayer then MakeESP(p) end end
    for p,o in pairs(ESPObjs) do
        if not p.Parent or not Alive(p) then KillESP(p)
        else local r=Root(p); local h=Hum(p)
            if not r or not h then HideESP(o)
            else local sp,vis,dep=Camera:WorldToViewportPoint(r.Position)
                if not vis or dep<=0 then HideESP(o)
                else local tp=Camera:WorldToViewportPoint(r.Position+Vector3.new(0,2.8,0))
                    local bp=Camera:WorldToViewportPoint(r.Position+Vector3.new(0,-3,0))
                    local ht=math.abs(tp.Y-bp.Y); local wd=ht*0.55
                    local L,R,T,B=sp.X-wd/2,sp.X+wd/2,tp.Y,bp.Y
                    local corners={{Vector2.new(L,T),Vector2.new(R,T)},{Vector2.new(L,B),Vector2.new(R,B)},
                                   {Vector2.new(L,T),Vector2.new(L,B)},{Vector2.new(R,T),Vector2.new(R,B)}}
                    for i,ln in ipairs(o.Box) do ln.From=corners[i][1]; ln.To=corners[i][2]; ln.Visible=Cfg.ESP.Box end
                    local vp=Camera.ViewportSize
                    o.Tracer.From=Vector2.new(vp.X/2,vp.Y); o.Tracer.To=Vector2.new(sp.X,sp.Y); o.Tracer.Visible=Cfg.ESP.Tracers
                    local pct=h.Health/h.MaxHealth
                    o.HpBg.Size=Vector2.new(4,ht); o.HpBg.Position=Vector2.new(L-6,T); o.HpBg.Visible=Cfg.ESP.HealthBar
                    o.Hp.Size=Vector2.new(4,ht*pct); o.Hp.Position=Vector2.new(L-6,T+ht*(1-pct))
                    o.Hp.Color=Color3.fromRGB(math.floor(255*(1-pct)),math.floor(255*pct),0); o.Hp.Visible=Cfg.ESP.HealthBar
                    o.Name.Text=p.Name; o.Name.Position=Vector2.new(sp.X,T-15); o.Name.Visible=Cfg.ESP.Name
                    o.Dist.Text=math.floor(Dist(p)).." studs"; o.Dist.Position=Vector2.new(sp.X,B+2); o.Dist.Visible=Cfg.ESP.Distance
                    o.Move.Text="["..GetMoveset(p).."]"; o.Move.Position=Vector2.new(sp.X,B+14); o.Move.Visible=Cfg.ESP.Moveset
                end end end end end)

Players.PlayerRemoving:Connect(function(p) KillESP(p) end)
LocalPlayer.CharacterAdded:Connect(function(char) task.wait(1)
    SetSpeedBypass(prevWS); SetInfJump(prevIJ); SetClickTP(prevCTP) end)

print("[ImpHubX v3] Loaded! GUI visible. Press RightShift to toggle.")

end) -- end pcall

if not ok then
    warn("[ImpHubX ERROR]: "..tostring(err))
    pcall(function()
        local pg=game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
        if not pg then return end
        local esg=Instance.new("ScreenGui",pg); esg.Name="ImpHubXErr"; esg.ResetOnSpawn=false; esg.DisplayOrder=9999
        local ef=Instance.new("TextLabel",esg)
        ef.Size=UDim2.new(0,500,0,70); ef.Position=UDim2.new(0.5,-250,0,10)
        ef.BackgroundColor3=Color3.fromRGB(180,30,30); ef.TextColor3=Color3.new(1,1,1)
        ef.Font=Enum.Font.GothamBold; ef.TextSize=10; ef.TextWrapped=true
        ef.Text="[ImpHubX Error] "..tostring(err); ef.BorderSizePixel=0
        Instance.new("UICorner",ef).CornerRadius=UDim.new(0,6)
    end)
end
