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
    mt.__call = function(class_tbl, ...)
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
