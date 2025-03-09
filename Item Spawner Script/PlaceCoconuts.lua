local terrain = game.Workspace.Terrain
local CoconutModel = game.ServerStorage.Coconut  -- change this to be whatever model
local CoconutCount = 500
local MinBounds = Vector3.new(-2150, 0, -2129)  -- CHANGE THESE TO FIT ISLAND BOUNDS (radius or rectangle)
local MaxBounds = Vector3.new(2050, 0, 2250) -- CHANGE THESE TO FIT ISLAND BOUNDS (radius or rectangle)
local CollisionRadius = 10 -- radius for checking for collisions next to new coconut
local CircleRadius = 200 -- radius for generating coconuts randomly in a circle; CHANGE TO FIT ISLAND BOUNDS

-- use raycasting to get the height of a certain point at x, z
local function castRayDown(x, z)
	local origin = Vector3.new(x, 800, z)
	local stop = Vector3.new(x, -100, z)
	local dir = (stop - origin)
	local height = game.Workspace:Raycast(origin, dir, nil)

	if height then
		return height.Position.Y
	else
		return nil
	end
end

-- get random position in circular bounded area
local function getRandomPositionInCircle()
	local angle = math.rad(math.random(0, 360))  -- random angle in radians
	local distance = math.sqrt(math.random()) * CircleRadius  -- random distance (sqrt for uniform spread)

	local x = MinBounds.X + ((MaxBounds.X - MinBounds.X) * 0.5) + distance * math.cos(angle)
	local z = MinBounds.Z + ((MaxBounds.Z - MinBounds.Z) * 0.5) + distance * math.sin(angle)
	local y = castRayDown(x, z)
	if not y then
		return nil
	end
	return Vector3.new(x, y, z)
end

-- get random position in a bound area
local function getRandomPosition()
	local x = math.random(MinBounds.X, MaxBounds.X)
	local z = math.random(MinBounds.Z, MaxBounds.Z)
	local y = castRayDown(x, z)
	if not y then
		return nil
	end

	return Vector3.new(x, y, z)
end

-- check if position is free; return true if position is free, false if occupied
local function isPositionFree(position, radius)
	local parts = workspace:GetPartBoundsInRadius(position, radius, nil)
	return #parts == 0  -- True if no parts are found
end

local function placeItems()
	for i = 1, CoconutCount do
		local attempts = 0
		local maxAttempts = 10

		while attempts < maxAttempts do
			local position = getRandomPosition() -- change to getRandomPositionInCircle() if generating within radius
			if isPositionFree(position, CollisionRadius) then
				local coconutClone = CoconutModel:Clone()
				coconutClone.CFrame = CFrame.new(position)
				coconutClone.Parent = game.Workspace.Coconuts
				break
			end
			attempts = attempts + 1
		end
	end
end

placeItems()