-- =====================================================
-- Suika Hub V3 (Orion UI版・スマホ対応・全機能)
-- =====================================================

local OrionLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/shlexware/Orion/main/source"))()

-- =====================================================
-- サービス
-- =====================================================
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer
if not localPlayer then
    Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    localPlayer = Players.LocalPlayer
end

local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

-- =====================================================
-- 状態管理
-- =====================================================
local selectedPlayer = nil
local killSwitchActive = false
local isDrifting = false
local currentTarget = nil
local flyBV = nil
local espEnabled = false
local espObjects = {}
local isMobile = UserInputService.TouchEnabled

-- =====================================================
-- ユーティリティ
-- =====================================================
local function isTargetSelf(target)
    if target == localPlayer then
        OrionLib:MakeNotification({
            Name = "エラー",
            Content = "自分には実行できません",
            Time = 3
        })
        return true
    end
    return false
end

-- =====================================================
-- エフェクト
-- =====================================================
local function createEffect(pos, color, size, dur)
    local part = Instance.new("Part")
    part.Size = size or Vector3.new(2, 2, 2)
    part.Anchored = true
    part.CanCollide = false
    part.Material = Enum.Material.Neon
    part.BrickColor = BrickColor.new(color or "Bright red")
    part.Position = pos
    part.Transparency = 0.3
    part.Parent = Workspace
    Debris:AddItem(part, dur or 0.5)
    task.spawn(function()
        for i = 1, 10 do
            if not part or not part.Parent then break end
            part.Transparency = part.Transparency + 0.07
            part.Size = part.Size + Vector3.new(0.2, 0.2, 0.2)
            task.wait((dur or 0.5) / 10)
        end
        pcall(function() part:Destroy() end)
    end)
end

local function createSplash(pos, color, count)
    for i = 1, count or 15 do
        local blob = Instance.new("Part")
        blob.Size = Vector3.new(0.2 + math.random() * 0.3, 0.2 + math.random() * 0.3, 0.2 + math.random() * 0.3)
        blob.Anchored = false
        blob.CanCollide = true
        blob.Material = Enum.Material.SmoothPlastic
        blob.BrickColor = BrickColor.new(color or "Lime green")
        blob.Position = pos + Vector3.new(math.random(-2, 2), math.random(0, 2), math.random(-2, 2))
        blob.Parent = Workspace
        local bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(500, 500, 500)
        bv.Velocity = Vector3.new(math.random(-12, 12), math.random(5, 20), math.random(-12, 12))
        bv.Parent = blob
        Debris:AddItem(blob, 2.5)
        Debris:AddItem(bv, 2.5)
    end
end

local function createRingEffect(pos, color, radius, duration)
    local ring = Instance.new("Part")
    ring.Size = Vector3.new(radius, 0.2, radius)
    ring.Shape = Enum.PartType.Cylinder
    ring.Anchored = true
    ring.CanCollide = false
    ring.Material = Enum.Material.Neon
    ring.BrickColor = BrickColor.new(color or "Bright cyan")
    ring.Position = pos
    ring.Transparency = 0.5
    ring.Parent = Workspace
    Debris:AddItem(ring, duration or 0.5)
    task.spawn(function()
        for i = 1, 10 do
            if not ring or not ring.Parent then break end
            ring.Transparency = ring.Transparency + 0.05
            ring.Size = ring.Size + Vector3.new(0.5, 0, 0.5)
            ring.Position = ring.Position + Vector3.new(0, 0.1, 0)
            task.wait((duration or 0.5) / 10)
        end
        pcall(function() ring:Destroy() end)
    end)
end

-- =====================================================
-- アクション関数
-- =====================================================
local function KickSelected()
    if not selectedPlayer then
        OrionLib:MakeNotification({Name = "エラー", Content = "プレイヤー未選択", Time = 3})
        return
    end
    if isTargetSelf(selectedPlayer) then return end
    pcall(function()
        selectedPlayer:Kick("強制キック")
        print(selectedPlayer.Name .. " キック")
    end)
    pcall(function()
        local c = selectedPlayer.Character
        if c then c:Destroy() end
    end)
    createEffect(rootPart.Position, "Bright red", Vector3.new(8, 8, 8), 1)
    createRingEffect(rootPart.Position, "Bright red", 5, 0.5)
end

local function KickAll()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= localPlayer then
            pcall(function() p:Kick("強制キック") end)
            pcall(function()
                local c = p.Character
                if c then c:Destroy() end
            end)
        end
    end
    createEffect(rootPart.Position, "Dark red", Vector3.new(10, 10, 10), 1)
    createRingEffect(rootPart.Position, "Dark red", 8, 0.8)
end

local function RagdollKill()
    if not character or not rootPart then return end
    local origin = rootPart.Position + Vector3.new(0, 1, 0)
    local dir = rootPart.CFrame.LookVector * 5
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {character}
    params.FilterType = Enum.RaycastFilterType.Blacklist
    local result = Workspace:Raycast(origin, dir, params)
    if result and result.Instance then
        local target = result.Instance.Parent
        local tHum = target:FindFirstChild("Humanoid")
        local tRoot = target:FindFirstChild("HumanoidRootPart")
        if tHum and tHum.Health > 0 and tRoot then
            local owner = Players:GetPlayerFromCharacter(target)
            if owner and owner == localPlayer then return end
            tHum.Health = 0
            tRoot.AssemblyLinearVelocity = Vector3.new(math.random(-50, 50), math.random(20, 60), math.random(-50, 50))
            tRoot.AssemblyAngularVelocity = Vector3.new(math.random(-20, 20), math.random(-20, 20), math.random(-20, 20))
            createEffect(tRoot.Position, "Dark red", Vector3.new(6, 6, 6), 1)
            createSplash(tRoot.Position, "Red", 30)
        end
    end
end

local function NormalKick()
    if not character or not rootPart or not humanoid then return end
    humanoid.Jump = true
    rootPart.AssemblyLinearVelocity = rootPart.CFrame.LookVector * 30 + Vector3.new(0, 8, 0)
    createEffect(rootPart.Position - Vector3.new(0, 0.5, 0), "Bright yellow", Vector3.new(3, 1, 3), 0.3)
    local origin = rootPart.Position + Vector3.new(0, 1, 0)
    local dir = rootPart.CFrame.LookVector * 6
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {character}
    params.FilterType = Enum.RaycastFilterType.Blacklist
    local result = Workspace:Raycast(origin, dir, params)
    if result and result.Instance then
        local target = result.Instance.Parent
        local tHum = target:FindFirstChild("Humanoid")
        if tHum and tHum.Health > 0 then
            local owner = Players:GetPlayerFromCharacter(target)
            if owner and owner == localPlayer then return end
            tHum:TakeDamage(15)
            local tRoot = target:FindFirstChild("HumanoidRootPart")
            if tRoot then
                local d = (tRoot.Position - rootPart.Position).Unit
                tRoot.AssemblyLinearVelocity = d * 35 + Vector3.new(0, 10, 0)
            end
            createEffect(result.Position, "Bright orange", Vector3.new(2, 2, 2), 0.4)
            createSplash(result.Position, "Lime green", 10)
        end
    end
end

local function DriftKick()
    if isDrifting then return end
    if not character or not rootPart then return end
    local origin = rootPart.Position + Vector3.new(0, 1, 0)
    local dir = rootPart.CFrame.LookVector * 10
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {character}
    params.FilterType = Enum.RaycastFilterType.Blacklist
    local result = Workspace:Raycast(origin, dir, params)
    if not result or not result.Instance then return end
    local target = result.Instance.Parent
    local tRoot = target:FindFirstChild("HumanoidRootPart")
    local tHum = target:FindFirstChild("Humanoid")
    if not tRoot or not tHum or tHum.Health <= 0 or target == character then return end
    local owner = Players:GetPlayerFromCharacter(target)
    if owner and owner == localPlayer then return end
    currentTarget = target
    local targetPos = tRoot.Position
    isDrifting = true
    local radius, speed, angle, laps, maxLaps = 4, 0.3, 0, 0, 3
    local origSpeed = humanoid.WalkSpeed
    humanoid.WalkSpeed = 20
    local conn
    conn = RunService.Heartbeat:Connect(function()
        if not character or not character.Parent or not currentTarget or not currentTarget.Parent then
            conn:Disconnect()
            isDrifting = false
            humanoid.WalkSpeed = origSpeed
            return
        end
        local ctp = currentTarget:FindFirstChild("HumanoidRootPart")
        if not ctp then
            conn:Disconnect()
            isDrifting = false
            humanoid.WalkSpeed = origSpeed
            return
        end
        local th = currentTarget:FindFirstChild("Humanoid")
        if not th or th.Health <= 0 then
            conn:Disconnect()
            isDrifting = false
            humanoid.WalkSpeed = origSpeed
            return
        end
        targetPos = ctp.Position
        angle = angle + speed
        if angle >= math.rad(360) then
            angle = 0
            laps = laps + 1
            if laps >= maxLaps then
                conn:Disconnect()
                humanoid.WalkSpeed = origSpeed
                task.wait(0.1)
                local kd = (targetPos - rootPart.Position).Unit
                rootPart.AssemblyLinearVelocity = kd * 50 + Vector3.new(0, 10, 0)
                th:TakeDamage(30)
                tRoot.AssemblyLinearVelocity = kd * 60 + Vector3.new(0, 15, 0)
                createEffect(targetPos, "Bright cyan", Vector3.new(5, 5, 5), 0.6)
                createSplash(targetPos, "Cyan", 30)
                createSplash(rootPart.Position, "Cyan", 20)
                createRingEffect(targetPos, "Cyan", 5, 0.5)
                isDrifting = false
                currentTarget = nil
                return
            end
        end
        local xOff = math.cos(angle) * radius
        local zOff = math.sin(angle) * radius
        local newPos = Vector3.new(targetPos.X + xOff, targetPos.Y + 1.5, targetPos.Z + zOff)
        local ld = (targetPos - newPos).Unit
        if ld.Magnitude > 0.1 then
            rootPart.CFrame = CFrame.lookAt(newPos, targetPos)
        end
        rootPart.AssemblyLinearVelocity = Vector3.new(0, 2, 0)
    end)
end

local function NoBlobKick()
    if not character or not rootPart or not humanoid then return end
    if humanoid.FloorMaterial == Enum.Material.Air then
        rootPart.AssemblyLinearVelocity = Vector3.new(0, -100, 0)
        task.wait(0.15)
        local exp = Instance.new("Explosion")
        exp.BlastRadius = 10
        exp.BlastPressure = 400000
        exp.Position = rootPart.Position
        exp.Parent = Workspace
        Debris:AddItem(exp, 0.5)
        for _, part in ipairs(Workspace:GetPartsInPart(rootPart, 10)) do
            local target = part.Parent
            if target and target ~= character and target:FindFirstChild("Humanoid") then
                local tHum = target.Humanoid
                if tHum.Health > 0 then
                    local owner = Players:GetPlayerFromCharacter(target)
                    if owner and owner == localPlayer then return end
                    tHum:TakeDamage(50)
                    local tRoot = target:FindFirstChild("HumanoidRootPart")
                    if tRoot then
                        tRoot.AssemblyLinearVelocity = Vector3.new(0, 30, 0) + (tRoot.Position - rootPart.Position).Unit * 25
                    end
                end
            end
        end
        createEffect(rootPart.Position, "Bright red", Vector3.new(8, 8, 8), 1)
        createSplash(rootPart.Position, "Magenta", 40)
        createRingEffect(rootPart.Position, "Red", 8, 0.8)
    else
        humanoid.Jump = true
        task.wait(0.2)
        NoBlobKick()
    end
end

local function AntiBlob()
    if not character or not rootPart then return end
    for _, part in ipairs(Workspace:GetPartsInPart(rootPart, 15)) do
        if part.Name == "BlobMan" or part.Name == "ブロブマン" then
            part:Destroy()
        end
    end
    createEffect(rootPart.Position, "Bright purple", Vector3.new(10, 10, 10), 0.5)
    createRingEffect(rootPart.Position, "Purple", 6, 0.5)
end

local function AntiPoison()
    if not character or not humanoid then return end
    for _, part in ipairs(Workspace:GetDescendants()) do
        if part:IsA("BasePart") and part.BrickColor == BrickColor.new("Bright green") then
            if part.Name:lower():find("poison") or part.Name:lower():find("毒") then
                part:Destroy()
            end
        end
    end
    humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + 50)
    createEffect(rootPart.Position, "Bright green", Vector3.new(5, 5, 5), 0.5)
end

local function Dance()
    if not character or not rootPart or not humanoid then return end
    for i = 1, 20 do
        rootPart.CFrame = rootPart.CFrame * CFrame.Angles(0, math.rad(18), 0) + Vector3.new(0, math.sin(i/2) * 0.5, 0)
        task.wait(0.05)
    end
    humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + 30)
    for _, part in ipairs(Workspace:GetPartsInPart(rootPart, 7)) do
        local target = part.Parent
        if target and target ~= character and target:FindFirstChild("Humanoid") then
            local tHum = target.Humanoid
            if tHum.Health > 0 then
                local owner = Players:GetPlayerFromCharacter(target)
                if owner and owner == localPlayer then return end
                local tRoot = target:FindFirstChild("HumanoidRootPart")
                if tRoot then
                    local d = (tRoot.Position - rootPart.Position).Unit
                    tRoot.AssemblyLinearVelocity = d * 30 + Vector3.new(0, 8, 0)
                end
            end
        end
    end
    createEffect(rootPart.Position, "Bright green", Vector3.new(6, 6, 6), 1)
    createSplash(rootPart.Position, "Bright green", 25)
    createRingEffect(rootPart.Position, "Green", 5, 0.5)
end

local function Feather()
    if not character or not rootPart or not humanoid then return end
    for i = 1, 20 do
        local f = Instance.new("Part")
        f.Size = Vector3.new(0.3, 0.1, 0.5)
        f.Anchored = false
        f.CanCollide = false
        f.Material = Enum.Material.Neon
        f.BrickColor = BrickColor.new("White")
        f.Position = rootPart.Position + Vector3.new(math.random(-5, 5), math.random(1, 6), math.random(-5, 5))
        f.Parent = Workspace
        local bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(500, 500, 500)
        bv.Velocity = Vector3.new(math.random(-3, 3), math.random(2, 6), math.random(-3, 3))
        bv.Parent = f
        Debris:AddItem(f, 3)
        Debris:AddItem(bv, 3)
    end
    local og = Workspace.Gravity
    Workspace.Gravity = 40
    humanoid.WalkSpeed = humanoid.WalkSpeed + 30
    humanoid.JumpPower = humanoid.JumpPower + 25
    task.wait(4)
    Workspace.Gravity = og
    humanoid.WalkSpeed = humanoid.WalkSpeed - 30
    humanoid.JumpPower = humanoid.JumpPower - 25
    createRingEffect(rootPart.Position, "White", 4, 0.3)
end

local function Fly()
    if not character or not rootPart then return end
    flyBV = Instance.new("BodyVelocity")
    flyBV.MaxForce = Vector3.new(10000, 10000, 10000)
    flyBV.Velocity = Vector3.new(0, 30, 0)
    flyBV.Parent = rootPart
    for i = 1, 40 do
        local f = Instance.new("Part")
        f.Size = Vector3.new(0.2, 0.1, 0.4)
        f.Anchored = false
        f.CanCollide = false
        f.Material = Enum.Material.Neon
        f.BrickColor = BrickColor.new("White")
        f.Position = rootPart.Position + Vector3.new(math.random(-7, 7), math.random(0, 10), math.random(-7, 7))
        f.Parent = Workspace
        local bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(300, 300, 300)
        bv.Velocity = Vector3.new(math.random(-4, 4), math.random(1, 5), math.random(-4, 4))
        bv.Parent = f
        Debris:AddItem(f, 4)
        Debris:AddItem(bv, 4)
        task.wait(0.03)
    end
    createRingEffect(rootPart.Position, "White", 6, 0.5)
    task.wait(6)
    if flyBV then flyBV:Destroy() end
    flyBV = nil
end

local function ParticleEffect()
    for i = 1, 50 do
        local p = Instance.new("Part")
        p.Size = Vector3.new(0.2, 0.2, 0.2)
        p.Shape = Enum.PartType.Ball
        p.Material = Enum.Material.Neon
        p.BrickColor = BrickColor.new("Bright cyan")
        p.Position = rootPart.Position + Vector3.new(math.random(-10, 10), math.random(-5, 15), math.random(-10, 10))
        p.Anchored = false
        p.CanCollide = false
        p.Parent = Workspace
        local bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(100, 100, 100)
        bv.Velocity = Vector3.new(math.random(-5, 5), math.random(5, 15), math.random(-5, 5))
        bv.Parent = p
        Debris:AddItem(p, 2)
        Debris:AddItem(bv, 2)
        task.wait(0.05)
    end
    createRingEffect(rootPart.Position, "Cyan", 6, 0.5)
end

local function LoopKill()
    if not character or not rootPart then return end
    for i = 1, 5 do
        for _, part in ipairs(Workspace:GetPartsInPart(rootPart, 6)) do
            local target = part.Parent
            if target and target ~= character and target:FindFirstChild("Humanoid") then
                local tHum = target.Humanoid
                if tHum.Health > 0 then
                    local owner = Players:GetPlayerFromCharacter(target)
                    if owner and owner == localPlayer then return end
                    tHum:TakeDamage(15)
                    local tRoot = target:FindFirstChild("HumanoidRootPart")
                    if tRoot then
                        tRoot.AssemblyLinearVelocity = Vector3.new(0, 20, 0) + (tRoot.Position - rootPart.Position).Unit * 10
                    end
                    createEffect(tRoot.Position, "Bright magenta", Vector3.new(2, 2, 2), 0.3)
                    createSplash(tRoot.Position, "Pink", 8)
                end
            end
        end
        task.wait(0.12)
    end
end

local function Kill()
    if not character or not rootPart then return end
    local origin = rootPart.Position + Vector3.new(0, 1, 0)
    local dir = rootPart.CFrame.LookVector * 4
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {character}
    params.FilterType = Enum.RaycastFilterType.Blacklist
    local result = Workspace:Raycast(origin, dir, params)
    if result and result.Instance then
        local target = result.Instance.Parent
        local tHum = target:FindFirstChild("Humanoid")
        if tHum and tHum.Health > 0 then
            local owner = Players:GetPlayerFromCharacter(target)
            if owner and owner == localPlayer then return end
            tHum.Health = 0
            createEffect(target.HumanoidRootPart.Position, "Black", Vector3.new(10, 10, 10), 1.5)
            createSplash(target.HumanoidRootPart.Position, "Dark red", 50)
            createRingEffect(target.HumanoidRootPart.Position, "Black", 6, 0.6)
        end
    end
end

local function AllKill()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= localPlayer then
            local c = p.Character
            if c then
                local h = c:FindFirstChild("Humanoid")
                if h and h.Health > 0 then
                    h.Health = 0
                    local r = c:FindFirstChild("HumanoidRootPart")
                    if r then
                        createEffect(r.Position, "Dark red", Vector3.new(5, 5, 5), 0.5)
                        createRingEffect(r.Position, "Dark red", 4, 0.3)
                    end
                end
            end
        end
    end
    createEffect(rootPart.Position, "Black", Vector3.new(10, 10, 10), 1)
    createRingEffect(rootPart.Position, "Black", 8, 0.8)
end

local function AllKick()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= localPlayer then
            local c = p.Character
            if c then
                local r = c:FindFirstChild("HumanoidRootPart")
                if r then
                    local d = (r.Position - rootPart.Position).Unit
                    r.AssemblyLinearVelocity = d * 80 + Vector3.new(0, 30, 0)
                    createEffect(r.Position, "Bright cyan", Vector3.new(3, 3, 3), 0.3)
                    createSplash(r.Position, "Cyan", 10)
                end
            end
        end
    end
end

local function KillSwitch()
    killSwitchActive = not killSwitchActive
    if killSwitchActive then
        OrionLib:MakeNotification({Name = "KillSwitch", Content = "ON", Time = 3})
        createEffect(rootPart.Position, "Red", Vector3.new(8, 8, 8), 1)
        createRingEffect(rootPart.Position, "Red", 6, 0.5)
        task.spawn(function()
            while killSwitchActive do
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= localPlayer then
                        local c = p.Character
                        if c then
                            local h = c:FindFirstChild("Humanoid")
                            if h and h.Health > 0 then
                                h.Health = h.Health - 10
                                local r = c:FindFirstChild("HumanoidRootPart")
                                if r then createSplash(r.Position, "Red", 5) end
                            end
                        end
                    end
                end
                task.wait(0.5)
            end
        end)
    else
        OrionLib:MakeNotification({Name = "KillSwitch", Content = "OFF", Time = 3})
        createEffect(rootPart.Position, "White", Vector3.new(5, 5, 5), 0.5)
    end
end

local function KillOthers()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= localPlayer then
            local char = p.Character
            if char then
                local hum = char:FindFirstChild("Humanoid")
                if hum and hum.Health > 0 then
                    hum.Health = 0
                    local root = char:FindFirstChild("HumanoidRootPart")
                    if root then
                        createEffect(root.Position, "Dark red", Vector3.new(5, 5, 5), 0.5)
                        createSplash(root.Position, "Red", 20)
                        createRingEffect(root.Position, "Dark red", 4, 0.3)
                    end
                end
            end
        end
    end
    createEffect(rootPart.Position, "Black", Vector3.new(10, 10, 10), 1)
    createRingEffect(rootPart.Position, "Black", 8, 0.8)
end

local function ServerAccess()
    pcall(function()
        for _, c in ipairs(ReplicatedStorage:GetChildren()) do
            if c:IsA("RemoteEvent") or c:IsA("RemoteFunction") then
                pcall(function()
                    if c:IsA("RemoteEvent") then c:FireServer("Access")
                    else c:InvokeServer("Access") end
                end)
            end
        end
        local r = Instance.new("RemoteEvent")
        r.Name = "AccessEvent"
        r.Parent = ReplicatedStorage
        r:FireServer()
        task.wait(0.3)
        r:Destroy()
        createEffect(rootPart.Position, "Bright cyan", Vector3.new(8, 8, 8), 1)
        createRingEffect(rootPart.Position, "Cyan", 6, 0.5)
    end)
end

local function FreezeAll()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= localPlayer then
            local char = p.Character
            if char then
                local hum = char:FindFirstChild("Humanoid")
                if hum then
                    hum.WalkSpeed = 0
                    hum.JumpPower = 0
                    createEffect(char.HumanoidRootPart.Position, "Bright blue", Vector3.new(3, 3, 3), 0.5)
                end
            end
        end
    end
    createRingEffect(rootPart.Position, "Blue", 5, 0.5)
    task.wait(5)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= localPlayer then
            local char = p.Character
            if char then
                local hum = char:FindFirstChild("Humanoid")
                if hum then
                    hum.WalkSpeed = 16
                    hum.JumpPower = 50
                end
            end
        end
    end
end

local function CrashServer()
    createRingEffect(rootPart.Position, "Red", 10, 1)
    for i = 1, 100 do
        pcall(function()
            local part = Instance.new("Part")
            part.Size = Vector3.new(100, 100, 100)
            part.Position = Vector3.new(math.random(-1000, 1000), math.random(-1000, 1000), math.random(-1000, 1000))
            part.Anchored = true
            part.CanCollide = false
            part.Transparency = 1
            part.Parent = Workspace
            Debris:AddItem(part, 0.1)
        end)
    end
    createEffect(rootPart.Position, "Dark red", Vector3.new(20, 20, 20), 1)
end

local function toggleESP()
    espEnabled = not espEnabled
    if espEnabled then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= localPlayer then
                local char = p.Character
                if char then
                    local root = char:FindFirstChild("HumanoidRootPart")
                    if root then
                        local box = Instance.new("BoxHandleAdornment")
                        box.Size = Vector3.new(3, 5, 2)
                        box.Color3 = Color3.fromRGB(255, 0, 0)
                        box.Transparency = 0.5
                        box.AlwaysOnTop = true
                        box.ZIndex = 0
                        box.Adornee = root
                        box.Parent = root
                        table.insert(espObjects, box)
                        
                        local nameTag = Instance.new("BillboardGui")
                        nameTag.Size = UDim2.new(0, 100, 0, 30)
                        nameTag.AlwaysOnTop = true
                        nameTag.Parent = root
                        nameTag.Adornee = root
                        
                        local label = Instance.new("TextLabel")
                        label.Size = UDim2.new(1, 0, 1, 0)
                        label.BackgroundTransparency = 1
                        label.Text = p.Name .. " | " .. math.floor((root.Position - rootPart.Position).Magnitude) .. "m"
                        label.TextColor3 = Color3.fromRGB(255, 255, 255)
                        label.TextSize = 14
                        label.Font = Enum.Font.GothamBold
                        label.TextStrokeTransparency = 0.5
                        label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
                        label.Parent = nameTag
                        table.insert(espObjects, nameTag)
                    end
                end
            end
        end
        OrionLib:MakeNotification({Name = "ESP", Content = "ON", Time = 3})
    else
        for _, obj in ipairs(espObjects) do
            pcall(function() obj:Destroy() end)
        end
        espObjects = {}
        OrionLib:MakeNotification({Name = "ESP", Content = "OFF", Time = 3})
    end
end

local function TeleportToPlayer()
    if not selectedPlayer then
        OrionLib:MakeNotification({Name = "エラー", Content = "プレイヤー未選択", Time = 3})
        return
    end
    if selectedPlayer == localPlayer then
        OrionLib:MakeNotification({Name = "エラー", Content = "自分にはできません", Time = 3})
        return
    end
    local char = selectedPlayer.Character
    if not char then
        OrionLib:MakeNotification({Name = "エラー", Content = "キャラクターなし", Time = 3})
        return
    end
    local targetRoot = char:FindFirstChild("HumanoidRootPart")
    if not targetRoot then return end
    rootPart.CFrame = targetRoot.CFrame + Vector3.new(0, 3, 0)
    createEffect(rootPart.Position, "Bright cyan", Vector3.new(5, 5, 5), 0.5)
    createRingEffect(rootPart.Position, "Cyan", 4, 0.3)
end

local function InfiniteJump()
    if not humanoid then return end
    humanoid.JumpPower = 100
    local conn
    conn = RunService.Heartbeat:Connect(function()
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            humanoid.Jump = true
        end
    end)
    createRingEffect(rootPart.Position, "Yellow", 4, 0.3)
    task.wait(10)
    conn:Disconnect()
    humanoid.JumpPower = 50
end

local function SpeedHack()
    if not humanoid then return end
    local origSpeed = humanoid.WalkSpeed
    humanoid.WalkSpeed = 120
    createEffect(rootPart.Position, "Bright yellow", Vector3.new(5, 5, 5), 0.5)
    createRingEffect(rootPart.Position, "Yellow", 5, 0.4)
    task.wait(10)
    humanoid.WalkSpeed = origSpeed
end

local function Invisible()
    if not character then return end
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Transparency = 1
        end
    end
    createEffect(rootPart.Position, "White", Vector3.new(5, 5, 5), 0.5)
    createRingEffect(rootPart.Position, "White", 4, 0.3)
    task.wait(10)
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Transparency = 0
        end
    end
end

-- =====================================================
-- Orion UI 作成
-- =====================================================
local Window = OrionLib:MakeWindow({
    Name = "Suika Hub V3",
    HidePremium = false,
    SaveConfig = true,
    ConfigFolder = "SuikaHubV3",
    IntroEnabled = true,
    IntroText = "Suika Hub V3",
    IntroIcon = "rbxassetid://8834748103",
    Icon = "rbxassetid://8834748103",
    ShowIcon = true,
    KeyToOpenWindow = "K"
})

-- =====================================================
-- タブ作成
-- =====================================================

-- キックタブ
local KickTab = Window:MakeTab({
    Name = "キック",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

KickTab:AddButton({
    Name = "選択キック",
    Callback = function() KickSelected() end
})

KickTab:AddButton({
    Name = "全員キック",
    Callback = function() KickAll() end
})

KickTab:AddButton({
    Name = "ラグドールキル",
    Callback = function() RagdollKill() end
})

KickTab:AddButton({
    Name = "ドリフトキック",
    Callback = function() DriftKick() end
})

KickTab:AddButton({
    Name = "通常キック",
    Callback = function() NormalKick() end
})

KickTab:AddButton({
    Name = "ノーブロブキック",
    Callback = function() NoBlobKick() end
})

-- アンチタブ
local AntiTab = Window:MakeTab({
    Name = "アンチ",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

AntiTab:AddButton({
    Name = "アンチブロブ",
    Callback = function() AntiBlob() end
})

AntiTab:AddButton({
    Name = "アンチ毒",
    Callback = function() AntiPoison() end
})

-- エフェクトタブ
local EffectTab = Window:MakeTab({
    Name = "エフェクト",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

EffectTab:AddButton({
    Name = "ダンス",
    Callback = function() Dance() end
})

EffectTab:AddButton({
    Name = "羽",
    Callback = function() Feather() end
})

EffectTab:AddButton({
    Name = "飛行",
    Callback = function() Fly() end
})

EffectTab:AddButton({
    Name = "パーティクル",
    Callback = function() ParticleEffect() end
})

-- キルタブ
local KillTab = Window:MakeTab({
    Name = "キル",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

KillTab:AddButton({
    Name = "キルスイッチ",
    Callback = function() KillSwitch() end
})

KillTab:AddButton({
    Name = "ループキル",
    Callback = function() LoopKill() end
})

KillTab:AddButton({
    Name = "キル",
    Callback = function() Kill() end
})

KillTab:AddButton({
    Name = "オールキル",
    Callback = function() AllKill() end
})

KillTab:AddButton({
    Name = "オールキック",
    Callback = function() AllKick() end
})

KillTab:AddButton({
    Name = "自分以外キル",
    Callback = function() KillOthers() end
})

-- サーバータブ
local ServerTab = Window:MakeTab({
    Name = "サーバー",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

ServerTab:AddButton({
    Name = "サーバーアクセス",
    Callback = function() ServerAccess() end
})

ServerTab:AddButton({
    Name = "全員凍結",
    Callback = function() FreezeAll() end
})

ServerTab:AddButton({
    Name = "サーバークラッシュ",
    Callback = function() CrashServer() end
})

-- プレミアムタブ
local PremiumTab = Window:MakeTab({
    Name = "プレミアム",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

PremiumTab:AddButton({
    Name = "ESP",
    Callback = function() toggleESP() end
})

PremiumTab:AddButton({
    Name = "ワープ",
    Callback = function() TeleportToPlayer() end
})

PremiumTab:AddButton({
    Name = "無限ジャンプ",
    Callback = function() InfiniteJump() end
})

PremiumTab:AddButton({
    Name = "スピードハック",
    Callback = function() SpeedHack() end
})

PremiumTab:AddButton({
    Name = "透明化",
    Callback = function() Invisible() end
})

-- プレイヤー選択タブ
local PlayerTab = Window:MakeTab({
    Name = "プレイヤー",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

PlayerTab:AddDropdown({
    Name = "プレイヤーを選択",
    Options = (function()
        local opts = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= localPlayer then
                table.insert(opts, p.Name)
            end
        end
        return opts
    end)(),
    Default = "",
    Callback = function(Value)
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Name == Value then
                selectedPlayer = p
                OrionLib:MakeNotification({
                    Name = "選択",
                    Content = p.Name .. " を選択しました",
                    Time = 3
                })
                return
            end
        end
    end
})

-- =====================================================
-- 起動通知
-- =====================================================
OrionLib:MakeNotification({
    Name = "Suika Hub V3",
    Content = "読み込み完了！ KキーでUI開閉",
    Time = 5
})

-- =====================================================
-- キーバインド（PC用）
-- =====================================================
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    local key = input.KeyCode

    if key == Enum.KeyCode.K then KickSelected()
    elseif key == Enum.KeyCode.L then KickAll()
    elseif key == Enum.KeyCode.R then RagdollKill()
    elseif key == Enum.KeyCode.E then DriftKick()
    elseif key == Enum.KeyCode.Q then NormalKick()
    elseif key == Enum.KeyCode.T then NoBlobKick()
    elseif key == Enum.KeyCode.X then KillSwitch()
    elseif key == Enum.KeyCode.Z then AllKill()
    elseif key == Enum.KeyCode.V then AllKick()
    elseif key == Enum.KeyCode.C then ServerAccess()
    elseif key == Enum.KeyCode.G then LoopKill()
    elseif key == Enum.KeyCode.H then Kill()
    elseif key == Enum.KeyCode.F then Dance()
    elseif key == Enum.KeyCode.Y then Feather()
    elseif key == Enum.KeyCode.U then Fly()
    elseif key == Enum.KeyCode.B then AntiBlob()
    elseif key == Enum.KeyCode.P then AntiPoison()
    elseif key == Enum.KeyCode.LeftBracket then toggleESP()
    elseif key == Enum.KeyCode.RightBracket then TeleportToPlayer()
    elseif key == Enum.KeyCode.J then InfiniteJump()
    elseif key == Enum.KeyCode.S then SpeedHack()
    elseif key == Enum.KeyCode.I then Invisible()
    elseif key == Enum.KeyCode.N then KillOthers()
    elseif key == Enum.KeyCode.M then ParticleEffect()
    elseif key == Enum.KeyCode.O then CrashServer()
    end
end)

print("Suika Hub V3 (Orion UI) Loaded!")
print("スマホ・PC両対応")
print("KキーでUI開閉")