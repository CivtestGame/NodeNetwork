--Network which keeps track of input and output devices.'

---@param n IO_network
---@param pos Position | nil
---@param save_id string
local function construct (n, pos, save_id)
	NodeNetwork.IO_network._base.init(n, pos, save_id)
	if not n.loaded then
		n.production_nodes = {}
		n.usage_nodes = {}
		n.production = 0
		n.demand = 0
		n.usage = 0
		n.pdRatio = 0
	end
end

---@class IO_network : Network
---@field public _base Network
---@field public production_nodes number[]
---@field public usage_nodes number[]
---@field public production number
---@field public demand number
---@field public usage number
NodeNetwork.IO_network = class(NodeNetwork.Network,construct)

---@param network IO_network_save
function NodeNetwork.IO_network:from_save(network)
	self._base.from_save(self, network)
	self.production_nodes = network.production_nodes
	self.usage_nodes = network.usage_nodes
	self.production = network.production
	self.demand = network.demand
	self.usage = network.usage
	self.pdRatio = network.pdRatio
end

function NodeNetwork.IO_network:to_save()
	local v = self._base.to_save(self)
	v.production_nodes = self.production_nodes
	v.usage_nodes = self.usage_nodes
	v.production = self.production
	v.demand = self.demand
	v.usage = self.usage
	v.pdRatio = self.pdRatio
	return v
end

---@param pos Position | nil
function NodeNetwork.IO_network:update_infotext(pos)
	self._base.set_infotext(self, "Production: " .. self.production .. " Demand: " .. self.demand .. " Usage: " .. self.usage, pos)
end

function NodeNetwork.IO_network:calc_pdratio()
	if not self.demand or not self.production or self.demand == 0 then
		self.pdRatio = 0
	else
		self.pdRatio = self.production / self.demand
	end
end

function NodeNetwork.IO_network:add_node(node)
	local update_needed = false
	local key = self._base.add_node(self, node)
	if node.production then
		self:add_to_production_nodes(node.pos,key)
		if node.production > 0 then
			self.production = self.production + node.production
			update_needed = true
		end
	end
	if node.demand then
		self:add_to_usage_nodes(node.pos,key)
		if node.demand > 0 then
			self.demand = self.demand + node.demand
			update_needed = true
		end
	end
	if node.usage then
		self:add_to_usage_nodes(node.pos,key)
		update_needed = true
	end
	if update_needed then
		self:update_usage_nodes()
	else
		self:update_infotext(node.pos)
	end
end

---@param pos Position
function NodeNetwork.IO_network:delete_node(pos)
	local node = self._base.delete_node(self,pos)
	if node then -- If we get retuned a node, it means the network wasen't deleted
		local update_needed = false
		if node.production then
			self:remove_from_production_nodes(pos)
		 	if node.production > 0 then
				self.production = self.production - node.production
				update_needed = true
			end
		end
		if node.demand or node.usage then
			self:remove_from_usage_nodes(pos)
			if node.demand >0 then
				self.demand = self.demand - node.demand
				update_needed = true
			end
		end
		if update_needed then
			self:update_usage_nodes()
		end
	end
end

---@param pos Position
---@param key number
function NodeNetwork.IO_network:add_to_production_nodes(pos, key)
	local node_name = minetest.get_node(pos).name
	self.production_nodes[key] = node_name
end

---@param pos Position
---@param key number
function NodeNetwork.IO_network:add_to_usage_nodes(pos, key)
	local node_name = minetest.get_node(pos).name
	self.usage_nodes[key] = node_name
end

function NodeNetwork.IO_network:remove_from_production_nodes(pos)
	local id = NodeNetwork.to_node_id(pos)
	self.production_nodes[id] = nil
end

function NodeNetwork.IO_network:remove_from_usage_nodes(pos)
	local id = NodeNetwork.to_node_id(pos)
	self.usage_nodes[id] = nil
end

---@param pos Position
---@param production number
function NodeNetwork.IO_network:update_production(pos, production)
	local node, node_key = self:get_node(pos)
	local diff = production - (node.production or 0)
	node.production = production
	self:set_node(node, node_key)
	self.production = self.production + diff
	self:add_to_production_nodes(node.pos, node_key)
	self:update_usage_nodes()
	self:update_infotext()
end

---@param pos Position
---@param demand number
function NodeNetwork.IO_network:update_demand(pos, demand)
	local node, node_key = self:get_node(pos)
	local diff = demand - (node.demand or 0)
	node.demand = demand
	self:set_node(node, node_key)
	self.demand = self.demand + diff
	self:add_to_usage_nodes(node.pos, node_key)
	self:update_usage_nodes(pos)
	self:update_infotext()
end

function NodeNetwork.IO_network.check_burntime(pos, save_id)
	local network = NodeNetwork.IO_network(pos, save_id)
	local node, node_key = network:get_node(pos)
	if not node.burn_end or os.time() >= node.burn_end then -- There is no burn time left, turn off the boiler
		minetest.chat_send_all("Burn time is up!")
		node.burn_end = nil
		network:set_node(node, node_key)
		network:update_production(pos, 0)
		network:save()
		--Call same recalc function
	elseif node.burn_end and os.time() < node.burn_end then
		local diff = node.burn_end - os.time()
		minetest.after(diff, NodeNetwork.IO_network.check_burntime, pos, save_id)
	end	
end

---@param node Node
---@param node_name string | nil
---@param usage number | nil
function NodeNetwork.IO_network:call_usage_node(node, node_name, usage)
	node_name = node_name or minetest.get_node(node.pos).name
	if not usage then usage = node.demand * self.pdRatio end
	if self.set_value.usage_functions and self.set_value.usage_functions[node_name] then
		self.set_value.usage_functions[node_name](node, self, usage)
	end
end

---@param exclude_pos Position
function NodeNetwork.IO_network:update_usage_nodes(exclude_pos)
	local old_pd = self.pdRatio or 0
	self:calc_pdratio()
	self.usage = math.min(self.demand *self.pdRatio, self.demand)
	if old_pd >= 1 and self.pdRatio >= 1  then -- We dont need to update usage nodes. There is no change
	else -- We will need to update usgae nodes
		for node_key, node_name in pairs(self.usage_nodes) do
			local node = self.nodes[node_key]
			if not exclude_pos or not f_util.is_same_pos(exclude_pos, node.pos) then
				local usage = (node.demand or 0) * self.pdRatio
				node.usage = usage
				self:set_node(node, node_key)
				self:call_usage_node(node, node_name, usage)
			end
		end
		self:update_infotext()
	end
end

---@param network IO_network
function NodeNetwork.IO_network:merge(network)
	self._base.merge(self, network)
	--self:force_network_recalc()
end

function NodeNetwork.IO_network:force_network_recalc()
	for key, node in pairs(self.nodes) do
		if node.production then self:add_to_production_nodes(node.pos,key) end
		if node.demand then self:add_to_usage_nodes(node.pos,key) end
		if node.usage then self:add_to_usage_nodes(node.pos,key) end
	end
	self.demand = 0
	self.usage = 0
	self.production = 0
	for node_key, node_name in pairs(self.usage_nodes) do
		local node = self.nodes[node_key]
		self.demand = self.demand + (node.demand or 0)
	end
	for node_key, node_name in pairs(self.production_nodes) do
		local node = self.nodes[node_key]
		self.production = self.production + (node.production or 0)
	end
	self:update_usage_nodes()
end

---@param save_id string
---@param block_name string
---@param usage_function function
function NodeNetwork.register_usage_node(save_id, block_name, usage_function)
	NodeNetwork.register_node(save_id, block_name)
	NodeNetwork.set_values[save_id].usage_functions[block_name] = usage_function
end

---@param save_id string
---@param block_name string
function NodeNetwork.register_production_node(save_id, block_name)
	NodeNetwork.register_node(save_id, block_name)
end