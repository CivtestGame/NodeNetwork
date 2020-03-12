
 -- Don't know if this is actually random, but it's semi-random and will do for it's one usecase
 local function get_random_node(nodes)
    local f,t,key = pairs(nodes)
    local node
    key,node = f(t, key)
    return node,key
end

--Recursive function to hopefully generate a new network in cases of network splits
---@param network Network
---@param old_network Network
---@param pos Position
---@param types string[]
---@return Network, Network
local function recursive_add(network, old_network, pos, types)
    for key, node in pairs(old_network.nodes) do
        if NodeNetwork.is_same_pos(node.pos, pos) then
            network:add_node(node)
            old_network.nodes[key] = nil -- We dont use delete node here since we won't use the old network for anything
            for _, adj_pos in pairs(NodeNetwork.get_adjacent_nodes(pos, types)) do
                network, old_network = recursive_add(network, old_network, adj_pos, types)
            end
            return network, old_network
        end
    end
    return network, old_network
end

---@param networks Network[]
---@param extra_node Node
---@param save_id string
---@return number
local function merge_networks(networks, extra_node, save_id)
    local new_network = NodeNetwork.set_values[save_id].constructor(nil, save_id)
    local key = new_network:add_node(extra_node)
    for _, network in pairs(networks) do
        new_network:merge(network)
        network:delete()
    end
    new_network:update_infotext()
    new_network:save()
    return key
end


---@param save_id string
---@param pos Position
---@param ensure_continuity boolean
local function on_node_destruction(save_id, pos, ensure_continuity)
    ---@type Network
    local set_value = NodeNetwork.set_values[save_id]
    local network = set_value.constructor(pos, save_id)
    local connected_nodes = NodeNetwork.get_adjacent_nodes(pos, set_value.types)
    if network.loaded then
        if table.getn(connected_nodes) > 1 and ensure_continuity == true then
            local node, key = network:get_node(pos)
            network.nodes[key] = nil -- We dont use delete node here since we won't use the old network for anything
            while network:get_nodes_amount() > 0 do
                local _,initial_key = get_random_node(network.nodes)
                local new_network = set_value.constructor(nil, save_id)
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

--Set values is an array of possible networks that the block can connect to
---@param save_id string
---@param node Node
---@return number[] @comment array key of inserted node
local function on_node_place(save_id, node)
    local inserted_key
    local connected_networks = NodeNetwork.get_adjacent_networks(node.pos, save_id)
    local count = NodeNetwork.count_list(connected_networks)
    if count == 0 then
        local n = NodeNetwork.set_values[save_id].constructor(nil, save_id)
        inserted_key = n:add_node(node)
        n:save()
    elseif count == 1 then
        local nkey, network = next(connected_networks)
        inserted_key = network:add_node(node)
        network:save()
    else
        inserted_key = merge_networks(connected_networks, node, save_id)
    end
    return inserted_key
end

local function wrap_node_place(def)
    local old_node_place = def.on_place

    def.on_place = function(itemstack, placer, pointed_thing)
        local pos = minetest.get_pointed_thing_position(pointed_thing, true)
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

        if old_node_place then
             return old_node_place(itemstack, placer, pointed_thing)
        else
            return minetest.item_place(itemstack, placer, pointed_thing) 
        end
    end

    return def
end

local function wrap_after_place(def, block_name, set_value)
    local old_after_place = def.after_place_node

    def.after_place_node = function(pos, placer, itemstack, pointed_thing)
        local node = {pos = pos}
        if set_value.production_nodes[block_name] then node.production = set_value.production_nodes[block_name].initial_production end
        if set_value.usage_nodes[block_name] then node.demand = set_value.usage_nodes[block_name].demand end
        on_node_place(set_value.save_id, node)
        if old_after_place then old_after_place(pos, placer, itemstack, pointed_thing) end
    end
    return def
end

local function wrap_after_destruct(def, block_name, set_value)
    local old_after_destruct = def.after_destruct
    def.after_destruct = function(pos, old_node)
        on_node_destruction(set_value.save_id, pos, set_value.ensure_continuity)
        if old_after_destruct then old_after_destruct(pos, old_node) end
    end
    return def
end

local function wrap_functions(block_name, set_value)
    local olddef = table.copy(core.registered_nodes[block_name])
    if olddef then
        local def = wrap_after_place(olddef, block_name, set_value)
        def = wrap_after_destruct(def,block_name, set_value)
        --Citadella integration
        if ct then
            def = wrap_node_place(def)
        end
        minetest.register_node(block_name, def)
    end
end

--START OF GLOBAL FUNCTIONS

NodeNetwork.set_values = {}

---@param save_id string
---@param unit_name string| nil
---@param class Network | IO_network
---@param ensure_continuity boolean
function NodeNetwork.register_network(save_id, unit_name, class, ensure_continuity)
    NodeNetwork.set_values[save_id] = {save_id = save_id, unit_name = unit_name, constructor = class.new, 
     types = {}, usage_functions = {}, usage_nodes = {}, production_nodes = {}}
    NodeNetwork.set_values[save_id].ensure_continuity = ensure_continuity or true
end

function NodeNetwork.register_node(save_id, block_name)
    table.insert(NodeNetwork.set_values[save_id].types,  block_name)
    wrap_functions(block_name, NodeNetwork.set_values[save_id])
end

---@param save_id string
---@param block_name string
---@param usage_function function
---@param demand number
function NodeNetwork.register_usage_node(save_id, block_name, usage_function, demand)
    NodeNetwork.set_values[save_id].usage_functions[block_name] = usage_function
    NodeNetwork.set_values[save_id].usage_nodes[block_name] = {demand = demand}
	NodeNetwork.register_node(save_id, block_name)
end

---@param save_id string
---@param block_name string
---@param initial_production number
function NodeNetwork.register_production_node(save_id, block_name, initial_production)
    NodeNetwork.set_values[save_id].production_nodes[block_name] = {init_production = initial_production or 0}
    NodeNetwork.register_node(save_id, block_name)
end

function NodeNetwork.register_transfer_node(from_save_id, to_save_id, block_name, usage_functions, demand, initial_production)
    NodeNetwork.register_usage_node(from_save_id, block_name, usage_functions, demand)
    NodeNetwork.register_production_node(to_save_id, block_name, initial_production)
end
