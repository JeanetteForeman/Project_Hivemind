local treeCoords = {} -- tree positions
local minDist = 10 -- minimum distance between trees
local maxNumTrees = 300

local treeModels = game.ReplicatedStorage.SingleTree
local minX, maxX = -200, 200
local minZ, maxZ = -200, 200
local yHeight = 135

-- function to check if a tree that is about to be placed is too close to another tree
function isTooClose(newPosition)
	for _, treePos in pairs(treeCoords) do
		if (treePos - newPosition).Magnitude < minDist then
			return true -- Too close to another tree
		end
	end
	return false -- Safe to place
end

-- generate a tree at a random position and make sure it's not too close to another tree
function generateTree()
	local maxTries = 10 -- max number of times it'll try to place a tree
	for i = 1, maxTries do
		local x = math.random(minX, maxX)
		local z = math.random(minZ, maxZ)
		local y = yHeight
		-- create a new tree at the calculated position
		local newPos = Vector3.new(x, y, z)
		
		-- check if the position is too close to another tree
		if not isTooClose(newPos) then
			-- clone the SingleTree model and set its trunk coordinates to the new vector3, then place on the terrain
			local tree = treeModels:Clone()
			tree:SetPrimaryPartCFrame(CFrame.new(x, y, z))
			tree.Parent = game.Workspace
			
			table.insert(treeCoords, newPos)
			return
		end
	end
end

for i = 1, maxNumTrees do
	generateTree()
end
