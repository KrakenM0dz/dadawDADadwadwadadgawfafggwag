local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local ESP = {}
ESP.TrackedPlayers = {}
ESP.RainbowHue = 0

ESP.Config = setmetatable({
    Enabled = false,
    TeamCheck = false,
    Text = false,
    TextSize = 16,
    TextColor = Color3.fromRGB(255,255,255),
    TextOutline = false,
    TextOutlineColor = Color3.fromRGB(0,0,0),
    Healthbar = false,
    HealthBarWidth = 50,
    HealthBarHeight = 5,
    HeadOffset = 1.2,
    Smoothness = 0.15,
    Chams = false,
    ChamFillTransparency = 0.7,
    ChamOutlineTransparency = 0,
    ChamPulse = false,
    Distance = false,
    DistanceColor = Color3.fromRGB(255,255,255),
    DistanceOffset = 2,
}, {
    __newindex = function(tbl, key, value)
        rawset(tbl, key, value)
        if key == "Enabled" then
            if value then
                -- ESP turned ON: create ESP for all players
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer then ESP:CreateESP(p) end
                end
            else
                -- ESP turned OFF: instantly remove all drawings/highlights
                for p,_ in pairs(ESP.TrackedPlayers) do
                    ESP:RemoveESP(p)
                end
            end
        end
    end
})

-- Health color function
local function GetHealthColor(percent)
    if percent > 0.5 then return Color3.fromRGB(0,255,0)
    elseif percent > 0.25 then return Color3.fromRGB(255,255,0)
    else return Color3.fromRGB(255,0,0) end
end

local function IsEnemy(player)
    if not ESP.Config.TeamCheck then return true end
    return player.Team ~= LocalPlayer.Team
end

function ESP:CreateESP(player)
    if self.TrackedPlayers[player] or not IsEnemy(player) then return end
    local data = {}

    if self.Config.Text then
        local text = Drawing.new("Text")
        text.Visible = false
        text.Center = true
        text.Size = self.Config.TextSize
        text.Color = self.Config.TextColor
        text.Outline = self.Config.TextOutline
        text.OutlineColor = self.Config.TextOutlineColor
        data.Text = text
    end

    if self.Config.Distance then
        local distText = Drawing.new("Text")
        distText.Visible = false
        distText.Center = true
        distText.Size = self.Config.TextSize - 2
        distText.Color = self.Config.DistanceColor
        distText.Outline = self.Config.TextOutline
        distText.OutlineColor = self.Config.TextOutlineColor
        data.DistanceText = distText
    end

    if self.Config.Healthbar then
        local bar = Drawing.new("Square")
        bar.Visible = false
        bar.Filled = true
        bar.Size = Vector2.new(self.Config.HealthBarWidth, self.Config.HealthBarHeight)
        data.HealthBar = bar
        data.CurrentHealthWidth = self.Config.HealthBarWidth
    end

    if self.Config.Chams then
        local highlight = Instance.new("Highlight")
        highlight.FillTransparency = self.Config.ChamFillTransparency
        highlight.OutlineTransparency = self.Config.ChamOutlineTransparency
        highlight.FillColor = Color3.fromHSV(self.RainbowHue,1,1)
        highlight.OutlineColor = Color3.fromRGB(255,255,255)
        highlight.Enabled = false
        highlight.Parent = game:GetService("CoreGui")
        data.Highlight = highlight
    end

    self.TrackedPlayers[player] = data

    local function onCharacterAdded(character)
        local humanoid = character:WaitForChild("Humanoid",5)
        if humanoid then
            humanoid.Died:Connect(function()
                if data.Text then data.Text.Visible = false end
                if data.DistanceText then data.DistanceText.Visible = false end
                if data.HealthBar then data.HealthBar.Visible = false end
                if data.Highlight then data.Highlight.Enabled = false end
            end)
        end
    end

    if player.Character then onCharacterAdded(player.Character) end
    player.CharacterAdded:Connect(onCharacterAdded)
end

function ESP:RemoveESP(player)
    local data = self.TrackedPlayers[player]
    if not data then return end
    if data.Text then data.Text:Remove() end
    if data.DistanceText then data.DistanceText:Remove() end
    if data.HealthBar then data.HealthBar:Remove() end
    if data.Highlight then data.Highlight:Destroy() end
    self.TrackedPlayers[player] = nil
end

function ESP:Update()
    if not self.Config.Enabled then return end
    local localChar = LocalPlayer.Character
    local localRoot = localChar and localChar:FindFirstChild("HumanoidRootPart")
    self.RainbowHue = (self.RainbowHue + 0.005) % 1

    for player,data in pairs(self.TrackedPlayers) do
        if not IsEnemy(player) then
            if data.Text then data.Text.Visible = false end
            if data.DistanceText then data.DistanceText.Visible = false end
            if data.HealthBar then data.HealthBar.Visible = false end
            if data.Highlight then data.Highlight.Enabled = false end
            continue
        end

        local char = player.Character
        local humanoid = char and char:FindFirstChild("Humanoid")
        local head = char and char:FindFirstChild("Head")
        if humanoid and humanoid.Health > 0 and head then
            local pos, onScreen = Camera:WorldToViewportPoint(head.Position + Vector3.new(0,self.Config.HeadOffset,0))

            if self.Config.Healthbar and data.HealthBar then
                local hp = math.clamp(humanoid.Health / humanoid.MaxHealth,0,1)
                data.CurrentHealthWidth += (self.Config.HealthBarWidth*hp - data.CurrentHealthWidth)*self.Config.Smoothness
                data.HealthBar.Size = Vector2.new(data.CurrentHealthWidth, self.Config.HealthBarHeight)
                data.HealthBar.Position = Vector2.new(pos.X - self.Config.HealthBarWidth/2, pos.Y - self.Config.HealthBarHeight)
                data.HealthBar.Color = GetHealthColor(hp)
                data.HealthBar.Visible = onScreen
            end

            if self.Config.Text and data.Text then
                local y = pos.Y - (self.Config.Healthbar and self.Config.HealthBarHeight + 2 or 0) - self.Config.TextSize
                data.Text.Position = Vector2.new(pos.X, y)
                data.Text.Text = player.Name
                data.Text.Visible = onScreen
            end

            if self.Config.Distance and data.DistanceText and localRoot then
                local dist = math.floor((localRoot.Position - head.Position).Magnitude)
                local y = pos.Y + self.Config.TextSize + self.Config.DistanceOffset
                data.DistanceText.Position = Vector2.new(pos.X, y)
                data.DistanceText.Text = dist.." studs"
                data.DistanceText.Visible = onScreen
            end

            if self.Config.Chams and data.Highlight then
                data.Highlight.Adornee = char
                if self.Config.ChamPulse then
                    local pulse = 0.5 + 0.5*math.sin(tick()*3)
                    data.Highlight.FillTransparency = self.Config.ChamFillTransparency * pulse
                    data.Highlight.FillColor = Color3.fromHSV(self.RainbowHue,1,1)
                end
                data.Highlight.Enabled = true
            end
        else
            if data.Text then data.Text.Visible = false end
            if data.DistanceText then data.DistanceText.Visible = false end
            if data.HealthBar then data.HealthBar.Visible = false end
            if data.Highlight then data.Highlight.Enabled = false end
        end
    end
end

Players.PlayerAdded:Connect(function(p) ESP:CreateESP(p) end)
Players.PlayerRemoving:Connect(function(p) ESP:RemoveESP(p) end)
for _,p in ipairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then ESP:CreateESP(p) end
end

RunService.RenderStepped:Connect(function() ESP:Update() end)

return ESP
