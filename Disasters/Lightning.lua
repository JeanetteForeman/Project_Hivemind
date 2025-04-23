--EXAMPLE USAGE
--game.ServerScriptService.Disasters.Barrier.toggle:Fire("On")
--game.ServerScriptService.Disasters.Barrier.toggle:Fire("Off")

local getData = require(game.ReplicatedStorage.GetData)
local lightningEnabled = false


function strikePlayer(player)
	local bolt = script.Bolt:Clone()
	local angle = math.rad(math.random(0,360))
	local spot1
	if (math.abs(player.Character.HumanoidRootPart.Velocity.X) > 0 and math.abs(player.Character.HumanoidRootPart.Velocity.Z) > 0) then
		spot1 = player.Character.HumanoidRootPart.Position + player.Character.HumanoidRootPart.Velocity.Unit*10 + math.random(1,7)*Vector3.new(math.cos(angle),0,math.sin(angle))
	else
		spot1 = player.Character.HumanoidRootPart.Position + math.random(1,7)*Vector3.new(math.cos(angle),0,math.sin(angle))
	end
	
	local rayOrigin = spot1 + Vector3.new(0, 50, 0)
	local rayDirection = Vector3.new(0, -100, 0)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {player.Character}
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	local result = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
	local yPos = nil
	if result then
		yPos = result.Position.Y + .5
	else
		yPos = spot1.Y - 2
	end
	local strikePos = Vector3.new(spot1.X, yPos, spot1.Z)
	
	bolt:SetPrimaryPartCFrame(CFrame.Angles(0,math.rad(math.random(-360,360)),0)+strikePos)
	bolt.Parent = workspace
	wait(.1)
	bolt.Strike.start:Fire()
end

function startLightning()
	repeat
		local players = game.Players:GetChildren()
		for i = 1, #players do
			local playerData = getData.getDataFromPlayer(players[i])
			if players[i] and players[i].Character and players[i].Character:FindFirstChild("HumanoidRootPart") and playerData then
				wait( (math.random(7,18)/10) / math.pow(#players,.5))
				strikePlayer(players[i])
			end
		end
		wait(.1)
	until lightningEnabled == false
end

script.toggle.Event:Connect(function(choice)
	if choice == "On" then
		lightningEnabled = true
		startLightning()
	else
		lightningEnabled = false
	end
end)
