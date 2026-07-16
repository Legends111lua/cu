local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Teams = game:GetService("Teams")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer

local STAFF_MIN_RANK = 3
local STAFF_GROUP_ID = game.CreatorType == Enum.CreatorType.Group and game.CreatorId or 0
local detectedStaff = {}
local staffDetectorGui
local staffIndicator
local staffIndicatorDot
local staffIndicatorText

local function ensureStaffIndicator()
	if staffDetectorGui and staffDetectorGui.Parent then return end
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	staffDetectorGui = Instance.new("ScreenGui")
	staffDetectorGui.Name = "WaveStaffDetector"
	staffDetectorGui.ResetOnSpawn = false
	staffDetectorGui.DisplayOrder = 999
	staffDetectorGui.Parent = playerGui

	staffIndicator = Instance.new("Frame")
	staffIndicator.AnchorPoint = Vector2.new(1, 0)
	staffIndicator.Position = UDim2.new(1, -12, 0, 12)
	staffIndicator.Size = UDim2.fromOffset(210, 32)
	staffIndicator.BackgroundColor3 = Color3.fromRGB(24, 28, 26)
	staffIndicator.BackgroundTransparency = 0.15
	staffIndicator.BorderSizePixel = 0
	staffIndicator.Parent = staffDetectorGui
	Instance.new("UICorner", staffIndicator).CornerRadius = UDim.new(0, 8)

	local stroke = Instance.new("UIStroke")
	stroke.Name = "AlertStroke"
	stroke.Color = Color3.fromRGB(70, 190, 110)
	stroke.Transparency = 0.35
	stroke.Thickness = 1
	stroke.Parent = staffIndicator

	staffIndicatorDot = Instance.new("Frame")
	staffIndicatorDot.Position = UDim2.fromOffset(11, 10)
	staffIndicatorDot.Size = UDim2.fromOffset(12, 12)
	staffIndicatorDot.BackgroundColor3 = Color3.fromRGB(70, 230, 120)
	staffIndicatorDot.BorderSizePixel = 0
	staffIndicatorDot.Parent = staffIndicator
	Instance.new("UICorner", staffIndicatorDot).CornerRadius = UDim.new(1, 0)

	staffIndicatorText = Instance.new("TextLabel")
	staffIndicatorText.BackgroundTransparency = 1
	staffIndicatorText.Position = UDim2.fromOffset(31, 5)
	staffIndicatorText.Size = UDim2.new(1, -39, 1, -10)
	staffIndicatorText.Font = Enum.Font.GothamSemibold
	staffIndicatorText.Text = "Sem staff no servidor"
	staffIndicatorText.TextColor3 = Color3.fromRGB(205, 225, 212)
	staffIndicatorText.TextSize = 11
	staffIndicatorText.TextWrapped = true
	staffIndicatorText.TextXAlignment = Enum.TextXAlignment.Left
	staffIndicatorText.TextYAlignment = Enum.TextYAlignment.Center
	staffIndicatorText.Parent = staffIndicator
end

local function updateStaffIndicator()
	ensureStaffIndicator()
	local names = {}
	for _, info in detectedStaff do
		table.insert(names, "@" .. info.player.Name .. " (" .. info.role .. ")")
	end
	table.sort(names)
	local count = #names
	local stroke = staffIndicator:FindFirstChild("AlertStroke")
	if count == 0 then
		staffIndicator.Size = UDim2.fromOffset(210, 32)
		staffIndicator.BackgroundColor3 = Color3.fromRGB(24, 28, 26)
		staffIndicator.BackgroundTransparency = 0.15
		staffIndicatorDot.BackgroundColor3 = Color3.fromRGB(70, 230, 120)
		staffIndicatorText.TextColor3 = Color3.fromRGB(205, 225, 212)
		staffIndicatorText.Text = "Sem staff no servidor"
		if stroke then stroke.Color = Color3.fromRGB(70, 190, 110); stroke.Transparency = 0.35; stroke.Thickness = 1 end
	else
		staffIndicator.Size = UDim2.fromOffset(270, math.min(105, 38 + count * 16))
		staffIndicator.BackgroundColor3 = Color3.fromRGB(82, 20, 24)
		staffIndicator.BackgroundTransparency = 0.05
		staffIndicatorDot.BackgroundColor3 = Color3.fromRGB(255, 55, 65)
		staffIndicatorText.TextColor3 = Color3.fromRGB(255, 225, 225)
		staffIndicatorText.Text = string.format("STAFF DETECTADO: %d\n%s", count, table.concat(names, "\n"))
		if stroke then stroke.Color = Color3.fromRGB(255, 60, 70); stroke.Transparency = 0; stroke.Thickness = 2 end
	end
end

local function notifyStaff(player, rank, role)
	if detectedStaff[player.UserId] then return end
	detectedStaff[player.UserId] = { player = player, rank = rank, role = role }
	updateStaffIndicator()
	local message = string.format("%s (@%s) | %s | Rank %d", player.DisplayName, player.Name, role, rank)
	warn("[Staff Detector] " .. message)
	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = "STAFF DETECTADO",
			Text = message,
			Duration = 12,
		})
	end)
end

local function checkPlayerStaff(player)
	if player == LocalPlayer or STAFF_GROUP_ID <= 0 then return end
	task.spawn(function()
		local okRank, rank = pcall(player.GetRankInGroup, player, STAFF_GROUP_ID)
		if not okRank or rank < STAFF_MIN_RANK then return end
		local okRole, role = pcall(player.GetRoleInGroup, player, STAFF_GROUP_ID)
		notifyStaff(player, rank, okRole and role or "Staff")
	end)
end

task.defer(updateStaffIndicator)

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

local Selection = {
	targetPlayers = {},
	targetTeams = {},
	whitelistPlayers = {},
	whitelistTeams = {},
}

local function isSelected(player, playerSet, teamSet)
	return playerSet[player.UserId] == true
		or player.Team ~= nil and teamSet[player.Team.Name] == true
end

local function isAllowedTarget(player)
	local selected = isSelected(player, Selection.targetPlayers, Selection.targetTeams)
	local whitelisted = isSelected(player, Selection.whitelistPlayers, Selection.whitelistTeams)
	return selected and not whitelisted
end

local function hasProtectionAttribute(instance)
	if not instance then return false end
	for name, value in instance:GetAttributes() do
		local key = string.lower(name)
		local protectedName = key:find("shield", 1, true)
			or key:find("protect", 1, true)
			or key:find("invulner", 1, true)
			or key:find("safezone", 1, true)
		if protectedName and (value == true or type(value) == "number" and value > 0) then
			return true
		end
	end
	return false
end

local function isCombatProtected(player, character)
	if not character then return true end
	if character:FindFirstChildOfClass("ForceField") or character:FindFirstChild("Shield", true) then
		return true
	end
	return hasProtectionAttribute(character) or hasProtectionAttribute(player)
end

local function findNearestTarget(origin, range)
	local nearestCharacter, nearestRoot, nearestHumanoid, nearestPosition
	local nearestDistance = (range or math.huge) + 1

	for _, player in Players:GetPlayers() do
		if player == LocalPlayer then continue end
		if not isAllowedTarget(player) then continue end

		local character = player.Character
		if isCombatProtected(player, character) then continue end
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

local function findLowestLifeTarget(origin, range)
	local bestCharacter, bestRoot, bestHumanoid, bestPosition
	local lowestHealth = math.huge
	local nearestDistance = (range or math.huge) + 1

	for _, player in Players:GetPlayers() do
		if player == LocalPlayer or not isAllowedTarget(player) then continue end
		local character = player.Character
		if isCombatProtected(player, character) then continue end
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not humanoid or humanoid.Health <= 0 or not root then continue end
		local distance = (origin - root.Position).Magnitude
		if distance <= (range or math.huge)
			and (humanoid.Health < lowestHealth or humanoid.Health == lowestHealth and distance < nearestDistance) then
			lowestHealth = humanoid.Health
			nearestDistance = distance
			bestCharacter, bestRoot, bestHumanoid, bestPosition = character, root, humanoid, root.Position
		end
	end

	return bestCharacter, bestRoot, bestHumanoid, bestPosition
end

local Settings = {
	killAura = true,
	lowLifeTarget = false,
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
	fly = false,
	esp = false,
	followHeight = 8,
	followDistance = 5,
	followSpeed = 80,
	cruiseHeight = 65,
	descentDistance = 200,
}

local lastTarget
local ragdollTeleportBusy = false
local followHasTarget = false
local rockWaitPart
local rockWaitBusy = false
local rockWaitCollisions = {}
local selectedRestPoint
local lastRestTeleportAt = -math.huge
local REST_TELEPORT_COOLDOWN = 25
local postKillRestActive = false
local postKillRestUntil
local forceSafeReturn = false
local engagedTarget
local targetEngagedAt
local MAX_TARGET_ENGAGE_TIME = 15
local lastFlightPosition
local characterNoclipParts = {}
local noclipPulseId = 0
local REST_POINTS = {
	["Mini Ilha"] = {
		type = "platform",
		cframe = CFrame.new(-7076.4453125, -10.88628101348877, 4391.662109375, 0.9044032096862793, 0.023793241009116173, 0.42601490020751953, 0.0004958743811585009, 0.9983847141265869, -0.05681321769952774, -0.42667853832244873, 0.05159330740571022, 0.9029305577278137),
	},
	["Topo Pride"] = {
		type = "platform",
		cframe = CFrame.new(-5765.14306640625, 362.97052001953125, 4411.55908203125, 0.9630705714225769, -0.05434619262814522, 0.26370733976364136, 0.00012212539149913937, 0.9795058369636536, 0.20141570270061493, -0.2692490518093109, -0.19394533336162567, 0.9433398842811584),
	},
	Mirage = {
		type = "platform",
		cframe = CFrame.new(-7159.92431640625, 49.9999885559082, 2621.214599609375, 0.31048059463500977, -0.0000820758068584837, 0.9505797028541565, 0.0009678906644694507, 0.9999995231628418, -0.00022979189816396683, -0.9505792260169983, 0.0009914031252264977, 0.310480535030365),
	},
	vsone = {
		type = "platform",
		cframe = CFrame.new(-5213.1923828125, 73.87883758544922, 3245.0361328125, -0.9892290830612183, 0.0014818820636719465, 0.14636823534965515, 0.005826029926538467, 0.9995549917221069, 0.02925536222755909, -0.14625973999500275, 0.02979299984872341, -0.9887974858283997),
	},
	["Pride Inside"] = {
		type = "noclip",
		cframe = CFrame.new(-5860.52978515625, 23.396947860717773, 4351.421875, -0.6168082356452942, -0.040299803018569946, 0.7860811352729797, 0.0008164339233189821, 0.9986551403999329, 0.05183840170502663, -0.7871130108833313, 0.03261613845825195, -0.6159458160400391),
	},
}

local function getFlightController(root)
	local attachment = root:FindFirstChild("WaveFlightAttachment")
	if not attachment then
		attachment = Instance.new("Attachment")
		attachment.Name = "WaveFlightAttachment"
		attachment.Parent = root
	end

	local velocity = root:FindFirstChild("WaveFlightVelocity")
	if not velocity then
		velocity = Instance.new("LinearVelocity")
		velocity.Name = "WaveFlightVelocity"
		velocity.Attachment0 = attachment
		velocity.RelativeTo = Enum.ActuatorRelativeTo.World
		velocity.MaxForce = math.huge
		velocity.VectorVelocity = Vector3.zero
		velocity.Parent = root
	end

	local orientation = root:FindFirstChild("WaveFlightOrientation")
	if not orientation then
		orientation = Instance.new("AlignOrientation")
		orientation.Name = "WaveFlightOrientation"
		orientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
		orientation.Attachment0 = attachment
		orientation.MaxTorque = math.huge
		orientation.Responsiveness = 35
		orientation.RigidityEnabled = false
		orientation.Parent = root
	end

	velocity.Enabled = true
	orientation.Enabled = true
	return velocity, orientation
end

local function setFlight(root, velocity, facingDirection)
	local linearVelocity, alignOrientation = getFlightController(root)
	linearVelocity.VectorVelocity = velocity
	local flatDirection = facingDirection and Vector3.new(facingDirection.X, 0, facingDirection.Z)
	if flatDirection and flatDirection.Magnitude > 0.01 then
		alignOrientation.CFrame = CFrame.lookAlong(Vector3.zero, flatDirection.Unit)
	end
end

local function disableFlight(root)
	if not root then return end
	local velocity = root:FindFirstChild("WaveFlightVelocity")
	local orientation = root:FindFirstChild("WaveFlightOrientation")
	if velocity then velocity.Enabled = false end
	if orientation then orientation.Enabled = false end
end

local function enableCharacterNoclip(character)
	if not character then return end
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			if not characterNoclipParts[part] then
				characterNoclipParts[part] = { canCollide = part.CanCollide }
			end
			part.CanCollide = false
		end
	end
end

local function disableCharacterNoclip(character)
	for part, state in characterNoclipParts do
		if part.Parent and (not character or part:IsDescendantOf(character)) then
			part.CanCollide = state.canCollide
		end
		characterNoclipParts[part] = nil
	end
end

local function pulseCharacterNoclip(character, duration)
	noclipPulseId += 1
	local pulseId = noclipPulseId
	enableCharacterNoclip(character)
	task.delay(duration or 0.75, function()
		if noclipPulseId == pulseId then
			disableCharacterNoclip(character)
		end
	end)
end

local function leaveRockWait(immediate)
	rockWaitBusy = false
	local support = rockWaitPart
	local collisions = rockWaitCollisions
	rockWaitPart = nil
	rockWaitCollisions = {}
	if support and support.Name == "WaveLocalWaitingPlatform" then support:Destroy() end
	local function restoreCollisions()
		for part, canCollide in collisions do
			if part.Parent then part.CanCollide = canCollide end
		end
	end
	if immediate then restoreCollisions() else task.delay(0.5, restoreCollisions) end
end

local function findSparseWaypoint(origin, character)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.IgnoreWater = true

	local bestCFrame
	local bestScore = -math.huge
	for _, radius in { 90, 150, 220 } do
		for index = 0, 11 do
			local angle = math.rad(index * 30)
			local flat = origin + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
			local hit = workspace:Raycast(flat + Vector3.new(0, 180, 0), Vector3.new(0, -420, 0), params)
			if hit then
				local candidate = hit.Position + Vector3.new(0, 5, 0)
				local nearestPlayer = math.huge
				for _, player in Players:GetPlayers() do
					if player == LocalPlayer then continue end
					local otherRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
					if otherRoot then
						nearestPlayer = math.min(nearestPlayer, (otherRoot.Position - candidate).Magnitude)
					end
				end
				local score = nearestPlayer - radius * 0.15
				if score > bestScore then
					bestScore = score
					bestCFrame = CFrame.new(candidate)
				end
			end
		end
	end
	return bestCFrame
end

local function enterRockWait(root, ignoreCooldown)
	if rockWaitBusy or rockWaitPart then return true end
	if not ignoreCooldown and tick() - lastRestTeleportAt < REST_TELEPORT_COOLDOWN then return false end
	local point = selectedRestPoint and REST_POINTS[selectedRestPoint]
	if not point then return false end
	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not root or not humanoid then return false end

	local support
	rockWaitCollisions = {}
	if point.type == "noclip" then
		local mapAssets = workspace:FindFirstChild("MapAssets")
		local rocks = mapAssets and mapAssets:FindFirstChild("LargeRocksPersistentStreaming")
		local prideRock = rocks and rocks:FindFirstChild("PrideRock")
		support = prideRock and prideRock:GetChildren()[28]
		if not support then return false end
		if support:IsA("BasePart") then
			rockWaitCollisions[support] = support.CanCollide
			support.CanCollide = false
		end
		for _, object in support:GetDescendants() do
			if object:IsA("BasePart") then
				rockWaitCollisions[object] = object.CanCollide
				object.CanCollide = false
			end
		end
	else
		support = Instance.new("Part")
		support.Name = "WaveLocalWaitingPlatform"
		support.Anchored = true
		support.CanCollide = true
		support.CanTouch = false
		support.Size = Vector3.new(30, 1, 30)
		support.Transparency = 1
		support.CFrame = CFrame.new(point.cframe.Position - Vector3.new(0, 3.5, 0))
		support.Parent = workspace
	end
	rockWaitPart = support
	rockWaitBusy = true
	lastRestTeleportAt = tick()

	task.spawn(function()
		disableFlight(root)
		root.Anchored = false
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		humanoid:ChangeState(Enum.HumanoidStateType.Physics)

		local function stagedMove(goalCFrame)
			local startPivot = character:GetPivot()
			local distance = (goalCFrame.Position - startPivot.Position).Magnitude
			local segmentCount = math.max(1, math.ceil(distance / 60))
			for segment = 1, segmentCount do
				if rockWaitPart ~= support or not character.Parent or not root.Parent then return false end
				local alpha = segment / segmentCount
				local position = startPivot.Position:Lerp(goalCFrame.Position, alpha)
				local segmentCFrame = CFrame.new(position) * goalCFrame.Rotation
				for _ = 1, 2 do
					if rockWaitPart ~= support or not character.Parent or not root.Parent then return false end
					character:PivotTo(segmentCFrame)
					root.AssemblyLinearVelocity = Vector3.zero
					root.AssemblyAngularVelocity = Vector3.zero
					task.wait()
				end
			end
			return true
		end

		local waypoint = findSparseWaypoint(root.Position, character)
		if waypoint and stagedMove(waypoint) then
			for _ = 1, 10 do
				if rockWaitPart ~= support or not character.Parent or not root.Parent then break end
				character:PivotTo(waypoint)
				root.AssemblyLinearVelocity = Vector3.zero
				root.AssemblyAngularVelocity = Vector3.zero
				task.wait(0.1)
			end
		end

		stagedMove(point.cframe)
		for _ = 1, 8 do
			if rockWaitPart ~= support or not character.Parent or not root.Parent then break end
			character:PivotTo(point.cframe)
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
			task.wait()
		end

		task.wait(0.35)
		if rockWaitPart == support and humanoid.Parent then
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
			for _ = 1, 8 do
				if rockWaitPart ~= support or not character.Parent then break end
				root.AssemblyLinearVelocity = Vector3.zero
				root.AssemblyAngularVelocity = Vector3.zero
				character:SetAttribute("MovementDisabled", false)
				task.wait(0.1)
			end
		end
		rockWaitBusy = false
	end)

	return true
end

local function maintainSafeFlight(root)
	local character = LocalPlayer.Character
	if not character or not root then return end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.IgnoreWater = false
	local ground = workspace:Raycast(root.Position, Vector3.new(0, -500, 0), params)
	if not ground then return end
	local difference = ground.Position.Y + Settings.cruiseHeight - root.Position.Y
	if difference > 2 then
		local riseSpeed = math.min(Settings.followSpeed, math.max(25, difference * 4))
		setFlight(root, Vector3.new(0, riseSpeed, 0), root.CFrame.LookVector)
	else
		setFlight(root, Vector3.zero, root.CFrame.LookVector)
	end
end

local function ragdollTeleport(targetRoot)
	if ragdollTeleportBusy then return end
	ragdollTeleportBusy = true
	local character = LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and humanoid then
		disableFlight(root)
		root.Anchored = false
		humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		for _ = 1, 25 do
			if LocalPlayer.Character ~= character or not root.Parent or not targetRoot.Parent then break end
			local targetPosition = targetRoot.Position
			if (root.Position - targetPosition).Magnitude <= 8 then break end
			local destination = targetPosition - targetRoot.CFrame.LookVector * 4
			character:SetPrimaryPartCFrame(CFrame.lookAt(destination, targetPosition))
			task.wait()
		end
		task.wait(1)
		if humanoid.Parent then
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
		if root.Parent then
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
			local facing = targetRoot.Parent
				and targetRoot.Position - root.Position
				or root.CFrame.LookVector
			setFlight(root, Vector3.new(0, 45, 0), facing)
		end
		for _ = 1, 10 do
			if not character.Parent then break end
			character:SetAttribute("MovementDisabled", false)
			if root.Parent and root.AssemblyLinearVelocity.Y < 0 then
				root.AssemblyLinearVelocity = Vector3.new(0, 45, 0)
			end
			task.wait(0.1)
		end
	end
	ragdollTeleportBusy = false
end

local function runKillAura()
	local character = LocalPlayer.Character
	if not character then return end

	local root = character.HumanoidRootPart

	if lastTarget and not postKillRestActive then
		local previousHumanoid = lastTarget:FindFirstChildOfClass("Humanoid")
		if not previousHumanoid or previousHumanoid.Health <= 0 then
			postKillRestActive = true
			postKillRestUntil = nil
			forceSafeReturn = true
			lastTarget = nil
			engagedTarget = nil
			targetEngagedAt = nil
			lastFlightPosition = nil
			followHasTarget = false
		end
	end

	if postKillRestActive then
		followHasTarget = false
		lastFlightPosition = nil
		disableCharacterNoclip(character)
		if selectedRestPoint then
			local enteredRest = enterRockWait(root, forceSafeReturn)
			if enteredRest and rockWaitPart and not rockWaitBusy then
				postKillRestUntil = postKillRestUntil or tick() + 3
			elseif not enteredRest then
				disableFlight(root)
				postKillRestUntil = postKillRestUntil or tick() + 3
			end
		else
			disableFlight(root)
			postKillRestUntil = postKillRestUntil or tick() + 3
		end

		if postKillRestUntil and tick() >= postKillRestUntil then
			postKillRestActive = false
			postKillRestUntil = nil
			forceSafeReturn = false
			engagedTarget = nil
			targetEngagedAt = nil
			leaveRockWait()
		end
		return
	end

	local target, targetRoot, humanoid, targetPosition
	if Settings.lowLifeTarget then
		target, targetRoot, humanoid, targetPosition = findLowestLifeTarget(root.Position, math.huge)
	else
		target, targetRoot, humanoid, targetPosition = findNearestTarget(root.Position, math.huge)
	end

	if target then
		lastTarget = target
	else
		target = lastTarget
		local targetPlayer = target and Players:GetPlayerFromCharacter(target)
		if not target or not targetPlayer or not isAllowedTarget(targetPlayer)
			or isCombatProtected(targetPlayer, target) then
			lastTarget = nil
			engagedTarget = nil
			targetEngagedAt = nil
			lastFlightPosition = nil
			followHasTarget = false
			disableCharacterNoclip(character)
			if Settings.followTarget and selectedRestPoint then
				enterRockWait(root)
			elseif not Settings.fly then
				disableFlight(root)
			end
			return
		end

		humanoid = target:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			lastTarget = nil
			engagedTarget = nil
			targetEngagedAt = nil
			lastFlightPosition = nil
			followHasTarget = false
			disableCharacterNoclip(character)
			if Settings.followTarget and selectedRestPoint then
				enterRockWait(root)
			elseif not Settings.fly then
				disableFlight(root)
			end
			return
		end

		targetRoot = target:FindFirstChild("HumanoidRootPart")
		if not targetRoot then
			lastTarget = nil
			engagedTarget = nil
			targetEngagedAt = nil
			lastFlightPosition = nil
			followHasTarget = false
			disableCharacterNoclip(character)
			if Settings.followTarget and selectedRestPoint then
				enterRockWait(root)
			elseif not Settings.fly then
				disableFlight(root)
			end
			return
		end
		targetPosition = targetRoot.Position
	end

	engagedTarget = target
	targetEngagedAt = targetEngagedAt or tick()
	if tick() - targetEngagedAt >= MAX_TARGET_ENGAGE_TIME then
		postKillRestActive = true
		postKillRestUntil = nil
		forceSafeReturn = false
		lastTarget = nil
		engagedTarget = nil
		targetEngagedAt = nil
		lastFlightPosition = nil
		followHasTarget = false
		disableCharacterNoclip(character)
		return
	end

	if Settings.followTarget and not ragdollTeleportBusy then
		if lastFlightPosition then
			local correction = root.Position - lastFlightPosition
			if correction.Y < -15 then
				postKillRestActive = true
				postKillRestUntil = nil
				forceSafeReturn = false
				lastTarget = nil
				engagedTarget = nil
				targetEngagedAt = nil
				lastFlightPosition = nil
				followHasTarget = false
				disableFlight(root)
				disableCharacterNoclip(character)
				return
			end
		end
		lastFlightPosition = root.Position
	else
		lastFlightPosition = nil
	end

	if Settings.followTarget and selectedRestPoint == "Pride Inside" and rockWaitPart then
		pulseCharacterNoclip(character, 0.75)
	else
		disableCharacterNoclip(character)
	end
	leaveRockWait()
	followHasTarget = true

	if Settings.killAura then
		local useBasic = Settings.useBasicAttack and not Combat.isBasicAttackOnCooldown()
		local useSpecial = Settings.useSpecialAttack and not Combat.isSpecialAttackOnCooldown()

		if useBasic or useSpecial then
			for _, player in Players:GetPlayers() do
				if player == LocalPlayer or not isAllowedTarget(player) then continue end
				local enemyCharacter = player.Character
				if Settings.lowLifeTarget and enemyCharacter ~= target then continue end
				if isCombatProtected(player, enemyCharacter) then continue end
				local enemyHumanoid = enemyCharacter and enemyCharacter:FindFirstChildOfClass("Humanoid")
				local enemyRoot = enemyCharacter and enemyCharacter:FindFirstChild("HumanoidRootPart")
				if not enemyHumanoid or enemyHumanoid.Health <= 0 or not enemyRoot then continue end
				if (root.Position - enemyRoot.Position).Magnitude > Settings.range then continue end

				if useBasic then Combat.basicAttack(enemyHumanoid) end
				if useSpecial then Combat.specialAttack(enemyHumanoid) end
			end
		end
	end

	if Settings.followTarget then
		local distance = (targetPosition - root.Position).Magnitude
		if distance > Settings.descentDistance and not ragdollTeleportBusy then
			task.spawn(ragdollTeleport, targetRoot)
		elseif not ragdollTeleportBusy then
			local predictedPosition = targetPosition + targetRoot.AssemblyLinearVelocity * 0.2
			local destination = predictedPosition
				- targetRoot.CFrame.LookVector * Settings.followDistance
				+ Vector3.new(0, Settings.followHeight, 0)
			local offset = destination - root.Position
			if offset.Magnitude > 2 then
				local speed = math.min(Settings.followSpeed, offset.Magnitude * 4)
				setFlight(root, offset.Unit * speed, targetPosition - root.Position)
			else
				setFlight(root, targetRoot.AssemblyLinearVelocity, targetPosition - root.Position)
			end
		end
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

local window = Instance.new("ScrollingFrame")
window.Name = "Window"
window.BackgroundColor3 = Color3.fromRGB(20, 20, 22)
window.BorderSizePixel = 0
window.Position = UDim2.fromOffset(40, 30)
window.Size = UDim2.fromOffset(360, 500)
window.AutomaticCanvasSize = Enum.AutomaticSize.Y
window.CanvasSize = UDim2.new()
window.ScrollBarThickness = 4
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
title.Text = "Savannah — Hunter Script"
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

local function createSpeedInput()
	local input = Instance.new("TextBox")
	input.Name = "FollowSpeed"
	input.BackgroundColor3 = Color3.fromRGB(42, 42, 46)
	input.BorderSizePixel = 0
	input.ClearTextOnFocus = false
	input.Size = UDim2.new(1, 0, 0, 30)
	input.Font = Enum.Font.Gotham
	input.Text = string.format("Velocidade: %d studs/s (máximo recomendado: 90)", Settings.followSpeed)
	input.TextColor3 = Color3.fromRGB(220, 220, 220)
	input.PlaceholderColor3 = Color3.fromRGB(140, 140, 140)
	input.TextSize = 11
	input.Parent = window

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 7)
	corner.Parent = input

	input.Focused:Connect(function()
		input.Text = tostring(Settings.followSpeed)
	end)

	input.FocusLost:Connect(function()
		local requestedSpeed = tonumber(input.Text)
		if requestedSpeed then
			Settings.followSpeed = math.clamp(math.floor(requestedSpeed + 0.5), 1, 90)
		end
		input.Text = string.format("Velocidade: %d studs/s (máximo recomendado: 90)", Settings.followSpeed)
	end)

	return input
end

local function createRestPointButtons()
	local container = Instance.new("Frame")
	container.Name = "RestPoints"
	container.BackgroundTransparency = 1
	container.Size = UDim2.new(1, 0, 0, 62)
	container.Parent = window

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, 14)
	label.Font = Enum.Font.GothamBold
	label.Text = "PONTO DE DESCANSO (nenhum)"
	label.TextColor3 = Color3.fromRGB(190, 190, 195)
	label.TextSize = 9
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = container

	local gridFrame = Instance.new("Frame")
	gridFrame.BackgroundTransparency = 1
	gridFrame.Position = UDim2.fromOffset(0, 16)
	gridFrame.Size = UDim2.new(1, 0, 0, 46)
	gridFrame.Parent = container

	local grid = Instance.new("UIGridLayout")
	grid.CellPadding = UDim2.fromOffset(4, 4)
	grid.CellSize = UDim2.new(1 / 3, -3, 0, 20)
	grid.FillDirectionMaxCells = 3
	grid.Parent = gridFrame

	local buttons = {}
	local names = { "Mini Ilha", "Topo Pride", "Mirage", "vsone", "Pride Inside" }
	local function render()
		label.Text = "PONTO DE DESCANSO: " .. (selectedRestPoint or "nenhum")
		for name, button in buttons do
			local selected = selectedRestPoint == name
			button.BackgroundColor3 = selected and Color3.fromRGB(122, 255, 170) or Color3.fromRGB(42, 42, 46)
			button.TextColor3 = selected and Color3.fromRGB(15, 15, 15) or Color3.fromRGB(210, 210, 215)
		end
	end

	for _, name in names do
		local button = Instance.new("TextButton")
		button.Name = name:gsub("%s+", "")
		button.BorderSizePixel = 0
		button.Font = Enum.Font.Gotham
		button.Text = name
		button.TextSize = 9
		button.Parent = gridFrame
		Instance.new("UICorner", button).CornerRadius = UDim.new(0, 5)
		buttons[name] = button
		button.Activated:Connect(function()
			leaveRockWait(true)
			selectedRestPoint = selectedRestPoint == name and nil or name
			render()
		end)
	end
	render()
end

local selectorRefreshers = {}
local selectorConnections = {}

local function createSelector(titleText, playerSet, teamSet)
	local container = Instance.new("Frame")
	container.Name = titleText:gsub("%s+", "")
	container.BackgroundColor3 = Color3.fromRGB(30, 30, 34)
	container.BorderSizePixel = 0
	container.Size = UDim2.new(1, 0, 0, 150)
	container.Parent = window

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 7)
	corner.Parent = container

	local heading = Instance.new("TextLabel")
	heading.BackgroundTransparency = 1
	heading.Position = UDim2.fromOffset(8, 4)
	heading.Size = UDim2.new(1, -16, 0, 20)
	heading.Font = Enum.Font.GothamBold
	heading.Text = titleText
	heading.TextColor3 = Color3.fromRGB(235, 235, 235)
	heading.TextSize = 12
	heading.TextXAlignment = Enum.TextXAlignment.Left
	heading.Parent = container

	local search = Instance.new("TextBox")
	search.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
	search.BorderSizePixel = 0
	search.ClearTextOnFocus = false
	search.PlaceholderText = "Buscar jogador ou team..."
	search.Position = UDim2.fromOffset(8, 27)
	search.Size = UDim2.new(1, -16, 0, 27)
	search.Font = Enum.Font.Gotham
	search.Text = ""
	search.TextColor3 = Color3.new(1, 1, 1)
	search.PlaceholderColor3 = Color3.fromRGB(145, 145, 145)
	search.TextSize = 11
	search.Parent = container
	Instance.new("UICorner", search).CornerRadius = UDim.new(0, 6)

	local list = Instance.new("ScrollingFrame")
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(8, 59)
	list.Size = UDim2.new(1, -16, 0, 83)
	list.ScrollBarThickness = 3
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = container

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 3)
	layout.Parent = list

	local function addRow(text, selected, toggle)
		local row = Instance.new("TextButton")
		row.AutoButtonColor = false
		row.BackgroundColor3 = selected and Color3.fromRGB(70, 140, 95) or Color3.fromRGB(40, 40, 45)
		row.BorderSizePixel = 0
		row.Size = UDim2.new(1, -4, 0, 24)
		row.Font = Enum.Font.Gotham
		row.Text = (selected and "[X] " or "[ ] ") .. text
		row.TextColor3 = Color3.fromRGB(225, 225, 225)
		row.TextSize = 11
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.Parent = list
		Instance.new("UICorner", row).CornerRadius = UDim.new(0, 5)
		local padding = Instance.new("UIPadding", row)
		padding.PaddingLeft = UDim.new(0, 7)
		row.Activated:Connect(toggle)
	end

	local refresh
	refresh = function()
		for _, child in list:GetChildren() do
			if child:IsA("GuiButton") then child:Destroy() end
		end

		local query = string.lower(search.Text)
		for _, player in Players:GetPlayers() do
			if player ~= LocalPlayer then
				local label = player.DisplayName .. " (@" .. player.Name .. ")"
				if query == "" or string.find(string.lower(label), query, 1, true) then
					addRow("PLAYER  " .. label, playerSet[player.UserId] == true, function()
						playerSet[player.UserId] = not playerSet[player.UserId] or nil
						refresh()
					end)
				end
			end
		end

		local teamNames = {}
		for _, team in Teams:GetTeams() do teamNames[team.Name] = true end
		for _, player in Players:GetPlayers() do
			if player.Team then teamNames[player.Team.Name] = true end
		end
		local sortedTeams = {}
		for teamName in teamNames do table.insert(sortedTeams, teamName) end
		table.sort(sortedTeams)
		for _, teamName in sortedTeams do
			if query == "" or string.find(string.lower(teamName), query, 1, true) then
				addRow("TEAM  " .. teamName, teamSet[teamName] == true, function()
					teamSet[teamName] = not teamSet[teamName] or nil
					refresh()
				end)
			end
		end
	end

	table.insert(selectorRefreshers, refresh)
	table.insert(selectorConnections, search:GetPropertyChangedSignal("Text"):Connect(refresh))
	refresh()
end

createSelector("ALVOS", Selection.targetPlayers, Selection.targetTeams)
createSelector("WHITELIST", Selection.whitelistPlayers, Selection.whitelistTeams)

local function refreshSelectors()
	for _, refresh in selectorRefreshers do refresh() end
end

local function makeCharacterPersistent(character)
	if not character or character == LocalPlayer.Character then return end
	pcall(function()
		character.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end)
end

local function watchPlayerStreaming(player)
	if player == LocalPlayer then return end
	makeCharacterPersistent(player.Character)
	table.insert(selectorConnections, player.CharacterAdded:Connect(makeCharacterPersistent))
end

for _, player in Players:GetPlayers() do
	watchPlayerStreaming(player)
	checkPlayerStaff(player)
end

table.insert(selectorConnections, Players.PlayerAdded:Connect(function(player)
	watchPlayerStreaming(player)
	checkPlayerStaff(player)
	refreshSelectors()
end))
table.insert(selectorConnections, Players.PlayerRemoving:Connect(function(player)
	detectedStaff[player.UserId] = nil
	updateStaffIndicator()
	refreshSelectors()
end))
table.insert(selectorConnections, Teams.ChildAdded:Connect(refreshSelectors))
table.insert(selectorConnections, Teams.ChildRemoved:Connect(refreshSelectors))

createToggle("Kill aura", Settings.killAura, function(value)
	Settings.killAura = value
end)

createToggle("Matar low life", Settings.lowLifeTarget, function(value)
	Settings.lowLifeTarget = value
	lastTarget = nil
	engagedTarget = nil
	targetEngagedAt = nil
end)

createToggle("Ataque básico", Settings.useBasicAttack, function(value)
	Settings.useBasicAttack = value
end)

createToggle("Ataque especial", Settings.useSpecialAttack, function(value)
	Settings.useSpecialAttack = value
end)

createToggle("Seguir alvo", Settings.followTarget, function(value)
	Settings.followTarget = value
	if not value then
		leaveRockWait()
		disableCharacterNoclip(LocalPlayer.Character)
	end
end)

createRestPointButtons()

createSpeedInput()

createToggle("Godmode", Settings.godmode, function(value)
	Settings.godmode = value
	setGodmode(value)
end)

createToggle("Sair do terreno", Settings.autoEscapeTerrain, function(value)
	Settings.autoEscapeTerrain = value
end)

createToggle("Fly", Settings.fly, function(value)
	Settings.fly = value
end)

createToggle("ESP + tracer", Settings.esp, function(value)
	Settings.esp = value
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

local espObjects = {}

local function removeEsp(player)
	local objects = espObjects[player]
	if not objects then return end
	objects.text:Remove()
	objects.tracer:Remove()
	espObjects[player] = nil
end

local function getEsp(player)
	if espObjects[player] then return espObjects[player] end
	if not Drawing or not Drawing.new then return end
	local text = Drawing.new("Text")
	text.Center, text.Outline, text.Size, text.Visible = true, true, 14, false
	local tracer = Drawing.new("Line")
	tracer.Thickness, tracer.Visible = 1, false
	espObjects[player] = { text = text, tracer = tracer }
	return espObjects[player]
end

local espConnection = RunService.RenderStepped:Connect(function(deltaTime)
	local camera = workspace.CurrentCamera
	local localCharacter = LocalPlayer.Character
	local localRoot = localCharacter and localCharacter:FindFirstChild("HumanoidRootPart")

	if Settings.fly and localRoot and not rockWaitPart and (not Settings.followTarget or not followHasTarget) then
		local direction = Vector3.zero
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then direction += camera.CFrame.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then direction -= camera.CFrame.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then direction += camera.CFrame.RightVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then direction -= camera.CFrame.RightVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then direction += Vector3.yAxis end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then direction -= Vector3.yAxis end
		local velocity = direction.Magnitude > 0 and direction.Unit * Settings.followSpeed or Vector3.zero

		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { localCharacter }
		local ground = workspace:Raycast(localRoot.Position, Vector3.new(0, -500, 0), params)
		if ground then
			local difference = ground.Position.Y + Settings.cruiseHeight - localRoot.Position.Y
			if difference > 2 then
				local riseSpeed = math.min(Settings.followSpeed, math.max(25, difference * 4))
				velocity = Vector3.new(velocity.X, math.max(velocity.Y, riseSpeed), velocity.Z)
			end
		end

		setFlight(localRoot, velocity, camera.CFrame.LookVector)
	elseif localRoot and (rockWaitPart or not Settings.followTarget) then
		disableFlight(localRoot)
	end

	for _, player in Players:GetPlayers() do
		if player == LocalPlayer then continue end
		local objects = getEsp(player)
		if not objects then continue end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not Settings.esp or not root or not humanoid or humanoid.Health <= 0 then
			objects.text.Visible, objects.tracer.Visible = false, false
			continue
		end
		local point, onScreen = camera:WorldToViewportPoint(root.Position + Vector3.new(0, 3, 0))
		if not onScreen then
			objects.text.Visible, objects.tracer.Visible = false, false
			continue
		end
		local distance = localRoot and math.floor((localRoot.Position - root.Position).Magnitude) or 0
		local animalName = character:GetAttribute("AnimalName") or "Desconhecido"
		local color = Color3.fromRGB(230, 230, 230)
		if isSelected(player, Selection.whitelistPlayers, Selection.whitelistTeams) then
			color = Color3.fromRGB(100, 255, 140)
		elseif isAllowedTarget(player) then
			color = Color3.fromRGB(255, 90, 90)
		end
		local healthText = ""
		if character == lastTarget then
			healthText = string.format(" | HP: %d/%d", math.ceil(humanoid.Health), math.ceil(humanoid.MaxHealth))
		end
		objects.text.Text = string.format("%s | %s | %dm%s", player.Name, tostring(animalName), distance, healthText)
		objects.text.Position, objects.text.Color, objects.text.Visible = Vector2.new(point.X, point.Y), color, true
		objects.tracer.From = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y)
		objects.tracer.To, objects.tracer.Color, objects.tracer.Visible = Vector2.new(point.X, point.Y), color, true
	end
end)

table.insert(selectorConnections, Players.PlayerRemoving:Connect(removeEsp))
local selectorRefreshTimer = 0

local heartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime)
	selectorRefreshTimer += deltaTime
	if selectorRefreshTimer >= 1 then
		selectorRefreshTimer = 0
		refreshSelectors()
	end
	if Settings.killAura or Settings.followTarget then
		runKillAura()
	end

	if Settings.autoEscapeTerrain then
		AutoFarm.escapeTerrain()
	end
end)

local PublicApi = {
	Settings = Settings,
	Selection = Selection,
	Combat = Combat,
	Movement = Movement,
	ControlManager = ControlManager,
	AutoFarm = AutoFarm,
	findNearestTarget = findNearestTarget,
	runKillAura = runKillAura,
	setGodmode = setGodmode,
}

function PublicApi.cleanup()
	leaveRockWait(true)
	disableCharacterNoclip(LocalPlayer.Character)
	if staffDetectorGui then
		staffDetectorGui:Destroy()
		staffDetectorGui = nil
	end
	if heartbeatConnection then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end
	if inputChangedConnection then
		inputChangedConnection:Disconnect()
		inputChangedConnection = nil
	end
	if espConnection then
		espConnection:Disconnect()
		espConnection = nil
	end
	for player in espObjects do removeEsp(player) end
	for _, connection in selectorConnections do connection:Disconnect() end
	table.clear(selectorConnections)
	if screenGui then
		screenGui:Destroy()
		screenGui = nil
	end
	shared.SavannahReadableCleanup = nil
end

shared.SavannahReadable = PublicApi
shared.SavannahReadableCleanup = PublicApi.cleanup

return PublicApi
