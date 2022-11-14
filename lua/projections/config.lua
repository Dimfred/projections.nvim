local Path = require("projections.path")

local Config = {}
Config.__index = Config

function Config.new()
    local config = setmetatable({}, Config)
    config.store_hooks = { pre = nil, post = nil }
    config.restore_hooks = { pre = nil, post = nil }
    config.workspaces = { '~/Documents/dev' }
    config.patterns = { '.git', '.svn', '.hg' }
    config.workspaces_file = Path.new(vim.fn.stdpath("data")) .. "projections_workspaces.json"
    config.sessions_folder = Path.new(vim.fn.stdpath("cache")) .. "projections_sessions"
    return config
end

function Config:merge(conf)
    vim.tbl_deep_extend("force", {}, {})
end

local config_singleton = Config.new()

return config_singleton
