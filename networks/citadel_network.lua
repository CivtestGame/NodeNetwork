--If citadella isn't loaded.
if not ct then
    local function construct (n, pos, save_id)
        NodeNetwork.craft_network._base.init(n, pos, save_id)
    end
    NodeNetwork.citadel_network = NodeNetwork.class(NodeNetwork.Network,construct)
    return -- Don't know if this works, but the aim is to stop the execution of the rest of the file
end


---@param n craft_network
---@param pos Position | nil
---@param save_id string
local function construct (n, pos, save_id)
	NodeNetwork.craft_network._base.init(n, pos, save_id)
	if not n.loaded then
		n.conversion_nodes = {}
		n.conversion_item = nil
		n.output_buffer = 0
	end
end

---@class citadel_network : Network
NodeNetwork.citadel_network = NodeNetwork.class(NodeNetwork.Network,construct)

local is_protected_fn = minetest.is_protected

function minetest.is_protected(pos, pname, action)
    -- body
end

function NodeNetwork.citadel_network.before_node_place()

end