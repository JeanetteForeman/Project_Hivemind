--EXAMPLE USAGE
--game.ServerScriptService.Disasters.Barrier.toggle:Fire("Enable")
--game.ServerScriptService.Disasters.Barrier.toggle:Fire("Move", Vector3.new(206.801, 226.678, -169.051), 60, 500)
--game.ServerScriptService.Disasters.Barrier.toggle:Fire("Disable")

local getData = require(game.ReplicatedStorage.GetData)
local TS = game:GetService("TweenService")

script.toggle.Event:Connect(function(action, location, duration, radius)
	if action == "Enable" then
		script.isEnabled.Value = true
	end
	if action == "Disable" then
		script.isEnabled.Value = false
	end
	game.ReplicatedStorage.RemoteEvents.Barrier:FireAllClients(action, location, duration, radius)
	if action == "Move" then
		local tweenPositionInfo = TweenInfo.new(duration,Enum.EasingStyle.Linear)
		local tweeenPositionData = {Value = location}
		local tweenPosition = TS:Create(script.Position,tweenPositionInfo,tweeenPositionData)
		tweenPosition:Play()

		local tweenRadiusInfo = TweenInfo.new(duration,Enum.EasingStyle.Linear)
		local tweeenRadiusData = {Value = radius*.999-2}
		local tweenRadius = TS:Create(script.Radius,tweenRadiusInfo,tweeenRadiusData)
		tweenRadius:Play()
	end
end)

local barrierDamagePerSecond = 5
while true do
	wait(1)
	if script.isEnabled.Value == true then
		local players = game.Players:GetChildren()
		for i = 1, #players do
			local playerData = getData.getDataFromPlayer(players[i])
			if players[i] and players[i].Character and players[i].Character:FindFirstChild("HumanoidRootPart") then
				local distance = (players[i].Character.HumanoidRootPart.Position - script.Position.Value).magnitude
				if distance > script.Radius.Value then
					playerData.inBarrier.Value = false
					playerData.Health.Value = playerData.Health.Value - barrierDamagePerSecond
				else
					playerData.inBarrier.Value = true
				end
			end
		end
	else
		local players = game.Players:GetChildren()
		for i = 1, #players do
			local playerData = getData.getDataFromPlayer(players[i])
			if playerData and playerData:FindFirstChild("inBarrier") then
				playerData.inBarrier.Value = true
			end
		end
	end
end
