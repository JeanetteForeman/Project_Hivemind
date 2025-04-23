local PhysicsService = game:GetService("PhysicsService")
PhysicsService:RegisterCollisionGroup("CharGroup")
PhysicsService:CollisionGroupSetCollidable("CharGroup", "CharGroup", false)

script.AddPlayer.Event:Connect(function(player)
	local char = player.Character
	local children = char:GetDescendants()
	for i = 1, #children do
		if children[i]:IsA("BasePart") then
			children[i].CollisionGroup = "CharGroup"
		end
	end
	char.DescendantAdded:Connect(function(part)
		if part:IsA("BasePart") then
			part.CollisionGroup = "CharGroup"
		end
	end)
	
	player.CharacterAdded:Connect(function(char)
		local children = char:GetDescendants()
		for i = 1, #children do
			if children[i]:IsA("BasePart") then
				children[i].CollisionGroup = "CharGroup"
			end
		end
		char.DescendantAdded:Connect(function(part)
			if part:IsA("BasePart") then
				part.CollisionGroup = "CharGroup"
			end
		end)
	end)
end)
