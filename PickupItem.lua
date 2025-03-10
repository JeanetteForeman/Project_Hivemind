local pickupItem = script.Parent
local tool = game.ServerStorage.CollectibleItems:FindFirstChild("Mango")

local function onTouched(otherPart)
	--print("Item touched")
	local character = otherPart.Parent
	local player = game.Players:GetPlayerFromCharacter(character)

	if player and tool then
		-- Check if the player already has the item
		if not player.Backpack:FindFirstChild(tool.Name) then
			-- Clone the tool and give it to the player
			local clonedTool = tool:Clone()
			clonedTool.Parent = player.Backpack

			-- Remove the pickup item after collection
			pickupItem:Destroy()
		end
	end
end

pickupItem.Handle.Touched:Connect(onTouched)
