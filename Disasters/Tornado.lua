--EXAMPLE USAGE
--game.ServerScriptService.Disasters.Barrier.toggle:Fire("Spawn",5) (SPAWNS 5 TORNADOS)
--game.ServerScriptService.Disasters.Barrier.toggle:Fire("Clear") (REMOVES ALL TORNADOS)
local getData = require(game.ReplicatedStorage.GetData)
local centerPos = Vector3.new(206.801, 226.678, -169.051)
local tornadoMinSpeed = 20
local tornadoMaxSpeed = 70
local tornadoDamage = 20

function randomInCircle(center, radius)
	local angle = math.random() * 2 * math.pi
	local distance = math.sqrt(math.random()) * radius
	local x = math.cos(angle) * distance
	local z = math.sin(angle) * distance
	return Vector3.new(center.X + x, center.Y, center.Z + z)
end


function getRandomSpawnPos()
	local position = randomInCircle(centerPos, 3000)
	position = Vector3.new(position.X, 400, position.Z)
	
	local rayOrigin = position
	local rayDirection = Vector3.new(0, -1000, 0)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {workspace.Terrain}
	raycastParams.FilterType = Enum.RaycastFilterType.Include
	local result = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
	local yPos = position.Y
	if result then
		yPos = result.Position.Y
	end
	local strikePos = Vector3.new(position.X, yPos, position.Z)
	return strikePos
end

function getTargetPlayerPos(player)
	if player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
		local spot1
		if (math.abs(player.Character.HumanoidRootPart.Velocity.X) > 0 and math.abs(player.Character.HumanoidRootPart.Velocity.Z) > 0) then
			spot1 = player.Character.HumanoidRootPart.Position + player.Character.HumanoidRootPart.Velocity.Unit*10
		else
			spot1 = player.Character.HumanoidRootPart.Position
		end
		local rayOrigin = spot1 + Vector3.new(0, 50, 0)
		local rayDirection = Vector3.new(0, -10000, 0)
		local raycastParams = RaycastParams.new()
		raycastParams.FilterDescendantsInstances = {workspace.Terrain}
		raycastParams.FilterType = Enum.RaycastFilterType.Include
		local result = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
		local yPos = nil
		if result then
			yPos = result.Position.Y
		else
			yPos = spot1.Y
		end
		local goalPos = Vector3.new(spot1.X, yPos, spot1.Z)
		return goalPos
	end
	return nil
end

local tornadoSwitches = {}
script.createTornado.Event:Connect(function()
	local tornado = script.Tornado:Clone()
	local position = getRandomSpawnPos()
	tornado:SetPrimaryPartCFrame(CFrame.new(position))
	tornado.Parent = workspace.Tornados
	tornadoSwitches[tornado] = nil
	
	local players = game.Players:GetChildren()
	for i = 1, #players do
		local duration = 25
		local delayTime = .2
		repeat
			local targetPos = getTargetPlayerPos(players[i])
			if targetPos then
				local direction = (targetPos - tornado.Main.Position).Unit
				local distance =  (targetPos - tornado.Main.Position).Magnitude
				if distance > 500 then
					distance = 500
				end
				local speed = tornadoMinSpeed + (distance/500)*(tornadoMaxSpeed-tornadoMinSpeed)
				local velocity = direction * speed
				tornado.Main.BodyVelocity.Velocity = velocity
			end
			local playerData = getData.getDataFromPlayer(players[i])
			wait(delayTime)
			duration = duration - (1 * delayTime)
		until duration == 0 or targetPos == nil or playerData.Health.Value <= 0 or tornadoSwitches[tornado] == players[i]
		tornadoSwitches[tornado] = nil
	end
end)

script.toggle.Event:Connect(function(choice, quantity)
	if choice == "Spawn" then
		for i = 1, quantity do
			script.createTornado:Fire()
		end
	end
	if choice == "Clear" then
		local tornados = workspace.Tornados:GetChildren()
		for i = 1, #tornados do
			tornados[i]:Destroy()
		end
	end
end)

local function flingPlayer(player)
	local character = player.Character
	if not character then return end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end
	
	local randomDirection = Vector3.new(math.clamp((math.random()-0.5)*3.5, -.8, .8), 1.4, math.clamp((math.random()-0.5)*3.5, -.8, .8)).Unit

	local forceMagnitude = 500
	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.Velocity = randomDirection * forceMagnitude
	bodyVelocity.MaxForce = Vector3.new(1, 1, 1) * math.huge
	bodyVelocity.P = 100000
	bodyVelocity.Parent = rootPart
	game:GetService("Debris"):AddItem(bodyVelocity, 0.3)
end

game.ReplicatedStorage.RemoteEvents.tornadoHit.OnServerEvent:Connect(function(player, tornado)
	local playerData = getData.getDataFromPlayer(player)
	flingPlayer(player)
	playerData.Health.Value = playerData.Health.Value - tornadoDamage
	tornadoSwitches[tornado] = player
end)
