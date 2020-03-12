---@param save_id string
---@return Network_save[]
function NodeNetwork.get_set(save_id)
    return minetest.deserialize(NodeNetwork.storage:get_string(save_id .. "_network")) or {}
end

---@param save_id string
---@param set Network_save[]
function NodeNetwork.save_set(save_id, set)
    NodeNetwork.storage:set_string(save_id .. "_network", minetest.serialize(set))
end
