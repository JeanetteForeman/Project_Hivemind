script.StartCrashScene.Event:Connect(function(expectedPlayers)
	local i = 10
	repeat
		wait(1)
		i = i - 1
		local players = game.Players:GetChildren()
	until #players >= expectedPlayers or i == 0

	wait(3)
	game.ReplicatedStorage.RemoteEvents.PlayCutscene:FireAllClients("PlaneCrash")
	
	local players = game.Players:GetChildren()
	for i = 1, #players do
		if players[i] and players[i].Character and players[i].Character:FindFirstChild("HumanoidRootPart") then
			players[i].Character.HumanoidRootPart.CFrame = workspace.Nodes.CrashPos.CFrame
		end
	end
	
	wait(42)--however long first cutscene is
	script.Start60Seconds:Fire()
end)

script.Start60Seconds.Event:Connect(function()
	wait(5)
	local textList = {
		English = "OH NO! WE CRASHED!",
		Spanish = "SpanishText",
		French = "FrenchText",
		Portuguese = "PortugueseText",
		Russian = "RussianText",
		Japanese = "JapaneseText",
		Korean = "KoreanText",
		German = "GermanText"
	}
	game.ReplicatedStorage.RemoteEvents.Dialogue:FireAllClients(textList, Color3.fromRGB(80,255,110))
	wait(5)
	game.ReplicatedStorage.RemoteEvents.RemoveNotification:FireAllClients() -- Normally it removes automatically but this can be used to force it to remove sooner

	local textList = {
		English = "The plane is going to blow!",
		Spanish = "SpanishText",
		French = "FrenchText",
		Portuguese = "PortugueseText",
		Russian = "RussianText",
		Japanese = "JapaneseText",
		Korean = "KoreanText",
		German = "GermanText"
	}
	game.ReplicatedStorage.RemoteEvents.Dialogue:FireAllClients(textList, Color3.fromRGB(80,255,110))
	wait(6)
	game.ReplicatedStorage.RemoteEvents.RemoveNotification:FireAllClients()

	local textList = {
		English = "We need to grab everything we can!",
		Spanish = "SpanishText",
		French = "FrenchText",
		Portuguese = "PortugueseText",
		Russian = "RussianText",
		Japanese = "JapaneseText",
		Korean = "KoreanText",
		German = "GermanText"
	}
	game.ReplicatedStorage.RemoteEvents.Dialogue:FireAllClients(textList, Color3.fromRGB(80,255,110))
	wait(8)
	game.ReplicatedStorage.RemoteEvents.RemoveNotification:FireAllClients()

	game.ReplicatedStorage.RemoteEvents.Begin60Seconds:FireAllClients()
	wait(60) --time it takes to finish countdown
	print("Starting explosion")
	game.ServerScriptService.WreckExplosion.explosion:Fire(workspace.Wreck.Explosion.MeshPart1.Position)
	
	script.StartDisasters:Fire()
end)









script.Disasters.lightning.Event:Connect(function()
	game.ServerScriptService.Disasters.Lightning.toggle:Fire("On")
	wait(math.random(30,50))
	game.ServerScriptService.Disasters.Lightning.toggle:Fire("Off")
end)

function randomInCircle(center, radius)
	local angle = math.random() * 2 * math.pi
	local distance = math.sqrt(math.random()) * radius
	local x = math.cos(angle) * distance
	local z = math.sin(angle) * distance
	return Vector3.new(center.X + x, center.Y, center.Z + z)
end
script.Disasters.barrier.Event:Connect(function()
	local centerPos = Vector3.new(206.801, 226.678, -169.051)
	local goalPos = randomInCircle(centerPos, 1000)
	local goalRadius = math.random(100,1000)
	local radiusMult = (1000-goalRadius)/900
	local duration = 40 + radiusMult * 30
	game.ServerScriptService.Disasters.Barrier.toggle:Fire("Enable")
	game.ServerScriptService.Disasters.Barrier.toggle:Fire("Move", goalPos, duration, goalRadius)
	
	wait(duration)
	game.ServerScriptService.Disasters.Barrier.toggle:Fire("Disable")
	game.ServerScriptService.Disasters.Barrier.toggle:Fire("Move", Vector3.new(206.801, 226.678, -169.051), .1, 3602)
end)

script.Disasters.tornadoes.Event:Connect(function()
	local tornadoCount = math.random(5,10)
	game.ServerScriptService.Disasters.Tornado.toggle:Fire("Spawn",tornadoCount)
	wait(math.random(40,55))
	game.ServerScriptService.Disasters.Tornado.toggle:Fire("Clear")
end)

script.Disasters.cultmembers.Event:Connect(function()
	local cultCount = math.random(25,35)
	game.ServerScriptService.Disasters.Cult.toggle:Fire("Spawn",cultCount)
	wait(math.random(45,55))
	--game.ServerScriptService.Disasters.Cult.toggle:Fire("Clear")
end)

script.Disasters.finalBarrier.Event:Connect(function()
	game.ServerScriptService.Disasters.Barrier.toggle:Fire("Enable")
	local goalPos = workspace.Nodes.BunkerLocationNode.Position
	game.ServerScriptService.Disasters.Barrier.toggle:Fire("Move", goalPos, 100, 400)
end)


script.StartDisasters.Event:Connect(function()
	game.ServerScriptService["Day/Night"].start:Fire()
	for i = 1, 12 do
		wait(60)
		local disaster = math.random(1,4)
		if disaster == 1 then
			script.Disasters.lightning:Fire()
		end
		if disaster == 2 then
			script.Disasters.barrier:Fire()
		end
		if disaster == 3 then
			script.Disasters.tornadoes:Fire()
		end
		if disaster == 4 then
			script.Disasters.cultmembers:Fire()
		end
	end
	script.Disasters.finalBarrier:Fire()
end)
