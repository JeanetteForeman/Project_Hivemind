local treeModels = game.ReplicatedStorage.SingleTree
local terrain = game.Workspace.Terrain
local minX, maxX = -200, 200
local minZ, maxZ = -200, 200
local yOffset = 68

for i = 1, 10 do -- Number of trees
	local x = math.random(minX, maxX)
	local z = math.random(minZ, maxZ)
	local y = yOffset

	local treeClone = treeModels:Clone()
	treeClone.Parent = game.Workspace
	treeClone:SetPrimaryPartCFrame(CFrame.new(x, y + yOffset, z))
end