local ServerStorage = game:GetService("ServerStorage")

-- Grab all 5 models
local modelPool = ServerStorage.Puzzles:GetChildren() -- Assumes folder named "Models"

-- Define your 3 room positions (Parts or folders with reference points)
local rooms = {
	workspace.RoomA,
	workspace.RoomB,
	workspace.RoomC
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
	end
end

-- Run once at game start
setupPuzzles()
