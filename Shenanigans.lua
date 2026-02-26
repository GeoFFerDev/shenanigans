--[[
    Imp Hub X - Jujutsu Shenanigans
    Educational Script - Reconstructed from UI Analysis
    Features: Auto Farm, Combat System, ESP, Misc, Player Control
]]

-- ──────────────────────────────────────────────────────────────
-- SERVICES
-- ──────────────────────────────────────────────────────────────
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local Lighting          = game:GetService("Lighting")
local HttpService       = game:GetService("HttpService")
local CoreGui           = game:GetService("CoreGui")
local Camera            = workspace.CurrentCamera

local LocalPlayer       = Players.LocalPlayer
local Mouse             = LocalPlayer:GetMouse()

-- ──────────────────────────────────────────────────────────────
-- CONFIGURATION (mirrors every UI option)
-- ──────────────────────────────────────────────────────────────
local Config = {
    -- Auto Farm / Farming
    Farm = {
        Enabled         = false,
        SelectedPlayer  = "All",       -- dropdown selection
        TargetMethod    = "Closest",   -- Closest | Furthest | Random | Most HP | Least HP
        FaceAtTarget    = true,
        FastAttack      = true,
        UseSkills       = true,
    },
    -- Blocking
    Block = {
        Enabled         = false,
        AutoBlock       = true,
        AutoPunish      = true,
        FaceAttacker    = true,
        ShowRange       = false,
        DetectionRange  = 20,
        BlockDelay      = 0,
    },
    -- Aimlock
    Aimlock = {
        Enabled         = false,
        EnableAimlock   = false,
        Mode            = "Camera",    -- Camera | Silent | Body
        TargetPart      = "Head",      -- Head | HumanoidRootPart | Torso
        Prediction      = false,
    },
    -- Combat System
    Combat = {
        Enabled              = false,
        TeleportMethod       = "Tween", -- Tween | Instant | Lerp
        MovementMode         = "Orbit", -- Orbit | Follow | Static
        TweenSpeed           = 135,
        FollowDistance       = 4,
        SmartKiting          = true,
        AutoFlee             = false,
        FleeHealthPct        = 20,
        PriorityClosest      = true,
        HunterMode           = false,
        SelectedSkill        = "Divergent Fist",
        UseSkillDelay        = 6,
        AvoidSkillsNoTarget  = true,
        SemiKillAura         = false,
        SpinBot              = false,
    },
    -- ESP / Visuals
    ESP = {
        Enabled      = false,
        EspPlayers   = false,
        Box          = true,
        Tracers      = true,
        HealthBar    = true,
        Distance     = true,
        Name         = true,
        Moveset      = true,
    },
    -- Misc
    Misc = {
        Enabled         = false,
        AntiRagdoll     = false,
        AutoTech        = false,
        WalkSpeedBypass = false,
        Speed           = 100,
        InfiniteJump    = false,
        Fullbright      = false,
        WhiteScreen     = false,
        AntiAFK         = true,
        ClickTP         = false,
        TimeChanger     = 14,
        FPSUnlock       = false,
    },
    -- Player Control
    PlayerControl = {
        SelectedPlayer = "",
    },
}

-- ──────────────────────────────────────────────────────────────
-- HELPERS
-- ──────────────────────────────────────────────────────────────
local function GetCharacter(player)
    return player and player.Character
end

local function GetRoot(player)
    local char = GetCharacter(player)
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function GetHumanoid(player)
    local char = GetCharacter(player)
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function GetHead(player)
    local char = GetCharacter(player)
    return char and char:FindFirstChild("Head")
end

local function IsAlive(player)
    local hum = GetHumanoid(player)
    return hum and hum.Health > 0
end

local function GetDistance(player)
    local myRoot  = GetRoot(LocalPlayer)
    local thRoot  = GetRoot(player)
    if myRoot and thRoot then
        return (myRoot.Position - thRoot.Position).Magnitude
    end
    return math.huge
end

local function GetTargetPart(player)
    local char = GetCharacter(player)
    if not char then return nil end
    return char:FindFirstChild(Config.Aimlock.TargetPart)
        or char:FindFirstChild("HumanoidRootPart")
end

-- ──────────────────────────────────────────────────────────────
-- TARGET SELECTION
-- ──────────────────────────────────────────────────────────────
local function GetAllEnemies()
    local enemies = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and IsAlive(p) then
            table.insert(enemies, p)
        end
    end
    return enemies
end

local function GetTarget()
    local enemies = GetAllEnemies()
    if #enemies == 0 then return nil end

    -- filter by Config.Farm.SelectedPlayer
    if Config.Farm.SelectedPlayer ~= "All" then
        for _, p in ipairs(enemies) do
            if p.Name == Config.Farm.SelectedPlayer then
                return p
            end
        end
        return nil
    end

    local method = Config.Farm.TargetMethod
    if method == "Closest" then
        table.sort(enemies, function(a, b)
            return GetDistance(a) < GetDistance(b)
        end)
    elseif method == "Furthest" then
        table.sort(enemies, function(a, b)
            return GetDistance(a) > GetDistance(b)
        end)
    elseif method == "Most HP" then
        table.sort(enemies, function(a, b)
            local ha = GetHumanoid(a)
            local hb = GetHumanoid(b)
            return (ha and ha.Health or 0) > (hb and hb.Health or 0)
        end)
    elseif method == "Least HP" then
        table.sort(enemies, function(a, b)
            local ha = GetHumanoid(a)
            local hb = GetHumanoid(b)
            return (ha and ha.Health or 0) < (hb and hb.Health or 0)
        end)
    elseif method == "Random" then
        return enemies[math.random(1, #enemies)]
    end
    return enemies[1]
end

-- ──────────────────────────────────────────────────────────────
-- TELEPORT / MOVEMENT
-- ──────────────────────────────────────────────────────────────
local function TweenToPosition(targetCFrame, speed)
    local root = GetRoot(LocalPlayer)
    if not root then return end
    speed = speed or Config.Combat.TweenSpeed
    local dist = (root.Position - targetCFrame.Position).Magnitude
    local duration = dist / speed
    duration = math.clamp(duration, 0.05, 1.0)
    local tween = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Linear), {CFrame = targetCFrame})
    tween:Play()
    tween.Completed:Wait()
end

local function MoveToTarget(target)
    if not target then return end
    local root   = GetRoot(LocalPlayer)
    local tRoot  = GetRoot(target)
    if not root or not tRoot then return end

    local dist   = Config.Combat.FollowDistance
    local dir    = (root.Position - tRoot.Position).Unit
    local targetCF = tRoot.CFrame * CFrame.new(dir * dist)

    if Config.Combat.TeleportMethod == "Instant" then
        root.CFrame = targetCF
    elseif Config.Combat.TeleportMethod == "Lerp" then
        root.CFrame = root.CFrame:Lerp(targetCF, 0.3)
    else -- Tween
        TweenToPosition(targetCF, Config.Combat.TweenSpeed)
    end
end

-- ──────────────────────────────────────────────────────────────
-- ORBIT MOVEMENT
-- ──────────────────────────────────────────────────────────────
local orbitAngle = 0
local function OrbitTarget(target)
    if not target then return end
    local root  = GetRoot(LocalPlayer)
    local tRoot = GetRoot(target)
    if not root or not tRoot then return end
    orbitAngle = orbitAngle + 0.05
    local dist = Config.Combat.FollowDistance + 2
    local x = tRoot.Position.X + math.cos(orbitAngle) * dist
    local z = tRoot.Position.Z + math.sin(orbitAngle) * dist
    root.CFrame = CFrame.new(x, tRoot.Position.Y, z)
        * CFrame.Angles(0, math.atan2(tRoot.Position.X - x, tRoot.Position.Z - z), 0)
end

-- ──────────────────────────────────────────────────────────────
-- FACING
-- ──────────────────────────────────────────────────────────────
local function FaceTarget(target)
    local root  = GetRoot(LocalPlayer)
    local tRoot = GetRoot(target)
    if not root or not tRoot then return end
    root.CFrame = CFrame.new(root.Position, Vector3.new(tRoot.Position.X, root.Position.Y, tRoot.Position.Z))
end

-- ──────────────────────────────────────────────────────────────
-- ATTACK (game-specific remotes for Jujutsu Shenanigans)
-- ──────────────────────────────────────────────────────────────
local CombatRemote   = workspace:FindFirstChild("Remotes") and workspace.Remotes:FindFirstChild("CombatEvent")
local SkillsFolder   = LocalPlayer.PlayerGui:FindFirstChild("Skills") -- fallback
                    or workspace:FindFirstChild("SkillFolder")

local lastAttack = 0
local attackCooldown = 0.15 -- Fast Attack cooldown

local function DoAttack(target)
    local now = tick()
    if now - lastAttack < attackCooldown then return end
    lastAttack = now

    -- Try to fire the combat remote
    local remote = game:GetService("ReplicatedStorage"):FindFirstChild("Combat")
                or game:GetService("ReplicatedStorage"):FindFirstChild("Attack")
                or game:GetService("ReplicatedStorage"):FindFirstChild("CombatEvent")
    if remote and remote:IsA("RemoteEvent") then
        remote:FireServer("Attack", target and GetRoot(target))
    elseif remote and remote:IsA("RemoteFunction") then
        remote:InvokeServer("Attack", target and GetRoot(target))
    else
        -- Fallback: simulate click/input
        local vgui = game:GetService("VirtualInputManager") -- executor dependent
        if vgui then vgui:SendMouseButtonEvent(0, 0, 0, true, game, 1) end
    end
end

-- ──────────────────────────────────────────────────────────────
-- SKILLS
-- ──────────────────────────────────────────────────────────────
local lastSkillUse = 0

local function UseSkill(target)
    if not Config.Farm.UseSkills then return end
    local now = tick()
    if now - lastSkillUse < Config.Combat.UseSkillDelay then return end
    if Config.Combat.AvoidSkillsNoTarget and not target then return end
    lastSkillUse = now

    -- Simulate key press for skill slots (1-4 are common in JJS)
    local skillKeys = {Enum.KeyCode.Q, Enum.KeyCode.E, Enum.KeyCode.R, Enum.KeyCode.F}
    local vgui = game:GetService("VirtualInputManager")
    if vgui then
        local key = skillKeys[math.random(1, #skillKeys)]
        vgui:SendKeyEvent(true, key, false, game)
        task.wait(0.05)
        vgui:SendKeyEvent(false, key, false, game)
    end
end

-- ──────────────────────────────────────────────────────────────
-- BLOCKING SYSTEM
-- ──────────────────────────────────────────────────────────────
local isBlocking = false
local lastBlock  = 0

local function SetBlock(state)
    if isBlocking == state then return end
    isBlocking = state
    -- In JJS blocking is typically held with a key or remote
    local blockRemote = game:GetService("ReplicatedStorage"):FindFirstChild("Block")
                     or game:GetService("ReplicatedStorage"):FindFirstChild("BlockEvent")
    if blockRemote and blockRemote:IsA("RemoteEvent") then
        blockRemote:FireServer(state and "BlockStart" or "BlockEnd")
    else
        -- Simulate key hold
        local vgui = game:GetService("VirtualInputManager")
        if vgui then
            vgui:SendKeyEvent(state, Enum.KeyCode.G, false, game)
        end
    end
end

local blockRangeAdornment
local function ToggleBlockRange(show)
    if blockRangeAdornment then
        blockRangeAdornment:Destroy()
        blockRangeAdornment = nil
    end
    if show then
        local root = GetRoot(LocalPlayer)
        if root then
            local sphere = Instance.new("SelectionSphere", root)
            sphere.Color3 = Color3.fromRGB(100, 100, 255)
            sphere.SurfaceTransparency = 0.7
            sphere.SurfaceColor3 = Color3.fromRGB(100, 100, 255)
            sphere.Adornee = root
            blockRangeAdornment = sphere
        end
    end
end

-- ──────────────────────────────────────────────────────────────
-- AIMLOCK
-- ──────────────────────────────────────────────────────────────
local aimlockTarget = nil
local aimlockConn   = nil

local function EnableAimlock()
    if aimlockConn then aimlockConn:Disconnect() end
    aimlockConn = RunService.RenderStepped:Connect(function()
        if not Config.Aimlock.Enabled or not Config.Aimlock.EnableAimlock then return end
        -- Re-pick target each frame
        aimlockTarget = GetTarget()
        if not aimlockTarget then return end
        local part = GetTargetPart(aimlockTarget)
        if not part then return end

        local targetPos = part.Position
        if Config.Aimlock.Prediction then
            -- Simple linear prediction using velocity
            local vel = part.AssemblyLinearVelocity
            targetPos = targetPos + vel * 0.1
        end

        if Config.Aimlock.Mode == "Camera" then
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, targetPos)
        elseif Config.Aimlock.Mode == "Silent" then
            -- Silent aim: redirect bullet trajectory (executor-dependent)
            Mouse.Hit = CFrame.new(targetPos)
        elseif Config.Aimlock.Mode == "Body" then
            local root = GetRoot(LocalPlayer)
            if root then
                root.CFrame = CFrame.new(root.Position, Vector3.new(targetPos.X, root.Position.Y, targetPos.Z))
            end
        end
    end)
end

local function DisableAimlock()
    if aimlockConn then aimlockConn:Disconnect() aimlockConn = nil end
end

-- ──────────────────────────────────────────────────────────────
-- ESP SYSTEM
-- ──────────────────────────────────────────────────────────────
local ESPObjects = {}

local function GetMovesetLabel(player)
    -- JJS stores moveset/class in leaderstats or a StringValue
    local char = GetCharacter(player)
    if char then
        local moveset = char:FindFirstChild("Moveset")
                     or char:FindFirstChild("Class")
                     or char:FindFirstChild("Style")
        if moveset then return moveset.Value end
    end
    local stats = player:FindFirstChild("leaderstats")
    if stats then
        local ms = stats:FindFirstChild("Moveset") or stats:FindFirstChild("Class")
        if ms then return ms.Value end
    end
    return "Unknown"
end

local function CreateESPForPlayer(player)
    if player == LocalPlayer then return end
    if ESPObjects[player] then return end

    local objects = {}

    -- Box (4 lines forming a rectangle)
    objects.Box = {}
    for i = 1, 4 do
        local line = Drawing.new("Line")
        line.Thickness = 1
        line.Color = Color3.fromRGB(180, 0, 255)
        line.Visible = false
        line.ZIndex = 2
        table.insert(objects.Box, line)
    end

    -- Tracer (line from screen bottom to player)
    objects.Tracer = Drawing.new("Line")
    objects.Tracer.Thickness = 1
    objects.Tracer.Color = Color3.fromRGB(180, 0, 255)
    objects.Tracer.Visible = false

    -- Health Bar background
    objects.HpBarBg = Drawing.new("Square")
    objects.HpBarBg.Filled = true
    objects.HpBarBg.Color = Color3.fromRGB(30, 30, 30)
    objects.HpBarBg.Visible = false

    -- Health Bar fill
    objects.HpBar = Drawing.new("Square")
    objects.HpBar.Filled = true
    objects.HpBar.Color = Color3.fromRGB(0, 200, 60)
    objects.HpBar.Visible = false

    -- Name label
    objects.NameLabel = Drawing.new("Text")
    objects.NameLabel.Size = 13
    objects.NameLabel.Color = Color3.fromRGB(255, 255, 255)
    objects.NameLabel.Center = true
    objects.NameLabel.Outline = true
    objects.NameLabel.Visible = false

    -- Distance label
    objects.DistLabel = Drawing.new("Text")
    objects.DistLabel.Size = 11
    objects.DistLabel.Color = Color3.fromRGB(200, 200, 200)
    objects.DistLabel.Center = true
    objects.DistLabel.Outline = true
    objects.DistLabel.Visible = false

    -- Moveset label
    objects.MoveLabel = Drawing.new("Text")
    objects.MoveLabel.Size = 11
    objects.MoveLabel.Color = Color3.fromRGB(180, 140, 255)
    objects.MoveLabel.Center = true
    objects.MoveLabel.Outline = true
    objects.MoveLabel.Visible = false

    ESPObjects[player] = objects
end

local function RemoveESPForPlayer(player)
    local objects = ESPObjects[player]
    if not objects then return end
    for k, v in pairs(objects) do
        if type(v) == "table" then
            for _, line in ipairs(v) do line:Remove() end
        elseif v.Remove then
            v:Remove()
        end
    end
    ESPObjects[player] = nil
end

local function UpdateESP()
    if not Config.ESP.Enabled or not Config.ESP.EspPlayers then
        for _, objects in pairs(ESPObjects) do
            for k, v in pairs(objects) do
                if type(v) == "table" then
                    for _, l in ipairs(v) do l.Visible = false end
                elseif v then v.Visible = false end
            end
        end
        return
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            if not ESPObjects[player] then
                CreateESPForPlayer(player)
            end
        end
    end

    for player, objects in pairs(ESPObjects) do
        if not player.Parent or not IsAlive(player) then
            RemoveESPForPlayer(player)
        else
            local char = GetCharacter(player)
            local root = GetRoot(player)
            local hum  = GetHumanoid(player)
            if not char or not root or not hum then
                for k, v in pairs(objects) do
                    if type(v) == "table" then
                        for _, l in ipairs(v) do l.Visible = false end
                    elseif v then v.Visible = false end
                end
            else
                -- Compute bounding box via character's model
                local _, onScreen, depth = Camera:WorldToViewportPoint(root.Position)
                if not onScreen or depth <= 0 then
                    for k, v in pairs(objects) do
                        if type(v) == "table" then
                            for _, l in ipairs(v) do l.Visible = false end
                        elseif v then v.Visible = false end
                    end
                else
                    -- Approximate box from HRP + size
                    local screenPos, _ = Camera:WorldToViewportPoint(root.Position)
                    local topPos, _    = Camera:WorldToViewportPoint(root.Position + Vector3.new(0, 2.8, 0))
                    local botPos, _    = Camera:WorldToViewportPoint(root.Position + Vector3.new(0, -3.0, 0))
                    local heightPx = math.abs(topPos.Y - botPos.Y)
                    local widthPx  = heightPx * 0.55

                    local left   = screenPos.X - widthPx / 2
                    local right  = screenPos.X + widthPx / 2
                    local top    = topPos.Y
                    local bottom = botPos.Y

                    -- Box lines: top, bottom, left, right
                    local corners = {
                        {Vector2.new(left, top),    Vector2.new(right, top)},
                        {Vector2.new(left, bottom), Vector2.new(right, bottom)},
                        {Vector2.new(left, top),    Vector2.new(left, bottom)},
                        {Vector2.new(right, top),   Vector2.new(right, bottom)},
                    }
                    for i, line in ipairs(objects.Box) do
                        line.From    = corners[i][1]
                        line.To      = corners[i][2]
                        line.Visible = Config.ESP.Box
                    end

                    -- Tracer
                    local vp = Camera.ViewportSize
                    objects.Tracer.From    = Vector2.new(vp.X / 2, vp.Y)
                    objects.Tracer.To      = Vector2.new(screenPos.X, screenPos.Y)
                    objects.Tracer.Visible = Config.ESP.Tracers

                    -- Health bar
                    local hpPct = hum.Health / hum.MaxHealth
                    local barH  = heightPx
                    local barW  = 4
                    local barX  = left - barW - 2
                    objects.HpBarBg.Size     = Vector2.new(barW, barH)
                    objects.HpBarBg.Position = Vector2.new(barX, top)
                    objects.HpBarBg.Visible  = Config.ESP.HealthBar
                    objects.HpBar.Size       = Vector2.new(barW, barH * hpPct)
                    objects.HpBar.Position   = Vector2.new(barX, top + barH * (1 - hpPct))
                    objects.HpBar.Color      = Color3.fromRGB(
                        math.floor(255 * (1 - hpPct)),
                        math.floor(255 * hpPct), 0)
                    objects.HpBar.Visible    = Config.ESP.HealthBar

                    -- Name
                    objects.NameLabel.Text     = player.Name
                    objects.NameLabel.Position = Vector2.new(screenPos.X, top - 14)
                    objects.NameLabel.Visible  = Config.ESP.Name

                    -- Distance
                    local dist = math.floor(GetDistance(player))
                    objects.DistLabel.Text     = dist .. " studs"
                    objects.DistLabel.Position = Vector2.new(screenPos.X, bottom + 2)
                    objects.DistLabel.Visible  = Config.ESP.Distance

                    -- Moveset
                    objects.MoveLabel.Text     = "[" .. GetMovesetLabel(player) .. "]"
                    objects.MoveLabel.Position = Vector2.new(screenPos.X, bottom + 13)
                    objects.MoveLabel.Visible  = Config.ESP.Moveset
                end
            end
        end
    end
end

-- ──────────────────────────────────────────────────────────────
-- MISC FEATURES
-- ──────────────────────────────────────────────────────────────

-- Anti Ragdoll
local function ApplyAntiRagdoll(char)
    if not char then return end
    for _, v in ipairs(char:GetDescendants()) do
        if v:IsA("BallSocketConstraint") or v:IsA("HingeConstraint") then
            v.Enabled = not Config.Misc.AntiRagdoll
        end
    end
end

-- Auto Tech (jump when ragdolled to recover)
local lastTech = 0
local function AutoTech()
    if not Config.Misc.AutoTech then return end
    local hum = GetHumanoid(LocalPlayer)
    if not hum then return end
    if hum:GetState() == Enum.HumanoidStateType.Ragdoll
    or hum:GetState() == Enum.HumanoidStateType.FallingDown then
        local now = tick()
        if now - lastTech > 0.3 then
            lastTech = now
            hum.Jump = true
            -- Also fire tech remote if exists
            local techRemote = game:GetService("ReplicatedStorage"):FindFirstChild("Tech")
            if techRemote and techRemote:IsA("RemoteEvent") then
                techRemote:FireServer()
            end
        end
    end
end

-- Walkspeed bypass via BodyVelocity
local speedBV
local function ApplySpeedBypass(enabled)
    local root = GetRoot(LocalPlayer)
    if not root then return end
    if enabled then
        if not speedBV then
            speedBV = Instance.new("BodyVelocity")
            speedBV.MaxForce = Vector3.new(1e4, 0, 1e4)
            speedBV.Velocity = Vector3.new(0, 0, 0)
            speedBV.Parent = root
        end
    else
        if speedBV then speedBV:Destroy() speedBV = nil end
        local hum = GetHumanoid(LocalPlayer)
        if hum then hum.WalkSpeed = 16 end
    end
end

-- Infinite jump
local jumpConn
local function SetInfiniteJump(enabled)
    if jumpConn then jumpConn:Disconnect() jumpConn = nil end
    if enabled then
        jumpConn = UserInputService.JumpRequest:Connect(function()
            local hum = GetHumanoid(LocalPlayer)
            if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
        end)
    end
end

-- Fullbright
local originalAmbient, originalBrightness
local function SetFullbright(enabled)
    if enabled then
        originalAmbient    = Lighting.Ambient
        originalBrightness = Lighting.Brightness
        Lighting.Ambient   = Color3.fromRGB(255, 255, 255)
        Lighting.Brightness = 2
        Lighting.FogEnd    = 1e6
        Lighting.ClockTime = 14
    else
        if originalAmbient then
            Lighting.Ambient    = originalAmbient
            Lighting.Brightness = originalBrightness or 1
        end
    end
end

-- White Screen
local whiteGui
local function SetWhiteScreen(enabled)
    if enabled then
        whiteGui = Instance.new("ScreenGui", CoreGui)
        whiteGui.Name = "WhiteScreen"
        local frame = Instance.new("Frame", whiteGui)
        frame.Size = UDim2.new(1, 0, 1, 0)
        frame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        frame.BackgroundTransparency = 0.4
        frame.BorderSizePixel = 0
    else
        if whiteGui then whiteGui:Destroy() whiteGui = nil end
    end
end

-- Anti AFK
local afkConn
local function SetAntiAFK(enabled)
    if afkConn then afkConn:Disconnect() afkConn = nil end
    if enabled then
        afkConn = RunService.Heartbeat:Connect(function()
            -- Jiggle the virtual thumbstick slightly to prevent AFK kick
            local vgui = game:GetService("VirtualInputManager")
            if vgui then
                -- This prevents the idle timeout detection in most executors
                local root = GetRoot(LocalPlayer)
                if root then
                    -- Tiny CFrame nudge that resets idle timer
                    local char = LocalPlayer.Character
                    if char then
                        local fired = char:FindFirstChildOfClass("Humanoid")
                        if fired then
                            fired.Jump = false -- reset to prevent jumping, just tickle the state
                        end
                    end
                end
            end
        end)
    end
end

-- Click TP (Ctrl + Click)
local clickTPConn
local function SetClickTP(enabled)
    if clickTPConn then clickTPConn:Disconnect() clickTPConn = nil end
    if enabled then
        clickTPConn = UserInputService.InputBegan:Connect(function(input, gp)
            if gp then return end
            if input.UserInputType == Enum.UserInputType.MouseButton1
            and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
                local root = GetRoot(LocalPlayer)
                if root then
                    local pos = Mouse.Hit.Position
                    root.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
                end
            end
        end)
    end
end

-- Time Changer
local function SetTimeChanger(hour)
    Lighting.ClockTime = hour
end

-- FPS Boost
local function ApplyFPSBoost()
    -- Reduce quality settings to boost FPS
    settings().Rendering.QualityLevel = 1
    workspace.StreamingEnabled = false
    -- Remove unnecessary particles/effects
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("ParticleEmitter") or v:IsA("Smoke")
        or v:IsA("Sparkles") or v:IsA("Fire") then
            v.Enabled = false
        end
    end
    -- Disable shadows
    Lighting.GlobalShadows = false
end

-- Server Hop
local function ServerHop()
    local success, servers = pcall(function()
        return HttpService:JSONDecode(
            game:HttpGet("https://games.roblox.com/v1/games/"
                .. game.PlaceId
                .. "/servers/Public?sortOrder=Asc&limit=100"))
    end)
    if not success then return end
    local currentJobId = game.JobId
    local bestServer
    for _, server in ipairs(servers.data or {}) do
        if server.id ~= currentJobId and server.playing < server.maxPlayers then
            bestServer = server
            break
        end
    end
    if bestServer then
        game:GetService("TeleportService"):TeleportToPlaceInstance(
            game.PlaceId, bestServer.id, LocalPlayer)
    end
end

-- SpinBot
local spinConn
local function SetSpinBot(enabled)
    if spinConn then spinConn:Disconnect() spinConn = nil end
    if enabled then
        spinConn = RunService.RenderStepped:Connect(function()
            local root = GetRoot(LocalPlayer)
            if root then
                root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(15), 0)
            end
        end)
    end
end

-- Semi Kill Aura
local killAuraConn
local function SetSemiKillAura(enabled)
    if killAuraConn then killAuraConn:Disconnect() killAuraConn = nil end
    if enabled then
        killAuraConn = RunService.Heartbeat:Connect(function()
            local enemies = GetAllEnemies()
            for _, enemy in ipairs(enemies) do
                if GetDistance(enemy) <= 25 then
                    DoAttack(enemy)
                end
            end
        end)
    end
end

-- Spectate player
local specConn
local function SpectatePlayer(targetPlayer)
    if specConn then specConn:Disconnect() specConn = nil end
    if not targetPlayer then return end
    specConn = RunService.RenderStepped:Connect(function()
        local tRoot = GetRoot(targetPlayer)
        if tRoot then
            Camera.CameraType = Enum.CameraType.Scriptable
            Camera.CFrame = CFrame.new(
                tRoot.Position + Vector3.new(0, 5, 10),
                tRoot.Position)
        end
    end)
end

local function StopSpectate()
    if specConn then specConn:Disconnect() specConn = nil end
    Camera.CameraType = Enum.CameraType.Custom
end

local function TeleportToPlayer(targetPlayer)
    local root  = GetRoot(LocalPlayer)
    local tRoot = GetRoot(targetPlayer)
    if root and tRoot then
        root.CFrame = tRoot.CFrame * CFrame.new(0, 0, -3)
    end
end

-- Auto Flee
local function CheckAutoFlee(target)
    if not Config.Combat.AutoFlee then return false end
    local hum = GetHumanoid(LocalPlayer)
    if not hum then return false end
    local pct = (hum.Health / hum.MaxHealth) * 100
    if pct <= Config.Combat.FleeHealthPct then
        -- Run away from target
        local root  = GetRoot(LocalPlayer)
        local tRoot = GetRoot(target)
        if root and tRoot then
            local awayDir = (root.Position - tRoot.Position).Unit
            local fleeCF  = CFrame.new(root.Position + awayDir * 30)
            if Config.Combat.TeleportMethod == "Instant" then
                root.CFrame = fleeCF
            else
                TweenToPosition(fleeCF, Config.Combat.TweenSpeed * 1.5)
            end
        end
        return true
    end
    return false
end

-- ──────────────────────────────────────────────────────────────
-- MAIN LOOPS
-- ──────────────────────────────────────────────────────────────
local farmConn
local function StartFarm()
    if farmConn then farmConn:Disconnect() end
    farmConn = RunService.Heartbeat:Connect(function()
        if not Config.Farm.Enabled then return end
        local target = GetTarget()
        if not target then return end

        -- Auto Flee check first
        if CheckAutoFlee(target) then return end

        -- Smart Kiting: retreat if on cooldown (simple: if blocked)
        if Config.Combat.SmartKiting and isBlocking then return end

        -- Movement
        if Config.Combat.MovementMode == "Orbit" then
            OrbitTarget(target)
        else
            MoveToTarget(target)
        end

        -- Face at target
        if Config.Farm.FaceAtTarget then
            FaceTarget(target)
        end

        -- Attack
        if Config.Farm.FastAttack then
            DoAttack(target)
        end

        -- Use skills
        UseSkill(target)
    end)
end

local blockCheckConn
local lastAttacker
local function StartBlockSystem()
    if blockCheckConn then blockCheckConn:Disconnect() end
    blockCheckConn = RunService.Heartbeat:Connect(function()
        if not Config.Block.Enabled then
            SetBlock(false)
            return
        end

        if not Config.Block.AutoBlock then return end

        local shouldBlock = false
        local attacker = nil

        -- Check if any enemy is within detection range
        for _, p in ipairs(GetAllEnemies()) do
            if GetDistance(p) <= Config.Block.DetectionRange then
                shouldBlock = true
                attacker = p
                break
            end
        end

        if shouldBlock then
            if Config.Block.FaceAttacker and attacker then
                FaceTarget(attacker)
            end
            task.wait(Config.Block.BlockDelay)
            SetBlock(true)
            lastAttacker = attacker
        else
            -- Auto Punish: if we just stopped blocking and have an attacker nearby, attack back
            if isBlocking and Config.Block.AutoPunish and lastAttacker then
                SetBlock(false)
                task.wait(0.05)
                DoAttack(lastAttacker)
            else
                SetBlock(false)
            end
            lastAttacker = nil
        end
    end)
end

local espConn
local function StartESP()
    if espConn then espConn:Disconnect() end
    espConn = RunService.RenderStepped:Connect(UpdateESP)
end

local miscConn
local function StartMisc()
    if miscConn then miscConn:Disconnect() end
    miscConn = RunService.Heartbeat:Connect(function()
        -- Auto Tech
        AutoTech()

        -- Walkspeed bypass velocity direction
        if Config.Misc.WalkSpeedBypass and speedBV then
            local root = GetRoot(LocalPlayer)
            if root then
                local moveDir = LocalPlayer.Character
                    and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                    and LocalPlayer.Character.Humanoid.MoveDirection
                    or Vector3.new(0, 0, 0)
                speedBV.Velocity = moveDir * Config.Misc.Speed
            end
        end

        -- Normal WalkSpeed (non-bypass)
        if not Config.Misc.WalkSpeedBypass then
            local hum = GetHumanoid(LocalPlayer)
            if hum then
                hum.WalkSpeed = 16 -- keep default unless bypass active
            end
        end

        -- Anti Ragdoll check
        local char = LocalPlayer.Character
        if char then
            ApplyAntiRagdoll(char)
        end
    end)
end

-- ──────────────────────────────────────────────────────────────
-- CHARACTER ADDED HANDLERS
-- ──────────────────────────────────────────────────────────────
LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(1)
    ApplyAntiRagdoll(char)
    ApplySpeedBypass(Config.Misc.WalkSpeedBypass)
    SetInfiniteJump(Config.Misc.InfiniteJump)
    SetClickTP(Config.Misc.ClickTP)
end)

Players.PlayerRemoving:Connect(function(player)
    RemoveESPForPlayer(player)
end)

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        task.wait(1)
        if Config.ESP.Enabled and Config.ESP.EspPlayers then
            CreateESPForPlayer(player)
        end
    end)
end)

-- ──────────────────────────────────────────────────────────────
-- ██╗   ██╗██╗    ██████╗ ██╗   ██╗██╗██╗     ██████╗
-- ██║   ██║██║    ██╔══██╗██║   ██║██║██║     ██╔══██╗
-- ██║   ██║██║    ██████╔╝██║   ██║██║██║     ██║  ██║
-- ██║   ██║██║    ██╔══██╗██║   ██║██║██║     ██║  ██║
-- ╚██████╔╝██║    ██████╔╝╚██████╔╝██║███████╗██████╔╝
--  ╚═════╝ ╚═╝    ╚═════╝  ╚═════╝ ╚═╝╚══════╝╚═════╝
-- ──────────────────────────────────────────────────────────────

-- COLOR PALETTE
local C = {
    BgDark      = Color3.fromRGB(18, 18, 22),
    BgMid       = Color3.fromRGB(25, 25, 32),
    BgPanel     = Color3.fromRGB(30, 30, 38),
    BgSection   = Color3.fromRGB(36, 36, 46),
    Purple      = Color3.fromRGB(140, 60, 255),
    PurpleDim   = Color3.fromRGB(90, 40, 170),
    PurpleGlow  = Color3.fromRGB(160, 80, 255),
    TextWhite   = Color3.fromRGB(230, 230, 235),
    TextGray    = Color3.fromRGB(150, 150, 160),
    TextRed     = Color3.fromRGB(255, 70, 70),
    TextGreen   = Color3.fromRGB(60, 220, 100),
    NavBg       = Color3.fromRGB(22, 22, 28),
    NavHover    = Color3.fromRGB(45, 35, 65),
    NavActive   = Color3.fromRGB(70, 40, 140),
    Separator   = Color3.fromRGB(50, 50, 65),
    ToggleOff   = Color3.fromRGB(60, 60, 75),
    ToggleOn    = Color3.fromRGB(140, 60, 255),
    CheckBg     = Color3.fromRGB(40, 40, 52),
    SliderBg    = Color3.fromRGB(50, 50, 65),
    SliderFill  = Color3.fromRGB(140, 60, 255),
    DropBg      = Color3.fromRGB(35, 35, 45),
    ButtonBg    = Color3.fromRGB(45, 35, 70),
    ButtonHover = Color3.fromRGB(70, 50, 120),
}

-- Destroy old gui if rerunning
local oldGui = CoreGui:FindFirstChild("ImpHubX")
if oldGui then oldGui:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ImpHubX"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true
ScreenGui.Parent = CoreGui

-- ──────────────────────────────────────────────────────────────
-- MAIN WINDOW (draggable)
-- ──────────────────────────────────────────────────────────────
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 790, 0, 520)
MainFrame.Position = UDim2.new(0.5, -395, 0.5, -260)
MainFrame.BackgroundColor3 = C.BgDark
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)
local shadow = Instance.new("UIStroke", MainFrame)
shadow.Color = C.Purple
shadow.Thickness = 1.5
shadow.Transparency = 0.5

-- TITLE BAR
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 48)
TitleBar.BackgroundColor3 = C.BgMid
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 10)
-- Flatten bottom corners
local titleFix = Instance.new("Frame")
titleFix.Size = UDim2.new(1, 0, 0.5, 0)
titleFix.Position = UDim2.new(0, 0, 0.5, 0)
titleFix.BackgroundColor3 = C.BgMid
titleFix.BorderSizePixel = 0
titleFix.Parent = TitleBar

-- Title icon
local TitleIcon = Instance.new("Frame")
TitleIcon.Size = UDim2.new(0, 32, 0, 32)
TitleIcon.Position = UDim2.new(0, 12, 0, 8)
TitleIcon.BackgroundColor3 = C.Purple
TitleIcon.BorderSizePixel = 0
TitleIcon.Parent = TitleBar
Instance.new("UICorner", TitleIcon).CornerRadius = UDim.new(0, 6)

local TIconLbl = Instance.new("TextLabel")
TIconLbl.Size = UDim2.new(1, 0, 1, 0)
TIconLbl.BackgroundTransparency = 1
TIconLbl.Text = "I"
TIconLbl.Font = Enum.Font.GothamBold
TIconLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
TIconLbl.TextSize = 18
TIconLbl.Parent = TitleIcon

local TitleText = Instance.new("TextLabel")
TitleText.Size = UDim2.new(0, 200, 0, 20)
TitleText.Position = UDim2.new(0, 52, 0, 5)
TitleText.BackgroundTransparency = 1
TitleText.Text = "Imp Hub X"
TitleText.Font = Enum.Font.GothamBold
TitleText.TextColor3 = C.TextWhite
TitleText.TextSize = 16
TitleText.TextXAlignment = Enum.TextXAlignment.Left
TitleText.Parent = TitleBar

local SubText = Instance.new("TextLabel")
SubText.Size = UDim2.new(0, 200, 0, 14)
SubText.Position = UDim2.new(0, 52, 0, 26)
SubText.BackgroundTransparency = 1
SubText.Text = "Jujutsu Shenanigans"
SubText.Font = Enum.Font.Gotham
SubText.TextColor3 = C.TextGray
SubText.TextSize = 11
SubText.TextXAlignment = Enum.TextXAlignment.Left
SubText.Parent = TitleBar

-- Close button
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 24, 0, 24)
CloseBtn.Position = UDim2.new(1, -36, 0, 12)
CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
CloseBtn.BorderSizePixel = 0
CloseBtn.Text = "×"
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.TextSize = 16
CloseBtn.Parent = TitleBar
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 5)

CloseBtn.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
    -- Cleanup
    if farmConn then farmConn:Disconnect() end
    if blockCheckConn then blockCheckConn:Disconnect() end
    if espConn then espConn:Disconnect() end
    if miscConn then miscConn:Disconnect() end
    if aimlockConn then aimlockConn:Disconnect() end
    if spinConn then spinConn:Disconnect() end
    if killAuraConn then killAuraConn:Disconnect() end
    for p, _ in pairs(ESPObjects) do RemoveESPForPlayer(p) end
end)

-- Minimize button
local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 24, 0, 24)
MinBtn.Position = UDim2.new(1, -66, 0, 12)
MinBtn.BackgroundColor3 = C.BgPanel
MinBtn.BorderSizePixel = 0
MinBtn.Text = "—"
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextColor3 = C.TextGray
MinBtn.TextSize = 12
MinBtn.Parent = TitleBar
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 5)

local minimized = false
local function ToggleMinimize()
    minimized = not minimized
    MainFrame.Size = minimized
        and UDim2.new(0, 790, 0, 48)
        or  UDim2.new(0, 790, 0, 520)
end
MinBtn.MouseButton1Click:Connect(ToggleMinimize)

-- Dragging
local dragging, dragStart, startPos
TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging  = true
        dragStart = input.Position
        startPos  = MainFrame.Position
    end
end)
TitleBar.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- ──────────────────────────────────────────────────────────────
-- CONTENT AREA (below title bar)
-- ──────────────────────────────────────────────────────────────
local ContentArea = Instance.new("Frame")
ContentArea.Size = UDim2.new(1, 0, 1, -48)
ContentArea.Position = UDim2.new(0, 0, 0, 48)
ContentArea.BackgroundTransparency = 1
ContentArea.Parent = MainFrame

-- ──────────────────────────────────────────────────────────────
-- LEFT NAV SIDEBAR
-- ──────────────────────────────────────────────────────────────
local NavFrame = Instance.new("Frame")
NavFrame.Size = UDim2.new(0, 185, 1, 0)
NavFrame.BackgroundColor3 = C.NavBg
NavFrame.BorderSizePixel = 0
NavFrame.Parent = ContentArea

-- Nav scrolling (for safety if many items)
local NavScroll = Instance.new("ScrollingFrame")
NavScroll.Size = UDim2.new(1, 0, 1, 0)
NavScroll.BackgroundTransparency = 1
NavScroll.BorderSizePixel = 0
NavScroll.ScrollBarThickness = 2
NavScroll.ScrollBarImageColor3 = C.Purple
NavScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
NavScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
NavScroll.Parent = NavFrame

local NavList = Instance.new("UIListLayout")
NavList.SortOrder = Enum.SortOrder.LayoutOrder
NavList.Padding = UDim.new(0, 2)
NavList.Parent = NavScroll

local NavPad = Instance.new("UIPadding")
NavPad.PaddingLeft   = UDim.new(0, 8)
NavPad.PaddingRight  = UDim.new(0, 8)
NavPad.PaddingTop    = UDim.new(0, 8)
NavPad.PaddingBottom = UDim.new(0, 8)
NavPad.Parent = NavScroll

-- Helper: nav category header
local function MakeNavHeader(text)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 22)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.Font = Enum.Font.GothamBold
    lbl.TextColor3 = C.TextGray
    lbl.TextSize = 10
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.LayoutOrder = 0
    local pad = Instance.new("UIPadding", lbl)
    pad.PaddingLeft = UDim.new(0, 4)
    pad.PaddingTop  = UDim.new(0, 8)
    lbl.Parent = NavScroll
    return lbl
end

-- Nav buttons registry
local NavButtons = {}
local ActiveTab  = nil
local TabPanels  = {}

local function MakeNavButton(icon, label, order)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 36)
    btn.BackgroundColor3 = C.NavBg
    btn.BorderSizePixel = 0
    btn.Text = ""
    btn.LayoutOrder = order
    btn.AutoButtonColor = false
    btn.Parent = NavScroll
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 7)

    local iconLbl = Instance.new("TextLabel")
    iconLbl.Size = UDim2.new(0, 22, 0, 22)
    iconLbl.Position = UDim2.new(0, 6, 0.5, -11)
    iconLbl.BackgroundColor3 = C.BgSection
    iconLbl.BorderSizePixel = 0
    iconLbl.Text = icon
    iconLbl.Font = Enum.Font.GothamBold
    iconLbl.TextColor3 = C.TextGray
    iconLbl.TextSize = 11
    iconLbl.Parent = btn
    Instance.new("UICorner", iconLbl).CornerRadius = UDim.new(0, 5)

    local txtLbl = Instance.new("TextLabel")
    txtLbl.Size = UDim2.new(1, -36, 1, 0)
    txtLbl.Position = UDim2.new(0, 34, 0, 0)
    txtLbl.BackgroundTransparency = 1
    txtLbl.Text = label
    txtLbl.Font = Enum.Font.Gotham
    txtLbl.TextColor3 = C.TextGray
    txtLbl.TextSize = 13
    txtLbl.TextXAlignment = Enum.TextXAlignment.Left
    txtLbl.Parent = btn

    table.insert(NavButtons, {btn = btn, icon = iconLbl, txt = txtLbl})
    return btn, iconLbl, txtLbl
end

-- ──────────────────────────────────────────────────────────────
-- RIGHT PANEL (scrollable)
-- ──────────────────────────────────────────────────────────────
local RightArea = Instance.new("Frame")
RightArea.Size = UDim2.new(1, -185, 1, 0)
RightArea.Position = UDim2.new(0, 185, 0, 0)
RightArea.BackgroundColor3 = C.BgDark
RightArea.BorderSizePixel = 0
RightArea.ClipsDescendants = true
RightArea.Parent = ContentArea

-- Each tab gets a ScrollingFrame inside RightArea
local function MakeTabPanel(name)
    local sf = Instance.new("ScrollingFrame")
    sf.Name = name
    sf.Size = UDim2.new(1, 0, 1, 0)
    sf.BackgroundTransparency = 1
    sf.BorderSizePixel = 0
    sf.ScrollBarThickness = 4
    sf.ScrollBarImageColor3 = C.Purple
    sf.CanvasSize = UDim2.new(0, 0, 0, 0)
    sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
    sf.Visible = false
    sf.Parent = RightArea

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 8)
    layout.Parent = sf

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft   = UDim.new(0, 10)
    pad.PaddingRight  = UDim.new(0, 10)
    pad.PaddingTop    = UDim.new(0, 10)
    pad.PaddingBottom = UDim.new(0, 20)
    pad.Parent = sf

    return sf
end

-- ──────────────────────────────────────────────────────────────
-- UI COMPONENT FACTORIES
-- ──────────────────────────────────────────────────────────────

-- Section container (two-column row of sections)
local function MakeSectionRow(parent, order)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 0)
    row.AutomaticSize = Enum.AutomaticSize.Y
    row.BackgroundTransparency = 1
    row.LayoutOrder = order
    row.Parent = parent

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    layout.Padding = UDim.new(0, 8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = row
    return row
end

-- A section card
local function MakeSection(parent, title, order, width)
    width = width or 285

    local card = Instance.new("Frame")
    card.Size = UDim2.new(0, width, 0, 0)
    card.AutomaticSize = Enum.AutomaticSize.Y
    card.BackgroundColor3 = C.BgSection
    card.BorderSizePixel = 0
    card.LayoutOrder = order
    card.Parent = parent
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

    -- Section header
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 38)
    header.BackgroundColor3 = C.BgPanel
    header.BorderSizePixel = 0
    header.Parent = card
    Instance.new("UICorner", header).CornerRadius = UDim.new(0, 8)
    -- Fix bottom rounding on header
    local hFix = Instance.new("Frame")
    hFix.Size = UDim2.new(1, 0, 0.5, 0)
    hFix.Position = UDim2.new(0, 0, 0.5, 0)
    hFix.BackgroundColor3 = C.BgPanel
    hFix.BorderSizePixel = 0
    hFix.Parent = header

    -- Icon circle in header
    local ico = Instance.new("Frame")
    ico.Size = UDim2.new(0, 22, 0, 22)
    ico.Position = UDim2.new(0, 10, 0.5, -11)
    ico.BackgroundColor3 = C.BgSection
    ico.BorderSizePixel = 0
    ico.Parent = header
    Instance.new("UICorner", ico).CornerRadius = UDim.new(1, 0)

    local icoLbl = Instance.new("TextLabel")
    icoLbl.Size = UDim2.new(1, 0, 1, 0)
    icoLbl.BackgroundTransparency = 1
    icoLbl.Text = "⚙"
    icoLbl.Font = Enum.Font.GothamBold
    icoLbl.TextColor3 = C.Purple
    icoLbl.TextSize = 11
    icoLbl.Parent = ico

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -80, 1, 0)
    titleLbl.Position = UDim2.new(0, 38, 0, 0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = title
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextColor3 = C.TextWhite
    titleLbl.TextSize = 13
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = header

    -- Master toggle in header
    local masterToggleBg = Instance.new("TextButton")
    masterToggleBg.Size = UDim2.new(0, 36, 0, 20)
    masterToggleBg.Position = UDim2.new(1, -46, 0.5, -10)
    masterToggleBg.BackgroundColor3 = C.ToggleOff
    masterToggleBg.BorderSizePixel = 0
    masterToggleBg.Text = ""
    masterToggleBg.AutoButtonColor = false
    masterToggleBg.Parent = header
    Instance.new("UICorner", masterToggleBg).CornerRadius = UDim.new(1, 0)

    local masterKnob = Instance.new("Frame")
    masterKnob.Size = UDim2.new(0, 14, 0, 14)
    masterKnob.Position = UDim2.new(0, 3, 0.5, -7)
    masterKnob.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
    masterKnob.BorderSizePixel = 0
    masterKnob.Parent = masterToggleBg
    Instance.new("UICorner", masterKnob).CornerRadius = UDim.new(1, 0)

    -- Body container (items inside section)
    local body = Instance.new("Frame")
    body.Size = UDim2.new(1, 0, 0, 0)
    body.AutomaticSize = Enum.AutomaticSize.Y
    body.BackgroundTransparency = 1
    body.Parent = card

    local bodyLayout = Instance.new("UIListLayout")
    bodyLayout.SortOrder = Enum.SortOrder.LayoutOrder
    bodyLayout.Padding = UDim.new(0, 0)
    bodyLayout.Parent = body

    local bodyPad = Instance.new("UIPadding")
    bodyPad.PaddingLeft   = UDim.new(0, 10)
    bodyPad.PaddingRight  = UDim.new(0, 10)
    bodyPad.PaddingTop    = UDim.new(0, 6)
    bodyPad.PaddingBottom = UDim.new(0, 10)
    bodyPad.Parent = body

    return card, body, masterToggleBg, masterKnob, icoLbl
end

-- Toggle row
local function MakeToggle(parent, labelText, default, order)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 32)
    row.BackgroundTransparency = 1
    row.LayoutOrder = order
    row.Parent = parent

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -50, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.Font = Enum.Font.Gotham
    lbl.TextColor3 = C.TextWhite
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local tBg = Instance.new("TextButton")
    tBg.Size = UDim2.new(0, 36, 0, 20)
    tBg.Position = UDim2.new(1, -36, 0.5, -10)
    tBg.BackgroundColor3 = default and C.ToggleOn or C.ToggleOff
    tBg.BorderSizePixel = 0
    tBg.Text = ""
    tBg.AutoButtonColor = false
    tBg.Parent = row
    Instance.new("UICorner", tBg).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.Position = default
        and UDim2.new(1, -17, 0.5, -7)
        or  UDim2.new(0, 3, 0.5, -7)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    knob.Parent = tBg
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local state = default or false

    local function SetState(v)
        state = v
        tBg.BackgroundColor3 = state and C.ToggleOn or C.ToggleOff
        TweenService:Create(knob, TweenInfo.new(0.12), {
            Position = state and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)
        }):Play()
    end

    tBg.MouseButton1Click:Connect(function() SetState(not state) end)

    return tBg, function() return state end, SetState
end

-- Checkbox row
local function MakeCheckbox(parent, labelText, default, order)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 28)
    row.BackgroundTransparency = 1
    row.LayoutOrder = order
    row.Parent = parent

    local box = Instance.new("TextButton")
    box.Size = UDim2.new(0, 16, 0, 16)
    box.Position = UDim2.new(0, 0, 0.5, -8)
    box.BackgroundColor3 = default and C.Purple or C.CheckBg
    box.BorderSizePixel = 0
    box.Text = default and "✓" or ""
    box.Font = Enum.Font.GothamBold
    box.TextColor3 = Color3.fromRGB(255, 255, 255)
    box.TextSize = 10
    box.AutoButtonColor = false
    box.Parent = row
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 3)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -22, 1, 0)
    lbl.Position = UDim2.new(0, 22, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.Font = Enum.Font.Gotham
    lbl.TextColor3 = C.TextWhite
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local state = default or false

    local function SetState(v)
        state = v
        box.BackgroundColor3 = state and C.Purple or C.CheckBg
        box.Text = state and "✓" or ""
    end

    box.MouseButton1Click:Connect(function() SetState(not state) end)
    lbl.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            SetState(not state)
        end
    end)

    return box, function() return state end, SetState
end

-- Slider row
local function MakeSlider(parent, labelText, min, max, default, suffix, order)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 46)
    row.BackgroundTransparency = 1
    row.LayoutOrder = order
    row.Parent = parent

    local topRow = Instance.new("Frame")
    topRow.Size = UDim2.new(1, 0, 0, 18)
    topRow.BackgroundTransparency = 1
    topRow.Parent = row

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.6, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.Font = Enum.Font.Gotham
    lbl.TextColor3 = C.TextWhite
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = topRow

    local valLbl = Instance.new("TextLabel")
    valLbl.Size = UDim2.new(0.4, 0, 1, 0)
    valLbl.Position = UDim2.new(0.6, 0, 0, 0)
    valLbl.BackgroundTransparency = 1
    valLbl.Text = tostring(default) .. (suffix or "")
    valLbl.Font = Enum.Font.Gotham
    valLbl.TextColor3 = C.Purple
    valLbl.TextSize = 12
    valLbl.TextXAlignment = Enum.TextXAlignment.Right
    valLbl.Parent = topRow

    -- Track
    local trackBg = Instance.new("Frame")
    trackBg.Size = UDim2.new(1, -20, 0, 5)
    trackBg.Position = UDim2.new(0, 10, 0, 28)
    trackBg.BackgroundColor3 = C.SliderBg
    trackBg.BorderSizePixel = 0
    trackBg.Parent = row
    Instance.new("UICorner", trackBg).CornerRadius = UDim.new(1, 0)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = C.SliderFill
    fill.BorderSizePixel = 0
    fill.Parent = trackBg
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local thumb = Instance.new("Frame")
    thumb.Size = UDim2.new(0, 13, 0, 13)
    thumb.Position = UDim2.new((default - min) / (max - min), -6, 0.5, -7)
    thumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    thumb.BorderSizePixel = 0
    thumb.ZIndex = 2
    thumb.Parent = trackBg
    Instance.new("UICorner", thumb).CornerRadius = UDim.new(1, 0)

    local value = default
    local draggingSlider = false

    local function UpdateSlider(input)
        local trackPos = trackBg.AbsolutePosition
        local trackW   = trackBg.AbsoluteSize.X
        local rel = math.clamp((input.Position.X - trackPos.X) / trackW, 0, 1)
        value = math.floor(min + rel * (max - min))
        fill.Size = UDim2.new(rel, 0, 1, 0)
        thumb.Position = UDim2.new(rel, -6, 0.5, -7)
        valLbl.Text = tostring(value) .. (suffix or "")
    end

    trackBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            draggingSlider = true
            UpdateSlider(input)
        end
    end)
    trackBg.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            draggingSlider = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if draggingSlider and input.UserInputType == Enum.UserInputType.MouseMovement then
            UpdateSlider(input)
        end
    end)

    return row, function() return value end
end

-- Dropdown
local function MakeDropdown(parent, labelText, options, default, order)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 32)
    row.BackgroundTransparency = 1
    row.LayoutOrder = order
    row.ClipsDescendants = false
    row.Parent = parent

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.45, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.Font = Enum.Font.Gotham
    lbl.TextColor3 = C.TextWhite
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local dropBtn = Instance.new("TextButton")
    dropBtn.Size = UDim2.new(0.55, 0, 0, 26)
    dropBtn.Position = UDim2.new(0.45, 0, 0, 3)
    dropBtn.BackgroundColor3 = C.DropBg
    dropBtn.BorderSizePixel = 0
    dropBtn.Text = default or options[1]
    dropBtn.Font = Enum.Font.Gotham
    dropBtn.TextColor3 = C.TextWhite
    dropBtn.TextSize = 11
    dropBtn.AutoButtonColor = false
    dropBtn.ClipsDescendants = false
    dropBtn.Parent = row
    Instance.new("UICorner", dropBtn).CornerRadius = UDim.new(0, 5)

    -- Arrow
    local arrow = Instance.new("TextLabel")
    arrow.Size = UDim2.new(0, 14, 1, 0)
    arrow.Position = UDim2.new(1, -16, 0, 0)
    arrow.BackgroundTransparency = 1
    arrow.Text = "▾"
    arrow.Font = Enum.Font.Gotham
    arrow.TextColor3 = C.Purple
    arrow.TextSize = 10
    arrow.Parent = dropBtn

    -- Dropdown list
    local listFrame = Instance.new("Frame")
    listFrame.Size = UDim2.new(1, 0, 0, 0)
    listFrame.Position = UDim2.new(0, 0, 1, 2)
    listFrame.BackgroundColor3 = C.DropBg
    listFrame.BorderSizePixel = 0
    listFrame.ZIndex = 10
    listFrame.Visible = false
    listFrame.ClipsDescendants = true
    listFrame.Parent = dropBtn
    Instance.new("UICorner", listFrame).CornerRadius = UDim.new(0, 5)
    Instance.new("UIStroke", listFrame).Color = C.Separator

    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent = listFrame

    local selectedValue = default or options[1]
    local isOpen = false

    for i, opt in ipairs(options) do
        local optBtn = Instance.new("TextButton")
        optBtn.Size = UDim2.new(1, 0, 0, 24)
        optBtn.BackgroundColor3 = C.DropBg
        optBtn.BorderSizePixel = 0
        optBtn.Text = "  " .. opt
        optBtn.Font = Enum.Font.Gotham
        optBtn.TextColor3 = opt == selectedValue and C.Purple or C.TextWhite
        optBtn.TextSize = 11
        optBtn.TextXAlignment = Enum.TextXAlignment.Left
        optBtn.ZIndex = 11
        optBtn.LayoutOrder = i
        optBtn.Parent = listFrame

        optBtn.MouseButton1Click:Connect(function()
            selectedValue = opt
            dropBtn.Text = opt
            for _, c in ipairs(listFrame:GetChildren()) do
                if c:IsA("TextButton") then
                    c.TextColor3 = c.Text:gsub("^%s+", "") == opt and C.Purple or C.TextWhite
                end
            end
            isOpen = false
            listFrame.Visible = false
            listFrame.Size = UDim2.new(1, 0, 0, 0)
        end)
    end

    local function ToggleOpen()
        isOpen = not isOpen
        listFrame.Visible = isOpen
        if isOpen then
            local h = #options * 24
            listFrame.Size = UDim2.new(1, 0, 0, h)
        else
            listFrame.Size = UDim2.new(1, 0, 0, 0)
        end
    end

    dropBtn.MouseButton1Click:Connect(ToggleOpen)
    return row, function() return selectedValue end
end

-- Sub-header label inside a section
local function MakeSectionSubHeader(parent, text, order)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 22)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.Font = Enum.Font.GothamBold
    lbl.TextColor3 = C.TextGray
    lbl.TextSize = 10
    lbl.TextXAlignment = Enum.TextXAlignment.Center
    lbl.LayoutOrder = order
    lbl.Parent = parent
    return lbl
end

-- Button
local function MakeButton(parent, text, order)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 30)
    btn.BackgroundColor3 = C.ButtonBg
    btn.BorderSizePixel = 0
    btn.Text = text
    btn.Font = Enum.Font.GothamBold
    btn.TextColor3 = C.TextWhite
    btn.TextSize = 12
    btn.LayoutOrder = order
    btn.AutoButtonColor = false
    btn.Parent = parent
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = C.ButtonHover}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = C.ButtonBg}):Play()
    end)

    return btn
end

-- Separator
local function MakeSeparator(parent, order)
    local sep = Instance.new("Frame")
    sep.Size = UDim2.new(1, 0, 0, 1)
    sep.BackgroundColor3 = C.Separator
    sep.BorderSizePixel = 0
    sep.LayoutOrder = order
    sep.Parent = parent
    return sep
end

-- ──────────────────────────────────────────────────────────────
-- NAV TAB SWITCHING
-- ──────────────────────────────────────────────────────────────
local function SwitchTab(tabName, btn, iconLbl, txtLbl)
    -- Hide all
    for _, panel in pairs(TabPanels) do
        panel.Visible = false
    end
    -- Deactivate all nav buttons
    for _, nb in ipairs(NavButtons) do
        nb.btn.BackgroundColor3 = C.NavBg
        nb.txt.TextColor3 = C.TextGray
        nb.txt.Font = Enum.Font.Gotham
        nb.icon.BackgroundColor3 = C.BgSection
        nb.icon.TextColor3 = C.TextGray
    end
    -- Show selected
    if TabPanels[tabName] then
        TabPanels[tabName].Visible = true
    end
    ActiveTab = tabName
    btn.BackgroundColor3 = C.NavActive
    txtLbl.TextColor3 = C.TextWhite
    txtLbl.Font = Enum.Font.GothamBold
    iconLbl.BackgroundColor3 = C.Purple
    iconLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
end

-- ──────────────────────────────────────────────────────────────
-- BUILD NAVIGATION
-- ──────────────────────────────────────────────────────────────
MakeNavHeader("Combat & Auto Farm")
local btnFarm,   icoFarm,   txtFarm   = MakeNavButton("⚔", "Auto Farm",      2)
local btnCombat, icoCombat, txtCombat = MakeNavButton("⊕", "Combat System",  3)
MakeNavHeader("ESP Engine")
local btnVisl,   icoVisl,   txtVisl   = MakeNavButton("◎", "Visuals",        5)
MakeNavHeader("Miscellaneous")
local btnMisc,   icoMisc,   txtMisc   = MakeNavButton("⚙", "Misc",           7)
MakeNavHeader("Credits & Settings")
local btnCreds,  icoCreds,  txtCreds  = MakeNavButton("◎", "Credits",        9)
local btnSetts,  icoSetts,  txtSetts  = MakeNavButton("◈", "Settings",       10)

-- ──────────────────────────────────────────────────────────────
-- TAB: AUTO FARM
-- ──────────────────────────────────────────────────────────────
local PanelFarm = MakeTabPanel("AutoFarm")
TabPanels["AutoFarm"] = PanelFarm

-- Row 1: Farming + Aimlock
local row1 = MakeSectionRow(PanelFarm, 1)

-- FARMING SECTION
local secFarming, bFarming = MakeSection(row1, "Farming", 1, 272)
bFarming.LayoutOrder = 0

local _, getTargetPlayer = MakeDropdown(bFarming,
    "Select Players",
    {"All", "Closest", "Specific"},
    "All", 1)

local _, getTargetMethod = MakeDropdown(bFarming,
    "Select Target Method",
    {"Closest", "Furthest", "Random", "Most HP", "Least HP"},
    "Closest", 2)

local _, getFaceAtTarget, setFaceAtTarget = MakeCheckbox(bFarming, "Face At Target", true, 3)
local _, getFastAttack,   setFastAttack   = MakeCheckbox(bFarming, "Fast Attack",    true, 4)
local _, getUseSkills,    setUseSkills    = MakeCheckbox(bFarming, "Use Skills",     true, 5)

MakeSectionSubHeader(bFarming, "Control", 6)

local enableFarmBtn = MakeButton(bFarming, "Enable Farm", 7)
enableFarmBtn.BackgroundColor3 = C.ButtonBg

local farmActive = false
enableFarmBtn.MouseButton1Click:Connect(function()
    farmActive = not farmActive
    Config.Farm.Enabled = farmActive
    enableFarmBtn.BackgroundColor3 = farmActive and C.Purple or C.ButtonBg
    enableFarmBtn.Text = farmActive and "Disable Farm" or "Enable Farm"
    if farmActive then
        StartFarm()
    else
        if farmConn then farmConn:Disconnect() farmConn = nil end
    end
end)

-- AIMLOCK SECTION
local secAimlock, bAimlock = MakeSection(row1, "Aimlock", 2, 272)

local _, getEnableAimlock, setEnableAimlock = MakeCheckbox(bAimlock, "Enable Aimlock", false, 1)
local _, getAimlockMode = MakeDropdown(bAimlock,
    "Aimlock Mode",
    {"Camera", "Silent", "Body"},
    "Camera", 2)

local _, getTargetPartDrop = MakeDropdown(bAimlock,
    "Target Part",
    {"Head", "HumanoidRootPart", "Torso", "UpperTorso"},
    "Head", 3)

local _, getPrediction, setPrediction = MakeCheckbox(bAimlock, "Prediction", false, 4)

-- STATUS SECTION (wide)
local secStatus, bStatus = MakeSection(PanelFarm, "Status", 2, 556)

local statusLbl = Instance.new("TextLabel")
statusLbl.Size = UDim2.new(1, 0, 0, 18)
statusLbl.BackgroundTransparency = 1
statusLbl.Text = "System Status"
statusLbl.Font = Enum.Font.GothamBold
statusLbl.TextColor3 = C.TextWhite
statusLbl.TextSize = 12
statusLbl.TextXAlignment = Enum.TextXAlignment.Left
statusLbl.LayoutOrder = 1
statusLbl.Parent = bStatus

local statusValueLbl = Instance.new("TextLabel")
statusValueLbl.Size = UDim2.new(1, 0, 0, 20)
statusValueLbl.BackgroundTransparency = 1
statusValueLbl.Text = "[ DISABLED ]"
statusValueLbl.Font = Enum.Font.GothamBold
statusValueLbl.TextColor3 = C.TextRed
statusValueLbl.TextSize = 13
statusValueLbl.TextXAlignment = Enum.TextXAlignment.Left
statusValueLbl.LayoutOrder = 2
statusValueLbl.Parent = bStatus

local statusSubLbl = Instance.new("TextLabel")
statusSubLbl.Size = UDim2.new(1, 0, 0, 16)
statusSubLbl.BackgroundTransparency = 1
statusSubLbl.Text = "Wait for activation..."
statusSubLbl.Font = Enum.Font.Gotham
statusSubLbl.TextColor3 = C.TextGray
statusSubLbl.TextSize = 11
statusSubLbl.TextXAlignment = Enum.TextXAlignment.Left
statusSubLbl.LayoutOrder = 3
statusSubLbl.Parent = bStatus

-- Row 3: BLOCKING SECTION
local secBlocking, bBlocking = MakeSection(PanelFarm, "Blocking", 3, 556)

local _, getAutoBlock,   _ = MakeCheckbox(bBlocking, "Enable Auto Block",      true,  1)
local _, getAutoPunish,  _ = MakeCheckbox(bBlocking, "Auto Punish (Attack Back)", true, 2)
local _, getFaceAttacker,_ = MakeCheckbox(bBlocking, "Face Attacker",          true,  3)

local showRangeBtn = MakeButton(bBlocking, "Show Range", 4)
local showRangeActive = false
showRangeBtn.MouseButton1Click:Connect(function()
    showRangeActive = not showRangeActive
    Config.Block.ShowRange = showRangeActive
    showRangeBtn.BackgroundColor3 = showRangeActive and C.Purple or C.ButtonBg
    ToggleBlockRange(showRangeActive)
end)

local _, getDetectionRange = MakeSlider(bBlocking, "Detection Range", 5, 60, 20, " studs", 5)
local _, getBlockDelay     = MakeSlider(bBlocking, "Block Delay",     0, 5,  0,  "s",      6)

-- Wire aimlock toggles
getEnableAimlock, setEnableAimlock = MakeCheckbox(bAimlock, "Enable Aimlock", false, 1)
RunService.Heartbeat:Connect(function()
    Config.Aimlock.EnableAimlock = getEnableAimlock()
    Config.Aimlock.Mode          = getAimlockMode()
    Config.Aimlock.TargetPart    = getTargetPartDrop()
    Config.Aimlock.Prediction    = getPrediction()
    if Config.Aimlock.Enabled and Config.Aimlock.EnableAimlock then
        EnableAimlock()
    end
    -- Update blocking config
    Config.Block.AutoBlock       = getAutoBlock()
    Config.Block.AutoPunish      = getAutoPunish()
    Config.Block.FaceAttacker    = getFaceAttacker()
    Config.Block.DetectionRange  = getDetectionRange()
    Config.Block.BlockDelay      = getBlockDelay()
    -- Update farming config
    Config.Farm.FaceAtTarget     = getFaceAtTarget()
    Config.Farm.FastAttack       = getFastAttack()
    Config.Farm.UseSkills        = getUseSkills()
    Config.Farm.TargetMethod     = getTargetMethod()
    -- Update status label
    if Config.Farm.Enabled then
        statusValueLbl.Text      = "[ ACTIVE ]"
        statusValueLbl.TextColor3 = C.TextGreen
        statusSubLbl.Text        = "Farming target: " ..
            (GetTarget() and GetTarget().Name or "searching...")
    else
        statusValueLbl.Text      = "[ DISABLED ]"
        statusValueLbl.TextColor3 = C.TextRed
        statusSubLbl.Text        = "Wait for activation..."
    end
end)

-- ──────────────────────────────────────────────────────────────
-- TAB: COMBAT SYSTEM
-- ──────────────────────────────────────────────────────────────
local PanelCombat = MakeTabPanel("Combat")
TabPanels["Combat"] = PanelCombat

local secCombatSettings, bCombatSettings = MakeSection(PanelCombat, "Settings", 1, 556)

local _, getTeleportMethod = MakeDropdown(bCombatSettings,
    "Select Teleport Method",
    {"Tween", "Instant", "Lerp"},
    "Tween", 1)

local _, getMovementMode = MakeDropdown(bCombatSettings,
    "Movement Mode",
    {"Orbit (Dodge)", "Follow", "Static"},
    "Orbit (Dodge)", 2)

local _, getTweenSpeed    = MakeSlider(bCombatSettings, "Tween Speed",      50,  400, 135, " studs/s", 3)
local _, getFollowDist    = MakeSlider(bCombatSettings, "Follow Distance",   2,   30,   4, " studs",   4)
local _, getSmartKiting,_ = MakeCheckbox(bCombatSettings, "Smart Kiting (Retreat on CD)", true, 5)

MakeSectionSubHeader(bCombatSettings, "Main Configurations", 6)

local _, getAutoFlee,  _ = MakeCheckbox(bCombatSettings, "Auto Flee (Low HP)",  false, 7)
local _, getFleeHP       = MakeSlider(bCombatSettings, "Flee Health %", 5, 80, 20, "%", 8)
local _, getPriorClosest,_ = MakeCheckbox(bCombatSettings, "Priority Closest",  true,  9)
local _, getHunterMode,_ = MakeCheckbox(bCombatSettings, "Hunter Mode",         false, 10)

MakeSectionSubHeader(bCombatSettings, "Skill System", 11)

local _, getSelectSkills = MakeDropdown(bCombatSettings,
    "Select Skills",
    {"Divergent Fist", "Black Flash", "Hollow Purple", "Cursed Energy", "Domain Expansion", "All"},
    "Divergent Fist", 12)

local _, getSkillDelay    = MakeSlider(bCombatSettings, "Use Skill Delay", 0, 30, 6, "s", 13)
local _, getAvoidSkills,_ = MakeCheckbox(bCombatSettings, "Avoid Skills With Target Required", true,  14)

MakeSeparator(bCombatSettings, 15)

local _, getSemiKill,_ = MakeCheckbox(bCombatSettings, "Semi Kill Aura (25 Studs)", false, 16)
local _, getSpinBot,_  = MakeCheckbox(bCombatSettings, "SpinBot",                  false, 17)

RunService.Heartbeat:Connect(function()
    Config.Combat.TeleportMethod       = getTeleportMethod()
    Config.Combat.MovementMode         = getMovementMode():gsub(" %(Dodge%)", "")
    Config.Combat.TweenSpeed           = getTweenSpeed()
    Config.Combat.FollowDistance       = getFollowDist()
    Config.Combat.SmartKiting          = getSmartKiting()
    Config.Combat.AutoFlee             = getAutoFlee()
    Config.Combat.FleeHealthPct        = getFleeHP()
    Config.Combat.PriorityClosest      = getPriorClosest()
    Config.Combat.HunterMode           = getHunterMode()
    Config.Combat.SelectedSkill        = getSelectSkills()
    Config.Combat.UseSkillDelay        = getSkillDelay()
    Config.Combat.AvoidSkillsNoTarget  = getAvoidSkills()

    local newSemi = getSemiKill()
    if newSemi ~= Config.Combat.SemiKillAura then
        Config.Combat.SemiKillAura = newSemi
        SetSemiKillAura(newSemi)
    end

    local newSpin = getSpinBot()
    if newSpin ~= Config.Combat.SpinBot then
        Config.Combat.SpinBot = newSpin
        SetSpinBot(newSpin)
    end
end)

-- ──────────────────────────────────────────────────────────────
-- TAB: VISUALS (ESP)
-- ──────────────────────────────────────────────────────────────
local PanelVisl = MakeTabPanel("Visuals")
TabPanels["Visuals"] = PanelVisl

local rowVisl = MakeSectionRow(PanelVisl, 1)

local secEspEnable, bEspEnable = MakeSection(rowVisl, "Enable", 1, 272)
local _, getEspEnabled, setEspEnabled = MakeCheckbox(bEspEnable, "Enable Esp Players", false, 1)

local secEspConfig, bEspConfig = MakeSection(rowVisl, "Configurations", 2, 272)
local _, getBox,       _ = MakeCheckbox(bEspConfig, "Box",             true, 1)
local _, getTracers,   _ = MakeCheckbox(bEspConfig, "Tracers",         true, 2)
local _, getHealthBar, _ = MakeCheckbox(bEspConfig, "Health Bar",      true, 3)
local _, getDistance,  _ = MakeCheckbox(bEspConfig, "Distance",        true, 4)
local _, getNameEsp,   _ = MakeCheckbox(bEspConfig, "Name",            true, 5)
local _, getMoveset,   _ = MakeCheckbox(bEspConfig, "Moveset (Class)", true, 6)

RunService.Heartbeat:Connect(function()
    local wasEnabled = Config.ESP.Enabled
    Config.ESP.EspPlayers = getEspEnabled()
    Config.ESP.Box        = getBox()
    Config.ESP.Tracers    = getTracers()
    Config.ESP.HealthBar  = getHealthBar()
    Config.ESP.Distance   = getDistance()
    Config.ESP.Name       = getNameEsp()
    Config.ESP.Moveset    = getMoveset()
    Config.ESP.Enabled    = Config.ESP.EspPlayers

    if Config.ESP.Enabled and not wasEnabled then
        StartESP()
        for _, p in ipairs(Players:GetPlayers()) do
            CreateESPForPlayer(p)
        end
    elseif not Config.ESP.Enabled and wasEnabled then
        for _, objs in pairs(ESPObjects) do
            for k, v in pairs(objs) do
                if type(v) == "table" then
                    for _, l in ipairs(v) do l.Visible = false end
                elseif v then v.Visible = false end
            end
        end
    end
end)

-- ──────────────────────────────────────────────────────────────
-- TAB: MISC
-- ──────────────────────────────────────────────────────────────
local PanelMisc = MakeTabPanel("Misc")
TabPanels["Misc"] = PanelMisc

local rowMisc = MakeSectionRow(PanelMisc, 1)

-- STUFF SECTION
local secStuff, bStuff = MakeSection(rowMisc, "Stuff", 1, 272)

local _, getAntiRagdoll, _ = MakeCheckbox(bStuff, "Anti Ragdoll",             false, 1)
local _, getAutoTech,    _ = MakeCheckbox(bStuff, "Auto Tech (Jump on Ragdoll)", false, 2)
local _, getWsbypass,    _ = MakeCheckbox(bStuff, "WalkSpeed Bypass (Velocity)", false, 3)
local _, getSpeed           = MakeSlider(bStuff, "Speed Amount", 16, 500, 100, " studs/s", 4)
local _, getInfiniteJump,_ = MakeCheckbox(bStuff, "Infinite Jump", false, 5)
local _, getFullbright,  _ = MakeCheckbox(bStuff, "Fullbright",    false, 6)
local _, getWhiteScreen, _ = MakeCheckbox(bStuff, "White Screen",  false, 7)
local _, getAntiAFK,     _ = MakeCheckbox(bStuff, "Anti AFK",      true,  8)
local _, getClickTP,     _ = MakeCheckbox(bStuff, "Click TP (Ctrl + Click)", false, 9)
local _, getTimeChanger     = MakeSlider(bStuff, "Time Changer", 0, 24, 14, "h", 10)

MakeSeparator(bStuff, 11)

local fpsBtn     = MakeButton(bStuff, "FPS Boost",  12)
local serverHopBtn = MakeButton(bStuff, "Server Hop", 13)

fpsBtn.MouseButton1Click:Connect(ApplyFPSBoost)
serverHopBtn.MouseButton1Click:Connect(ServerHop)

-- PLAYER CONTROL SECTION
local secPlayerCtrl, bPlayerCtrl = MakeSection(rowMisc, "Player Control", 2, 272)

-- Build player list dynamically
local function GetPlayerNames()
    local names = {""}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            table.insert(names, p.Name)
        end
    end
    return names
end

local _, getSelectedPlayer = MakeDropdown(bPlayerCtrl, "Select Player", GetPlayerNames(), "", 1)

local spectateBtn = MakeButton(bPlayerCtrl, "Spectate Player",    2)
local stopSpecBtn  = MakeButton(bPlayerCtrl, "Stop Spectate",     3)
local tpPlayerBtn  = MakeButton(bPlayerCtrl, "Teleport to Player", 4)

spectateBtn.MouseButton1Click:Connect(function()
    local pName = getSelectedPlayer()
    local target = Players:FindFirstChild(pName)
    if target then SpectatePlayer(target) end
end)
stopSpecBtn.MouseButton1Click:Connect(StopSpectate)
tpPlayerBtn.MouseButton1Click:Connect(function()
    local pName = getSelectedPlayer()
    local target = Players:FindFirstChild(pName)
    if target then TeleportToPlayer(target) end
end)

-- Wire misc feature toggles
local prevMiscState = {}
RunService.Heartbeat:Connect(function()
    Config.Misc.AntiRagdoll     = getAntiRagdoll()
    Config.Misc.AutoTech        = getAutoTech()
    Config.Misc.Speed           = getSpeed()
    Config.Misc.TimeChanger     = getTimeChanger()

    local newWsBypass = getWsbypass()
    if newWsBypass ~= prevMiscState.WsBypass then
        prevMiscState.WsBypass = newWsBypass
        Config.Misc.WalkSpeedBypass = newWsBypass
        ApplySpeedBypass(newWsBypass)
    end

    local newInfJump = getInfiniteJump()
    if newInfJump ~= prevMiscState.InfJump then
        prevMiscState.InfJump = newInfJump
        Config.Misc.InfiniteJump = newInfJump
        SetInfiniteJump(newInfJump)
    end

    local newFb = getFullbright()
    if newFb ~= prevMiscState.Fullbright then
        prevMiscState.Fullbright = newFb
        Config.Misc.Fullbright = newFb
        SetFullbright(newFb)
    end

    local newWS = getWhiteScreen()
    if newWS ~= prevMiscState.WhiteScreen then
        prevMiscState.WhiteScreen = newWS
        Config.Misc.WhiteScreen = newWS
        SetWhiteScreen(newWS)
    end

    local newAFK = getAntiAFK()
    if newAFK ~= prevMiscState.AntiAFK then
        prevMiscState.AntiAFK = newAFK
        Config.Misc.AntiAFK = newAFK
        SetAntiAFK(newAFK)
    end

    local newCTP = getClickTP()
    if newCTP ~= prevMiscState.ClickTP then
        prevMiscState.ClickTP = newCTP
        Config.Misc.ClickTP = newCTP
        SetClickTP(newCTP)
    end

    SetTimeChanger(Config.Misc.TimeChanger)
end)

-- ──────────────────────────────────────────────────────────────
-- TAB: CREDITS
-- ──────────────────────────────────────────────────────────────
local PanelCredits = MakeTabPanel("Credits")
TabPanels["Credits"] = PanelCredits

local secCred, bCred = MakeSection(PanelCredits, "Credits", 1, 556)

local function MakeCredLine(parent, text, color, size, order)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, size + 6)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.Font = Enum.Font.GothamBold
    lbl.TextColor3 = color
    lbl.TextSize = size
    lbl.TextXAlignment = Enum.TextXAlignment.Center
    lbl.LayoutOrder = order
    lbl.Parent = parent
end

MakeCredLine(bCred, "Imp Hub X", C.Purple, 20, 1)
MakeCredLine(bCred, "Jujutsu Shenanigans Script", C.TextWhite, 14, 2)
MakeCredLine(bCred, "Version 1.0", C.TextGray, 11, 3)
MakeSeparator(bCred, 4)
MakeCredLine(bCred, "Features", C.TextWhite, 13, 5)
MakeCredLine(bCred, "Auto Farm  •  Combat System  •  ESP  •  Misc  •  Aimlock", C.TextGray, 11, 6)
MakeSeparator(bCred, 7)
MakeCredLine(bCred, "For educational purposes only.", C.TextGray, 10, 8)

-- ──────────────────────────────────────────────────────────────
-- TAB: SETTINGS (Combat System Settings from Screenshot 4)
-- ──────────────────────────────────────────────────────────────
-- Note: The "Settings" nav item in screenshot 4 shows the same
-- Combat System content. We map it there for completeness.
TabPanels["Settings"] = PanelCombat -- re-use combat panel

-- ──────────────────────────────────────────────────────────────
-- WIRE NAV BUTTONS
-- ──────────────────────────────────────────────────────────────
btnFarm.MouseButton1Click:Connect(function()
    SwitchTab("AutoFarm", btnFarm, icoFarm, txtFarm)
end)
btnCombat.MouseButton1Click:Connect(function()
    SwitchTab("Combat", btnCombat, icoCombat, txtCombat)
end)
btnVisl.MouseButton1Click:Connect(function()
    SwitchTab("Visuals", btnVisl, icoVisl, txtVisl)
end)
btnMisc.MouseButton1Click:Connect(function()
    SwitchTab("Misc", btnMisc, icoMisc, txtMisc)
end)
btnCreds.MouseButton1Click:Connect(function()
    SwitchTab("Credits", btnCreds, icoCreds, txtCreds)
end)
btnSetts.MouseButton1Click:Connect(function()
    SwitchTab("Settings", btnSetts, icoSetts, txtSetts)
end)

-- ──────────────────────────────────────────────────────────────
-- INITIAL STATE: open Auto Farm tab
-- ──────────────────────────────────────────────────────────────
SwitchTab("AutoFarm", btnFarm, icoFarm, txtFarm)

-- Start background systems
StartBlockSystem()
StartMisc()
StartESP()
SetAntiAFK(Config.Misc.AntiAFK)
EnableAimlock()

-- Keyboard toggle (RightShift hides/shows GUI)
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        MainFrame.Visible = not MainFrame.Visible
    end
end)

print("[ImpHubX] Loaded successfully. Press RightShift to toggle GUI.")
