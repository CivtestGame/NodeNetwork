---@param n Network
---@param pos Position | nil
---@param save_id string
local function construct(n, pos, save_id)
    n.set_value = NodeNetwork.set_values[save_id]
    n.loaded = false
    if pos then n.loaded = n:load(pos) end
    if not n.loaded then
        minetest.chat_send_all("Network not found. Creating new")
        n.nodes = {}
        n:save()
    end
end

---@class Network
---@field public set_value SetValue
---@field public nodes Node[]
---@field public key number
NodeNetwork.Network = NodeNetwork.class(construct)

---@param pos Position
---@return boolean
function NodeNetwork.Network:load(pos)
    for key, network in pairs(NodeNetwork.get_set(self.set_value.save_id)) do
        local node_key = NodeNetwork.to_node_id(pos)
        if network.nodes[node_key] then
            self.key = key
            self:from_save(network)
            return true
        end
    end
    return false
end

---@param network Network_save
function NodeNetwork.Network:from_save(network)
    self.nodes = network.nodes
end

function NodeNetwork.Network:save()
    local set = NodeNetwork.get_set(self.set_value.save_id)
    if not self.key then
        self.key = NodeNetwork.generate_id(self.set_value.save_id)
    end
    set[self.key] = self:to_save()
    minetest.chat_send_all("Saving this key " .. self.key .. " for this save_id " .. self.set_value.save_id)
    NodeNetwork.save_set(self.set_value.save_id, set)
end

---@return Network_save
function NodeNetwork.Network:to_save()
    local v = {}
    v.nodes = self.nodes
    return v
end

function NodeNetwork.Network:delete()
    minetest.chat_send_all("Deleting key ".. tostring(self.key))
    if self.key then
        local set = NodeNetwork.get_set(self.set_value.save_id)
        set[self.key] = nil
        NodeNetwork.save_set(self.set_value.save_id, set)
    else
        minetest.debug("[Factorymod]Soft Error: Tried to delete a network which isn't saved")
    end
    self = nil
end

---@param pos Position
---@return Node, number
function NodeNetwork.Network:get_node(pos)
    local key = NodeNetwork.to_node_id(pos)
	return self.nodes[key], key
end

---@param node Node
---@return number
function NodeNetwork.Network:add_node(node)
    local key = NodeNetwork.to_node_id(node.pos)
    self.nodes[key] = node
    return key
end

---@param node Node
---@param key number
function NodeNetwork.Network:set_node(node, key)
    self.nodes[key] = node
end

---@param pos Position
---@return Node | nil
function NodeNetwork.Network:delete_node(pos)
    local node, key = self:get_node(pos)
    self.nodes[key] = nil
    if self:get_nodes_amount() > 0 then
        self:save()
        return node
    else self:delete() end
end

function NodeNetwork.Network:get_nodes_amount()
    return NodeNetwork.count_list(self.nodes)
end

---@param message string
function NodeNetwork.Network:set_infotext(message, pos)
    if pos then
        local meta = minetest.get_meta(pos)
        meta:set_string("infotext",  message)
    else
        for _, node in pairs(self.nodes) do
            local meta = minetest.get_meta(node.pos)
            meta:set_string("infotext",  message)
        end
    end
end

function NodeNetwork.Network:update_infotext()
end

function NodeNetwork.Network:merge(network2)
    for i, node in pairs(network2.nodes) do
        self:add_node(node)
    end
end

--Has no function in the base class, but can be overridden in child classes
function NodeNetwork.Network:force_network_recalc()
end
