--EXAMPLE USAGE
--game.ServerScriptService.Disasters.Cult.toggle:Fire("Spawn", 5) (Spawns 5 members randomly on the island)
--game.ServerScriptService.Disasters.Cult.toggle:Fire("Clear") (Removes all cult members)
local getData = require(game.ReplicatedStorage.GetData)
local centerPos = Vector3.new(206.801, 226.678, -169.051)

local minSpeed = 18
local maxSpeed = 36
local attackDamage = 3
local attackCooldown = .95

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
		yPos = result.Position.Y + 4
	end
	local spawnPos = Vector3.new(position.X, yPos, position.Z)
	return spawnPos
end

function getClosestPlayer(position)
	local closestPlayer = nil
	local shortestDistance = math.huge

	for _, player in pairs(game.Players:GetPlayers()) do
		if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			local charPos = player.Character.HumanoidRootPart.Position
			local distance = (charPos - position).Magnitude

			if distance < shortestDistance then
				shortestDistance = distance
				closestPlayer = player
			end
		end
	end

	return closestPlayer
end

script.attackPlayer.Event:Connect(function(cultMember, player)
	if cultMember.Humanoid.Health > 0 then
		local playerData = getData.getDataFromPlayer(player)
		cultMember.Animation.Play:Fire("Play", "Attack")
		wait(.27)
		cultMember.HumanoidRootPart.PunchSound:Play()
		playerData.Health.Value = playerData.Health.Value - attackDamage
	end
end)

local cultMemberAttacks = {}
script.cultMemberAttack.Event:Connect(function(cultMember, playerAttacked)
	local originalSize = cultMember.Hitbox.Size
	cultMember.Hitbox.Size = Vector3.new(.2,.2,.2)
	
	local playerData = getData.getDataFromPlayer(playerAttacked)
	script.attackPlayer:Fire(cultMember, playerAttacked)
	local maxDist = originalSize.Z - 4
	cultMember.Humanoid.WalkSpeed = 13
	repeat
		wait(attackCooldown)
		if cultMember then
			local distance = (cultMember.HumanoidRootPart.Position - playerAttacked.Character.HumanoidRootPart.Position).magnitude
			if distance < maxDist then
				script.attackPlayer:Fire(cultMember, playerAttacked)
			else
				break
			end
		else
			break
		end
	until playerData.Health.Value <= 0
	
	wait(.3)
	if cultMember then
		cultMember.Humanoid.WalkSpeed = minSpeed
		cultMember.Hitbox.Size = originalSize
		cultMemberAttacks[cultMember] = nil
	end
end)

script.createCultMember.Event:Connect(function()
	local cultMember = script["Cult Member"]:Clone()
	cultMember.HumanoidRootPart.CFrame = CFrame.new(getRandomSpawnPos())
	cultMember.Parent = workspace.CultMembers
	cultMember.Humanoid.WalkSpeed = minSpeed
	
	cultMember.Humanoid.Died:Connect(function()
		wait(3)
		cultMember:Destroy()
		return
	end)
	
	wait()
	cultMember.Animation.Play:Fire("Play","Run")
	
	repeat
		wait()
		local targetPlayer = getClosestPlayer(cultMember.HumanoidRootPart.Position)
		local playerData = getData.getDataFromPlayer(targetPlayer)
		repeat
			wait(.05)
			local validPlayer = false
			if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
				validPlayer = true
				local targetPos
				if (math.abs(targetPlayer.Character.HumanoidRootPart.Velocity.X) > 0 and math.abs(targetPlayer.Character.HumanoidRootPart.Velocity.Z) > 0) then
					targetPos = targetPlayer.Character.HumanoidRootPart.Position + targetPlayer.Character.HumanoidRootPart.Velocity.Unit*12
				else
					targetPos = targetPlayer.Character.HumanoidRootPart.Position
				end
				if cultMember then
					local dist = (cultMember.HumanoidRootPart.Position - targetPlayer.Character.HumanoidRootPart.Position).magnitude
					if dist > 500 then
						dist = 500
					end
					if dist >= 50 then
						cultMember.Humanoid.WalkSpeed = minSpeed + (dist/500)*(maxSpeed-minSpeed)
					end
					cultMember.Humanoid:MoveTo(targetPos)
				else
					return
				end
			end
			
			if cultMemberAttacks[cultMember] ~= nil and cultMemberAttacks[cultMember] ~= 0 then
				script.cultMemberAttack:Fire(cultMember, cultMemberAttacks[cultMember])
				cultMemberAttacks[cultMember] = 0
			end
		until cultMember.Humanoid.Health <= 0 or playerData.Health.Value <= 0 or validPlayer == false
	until cultMember.Humanoid.Health <= 0
end)

script.toggle.Event:Connect(function(choice, quantity)
	if choice == "Spawn" then
		for i = 1, quantity do
			script.createCultMember:Fire()
		end
	end
	if choice == "Clear" then
		local cultMembers = workspace.CultMembers:GetChildren()
		for i = 1, #cultMembers do
			cultMembers[i]:Destroy()
		end
	end
end)

game.ReplicatedStorage.RemoteEvents.cultMemberHit.OnServerEvent:Connect(function(player, cultMember)
	if cultMemberAttacks[cultMember] == nil then
		cultMemberAttacks[cultMember] = player
	end
end)


