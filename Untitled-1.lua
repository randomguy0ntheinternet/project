--[[
	***********************************************************
	 * VARIABLES
	 * Description: Variables referenced globally in the script
	 * Last updated: Feb. 23, 2025
	***********************************************************
]]
-- Services
local OrionLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/randomguy0ntheinternet/orion/refs/heads/main/Orion.lua"))()
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local StarterGui = game:GetService("StarterGui")
local Stats = game:GetService("Stats")

-- Constants
local MAX_HISTORY = 100
local GC_INTERVAL = 30 -- seconds
local CACHE_REFRESH_INTERVAL = 1/60

-- Player References
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local Camera = workspace.CurrentCamera

--[[
	***********************************************************
	 * CONFIGURATIONS
	 * Description: User-defined settings and configurations
	 * Last updated: Feb. 23, 2025
	***********************************************************
]]
local Config = {
    ESP = {
        Enabled = true,
        ShowDistance = false,
        ShowHealth = false,
        ShowTeam = false,
        BoxESP = true,
        TracerESP = false,
        TeamCheck = true
    },
    Aimbot = {
        Enabled = true,
        Key = Enum.UserInputType.MouseButton2,
        FOV = 120,
        Smoothness = 0.5,
        TargetPart = "Head",
        ShowFOVCircle = true,
        FOVCircleColor = Color3.new(1, 1, 1),
        FOVCircleThickness = 1,
        TeamCheck = true,
        WallCheck = true 
    }
}

--[[
	***********************************************************
	 * Performance Monitoring System
	 * Description: Tracks and displays performance metrics
	 * Last updated: Feb. 23, 2025
	***********************************************************
]]
local PerformanceStats = {
    espCount = 0,
    gridCells = 0,
    frameTime = 0,
    espUpdateTime = 0,
    gridUpdateTime = 0,
    luaMemory = 0,
    totalMemory = 0,
    history = {}
}

-- GUI Setup
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PerformanceMonitor"
screenGui.ResetOnSpawn = false

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 200, 0, 170)
frame.Position = UDim2.new(0, 10, 0, 10)
frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
frame.BackgroundTransparency = 0.5
frame.Parent = screenGui

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 5)
layout.Parent = frame

-- Performance Monitoring Labels
local labels = {}
local statNames = {
    "ESP Objects",
    "Grid Cells",
    "Frame Time (ms)",
    "ESP Update Time (ms)",
    "Grid Update Time (ms)",
    "Lua Memory (MB)",
    "Total Memory (MB)"
}

-- Function to get memory usage in MB
local function getLuaMemoryUsage()
    return math.floor((collectgarbage("count") / 1024) * 100) / 100  -- Convert KB to MB with 2 decimal places
end

-- Function to get total client memory usage in MB
local function getTotalMemoryUsage()
    return math.floor(Stats:GetTotalMemoryUsageMb() * 100) / 100  -- Round to 2 decimal places
end

for _, name in ipairs(statNames) do
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -10, 0, 20)
    label.Position = UDim2.new(0, 5, 0, 5)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = name .. ": 0"
    label.Parent = frame
    labels[name] = label
end

-- Function to update history
local historyIndex = 1
local function updateHistory()
    -- Reuse existing table slots instead of creating new ones
    PerformanceStats.history[historyIndex] = {
        frameTime = PerformanceStats.frameTime,
        espUpdateTime = PerformanceStats.espUpdateTime,
        gridUpdateTime = PerformanceStats.gridUpdateTime,
        espCount = PerformanceStats.espCount,
        gridCells = PerformanceStats.gridCells,
        luaMemory = PerformanceStats.luaMemory,
        totalMemory = PerformanceStats.totalMemory
    }
    historyIndex = (historyIndex % MAX_HISTORY) + 1
end

-- Pre-allocate history table
PerformanceStats.history = table.create(MAX_HISTORY)

-- Function to update GUI
local function updateGui()
    -- Update existing stats
    labels["ESP Objects"].Text = string.format("ESP Objects: %d", PerformanceStats.espCount)
    labels["Grid Cells"].Text = string.format("Grid Cells: %d", PerformanceStats.gridCells)
    labels["Frame Time (ms)"].Text = string.format("Frame Time: %.2fms", PerformanceStats.frameTime * 1000)
    labels["ESP Update Time (ms)"].Text = string.format("ESP Update: %.2fms", PerformanceStats.espUpdateTime * 1000)
    labels["Grid Update Time (ms)"].Text = string.format("Grid Update: %.2fms", PerformanceStats.gridUpdateTime * 1000)
    
    -- Update memory metrics
    PerformanceStats.luaMemory = getLuaMemoryUsage()
    PerformanceStats.totalMemory = getTotalMemoryUsage()
    
    labels["Lua Memory (MB)"].Text = string.format("Lua Memory: %.2f MB", PerformanceStats.luaMemory)
    labels["Total Memory (MB)"].Text = string.format("Total Memory: %.2f MB", PerformanceStats.totalMemory)
    
    -- Update history
    updateHistory()
end

--[[
	***********************************************************
	 * Mouse Position System
	 * Description: Handles caching and updating of mouse position
	 * Last updated: Feb. 23, 2025
	***********************************************************
]]
local cachedMousePosition = nil
local lastUpdateTime = 0

local function getMousePosition()
    local currentTime = tick()
    if cachedMousePosition and (currentTime - lastUpdateTime) < CACHE_REFRESH_INTERVAL then
        return cachedMousePosition
    end
    
    local mousePos = UserInputService:GetMouseLocation()
    cachedMousePosition = Vector2.new(mousePos.X, mousePos.Y)
    lastUpdateTime = currentTime
    return cachedMousePosition
end

local function clearMousePositionCache()
    cachedMousePosition = nil
    lastUpdateTime = 0
end

--[[
	***********************************************************
	 * FOV Circle System
	 * Description: Handles updating and visibility of the FOV circle
	 * Last updated: Feb. 23, 2025
	***********************************************************
]]
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = Config.Aimbot.FOVCircleThickness
FOVCircle.Color = Config.Aimbot.FOVCircleColor
FOVCircle.Filled = false
FOVCircle.Transparency = 1
FOVCircle.NumSides = 60

local function updateFOVCircle()
    if Config.Aimbot.Enabled and Config.Aimbot.ShowFOVCircle then
        FOVCircle.Visible = true
        FOVCircle.Radius = Config.Aimbot.FOV
        FOVCircle.Position = getMousePosition()
    else
        FOVCircle.Visible = false
    end
end

--[[
	***********************************************************
	 * Utility Functions
	 * Description: Miscellaneous utility functions
	 * Last updated: Feb. 23, 2025
	***********************************************************
]]
local function isTargetVisible(targetPart)
    local origin = Camera.CFrame.Position
    local direction = (targetPart.Position - origin).Unit
    local distance = (targetPart.Position - origin).Magnitude
    
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {LocalPlayer.Character}
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    
    local result = workspace:Raycast(origin, direction * distance, rayParams)
    return not result or result.Instance:IsDescendantOf(targetPart.Parent)
end

local function getPlayerTeamColor(player)
    return player.Team and player.TeamColor.Color or Color3.new(1, 1, 1)
end

local function isPlayerAlive(player)
    local character = player.Character
    local humanoid = character and character:FindFirstChild("Humanoid")
    return humanoid and humanoid.Health > 0
end

local function isEnemy(player)
    if player == LocalPlayer then return false end
    return not Config.Aimbot.TeamCheck or player.Team ~= LocalPlayer.Team
end

--[[
	***********************************************************
	 * ESP System
	 * Description: Handles creation and management of ESP objects
	 * Last updated: Feb. 23, 2025
	***********************************************************
]]
local espObjects = {}

local function createESP(player)
    local esp = Drawing.new("Text")
    esp.Visible = false
    esp.Center = true
    esp.Outline = true
    esp.Font = 2
    esp.Size = 13
    esp.Color = getPlayerTeamColor(player)

    local box = Drawing.new("Square")
    box.Visible = false
    box.Color = esp.Color
    box.Thickness = 1
    box.Filled = false

    local tracer = Drawing.new("Line")
    tracer.Visible = false
    tracer.Color = esp.Color
    tracer.Thickness = 1

    return {
        Text = esp,
        Box = box,
        Tracer = tracer
    }
end

-- Function to clean up ESP for a specific player
local function cleanupPlayerESP(player)
    local esp = espObjects[player]
    if esp then
        for _, object in pairs(esp) do
            pcall(function() 
                if object.Remove then object:Remove() end 
            end)
        end
        espObjects[player] = nil
    end
end

-- Function to handle team changes
local function handleTeamChange(player)
    cleanupPlayerESP(player)
    -- Only recreate ESP if the player is not on LocalPlayer's team
    if player ~= LocalPlayer and player.Team ~= LocalPlayer.Team then
        espObjects[player] = createESP(player)
    end
end

-- Connect to team change events
Players.PlayerAdded:Connect(function(player)
    player:GetPropertyChangedSignal("Team"):Connect(function()
        handleTeamChange(player)
    end)
end)

-- Handle existing players
for _, player in pairs(Players:GetPlayers()) do
    player:GetPropertyChangedSignal("Team"):Connect(function()
        handleTeamChange(player)
    end)
end

-- Handle player removal
Players.PlayerRemoving:Connect(cleanupPlayerESP)

-- Handle character removal/respawning
Players.PlayerAdded:Connect(function(player)
    player.CharacterRemoving:Connect(function(character)
        cleanupPlayerESP(player)
    end)
end)

-- Handle existing players' characters
for _, player in ipairs(Players:GetPlayers()) do
    player.CharacterRemoving:Connect(function(character)
        cleanupPlayerESP(player)
    end)
end

-- Add comprehensive cleanup
local function fullCleanupESP()
    for player in pairs(espObjects) do
        cleanupPlayerESP(player)
    end
    table.clear(espObjects)
end

-- Call cleanup when the script is destroyed
game.Players.LocalPlayer.Destroying:Connect(fullCleanupESP)

-- Function to update ESP elements
local function updateESP()
    --[[
    Function: updateESP
    Description: Updates ESP visuals for players, including text labels, boxes, and tracers.
    Handles player visibility, team-based filtering, and real-time position updates while managing cleanup of
    disconnected players.

    Parameters: None
    Returns: None
    --]]

	local espStart = tick()
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            -- Check if ESP should exist for this player based on team check settings
            local shouldHaveESP = not Config.ESP.TeamCheck or (Config.ESP.TeamCheck and player.Team ~= LocalPlayer.Team)
            local hasESP = espObjects[player] ~= nil

            -- Clean up ESP if player shouldn't have it
            if not shouldHaveESP and hasESP then
                cleanupPlayerESP(player)
            end
            -- Create ESP if player should have it but doesn't
            if shouldHaveESP and not hasESP then
                espObjects[player] = createESP(player)
            end

            -- Update existing ESP
            if shouldHaveESP then
                local esp = espObjects[player]
                local character = player.Character
                if character and isPlayerAlive(player) then
                    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
                    local humanoid = character:FindFirstChild("Humanoid")
                    local head = character:FindFirstChild("Head")

                    if humanoidRootPart and humanoid and head then
                        local vector, onScreen = Camera:WorldToViewportPoint(humanoidRootPart.Position)
                        local distance = (humanoidRootPart.Position - Camera.CFrame.Position).Magnitude

                        if onScreen and Config.ESP.Enabled then
                            -- Update Text ESP
                            esp.Text.Position = Vector2.new(vector.X, vector.Y - 40)
                            esp.Text.Visible = true
                            esp.Text.Color = getPlayerTeamColor(player)

                            -- Build ESP text information
                            local text = player.Name
                            if Config.ESP.ShowDistance then
                                text = text .. string.format("\n%.1fm", distance)
                            end
                            if Config.ESP.ShowHealth then
                                text = text .. string.format("\nHP: %.0f", humanoid.Health)
                            end
                            if Config.ESP.ShowTeam then
                                text = text .. string.format("\nTeam: %s", player.Team and player.Team.Name or "None")
                            end
                            esp.Text.Text = text

                            -- Update Box ESP
                            if Config.ESP.BoxESP then
                                local topLeft = Camera:WorldToViewportPoint((humanoidRootPart.CFrame * CFrame.new(-3, 3, 0)).Position)
                                local bottomRight = Camera:WorldToViewportPoint((humanoidRootPart.CFrame * CFrame.new(3, -3, 0)).Position)
                                
                                esp.Box.Visible = true
                                esp.Box.Size = Vector2.new(bottomRight.X - topLeft.X, bottomRight.Y - topLeft.Y)
                                esp.Box.Position = Vector2.new(topLeft.X, topLeft.Y)
                                esp.Box.Color = esp.Text.Color
                            else
                                esp.Box.Visible = false
                            end

                            -- Update Tracer ESP
                            if Config.ESP.TracerESP then
                                esp.Tracer.Visible = true
                                esp.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                                esp.Tracer.To = Vector2.new(vector.X, vector.Y)
                                esp.Tracer.Color = esp.Text.Color
                            else
                                esp.Tracer.Visible = false
                            end
                        else
                            -- Hide ESP elements when not on screen
                            esp.Text.Visible = false
                            esp.Box.Visible = false
                            esp.Tracer.Visible = false
                        end
                    else
                        -- Hide ESP elements when required parts are missing
                        esp.Text.Visible = false
                        esp.Box.Visible = false
                        esp.Tracer.Visible = false
                    end
                else
                    -- Hide ESP elements when character is not valid or player is dead
                    esp.Text.Visible = false
                    esp.Box.Visible = false
                    esp.Tracer.Visible = false
                end
            end
        end
    end
    PerformanceStats.espUpdateTime = tick() - espStart
    PerformanceStats.espCount = 0
    for _ in pairs(espObjects) do
        PerformanceStats.espCount = PerformanceStats.espCount + 1
    end
end

--[[
	***********************************************************
	 * View Matrix System
	 * Description: Functions for calculating and smoothing aim direction
	 * Last updated: Feb. 23, 2025
	***********************************************************
]]
local ViewMatrix = {}

function ViewMatrix.calculateAimDirection(fromPos, targetPos)
    return (targetPos - fromPos).Unit
end

function ViewMatrix.smoothAim(currentCFrame, targetPos, smoothness)
    local targetDirection = ViewMatrix.calculateAimDirection(currentCFrame.Position, targetPos)
    local targetCFrame = CFrame.new(currentCFrame.Position, targetPos)
    return currentCFrame:Lerp(targetCFrame, smoothness)
end

--[[
	***********************************************************
	 * Spatial Hash Grid System
	 * Description: Functions for creating and updating a spatial hash grid
	 * Last updated: Feb. 23, 2025
	***********************************************************
]]
local SpatialHashGrid = {}
SpatialHashGrid.__index = SpatialHashGrid

function SpatialHashGrid.new(cellSize)
    return setmetatable({
        cellSize = cellSize,
        grid = {},
        playerCells = {}
    }, SpatialHashGrid)
end

function SpatialHashGrid:getCell(position)
    local x = math.floor(position.X / self.cellSize)
    local y = math.floor(position.Y / self.cellSize)
    local z = math.floor(position.Z / self.cellSize)
    return string.format("%d:%d:%d", x, y, z)
end

function SpatialHashGrid:insert(player, position)
    local cell = self:getCell(position)
    
    -- Remove from old cells first
    self:removePlayer(player)
    
    -- Insert into new cell
    if not self.grid[cell] then
        self.grid[cell] = {}
    end
    self.grid[cell][player] = true
    
    -- Track this cell for the player
    if not self.playerCells[player] then
        self.playerCells[player] = {}
    end
    self.playerCells[player][cell] = true
end

function SpatialHashGrid:removePlayer(player)
    if self.playerCells[player] then
        for cell in pairs(self.playerCells[player]) do
            if self.grid[cell] then
                self.grid[cell][player] = nil
            end
        end
        self.playerCells[player] = {}
    end
end

function SpatialHashGrid:queryRange(position, range)
    local results = {}
    local minCell = self:getCell(Vector3.new(
        position.X - range,
        position.Y - range,
        position.Z - range
    ))
    local maxCell = self:getCell(Vector3.new(
        position.X + range,
        position.Y + range,
        position.Z + range
    ))
    
    -- Parse cell coordinates
    local minX, minY, minZ = minCell:match("(-?%d+):(-?%d+):(-?%d+)")
    local maxX, maxY, maxZ = maxCell:match("(-?%d+):(-?%d+):(-?%d+)")
    minX, minY, minZ = tonumber(minX), tonumber(minY), tonumber(minZ)
    maxX, maxY, maxZ = tonumber(maxX), tonumber(maxY), tonumber(maxZ)
    
    -- Query cells in range
    for x = minX, maxX do
        for y = minY, maxY do
            for z = minZ, maxZ do
                local cell = string.format("%d:%d:%d", x, y, z)
                if self.grid[cell] then
                    for player in pairs(self.grid[cell]) do
                        results[player] = true
                    end
                end
            end
        end
    end
    
    return results
end

local spatialGrid = SpatialHashGrid.new(50) -- 50 studs cell size

function SpatialHashGrid:cleanupEmptyCells()
    local cellsToRemove = {}
    
    -- Find empty cells
    for cell, players in pairs(self.grid) do
        local isEmpty = true
        for _ in pairs(players) do
            isEmpty = false
            break
        end
        if isEmpty then
            table.insert(cellsToRemove, cell)
        end
    end
    
    -- Remove empty cells
    for _, cell in ipairs(cellsToRemove) do
        self.grid[cell] = nil
    end
end

local function updateSpatialGrid()
    local gridStart = tick()
    
    -- Clear grid before updating
    spatialGrid.grid = {}
    
    -- Update positions
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
            if rootPart then
                spatialGrid:insert(player, rootPart.Position)
            end
        end
    end
    
    -- Cleanup empty cells
    spatialGrid:cleanupEmptyCells()

    PerformanceStats.gridUpdateTime = tick() - gridStart
    PerformanceStats.gridCells = 0
    for _ in pairs(spatialGrid.grid) do
        PerformanceStats.gridCells = PerformanceStats.gridCells + 1
    end
end

function SpatialHashGrid:fullCleanup()
    -- Clear existing references
    for player in pairs(self.playerCells) do
        if not Players:FindFirstChild(player.Name) then
            self:removePlayer(player)
            self.playerCells[player] = nil
        end
    end
    
    -- Remove empty cells
    for cell, players in pairs(self.grid) do
        local hasPlayers = false
        for _ in pairs(players) do
            hasPlayers = true
            break
        end
        if not hasPlayers then
            self.grid[cell] = nil
        end
    end
end

--[[
	***********************************************************
	 * Aimbot System
	 * Description: Functions for handling aimbot targeting
	 * Last updated: Feb. 23, 2025
	***********************************************************
]]
local function getAimbotTarget()
    --[[
    Function: getAimbotTarget
    Description: Gets the nearest valid target within FOV and visibility constraints,
    considering team status and wall penetration settings. Returns the target's aim point or null
    if no valid target found.
    
    Parameters: None    
    Returns: Player or nil - The closest valid target for the aimbot, or nil if no valid target is found.
    --]]
    -- Check if aimbot is enabled
    if not Config.Aimbot.Enabled then return nil end
    
    local mousePos = UserInputService:GetMouseLocation()
    local closestDistance = math.huge
    local closestTarget = nil
    
    -- Get camera position for distance calculations
    local cameraPos = Camera.CFrame.Position
    
    -- Query spatial grid for potential targets
    local potentialTargets = spatialGrid:queryRange(cameraPos, Config.Aimbot.FOV * 2)
    
    -- Find closest valid target
    for player in pairs(potentialTargets) do
        if isEnemy(player) then
            local character = player.Character
            if character and isPlayerAlive(player) then
        local targetPart = character:FindFirstChild(Config.Aimbot.TargetPart)
        if targetPart then
            local vector, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
            if onScreen then
                        -- Check if within FOV
                local screenDistance = (Vector2.new(mousePos.X, mousePos.Y) - Vector2.new(vector.X, vector.Y)).Magnitude
                if screenDistance <= Config.Aimbot.FOV then
                            -- Wall check
                    if not Config.Aimbot.WallCheck or isTargetVisible(targetPart) then
                        if screenDistance < closestDistance then
                            closestDistance = screenDistance
                            closestTarget = targetPart
                        end
                    end
                end
            end
        end
    end
        end
    end
    
    return closestTarget
end

-- Update spatial grid regularly
RunService.Heartbeat:Connect(updateSpatialGrid)

local function Aimbot()
    local target = getAimbotTarget()
    if not target then return end
    
    local currentCFrame = Camera.CFrame
    local targetPos = target.Position
    
    -- Calculate smooth aim transition
    local newCFrame = ViewMatrix.smoothAim(
        currentCFrame,
        targetPos,
        Config.Aimbot.Smoothness
    )
    
    -- Update camera CFrame
    Camera.CFrame = newCFrame
end

--[[
	***********************************************************
	 * GUI Setup
	 * Description: Sets up the user interface
	 * Last updated: Feb. 23, 2025
	***********************************************************
]]
local Window = OrionLib:MakeWindow({
    Name = "Window",
    HidePremium = false,
    SaveConfig = true,
    ConfigFolder = "New Folder"
})

local ESPTab = Window:MakeTab({
    Name = "ESP",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

local AimbotTab = Window:MakeTab({
    Name = "Aimbot",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

-- ESP Settings
ESPTab:AddToggle({
    Name = "Enable ESP",
    Default = Config.ESP.Enabled,
    Callback = function(Value)
        Config.ESP.Enabled = Value
    end    
})

ESPTab:AddToggle({
    Name = "Team Check",
    Default = Config.ESP.TeamCheck,
    Callback = function(Value)
        Config.ESP.TeamCheck = Value
    end    
})

ESPTab:AddToggle({
    Name = "Show Distance",
    Default = Config.ESP.ShowDistance,
    Callback = function(Value)
        Config.ESP.ShowDistance = Value
    end    
})

ESPTab:AddToggle({
    Name = "Show Health",
    Default = Config.ESP.ShowHealth,
    Callback = function(Value)
        Config.ESP.ShowHealth = Value
    end    
})

ESPTab:AddToggle({
    Name = "Box ESP",
    Default = Config.ESP.BoxESP,
    Callback = function(Value)
        Config.ESP.BoxESP = Value
    end    
})

ESPTab:AddToggle({
    Name = "Tracer ESP",
    Default = Config.ESP.TracerESP,
    Callback = function(Value)
        Config.ESP.TracerESP = Value
    end    
})

-- Aimbot Settings
AimbotTab:AddToggle({
    Name = "Enable Aimbot",
    Default = Config.Aimbot.Enabled,
    Callback = function(Value)
        Config.Aimbot.Enabled = Value
    end    
})

AimbotTab:AddToggle({
    Name = "Team Check",
    Default = Config.Aimbot.TeamCheck,
    Callback = function(Value)
        Config.Aimbot.TeamCheck = Value
    end    
})

AimbotTab:AddToggle({
    Name = "Wall Check",
    Default = Config.Aimbot.WallCheck,
    Callback = function(Value)
        Config.Aimbot.WallCheck = Value
    end    
})

AimbotTab:AddSlider({
    Name = "FOV",
    Min = 0,
    Max = 1000,
    Default = Config.Aimbot.FOV,
    Color = Color3.fromRGB(255,255,255),
    Increment = 10,
    ValueName = "pixels",
    Callback = function(Value)
        Config.Aimbot.FOV = Value
    end    
})

AimbotTab:AddSlider({
    Name = "Smoothness",
    Min = 0,
    Max = 1,
    Default = Config.Aimbot.Smoothness,
    Color = Color3.fromRGB(255,255,255),
    Increment = 0.01,
    ValueName = "factor",
    Callback = function(Value)
        Config.Aimbot.Smoothness = Value
    end    
})

AimbotTab:AddDropdown({
    Name = "Target Part",
    Default = Config.Aimbot.TargetPart,
    Options = {"Head", "HumanoidRootPart"},
    Callback = function(Value)
        Config.Aimbot.TargetPart = Value
    end    
})

AimbotTab:AddToggle({
    Name = "Show FOV Circle",
    Default = Config.Aimbot.ShowFOVCircle,
    Callback = function(Value)
        Config.Aimbot.ShowFOVCircle = Value
    end    
})

AimbotTab:AddColorpicker({
    Name = "FOV Circle Color",
    Default = Config.Aimbot.FOVCircleColor,
    Callback = function(Value)
        Config.Aimbot.FOVCircleColor = Value
        FOVCircle.Color = Value
    end  
})

AimbotTab:AddSlider({
    Name = "FOV Circle Thickness",
    Min = 1,
    Max = 5,
    Default = Config.Aimbot.FOVCircleThickness,
    Color = Color3.fromRGB(255,255,255),
    Increment = 0.5,
    ValueName = "pixels",
    Callback = function(Value)
        Config.Aimbot.FOVCircleThickness = Value
        FOVCircle.Thickness = Value
    end    
})

--[[
	***********************************************************
	 * Cleanup
	 * Description: Functions for periodic cleanup
	 * Last updated: Feb. 23, 2025
	***********************************************************
]]

-- Function to peridiocally cleanup
local function setupPeriodicCleanup()
    local CLEANUP_INTERVAL = 30 -- Seconds
    
    game:GetService("RunService").Heartbeat:Connect(function()
        if tick() % CLEANUP_INTERVAL < 1/60 then
            spatialGrid:fullCleanup()
            
            -- Clean up any orphaned ESP objects
            for player in pairs(espObjects) do
                if not game.Players:FindFirstChild(player.Name) then
                    cleanupPlayerESP(player)
                end
            end
        end
    end)
end

-- Initialize cleanup system
setupPeriodicCleanup()

-- Main loop
RunService.RenderStepped:Connect(function()
    local frameStart = tick()
    
    updateESP()
    updateFOVCircle()
    if Config.Aimbot.Enabled and UserInputService:IsMouseButtonPressed(Config.Aimbot.Key) then
        Aimbot()
    end
    
    PerformanceStats.frameTime = tick() - frameStart
    updateGui()
end)

-- Add toggle keybind (press P to toggle monitor visibility)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.P then
        screenGui.Enabled = not screenGui.Enabled
    end
end)

-- Initialize
if game:GetService("RunService"):IsStudio() then
    screenGui.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")
else
    screenGui.Parent = game.CoreGui
end

-- Clean up FOV Circle when script ends
game.Players.LocalPlayer.Destroying:Connect(function()
    FOVCircle:Remove()
end)

OrionLib:Init()