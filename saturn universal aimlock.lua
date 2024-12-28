


if not game:IsLoaded() then 
    game.Loaded:Wait()
end

if not syn or not protectgui then
    getgenv().protectgui = function() end
end

 


local SilentAimSettings = {
    Enabled = false,
    
    ClassName = "Saturn_v1  |  universal v1.02",
    ToggleKey = "U",
    
    TeamCheck = false,
    VisibleCheck = false, 
    TargetPart = "HumanoidRootPart",
    SilentAimMethod = "Raycast",
    
    FOVRadius = 130,
    FOVVisible = false,
    ShowSilentAimTarget = false, 
    
    MouseHitPrediction = false,
    MouseHitPredictionAmount = 0.165,
    HitChance = 100
}

getgenv().SilentAimSettings = Settings

local Camera = workspace.CurrentCamera
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local GetChildren = game.GetChildren
local GetPlayers = Players.GetPlayers
local WorldToScreen = Camera.WorldToScreenPoint
local WorldToViewportPoint = Camera.WorldToViewportPoint
local GetPartsObscuringTarget = Camera.GetPartsObscuringTarget
local FindFirstChild = game.FindFirstChild
local RenderStepped = RunService.RenderStepped
local GuiInset = GuiService.GetGuiInset
local GetMouseLocation = UserInputService.GetMouseLocation

local resume = coroutine.resume 
local create = coroutine.create

local ValidTargetParts = {"Head", "HumanoidRootPart"}
local PredictionAmount = 0.165

local mouse_box = Drawing.new("Square")
mouse_box.Visible = true 
mouse_box.ZIndex = 999 
mouse_box.Color = Color3.fromRGB(54, 57, 241)
mouse_box.Thickness = 20 
mouse_box.Size = Vector2.new(20, 20)
mouse_box.Filled = true 

local fov_circle = Drawing.new("Circle")
fov_circle.Thickness = 1
fov_circle.NumSides = 100
fov_circle.Radius = 180
fov_circle.Filled = false
fov_circle.Visible = false
fov_circle.ZIndex = 999
fov_circle.Transparency = 1
fov_circle.Color = Color3.fromRGB(54, 57, 241)

local ExpectedArguments = {
    FindPartOnRayWithIgnoreList = {
        ArgCountRequired = 3,
        Args = {
            "Instance", "Ray", "table", "boolean", "boolean"
        }
    },
    FindPartOnRayWithWhitelist = {
        ArgCountRequired = 3,
        Args = {
            "Instance", "Ray", "table", "boolean"
        }
    },
    FindPartOnRay = {
        ArgCountRequired = 2,
        Args = {
            "Instance", "Ray", "Instance", "boolean", "boolean"
        }
    },
    Raycast = {
        ArgCountRequired = 3,
        Args = {
            "Instance", "Vector3", "Vector3", "RaycastParams"
        }
    }
}

function CalculateChance(Percentage)

    Percentage = math.floor(Percentage)


    local chance = math.floor(Random.new().NextNumber(Random.new(), 0, 1) * 100) / 100


    return chance <= Percentage / 100
end


local function getPositionOnScreen(Vector)
    local Vec3, OnScreen = WorldToScreen(Camera, Vector)
    return Vector2.new(Vec3.X, Vec3.Y), OnScreen
end

local function ValidateArguments(Args, RayMethod)
    local Matches = 0
    if #Args < RayMethod.ArgCountRequired then
        return false
    end
    for Pos, Argument in next, Args do
        if typeof(Argument) == RayMethod.Args[Pos] then
            Matches = Matches + 1
        end
    end
    return Matches >= RayMethod.ArgCountRequired
end

local function getDirection(Origin, Position)
    return (Position - Origin).Unit * 1000
end

local function getMousePosition()
    return GetMouseLocation(UserInputService)
end

local function IsPlayerVisible(Player)
    local PlayerCharacter = Player.Character
    local LocalPlayerCharacter = LocalPlayer.Character
    
    if not (PlayerCharacter or LocalPlayerCharacter) then return end 
    
    local PlayerRoot = FindFirstChild(PlayerCharacter, Options.TargetPart.Value) or FindFirstChild(PlayerCharacter, "HumanoidRootPart")
    
    if not PlayerRoot then return end 
    
    local CastPoints, IgnoreList = {PlayerRoot.Position, LocalPlayerCharacter, PlayerCharacter}, {LocalPlayerCharacter, PlayerCharacter}
    local ObscuringObjects = #GetPartsObscuringTarget(Camera, CastPoints, IgnoreList)
    
    return ((ObscuringObjects == 0 and true) or (ObscuringObjects > 0 and false))
end

local function getClosestPlayer()
    if not Options.TargetPart.Value then return end
    local Closest
    local DistanceToMouse
    for _, Player in next, GetPlayers(Players) do
        if Player == LocalPlayer then continue end
        if Toggles.TeamCheck.Value and Player.Team == LocalPlayer.Team then continue end

        local Character = Player.Character
        if not Character then continue end
        
        if Toggles.VisibleCheck.Value and not IsPlayerVisible(Player) then continue end

        local HumanoidRootPart = FindFirstChild(Character, "HumanoidRootPart")
        local Humanoid = FindFirstChild(Character, "Humanoid")
        if not HumanoidRootPart or not Humanoid or Humanoid and Humanoid.Health <= 0 then continue end

        local ScreenPosition, OnScreen = getPositionOnScreen(HumanoidRootPart.Position)
        if not OnScreen then continue end

        local Distance = (getMousePosition() - ScreenPosition).Magnitude
        if Distance <= (DistanceToMouse or Options.Radius.Value or 2000) then
            Closest = ((Options.TargetPart.Value == "Random" and Character[ValidTargetParts[math.random(1, #ValidTargetParts)]]) or Character[Options.TargetPart.Value])
            DistanceToMouse = Distance
        end
    end
    return Closest
end


local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

local isLockedOn = false
local targetPlayer = nil
local lockEnabled = false
local smoothingFactor = 0.1
local predictionFactor = 0.0
local bodyPartSelected = "Head"
local aimLockEnabled = false 


local function getBodyPart(character, part)
    return character:FindFirstChild(part) and part or "Head"
end

local function getNearestPlayerToMouse()
    if not aimLockEnabled then return nil end 
    local nearestPlayer = nil
    local shortestDistance = math.huge
    local mousePosition = Camera:ViewportPointToRay(Mouse.X, Mouse.Y).Origin

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild(bodyPartSelected) then
            local part = player.Character[bodyPartSelected]
            local screenPosition, onScreen = Camera:WorldToViewportPoint(part.Position)
            if onScreen then
                local distance = (Vector2.new(screenPosition.X, screenPosition.Y) - Vector2.new(Mouse.X, Mouse.Y)).Magnitude
                if distance < shortestDistance then
                    nearestPlayer = player
                    shortestDistance = distance
                end
            end
        end
    end
    return nearestPlayer
end

local function toggleLockOnPlayer()
    if not lockEnabled or not aimLockEnabled then return end

    if isLockedOn then
        isLockedOn = false
        targetPlayer = nil
    else
        targetPlayer = getNearestPlayerToMouse()
        if targetPlayer and targetPlayer.Character then
            local part = getBodyPart(targetPlayer.Character, bodyPartSelected)
            if targetPlayer.Character:FindFirstChild(part) then
                isLockedOn = true
            end
        end
    end
end


RunService.RenderStepped:Connect(function()
    if aimLockEnabled and lockEnabled and isLockedOn and targetPlayer and targetPlayer.Character then
        local partName = getBodyPart(targetPlayer.Character, bodyPartSelected)
        local part = targetPlayer.Character:FindFirstChild(partName)

        if part and targetPlayer.Character:FindFirstChildOfClass("Humanoid").Health > 0 then
            local predictedPosition = part.Position + (part.AssemblyLinearVelocity * predictionFactor)
            local currentCameraPosition = Camera.CFrame.Position

            Camera.CFrame = CFrame.new(currentCameraPosition, predictedPosition) * CFrame.new(0, 0, smoothingFactor)
        else
            isLockedOn = false
            targetPlayer = nil
        end
    end
end)



local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/Horizon89002/Saturn-universal-aimlock-silentaim/refs/heads/main/linoralib.lua"))()
local ThemeManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/Horizon89002/Saturn-universal-aimlock-silentaim/refs/heads/main/manage2.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/Horizon89002/Saturn-universal-aimlock-silentaim/refs/heads/main/manager.lua"))()


local Window = Library:CreateWindow({
    Title = 'Saturn | universal v1.2',
    Center = true,
    AutoShow = true,  
    TabPadding = 8,
    MenuFadeTime = 0.2
})

local GeneralTab = Window:AddTab("Main")
local aimbox = GeneralTab:AddRightGroupbox("           AimLock")
local velbox = GeneralTab:AddRightGroupbox("        Anti Lock")
local settingsTab = Window:AddTab("Settings")


ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
ThemeManager:ApplyToTab(settingsTab)
SaveManager:BuildConfigSection(settingsTab)


aimbox:AddToggle("aimLock_Enabled", {
    Text = "enable/disable AimLock",
    Default = false,
    Tooltip = "Toggle the AimLock feature on or off.",
    Callback = function(value)
        aimLockEnabled = value
        if not aimLockEnabled then
            lockEnabled = false
            isLockedOn = false
            targetPlayer = nil
        end
    end,
})


aimbox:AddToggle("aim_Enabled", {
    Text = "aimlock keybind",
    Default = false,
    Tooltip = "Toggle AimLock on or off.",
    Callback = function(value)
        lockEnabled = value
        if not lockEnabled then
            isLockedOn = false
            targetPlayer = nil
        end
    end,
}):AddKeyPicker("aim_Enabled_KeyPicker", {
    Default = "Q", 
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "AimLock Key",
    Tooltip = "Key to toggle AimLock",
    Callback = function()
        toggleLockOnPlayer()
    end,
})

aimbox:AddSlider("Smoothing", {
    Text = "Camera Smoothing",
    Default = 0.1,
    Min = 0,
    Max = 1,
    Rounding = 2,
    Tooltip = "Adjust camera smoothing factor.",
    Callback = function(value)
        smoothingFactor = value
    end,
})


aimbox:AddSlider("Prediction", {
    Text = "Prediction Factor",
    Default = 0.0,
    Min = 0,
    Max = 2,
    Rounding = 2,
    Tooltip = "Adjust prediction for target movement.",
    Callback = function(value)
        predictionFactor = value
    end,
})

aimbox:AddDropdown("BodyParts", {
    Values = {"Head", "UpperTorso", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg", "LeftUpperArm"},
    Default = "Head",
    Multi = false,
    Text = "Target Body Part",
    Tooltip = "Select which body part to lock onto.",
    Callback = function(value)
        bodyPartSelected = value
    end,
})


local reverseResolveIntensity = 5
getgenv().Desync = false
getgenv().DesyncEnabled = false  


game:GetService("RunService").Heartbeat:Connect(function()
    if getgenv().DesyncEnabled then  
        if getgenv().Desync then
            local player = game.Players.LocalPlayer
            local character = player.Character
            if not character then return end 

            local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
            if not humanoidRootPart then return end

            local originalVelocity = humanoidRootPart.Velocity

            local randomOffset = Vector3.new(
                math.random(-1, 1) * reverseResolveIntensity * 1000,
                math.random(-1, 1) * reverseResolveIntensity * 1000,
                math.random(-1, 1) * reverseResolveIntensity * 1000
            )

            humanoidRootPart.Velocity = randomOffset
            humanoidRootPart.CFrame = humanoidRootPart.CFrame * CFrame.Angles(
                0,
                math.random(-1, 1) * reverseResolveIntensity * 0.001,
                0
            )

            game:GetService("RunService").RenderStepped:Wait()

            humanoidRootPart.Velocity = originalVelocity
        end
    end
end)

velbox:AddToggle("desyncMasterEnabled", {
    Text = "Enable Desync",
    Default = false,
    Tooltip = "Enable or disable the entire desync system.",
    Callback = function(value)
        getgenv().DesyncEnabled = value  
    end
})


velbox:AddToggle("desyncEnabled", {
    Text = "Desync keybind",
    Default = false,
    Tooltip = "Enable or disable reverse resolve desync.",
    Callback = function(value)
        getgenv().Desync = value
    end
}):AddKeyPicker("desyncToggleKey", {
    Default = "V", 
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "Desync Toggle Key",
    Tooltip = "Toggle to enable/disable velocity desync.",
    Callback = function(value)
        getgenv().Desync = value
    end
})


velbox:AddSlider("ReverseResolveIntensity", {
    Text = "velocity intensity",
    Default = 5,
    Min = 1,
    Max = 10,
    Rounding = 0,
    Tooltip = "Adjust the intensity of the reverse resolve effect.",
    Callback = function(value)
        reverseResolveIntensity = value
    end
})



local antiLockEnabled = false
local resolverIntensity = 1.0
local resolverMethod = "Recalculate"


RunService.RenderStepped:Connect(function()
    if aimLockEnabled and isLockedOn and targetPlayer and targetPlayer.Character then
        local partName = getBodyPart(targetPlayer.Character, bodyPartSelected)
        local part = targetPlayer.Character:FindFirstChild(partName)

        if part and targetPlayer.Character:FindFirstChildOfClass("Humanoid").Health > 0 then
            local predictedPosition = part.Position + (part.AssemblyLinearVelocity * predictionFactor)

            if antiLockEnabled then
                if resolverMethod == "Recalculate" then

                    predictedPosition = predictedPosition + (part.AssemblyLinearVelocity * resolverIntensity)
                elseif resolverMethod == "Randomize" then

                    predictedPosition = predictedPosition + Vector3.new(
                        math.random() * resolverIntensity - (resolverIntensity / 2),
                        math.random() * resolverIntensity - (resolverIntensity / 2),
                        math.random() * resolverIntensity - (resolverIntensity / 2)
                    )
                elseif resolverMethod == "Invert" then

                    predictedPosition = predictedPosition - (part.AssemblyLinearVelocity * resolverIntensity * 2)
                end
            end

            local currentCameraPosition = Camera.CFrame.Position
            Camera.CFrame = CFrame.new(currentCameraPosition, predictedPosition) * CFrame.new(0, 0, smoothingFactor)
        else
            isLockedOn = false
            targetPlayer = nil
        end
    end
end)


aimbox:AddToggle("antiLock_Enabled", {
    Text = "Enable Anti Lock Resolver",
    Default = false,
    Tooltip = "Toggle the Anti Lock Resolver on or off.",
    Callback = function(value)
        antiLockEnabled = value
    end,
})

aimbox:AddSlider("ResolverIntensity", {
    Text = "Resolver Intensity",
    Default = 1.0,
    Min = 0,
    Max = 5,
    Rounding = 2,
    Tooltip = "Adjust the intensity of the Anti Lock Resolver.",
    Callback = function(value)
        resolverIntensity = value
    end,
})

aimbox:AddDropdown("ResolverMethods", {
    Values = {"Recalculate", "Randomize", "Invert"},
    Default = "Recalculate", 
    Multi = false,
    Text = "Resolver Method",
    Tooltip = "Select the method used by the Anti Lock Resolver.",
    Callback = function(value)
        resolverMethod = value
    end,
})


local MainBOX = GeneralTab:AddLeftTabbox("silent aim")
local Main = MainBOX:AddTab("silent aim")
local frabox = GeneralTab:AddLeftGroupbox("Movement")

Main:AddToggle("aim_Enabled", {Text = "Enabled"})
    :AddKeyPicker("aim_Enabled_KeyPicker", {
        Default = "U", 
        SyncToggleState = true, 
        Mode = "Toggle", 
        Text = "Enabled", 
        NoUI = false
    })

Options.aim_Enabled_KeyPicker:OnClick(function()
    SilentAimSettings.Enabled = not SilentAimSettings.Enabled
    Toggles.aim_Enabled.Value = SilentAimSettings.Enabled
    Toggles.aim_Enabled:SetValue(SilentAimSettings.Enabled)
    mouse_box.Visible = SilentAimSettings.Enabled
end)


Main:AddToggle("TeamCheck", {
    Text = "Team Check", 
    Default = SilentAimSettings.TeamCheck
}):OnChanged(function()
    SilentAimSettings.TeamCheck = Toggles.TeamCheck.Value
end)


Main:AddToggle("VisibleCheck", {
    Text = "Visible Check", 
    Default = SilentAimSettings.VisibleCheck
}):OnChanged(function()
    SilentAimSettings.VisibleCheck = Toggles.VisibleCheck.Value
end)


Main:AddDropdown("TargetPart", {
    AllowNull = true, 
    Text = "Target Part", 
    Default = SilentAimSettings.TargetPart, 
    Values = {"Head", "HumanoidRootPart", "Random"}
}):OnChanged(function()
    SilentAimSettings.TargetPart = Options.TargetPart.Value
end)


Main:AddDropdown("Method", {
    AllowNull = true, 
    Text = "Silent Aim Method", 
    Default = SilentAimSettings.SilentAimMethod, 
    Values = {
        "Raycast",
        "FindPartOnRay",
        "FindPartOnRayWithWhitelist",
        "FindPartOnRayWithIgnoreList",
        "Mouse.Hit/Target"
    }
}):OnChanged(function() 
    SilentAimSettings.SilentAimMethod = Options.Method.Value 
end)


Main:AddSlider("HitChance", {
    Text = "Hit Chance",
    Default = 100,
    Min = 0,
    Max = 100,
    Rounding = 1,
    Compact = false,
}):OnChanged(function()
    SilentAimSettings.HitChance = Options.HitChance.Value
end)


local FieldOfViewBOX = GeneralTab:AddLeftTabbox("Field Of View") do
    local Main = FieldOfViewBOX:AddTab("Visuals")
    

    Main:AddToggle("Visible", {Text = "Show FOV Circle"})
        :AddColorPicker("Color", {Default = Color3.fromRGB(54, 57, 241)})
        :OnChanged(function()
            fov_circle.Visible = Toggles.Visible.Value
            SilentAimSettings.FOVVisible = Toggles.Visible.Value
        end)


    Main:AddSlider("Radius", {
        Text = "FOV Circle Radius", 
        Min = 0, 
        Max = 360, 
        Default = 130, 
        Rounding = 0
    }):OnChanged(function()
        fov_circle.Radius = Options.Radius.Value
        SilentAimSettings.FOVRadius = Options.Radius.Value
    end)


    Main:AddToggle("MousePosition", {Text = "Show Silent Aim Target"})
        :AddColorPicker("MouseVisualizeColor", {Default = Color3.fromRGB(54, 57, 241)})
        :OnChanged(function()
            mouse_box.Visible = Toggles.MousePosition.Value 
            SilentAimSettings.ShowSilentAimTarget = Toggles.MousePosition.Value 
        end)
end


local MiscellaneousBOX = GeneralTab:AddLeftTabbox("Miscellaneous") do
    local PredictionTab = MiscellaneousBOX:AddTab("Prediction")
    

    PredictionTab:AddToggle("Prediction", {Text = "Mouse.Hit/Target Prediction"})
        :OnChanged(function()
            SilentAimSettings.MouseHitPrediction = Toggles.Prediction.Value
        end)
    

    PredictionTab:AddSlider("Amount", {
        Text = "Prediction Amount", 
        Min = 0.165, 
        Max = 1, 
        Default = 0.165, 
        Rounding = 3
    }):OnChanged(function()
        PredictionAmount = Options.Amount.Value
        SilentAimSettings.MouseHitPredictionAmount = Options.Amount.Value
    end)
end


resume(create(function()
    RenderStepped:Connect(function()
        if Toggles.MousePosition.Value and Toggles.aim_Enabled.Value then
            if getClosestPlayer() then 
                local Root = getClosestPlayer().Parent.PrimaryPart or getClosestPlayer()
                local RootToViewportPoint, IsOnScreen = WorldToViewportPoint(Camera, Root.Position);

                mouse_box.Visible = IsOnScreen
                mouse_box.Position = Vector2.new(RootToViewportPoint.X, RootToViewportPoint.Y)
            else 
                mouse_box.Visible = false 
                mouse_box.Position = Vector2.new()
            end
        end
        
        if Toggles.Visible.Value then 
            fov_circle.Visible = Toggles.Visible.Value
            fov_circle.Color = Options.Color.Value
            fov_circle.Position = getMousePosition()
        end
    end)
end))


local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(...)
    local Method = getnamecallmethod()
    local Arguments = {...}
    local self = Arguments[1]
    local chance = CalculateChance(SilentAimSettings.HitChance)
    if Toggles.aim_Enabled.Value and self == workspace and not checkcaller() and chance == true then
        if Method == "FindPartOnRayWithIgnoreList" and Options.Method.Value == Method then
            if ValidateArguments(Arguments, ExpectedArguments.FindPartOnRayWithIgnoreList) then
                local A_Ray = Arguments[2]

                local HitPart = getClosestPlayer()
                if HitPart then
                    local Origin = A_Ray.Origin
                    local Direction = getDirection(Origin, HitPart.Position)
                    Arguments[2] = Ray.new(Origin, Direction)

                    return oldNamecall(unpack(Arguments))
                end
            end
        elseif Method == "FindPartOnRayWithWhitelist" and Options.Method.Value == Method then
            if ValidateArguments(Arguments, ExpectedArguments.FindPartOnRayWithWhitelist) then
                local A_Ray = Arguments[2]

                local HitPart = getClosestPlayer()
                if HitPart then
                    local Origin = A_Ray.Origin
                    local Direction = getDirection(Origin, HitPart.Position)
                    Arguments[2] = Ray.new(Origin, Direction)

                    return oldNamecall(unpack(Arguments))
                end
            end
        elseif (Method == "FindPartOnRay" or Method == "findPartOnRay") and Options.Method.Value:lower() == Method:lower() then
            if ValidateArguments(Arguments, ExpectedArguments.FindPartOnRay) then
                local A_Ray = Arguments[2]

                local HitPart = getClosestPlayer()
                if HitPart then
                    local Origin = A_Ray.Origin
                    local Direction = getDirection(Origin, HitPart.Position)
                    Arguments[2] = Ray.new(Origin, Direction)

                    return oldNamecall(unpack(Arguments))
                end
            end
        elseif Method == "Raycast" and Options.Method.Value == Method then
            if ValidateArguments(Arguments, ExpectedArguments.Raycast) then
                local A_Origin = Arguments[2]

                local HitPart = getClosestPlayer()
                if HitPart then
                    Arguments[3] = getDirection(A_Origin, HitPart.Position)

                    return oldNamecall(unpack(Arguments))
                end
            end
        end
    end
    return oldNamecall(...)
end))

local oldIndex = nil 
oldIndex = hookmetamethod(game, "__index", newcclosure(function(self, Index)
    if self == Mouse and not checkcaller() and Toggles.aim_Enabled.Value and Options.Method.Value == "Mouse.Hit/Target" and getClosestPlayer() then
        local HitPart = getClosestPlayer()
         
        if Index == "Target" or Index == "target" then 
            return HitPart
        elseif Index == "Hit" or Index == "hit" then 
            return ((Toggles.Prediction.Value and (HitPart.CFrame + (HitPart.Velocity * PredictionAmount))) or (not Toggles.Prediction.Value and HitPart.CFrame))
        elseif Index == "X" or Index == "x" then 
            return self.X 
        elseif Index == "Y" or Index == "y" then 
            return self.Y 
        elseif Index == "UnitRay" then 
            return Ray.new(self.Origin, (self.Hit - self.Origin).Unit)
        end
    end

    return oldIndex(self, Index)
end))


local orbbox = GeneralTab:AddRightGroupbox("        Orbit AimLock")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()
local isLockedOn = false
local targetPlayer = nil
local lockEnabled = false
local aimLockEnabled = false
local bodyPartSelected = "Head"

local isOrbiting = false
local orbitDuration = 2 
local orbitDistance = 5 

local function getBodyPart(character, part)
    return character:FindFirstChild(part) and part or "Head"
end

local function getNearestPlayerToMouse()
    if not aimLockEnabled then return nil end
    local nearestPlayer = nil
    local shortestDistance = math.huge
    local mousePosition = Camera:ViewportPointToRay(Mouse.X, Mouse.Y).Origin

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild(bodyPartSelected) then
            local part = player.Character[bodyPartSelected]
            local screenPosition, onScreen = Camera:WorldToViewportPoint(part.Position)
            if onScreen then
                local distance = (Vector2.new(screenPosition.X, screenPosition.Y) - Vector2.new(Mouse.X, Mouse.Y)).Magnitude
                if distance < shortestDistance then
                    nearestPlayer = player
                    shortestDistance = distance
                end
            end
        end
    end
    return nearestPlayer
end

local function orbitCharacter(target, duration)
    if not target or not target.Character then return end

    isOrbiting = true
    local humanoidRootPart = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local targetPart = target.Character:FindFirstChild("HumanoidRootPart")

    if humanoidRootPart and targetPart then
        humanoidRootPart.CanCollide = false

        local startTime = tick()
        RunService.RenderStepped:Connect(function()
            if tick() - startTime > duration then
                humanoidRootPart.CanCollide = true
                isOrbiting = false
                isLockedOn = false
                return
            end

            local angle = (tick() - startTime) * math.pi * 2 * 5 
            local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * orbitDistance
            humanoidRootPart.CFrame = CFrame.new(targetPart.Position + offset)
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, targetPart.Position)
        end)
    end
end

local function toggleLockOnPlayer()
    if not lockEnabled or not aimLockEnabled then return end

    if isLockedOn then
        isLockedOn = false
        targetPlayer = nil
    else
        targetPlayer = getNearestPlayerToMouse()
        if targetPlayer and targetPlayer.Character then
            local part = getBodyPart(targetPlayer.Character, bodyPartSelected)
            if targetPlayer.Character:FindFirstChild(part) then
                isLockedOn = true
                orbitCharacter(targetPlayer, orbitDuration)
            end
        end
    end
end

RunService.RenderStepped:Connect(function()
    if aimLockEnabled and lockEnabled and isLockedOn and targetPlayer and targetPlayer.Character then
        local partName = getBodyPart(targetPlayer.Character, bodyPartSelected)
        local part = targetPlayer.Character:FindFirstChild(partName)

        if part and targetPlayer.Character:FindFirstChildOfClass("Humanoid").Health > 0 then
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, part.Position)
        else
            isLockedOn = false
            targetPlayer = nil
        end
    end
end)


orbbox:AddToggle("orbitAimLock_Enabled", {
    Text = "Enable/Disable Orbit AimLock",
    Default = false,
    Tooltip = "Toggle the Orbit AimLock feature on or off.",
    Callback = function(value)
        aimLockEnabled = value 
        if not aimLockEnabled then
            lockEnabled = false
            isLockedOn = false
            targetPlayer = nil
        end
    end,
})

orbbox:AddToggle("orbitEnabled", {
    Text = "Orbit Keybind",
    Default = false,
    Tooltip = "Toggle the Orbit feature on or off.",
    Callback = function(value)
        lockEnabled = value 
        if not lockEnabled then
            isLockedOn = false
            targetPlayer = nil
        end
    end,
}):AddKeyPicker("orbitEnabled_KeyPicker", {
    Default = "Z",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "Orbit Key",
    Tooltip = "Key to toggle Orbit AimLock.",
    Callback = function()
        toggleLockOnPlayer()
    end,
})

orbbox:AddSlider("Orbit_timer", {
    Text = "Orbit Interval (sec)",
    Default = 2,
    Min = 0.5,
    Max = 30,
    Rounding = 1,
    Tooltip = "the amount of seconds you will orbit around",
    Callback = function(value)
        orbitDuration = value
    end,
})

orbbox:AddSlider("Orbit_studs", {
    Text = "Orbit distance",
    Default = 5,
    Min = 1,
    Max = 50,
    Rounding = 1,
    Tooltip = "the distance of the orbit",
    Callback = function(value)
        orbitDistance = value
    end,
})

orbbox:AddDropdown("orbitBodyParts", {
    Values = {"Head", "UpperTorso", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg", "LeftUpperArm"},
    Default = "Head",
    Multi = false,
    Text = "target Body Part",
    Tooltip = "Select which body part to orbit around.",
    Callback = function(value)
        bodyPartSelected = value 
    end,
})


local frabox = GeneralTab:AddLeftGroupbox("        Movement")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera

local BOXEnabled = false
local espBoxes = {}


local function createESPBox(color)
    local box = Drawing.new("Square")
    box.Color = color
    box.Thickness = 1
    box.Filled = false
    box.Visible = false
    return box
end


local function updateESPBoxes()
    if BOXEnabled then
        for player, box in pairs(espBoxes) do
            if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                local rootPart = player.Character.HumanoidRootPart
                local screenPosition, onScreen = Camera:WorldToViewportPoint(rootPart.Position)

                if onScreen then
                    local distance = screenPosition.Z
                    local scaleFactor = 70 / distance 
                    local boxWidth = 30 * scaleFactor 
                    local boxHeight = 50 * scaleFactor 

                    local boxX = screenPosition.X - boxWidth / 2
                    local boxY = screenPosition.Y - boxHeight / 2

                    box.Size = Vector2.new(boxWidth, boxHeight)
                    box.Position = Vector2.new(boxX, boxY)
                    box.Visible = true
                else
                    box.Visible = false
                end
            else
                box.Visible = false
            end
        end
    end
end


local function addESP(player)
    if player ~= Players.LocalPlayer then
        local box = createESPBox(Color3.fromRGB(255, 255, 255)) 
        espBoxes[player] = box

        player.CharacterAdded:Connect(function()
            espBoxes[player] = box
        end)
    end
end


local function removeESP(player)
    if espBoxes[player] then
        espBoxes[player].Visible = false  
        espBoxes[player] = nil
    end
end


Players.PlayerAdded:Connect(addESP)
Players.PlayerRemoving:Connect(removeESP)


for _, player in pairs(Players:GetPlayers()) do
    addESP(player)
end


RunService.RenderStepped:Connect(updateESPBoxes)



local Players = game:GetService("Players") 
local RunService = game:GetService("RunService") 
local Camera = workspace.CurrentCamera 
local LocalPlayer = Players.LocalPlayer 

local healthBars = {}
local Settings = { HealthBar = false } 


local function createSquare(color, size, outlineColor)
    local square = Drawing.new("Square")
    square.Visible = false
    square.Center = true
    square.Outline = true
    square.OutlineColor = outlineColor or Color3.fromRGB(0, 0, 0)
    square.Size = size or Vector2.new(4, 40)
    square.Color = color or Color3.fromRGB(0, 255, 0)
    return square
end

local espbox = GeneralTab:AddLeftGroupbox("esp")

local function updateHealthBars()
    local cameraCFrame = Camera.CFrame
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local healthBar = healthBars[player]
            if not healthBar then
                healthBar = createSquare(Color3.fromRGB(0, 255, 0), Vector2.new(4, 40), Color3.fromRGB(0, 0, 0))
                healthBars[player] = healthBar
            end

            local character = player.Character
            if Settings.HealthBar and character and character:FindFirstChild("Humanoid") and character:FindFirstChild("HumanoidRootPart") then
                local humanoid = character.Humanoid
                local humanoidRootPart = character.HumanoidRootPart

                if humanoid.Health > 0 then
                    local pos, visible = Camera:WorldToViewportPoint(humanoidRootPart.Position + Vector3.new(2.5, 0, 0))
                    if visible then
                        local healthPercent = humanoid.Health / humanoid.MaxHealth
                        local distance = (cameraCFrame.Position - humanoidRootPart.Position).Magnitude
                        local scale = math.clamp(1 / (distance * 0.02), 0.5, 2.5)

                        local healthBarSize = Vector2.new(4 * scale, 40 * scale * healthPercent)
                        healthBar.Visible = true
                        healthBar.Position = Vector2.new(pos.X, pos.Y) - Vector2.new(0, healthBarSize.Y / 2)

                        if healthPercent > 0.5 then
                            healthBar.Color = Color3.fromRGB((1 - healthPercent) * 510, 255, 0)
                        else
                            healthBar.Color = Color3.fromRGB(255, healthPercent * 510, 0)
                        end

                        healthBar.Size = healthBarSize
                    else
                        healthBar.Visible = false
                    end
                else
                    healthBar.Visible = false
                end
            else
                healthBar.Visible = false
            end
        end
    end
end


Players.PlayerAdded:Connect(function(player)
    healthBars[player] = createSquare(Color3.fromRGB(0, 255, 0), Vector2.new(4, 40), Color3.fromRGB(0, 0, 0))
end)


Players.PlayerRemoving:Connect(function(player)
    local healthBar = healthBars[player]
    if healthBar then
        healthBar.Visible = false
        healthBar:Remove()
        healthBars[player] = nil
    end
end)


RunService.RenderStepped:Connect(updateHealthBars)


local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera

local TRAEnabled = false
local espTracers = {}

local function createTracer(color)
    local tracer = Drawing.new("Line")
    tracer.Color = color
    tracer.Thickness = 2
    tracer.Visible = false
    return tracer
end

local function smoothInterpolation(from, to, factor)
    return from + (to - from) * factor
end


local function updateTracers()
    if TRAEnabled then
        for player, tracer in pairs(espTracers) do
            if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                local rootPart = player.Character.HumanoidRootPart
                local screenPosition, onScreen = Camera:WorldToViewportPoint(rootPart.Position)

                if onScreen then

                    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
                    local targetPosition = Vector2.new(screenPosition.X, screenPosition.Y)
                    tracer.From = smoothInterpolation(tracer.From, screenCenter, 0.1)
                    tracer.To = smoothInterpolation(tracer.To, targetPosition, 0.1)

                    tracer.Visible = true
                else
                    tracer.Visible = false
                end
            else
                tracer.Visible = false
            end
        end
    end
end


local function addTracer(player)
    if player ~= Players.LocalPlayer then
        local tracer = createTracer(Color3.fromRGB(255, 255, 255)) 
        espTracers[player] = tracer

        player.CharacterAdded:Connect(function()
            espTracers[player] = tracer
        end)
    end
end


local function removeTracer(player)
    if espTracers[player] then
        espTracers[player].Visible = false
        espTracers[player] = nil
    end
end


Players.PlayerAdded:Connect(addTracer)
Players.PlayerRemoving:Connect(removeTracer)


for _, player in pairs(Players:GetPlayers()) do
    addTracer(player)
end


RunService.RenderStepped:Connect(updateTracers)


espbox:AddToggle("EnableTracer", {
    Text = "Enable Tracers",
    Default = false,
    Callback = function(state)
        TRAEnabled = state

        if not TRAEnabled then
            for _, tracer in pairs(espTracers) do
                tracer.Visible = false
            end
        end
    end,
})

espbox:AddToggle("Healthbar", {
    Text = "Health Bar",
    Default = false,
    Tooltip = "Toggle health bars for players",
    Callback = function(Value)
        Settings.HealthBar = Value
    end
})

espbox:AddToggle("EnableESP", {
    Text = "Box ESP",
    Default = false,
    Callback = function(state)
        BOXEnabled = state
        if not BOXEnabled then
            for _, box in pairs(espBoxes) do
                box.Visible = false
            end
        end
    end,
})


local localPlayer = game:GetService("Players").LocalPlayer
local Cmultiplier = 1  
local isSpeedActive = false
local isFunctionalityEnabled = false


frabox:AddToggle("functionalityEnabled", {
    Text = "Enable/Disable CFrame Speed",
    Default = false,
    Tooltip = "Enable or disable the speed thingy.",
    Callback = function(value)
        isFunctionalityEnabled = value
    end
})


frabox:AddToggle("speedEnabled", {
    Text = "Speed Toggle",
    Default = false,
    Tooltip = "It makes you go fast.",
    Callback = function(value)
        isSpeedActive = value
    end
}):AddKeyPicker("speedToggleKey", {
    Default = "C",  
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "Speed KeyBind",
    Tooltip = "CFrame keybind.",
    Callback = function(value)
        isSpeedActive = value
    end
})


frabox:AddSlider("cframespeed", {
    Text = "CFrame Multiplier",
    Default = 1,
    Min = 1,
    Max = 20,
    Rounding = 1,
    Tooltip = "The CFrame speed.",
    Callback = function(value)
        Cmultiplier = value
    end,
})


while true do
    task.wait()

    if isFunctionalityEnabled then
        if localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local humanoid = localPlayer.Character:FindFirstChild("Humanoid")

            if isSpeedActive and humanoid and humanoid.MoveDirection.Magnitude > 0 then
                local moveDirection = humanoid.MoveDirection.Unit
                localPlayer.Character.HumanoidRootPart.CFrame = localPlayer.Character.HumanoidRootPart.CFrame + moveDirection * Cmultiplier
            end
        end
    end
end


ThemeManager:LoadDefaultTheme()
