---@class Position
---@field public x number
---@field public y number
---@field public z number
local Position = {} -- This is required to get emmylua to work

---@class SetValue
---@field public save_id string
---@field public types string[]
local SetValue = {} -- This is required to get emmylua to work

---@class Node
---@field public pos Position
local Node = {} -- This is required to get emmylua to work

---@class Network_save
---@field public nodes Node[]
---@field public min_pos Position
---@field public max_pos Position
local Network_save = {} -- This is required to get emmylua to work

---@class IO_network_save : Network_save
---@field public production_nodes number[]
---@field public usage_nodes number[]
---@field public production number
---@field public demand number
---@field public usage number
local IO_network_save = {} -- This is required to get emmylua to work