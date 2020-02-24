---@param save_id string
---@return Network_save[]
local function get_set(save_id)
    return minetest.deserialize(factory_mod_storage:get_string(save_id .. "_network")) or {}
end

---@param save_id string
---@param set Network_save[]
local function save_set(save_id, set)
    factory_mod_storage:set_string(save_id .. "_network", minetest.serialize(set))
end

 -- Don't know if this is actually random, but it's semi-random and will do for it's one usecase
local function get_random_node(nodes)
    local f,t,key = pairs(nodes)
    local node
    key,node = f(t, key)
    return node,key
end

local function split (inputstr, sep)
    if sep == nil then
            sep = "%s"
    end
    local t={}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
            table.insert(t, str)
    end
    return t
end

---@param string string
---@return Position
local function from_node_id(string)
    local p = split(string, ";")
    return {x = p[1], y = p[2], z=p[3]}
end

--Recursive function to hopefully generate a new network in cases of network splits
---@param network Network
---@param old_network Network
---@param pos Position
---@param types string[]
---@return Network, Network
local function recursive_add(network, old_network, pos, types)
    for key, node in pairs(old_network.nodes) do
        if f_util.is_same_pos(node.pos, pos) then
            network:add_node(node)
            old_network.nodes[key] = nil -- We dont use delete node here since we won't use the old network for anything
            for _, adj_pos in pairs(f_util.get_adjacent_nodes(pos, types)) do
                network, old_network = recursive_add(network, old_network, adj_pos, types)
            end
            return network, old_network
        end
    end
    return network, old_network
end

---@param networks Network[]
---@param extra_node Node
---@param n_class Network | IO_network
---@param save_id string
---@return number
local function merge_networks(networks, extra_node, n_class, save_id)
    local new_network = n_class(nil, save_id)
    local key = new_network:add_node(extra_node)
    for _, network in pairs(networks) do
        new_network:merge(network)
        network:delete()
    end
    new_network:update_infotext()
    new_network:save()
    return key
end

---@param n Network
---@param pos Position | nil
---@param save_id string
local function construct(n, pos, save_id)
    n.set_value = Network.set_values[save_id]
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
Network = class(construct)

---@param pos Position
---@return boolean
function Network:load(pos)
    for key, network in pairs(get_set(self.set_value.save_id)) do
        local node_key = Network.to_node_id(pos)
        if network.nodes[node_key] then
            self.key = key
            self:from_save(network)
            return true
        end
    end
    return false
end

---@param network Network_save
function Network:from_save(network)
    self.nodes = network.nodes
end

function Network:save()
    local set = get_set(self.set_value.save_id)
    if not self.key then
        self.key = Network.generate_id(self.set_value.save_id)
    end
    set[self.key] = self:to_save()
    minetest.chat_send_all("Saving this key " .. self.key .. " for this save_id " .. self.set_value.save_id)
    save_set(self.set_value.save_id, set)
end

---@return Network_save
function Network:to_save()
    local v = {}
    v.nodes = self.nodes
    return v
end

function Network:delete()
    minetest.chat_send_all("Deleting key ".. tostring(self.key))
    if self.key then
        local set = get_set(self.set_value.save_id)
        set[self.key] = nil
        save_set(self.set_value.save_id, set)
    else
        minetest.debug("[Factorymod]Soft Error: Tried to delete a network which isn't saved")
    end
    self = nil
end

---@param pos Position
---@return string
function Network.to_node_id(pos)
    return pos.x .. ";" .. pos.y .. ";" .. pos.z
end

---@param pos Position
---@return Node, number
function Network:get_node(pos)
    local key = Network.to_node_id(pos)
	return self.nodes[key], key
end

---@param node Node
---@return number
function Network:add_node(node)
    local key = Network.to_node_id(node.pos)
    self.nodes[key] = node
    return key
end

---@param node Node
---@param key number
function Network:set_node(node, key)
    self.nodes[key] = node
end

---@param pos Position
---@return Node | nil
function Network:delete_node(pos)
    local node, key = Network:get_node(pos)
    self.nodes[key] = nil
    if self:get_nodes_amount() > 0 then
        self:save()
        return node
    else self:delete() end
end

function Network:get_nodes_amount()
    local count = 0
    for _ in pairs(self.nodes) do count = count + 1 end
    return count
end

---@param message string
function Network:set_infotext(message, pos)
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

function Network:update_infotext()
end

function Network:merge(network2)
    for i, node in pairs(network2.nodes) do
        self:add_node(node)
    end
end

--Has no function in the base class, but can be overridden in child classes
function Network:force_network_recalc()
end


--Start of global methods

---@param save_id string
---@param pos Position
---@param ensure_continuity boolean
---@param n_class Network
function Network.on_node_destruction(save_id, pos, ensure_continuity, n_class)
    ---@type Network
    local set_value = Network.set_values[save_id]
    local network = n_class(pos, save_id)
    local connected_nodes = f_util.get_adjacent_nodes(pos, set_value.types)
    if network.loaded then
        if table.getn(connected_nodes) > 1 and ensure_continuity == true then
            local node, key = network:get_node(pos)
            network.nodes[key] = nil -- We dont use delete node here since we won't use the old network for anything
            while network:get_nodes_amount() > 0 do
                local _,initial_key = get_random_node(network.nodes)
                local new_network = n_class(nil, save_id)
                new_network, network = recursive_add(new_network, network, network.nodes[initial_key].pos, set_value.types)
                new_network:force_network_recalc()
                new_network:save()
            end
            network:delete()
        else
            network:delete_node(pos)
        end
    end
end

---@param pos Position
---@param save_id string
---@return Network[]
--Type is optional filter to reduce search space
function Network.get_adjacent_networks(pos, n_class, save_id)
    local connected_nodes = f_util.get_adjacent_nodes(pos, Network.set_values[save_id].types)
    local networks = {}
    for _, adj_pos in pairs(connected_nodes) do
        ---@type Network
        local n = n_class(adj_pos, save_id)
        if n.loaded then
            local duplicate = false
            for _, network in pairs(networks) do
                if(n.key == network.key) then duplicate = true end
            end
            if not duplicate then table.insert(networks, n) end
        end
    end
    return networks
end

--Set values is an array of possible networks that the block can connect to
---@param save_id string
---@param n_class Network
---@param node Node
---@return number[] @comment array key of inserted node
function Network.on_node_place(save_id, node, n_class)
    local inserted_key
    local connected_networks = Network.get_adjacent_networks(node.pos, n_class, save_id)
    if table.getn(connected_networks) == 0 then
        local n = n_class(nil, save_id)
        inserted_key = n:add_node(node)
        n:save()
    elseif table.getn(connected_networks) == 1 then
        local network = connected_networks[1]
        inserted_key = network:add_node(node)
        network:save()
    else
        inserted_key = merge_networks(connected_networks, node, n_class, save_id)
    end
    return inserted_key
end

Network.set_values = {}

---@param save_id string
---@param unit_name string| nil
function Network.register_network(save_id, unit_name)
    Network.set_values[save_id] = {save_id = save_id, unit_name = unit_name, types = {}, usage_functions = {}}
end

function Network.register_node(save_id, block_name)
    table.insert(Network.set_values[save_id].types,  block_name)
end
--[[
Random id generator, adapted from -- --
https://gist.github.com/haggen/2fd643ea9a261fea2094#gistcomment-2339900 -- --
--                              --
Generate random hex strings as uuids -- --
]]
local charset = {}  do -- [0-9a-f]
    for c = 48, 57  do table.insert(charset, string.char(c)) end
    for c = 97, 102 do table.insert(charset, string.char(c)) end
end

local function random_string(length)
    if not length or length <= 0 then return '' end
    math.randomseed(os.clock()^5)
    return random_string(length - 1) .. charset[math.random(1, #charset)]
end

local function check_network_id_colission(save_id, id)
    local return_v = false
    for key,_ in pairs(get_set(save_id)) do
        if key == id then return_v = true end
    end
    return return_v
end

function Network.generate_id(save_id)
    local id = random_string(16)
    while check_network_id_colission(save_id, id) do --Check we don't collide
        id = random_string(16)
    end
    return id
end