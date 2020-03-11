function NodeNetwork.class(base, init)
    local c = {}    -- a new class instance
    if not init and type(base) == 'function' then
        init = base
        base = nil
    elseif type(base) == 'table' then
        -- our new class is a shallow copy of the base class!
        for i,v in pairs(base) do
            c[i] = v
        end
        c._base = base
    end
    -- the class will be the metatable for all its objects,
    -- and they will look up their methods in it.
    c.__index = c
 
    -- expose a constructor which can be called by <classname>(<args>)
    local mt = {}
    local constructor = function(...)
        local obj = {}
        setmetatable(obj,c)
        if init then
            init(obj,...)
        else 
        -- make sure that any stuff from the base class is initialized!
            if base and base.init then
                base.init(obj, ...)
            end
        end
        return obj
    end
    mt.__call = function (class_tbl, ...)
       return constructor(...)
    end
    c.new = constructor
    c.init = init
    c.is_a = function(self, klass)
       local m = getmetatable(self)
       while m do 
          if m == klass then return true end
          m = m._base
       end
       return false
    end
    setmetatable(c, mt)
    return c
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
function NodeNetwork.from_node_id(string)
    local p = split(string, ";")
    return {x = p[1], y = p[2], z=p[3]}
end

---@param pos Position
---@return string
function NodeNetwork.to_node_id(pos)
    return pos.x .. ";" .. pos.y .. ";" .. pos.z
end

function NodeNetwork.is_same_pos(pos1, pos2)
    return pos1.x == pos2.x and pos1.y == pos2.y and pos1.z == pos2.z
end

---@param node_name string
---@param types string[]
---@return boolean
local function same_type(node_name, types)
    for _, type in pairs(types) do
        if node_name == type then return true end
    end
end

--Type is an optional filter
---@param pos Position
---@param types string[]
function NodeNetwork.get_adjacent_nodes(pos, types)
    local return_pos = {}
    local posy = { x = pos.x, y = pos.y + 1, z = pos.z }
    local negy = { x = pos.x, y = pos.y - 1, z = pos.z }
    local posx = { x = pos.x + 1, y = pos.y, z = pos.z }
    local negx = { x = pos.x - 1, y = pos.y, z = pos.z }
    local posz = { x = pos.x, y = pos.y, z = pos.z + 1}
    local negz = { x = pos.x, y = pos.y, z = pos.z - 1}
    if types then
        if same_type(minetest.get_node(posy).name,types) then table.insert(return_pos, posy) end
        if same_type(minetest.get_node(negy).name,types) then table.insert(return_pos, negy) end
        if same_type(minetest.get_node(posx).name,types) then table.insert(return_pos, posx) end
        if same_type(minetest.get_node(negx).name,types) then table.insert(return_pos, negx) end
        if same_type(minetest.get_node(posz).name,types) then table.insert(return_pos, posz) end
        if same_type(minetest.get_node(negz).name,types) then table.insert(return_pos, negz) end
    else
        return_pos = {posy,negy,posx,negx,posz,negz}
    end
    return return_pos
end

function NodeNetwork.count_list(list)
    local count = 0
    if list then
        for _ in pairs(list) do count = count + 1 end
    end
    return count
end

---@param pos Position
---@param save_id string | nil
---@return Network[]
--Type is optional filter to reduce search space
function NodeNetwork.get_adjacent_networks(pos, save_id)
    local set_vals
    if save_id then 
        set_vals = {}
        set_vals[save_id] = NodeNetwork.set_values[save_id]
    else set_vals = NodeNetwork.set_values end
    local networks = {}
    --minetest.chat_send_all("Called adjacent network")
    for key, val in pairs(set_vals) do
        local connected_nodes = NodeNetwork.get_adjacent_nodes(pos, val.types)
        for _, adj_pos in pairs(connected_nodes) do
            ---@type Network
            local n = val.constructor(adj_pos, key)
            if n.loaded then
                local duplicate = false
                for _, network in pairs(networks) do
                    if(n.key == network.key) then duplicate = true end
                end
                if not duplicate then 
                    local key = NodeNetwork.to_node_id(adj_pos)
                    networks[key] =  n
                end
            end
        end
    end
    return networks
end