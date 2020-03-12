--If citadella isn't loaded.
if not ct then
    local function construct (n, pos, save_id)
        NodeNetwork.citadel_network._base.init(n, pos, save_id)
    end
    NodeNetwork.citadel_network = NodeNetwork.class(NodeNetwork.Network,construct)
    return -- Don't know if this works, but the aim is to stop the execution of the rest of the file
end


---@param n citadel_network
---@param pos Position | nil
---@param save_id string
local function construct (n, pos, save_id)
	NodeNetwork.citadel_network._base.init(n, pos, save_id)
end

---@class citadel_network : Network
NodeNetwork.citadel_network = NodeNetwork.class(NodeNetwork.Network,construct)

local is_protected_fn = minetest.is_protected

---@param itemstack any
---@param placer any
---@param pointed_thing Position
function NodeNetwork.citadel_network.before_node_place(itemstack, placer, pointed_thing)
    minetest.chat_send_all("CALLED!")
    local pos = minetest.get_pointed_thing_position(pointed_thing, true) --Convert point thing to pos
    if pos then
        local connected_nets = NodeNetwork.get_adjacent_networks(pos)
        if connected_nets then
            for key,value in pairs(connected_nets) do
                local pos = NodeNetwork.from_node_id(key)
                if not ct.has_locked_container_privilege(pos, placer) then
                    minetest.chat_send_player(placer:get_player_name(),"You can't place a network block next to a network you don't have access to")
                    return itemstack, placer, pointed_thing
                end
            end
        end
    end
    return minetest.item_place(itemstack, placer, pointed_thing)
end