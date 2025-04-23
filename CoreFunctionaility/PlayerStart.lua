game.ReplicatedStorage.RemoteEvents.StartPlayer.OnServerEvent:Connect(function(player, playerCount)
	--CREATE DATA FOLDER
	local dataFolder = game.ReplicatedStorage.SampleData:Clone()
	dataFolder.Parent = game.ReplicatedStorage.PlayerData
	dataFolder.Player.Value = player
	dataFolder.Name = player.Name
	
	repeat
		wait()
	until player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	
	local HB = game.ServerStorage.HB:Clone() --Hitbox for players
	HB.Parent = player.Character
	local weld = Instance.new("Weld",HB)
	weld.Part0  = player.Character.HumanoidRootPart
	weld.Part1 = HB
	weld.C0 = CFrame.new(0,-.2,0)
	
	game.ServerScriptService.Collisions.AddPlayer:Fire(player)
	game.ServerScriptService.Death.addPlayer:Fire(player)

	if game.ServerScriptService.Game.Started.Value == false then
		game.ServerScriptService.Game.Started.Value = true
		if player.Name == "SamsonXVI" then
			--game.ServerScriptService.Game.StartCrashScene:Fire(playerCount)
		end
		game.ServerScriptService.Game.StartCrashScene:Fire(playerCount)
		--game.ServerScriptService.Game.Start60Seconds:Fire()
	end
	game.ServerScriptService.HungerServer.AddPlayer:Fire(player)
end)
