-- Versao legivel do payload funcional de "savannah trabalhos.txt".
-- A biblioteca de UI minificada (Vide 0.3.1) e o atlas de icones foram omitidos.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

local Movement = {}
local TWEEN_SPEED = 80

function Movement.tweenPart(part, targetCFrame, duration, callback)
	local initialCFrame = part.CFrame
	local startedAt = tick()
	local connection

	connection = RunService.PreRender:Connect(function()
		local alpha = math.min((tick() - startedAt) / (duration or 1), 1)
		part.CFrame = initialCFrame:Lerp(targetCFrame, alpha)

		if alpha >= 1 then
			connection:Disconnect()
			part.CFrame = targetCFrame
			if callback then callback() end
		end
	end)

	return connection
end

function Movement.tweenTo(targetCFrame)
	local character = LocalPlayer.Character
	if not character then return end

	local root = character.HumanoidRootPart
	local duration = (targetCFrame.Position - root.Position).Magnitude / TWEEN_SPEED
	Movement.tweenPart(root, targetCFrame, duration)
	return duration
end

function Movement.tweenToAsync(targetCFrame)
	local duration = Movement.tweenTo(targetCFrame)
	if duration then task.wait(duration) end
end

function Movement.isInsideTerrain()
	local character = LocalPlayer.Character
	if not character then return false end

	local position = character.HumanoidRootPart.Position
	local region = Region3.new(position, position + Vector3.new(4, 4, 4)):ExpandToGrid(4)
	local _, occupancy = workspace.Terrain:ReadVoxels(region, 4)
	return occupancy[1][1][1] > 0
end

local Combat = {
	basicAttackCooldown = 0.6,
	specialAttackCooldown = 1.9,
}

local BasicAttackRemote = ReplicatedStorage.AttackHandlerRemoteEvent
local SpecialAttackRemote = ReplicatedStorage.SpecialAttackRemoteEvent_RegularAttack

function Combat.basicAttack(humanoid)
	BasicAttackRemote:FireServer(humanoid)
	LocalPlayer.Character:SetAttribute("LastBasicAttack", tick())
end

function Combat.specialAttack(humanoid)
	SpecialAttackRemote:FireServer(humanoid)
	LocalPlayer.Character:SetAttribute("LastSpecialAttack", tick())
end

function Combat.isBasicAttackOnCooldown()
	local lastAttack = LocalPlayer.Character:GetAttribute("LastBasicAttack")
	return lastAttack and tick() - lastAttack < Combat.basicAttackCooldown
end

function Combat.isSpecialAttackOnCooldown()
	local lastAttack = LocalPlayer.Character:GetAttribute("LastSpecialAttack")
	return lastAttack and tick() - lastAttack < Combat.specialAttackCooldown
end

local function findNearestTarget(origin, range)
	local nearestCharacter, nearestRoot, nearestHumanoid, nearestPosition
	local nearestDistance = range + 1

	for _, player in Players:GetPlayers() do
		if player == LocalPlayer then continue end

		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not humanoid or humanoid.Health <= 0 or not root then continue end

		local distance = (origin - root.Position).Magnitude
		if distance < nearestDistance then
			nearestCharacter = character
			nearestRoot = root
			nearestHumanoid = humanoid
			nearestPosition = root.Position
			nearestDistance = distance
		end
	end

	return nearestCharacter, nearestRoot, nearestHumanoid, nearestPosition
end

local Settings = {
	killAura = true,
	useBasicAttack = true,
	useSpecialAttack = true,
	range = 39,
	followTarget = false,
	ghostMode = false, -- existe na UI original, mas nao e usado pelo payload
	ignoreFriends = true, -- existe na UI original, mas nao e usado
	ignoreGroupMembers = true, -- existe na UI original, mas nao e usado
	attackOnlyHostile = false, -- existe na UI original, mas nao e usado
	autoEscapeTerrain = true,
	godmode = false,
}

local lastTarget

local function runKillAura()
	local character = LocalPlayer.Character
	if not character then return end

	local root = character.HumanoidRootPart
	local target, targetRoot, humanoid, targetPosition = findNearestTarget(root.Position, Settings.range)

	if target then
		lastTarget = target
	else
		target = lastTarget
		if not target then return end

		humanoid = target:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			lastTarget = nil
			return
		end

		targetRoot = target.HumanoidRootPart
		targetPosition = targetRoot.Position
	end

	if Settings.useBasicAttack and not Combat.isBasicAttackOnCooldown() then
		Combat.basicAttack(humanoid)
	end

	if Settings.useSpecialAttack and not Combat.isSpecialAttackOnCooldown() then
		Combat.specialAttack(humanoid)
	end

	if Settings.followTarget then
		local direction = (root.Position - targetPosition).Unit
		local followDistance = Settings.range - 5
		root.CFrame = CFrame.new(targetPosition + direction * followDistance + targetRoot.Velocity, targetPosition)
	end
end

local GodmodeRemote = ReplicatedStorage.PlayerDamageSelfRemoteEvent
local RespawnRemote = ReplicatedStorage.SpawnAsCharacterRemoteFunction

local function setGodmode(enabled)
	if enabled then
		GodmodeRemote:FireServer(0 / 0)
		return
	end

	local character = LocalPlayer.Character
	if character then
		RespawnRemote:InvokeServer(character:GetAttribute("CharacterName"))
	end
end

local ControlManager = {
	states = {
		character = { controlled = false, priority = 0, owner = nil },
		camera = { controlled = false, priority = 0, owner = nil },
	},
	timeouts = {},
}

function ControlManager:request(owner, controlType, priority, timeout)
	local state = self.states[controlType]
	if not state or state.controlled and priority <= state.priority then return false end
	if state.controlled then self:release(controlType) end

	state.controlled = true
	state.priority = priority
	state.owner = owner

	if timeout then
		self.timeouts[controlType] = task.delay(timeout, function()
			if state.owner == owner then self:release(controlType) end
		end)
	end

	return true
end

function ControlManager:release(controlType, owner)
	local state = self.states[controlType]
	if not state or not state.controlled or owner and state.owner ~= owner then return end

	state.controlled = false
	state.priority = 0
	state.owner = nil

	if self.timeouts[controlType] then
		task.cancel(self.timeouts[controlType])
		self.timeouts[controlType] = nil
	end
end

local AutoFarm = {}

function AutoFarm.escapeTerrain()
	if not Movement.isInsideTerrain() then return false end

	local character = LocalPlayer.Character
	if character then
		local root = character.HumanoidRootPart
		root.CFrame = CFrame.new(root.Position + Vector3.new(0, 20, 0))
	end

	return true
end

if shared.SavannahReadableCleanup then
	pcall(shared.SavannahReadableCleanup)
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SavannahReadableHUD"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
screenGui.Parent = game:GetService("CoreGui")

local window = Instance.new("Frame")
window.Name = "Window"
window.BackgroundColor3 = Color3.fromRGB(20, 20, 22)
window.BorderSizePixel = 0
window.Position = UDim2.fromOffset(40, 140)
window.Size = UDim2.fromOffset(280, 0)
window.AutomaticSize = Enum.AutomaticSize.Y
window.Parent = screenGui

local windowCorner = Instance.new("UICorner")
windowCorner.CornerRadius = UDim.new(0, 10)
windowCorner.Parent = window

local windowPadding = Instance.new("UIPadding")
windowPadding.PaddingTop = UDim.new(0, 10)
windowPadding.PaddingBottom = UDim.new(0, 10)
windowPadding.PaddingLeft = UDim.new(0, 10)
windowPadding.PaddingRight = UDim.new(0, 10)
windowPadding.Parent = window

local windowLayout = Instance.new("UIListLayout")
windowLayout.Padding = UDim.new(0, 6)
windowLayout.SortOrder = Enum.SortOrder.LayoutOrder
windowLayout.Parent = window

local title = Instance.new("TextLabel")
title.Name = "Title"
title.BackgroundTransparency = 1
title.Size = UDim2.new(1, 0, 0, 28)
title.Font = Enum.Font.GothamBold
title.Text = "Savannah — legível"
title.TextColor3 = Color3.fromRGB(245, 245, 245)
title.TextSize = 15
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = window

local function createToggle(label, initialValue, onChanged)
	local enabled = initialValue
	local button = Instance.new("TextButton")
	button.Name = label:gsub("%s+", "")
	button.AutoButtonColor = false
	button.BorderSizePixel = 0
	button.Size = UDim2.new(1, 0, 0, 30)
	button.Font = Enum.Font.Gotham
	button.TextSize = 12
	button.TextXAlignment = Enum.TextXAlignment.Left
	button.Parent = window

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 7)
	corner.Parent = button

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 10)
	padding.Parent = button

	local function render()
		button.Text = string.format("%s    [%s]", label, enabled and "ON" or "OFF")
		button.TextColor3 = enabled and Color3.fromRGB(15, 15, 15) or Color3.fromRGB(205, 205, 205)
		button.BackgroundColor3 = enabled and Color3.fromRGB(122, 255, 170) or Color3.fromRGB(42, 42, 46)
	end

	button.Activated:Connect(function()
		enabled = not enabled
		render()
		onChanged(enabled)
	end)

	render()
	return button
end

createToggle("Kill aura", Settings.killAura, function(value)
	Settings.killAura = value
end)

createToggle("Ataque básico", Settings.useBasicAttack, function(value)
	Settings.useBasicAttack = value
end)

createToggle("Ataque especial", Settings.useSpecialAttack, function(value)
	Settings.useSpecialAttack = value
end)

createToggle("Seguir alvo", Settings.followTarget, function(value)
	Settings.followTarget = value
end)

createToggle("Godmode", Settings.godmode, function(value)
	Settings.godmode = value
	setGodmode(value)
end)

createToggle("Sair do terreno", Settings.autoEscapeTerrain, function(value)
	Settings.autoEscapeTerrain = value
end)

local dragging = false
local dragStart
local initialPosition

title.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = true
		dragStart = input.Position
		initialPosition = window.Position
	end
end)

title.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = false
	end
end)

local inputChangedConnection = game:GetService("UserInputService").InputChanged:Connect(function(input)
	if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
		local delta = input.Position - dragStart
		window.Position = initialPosition + UDim2.fromOffset(delta.X, delta.Y)
	end
end)

local heartbeatConnection = RunService.Heartbeat:Connect(function()
	if Settings.killAura then
		runKillAura()
	end

	if Settings.autoEscapeTerrain then
		AutoFarm.escapeTerrain()
	end
end)

local PublicApi = {
	Settings = Settings,
	Combat = Combat,
	Movement = Movement,
	ControlManager = ControlManager,
	AutoFarm = AutoFarm,
	findNearestTarget = findNearestTarget,
	runKillAura = runKillAura,
	setGodmode = setGodmode,
}

function PublicApi.cleanup()
	if heartbeatConnection then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end
	if inputChangedConnection then
		inputChangedConnection:Disconnect()
		inputChangedConnection = nil
	end
	if screenGui then
		screenGui:Destroy()
		screenGui = nil
	end
	shared.SavannahReadableCleanup = nil
end

shared.SavannahReadable = PublicApi
shared.SavannahReadableCleanup = PublicApi.cleanup

return PublicApi
