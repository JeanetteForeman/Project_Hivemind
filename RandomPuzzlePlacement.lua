local ServerStorage = game:GetService("ServerStorage")

-- Grab all models
local modelPool = ServerStorage.PuzzleModels:GetChildren() 

local rooms = {
	workspace.CultBase.RoomA,
	workspace.CultBase.RoomB,
	workspace.CultBase.RoomC
}
local treasureRuins = {
	workspace.TreasureRuins.Ruin1.Room1,
	workspace.TreasureRuins.Ruin2.Room2,
	workspace.TreasureRuins.Ruin3.Room3
}

-- Shuffle table function
local function shuffle(tbl)
	for i = #tbl, 2, -1 do
		local j = math.random(i)
		tbl[i], tbl[j] = tbl[j], tbl[i]
	end
end

-- Main logic to spawn puzzles
local function setupPuzzles()
	-- Shuffle models and pick first 3
	print("Starting puzzle spawn script...")

	shuffle(modelPool)
	local selectedModels = { modelPool[1], modelPool[2], modelPool[3] }

	-- Optional: shuffle rooms if you want randomness
	shuffle(rooms)

	-- Assign each model to a room
	for i = 1, 3 do

		local modelClone = selectedModels[i]:Clone()
		local targetRoom = rooms[i]

		-- Make sure model has a PrimaryPart
		if modelClone.PrimaryPart then
			modelClone:SetPrimaryPartCFrame(targetRoom.PrimaryPart.CFrame)

		else
			warn(modelClone.Name .. " has no PrimaryPart!")
		end
		print("Placing model:", modelClone.Name, "in room:", targetRoom.Name)
		

		modelClone.Parent = workspace
		
		local linkedDoor = targetRoom:FindFirstChild("Door")
		if linkedDoor then
			local doorRef = Instance.new("ObjectValue")
			doorRef.Name = "LinkedDoor"
			doorRef.Value = linkedDoor
			doorRef.Parent = modelClone
			print("Linked door:", linkedDoor.Name, "to puzzle:", modelClone.Name)
		else
			warn("No door found in " .. targetRoom.Name)
		end
		if i <=3 then 

			modelClone = selectedModels[i]:Clone()
			targetRoom = treasureRuins[i]

			-- Make sure model has a PrimaryPart
			if modelClone.PrimaryPart then
				modelClone:SetPrimaryPartCFrame(targetRoom.PrimaryPart.CFrame)

			else
				warn(modelClone.Name .. " has no PrimaryPart!")
			end
			print("Placing model:", modelClone.Name, "in room:", targetRoom.Name)


			modelClone.Parent = workspace
			
			local linkedDoor = targetRoom:FindFirstChild("Door")
			if linkedDoor then
				local doorRef = Instance.new("ObjectValue")
				doorRef.Name = "LinkedDoor"
				doorRef.Value = linkedDoor
				doorRef.Parent = modelClone
				print("Linked door:", linkedDoor.Name, "to puzzle:", modelClone.Name)
			else
				warn("No door found in " .. targetRoom.Name)
			end

		end 
		
	end
	
end

-- Run once at game start
setupPuzzles()

