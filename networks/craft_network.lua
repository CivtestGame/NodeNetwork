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

---@class craft_network : IO_network
NodeNetwork.craft_network = NodeNetwork.class(NodeNetwork.IO_network,construct)

---@param node Node
function NodeNetwork.craft_network:add_node(node)
	local key = self._base.add_node(self, node)
	if node.conversion then
		minetest.debug("ADDED CONVERSION NODE, THIS IS NOT A DRILL")
	end
end

---@param pos Position
function NodeNetwork.craft_network:delete_node(pos)
	local node = self._base.delete_node(self,pos)
	if node then -- If we get retuned a node, it means the network wasen't deleted
		if node.conversion then
			minetest.debug("DELETED CONVERSION NODE, THIS IS NOT A DRILL")
		end
	end
	return node
end