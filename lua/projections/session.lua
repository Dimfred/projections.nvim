local utils = require("projections.utils")
local config = require("projections.config").config
local Workspace = require("projections.workspace")
local Project = require("projections.project")

local Session = {}
Session.__index = Session


---@alias SessionInfo { path: Path, project: Project }

-- Returns the path of the session file as well as project information
-- Returns nil if path is not a valid project path
---@param spath string The path to project root
---@return nil | SessionInfo
---@nodiscard
function Session.info(spath)
    -- check if path is some project's root
    local path = Path.new(spath)
    local project_name = path:basename()
    local workspace_path = path:parent()

    -- allow skipping checks whether the provided path is a workspace or a project
    if config.skip_session_check then
        local filename = Session.session_filename(tostring(workspace_path), project_name)
        return {
            path = config.sessions_directory .. filename,
            project = Project.new(project_name, Workspace.new(workspace_path, {}))
        }
    end

    local all_workspaces = Workspace.get_workspaces()
    local workspace = nil
    for _, ws in ipairs(all_workspaces) do
        if workspace_path == ws.path then
            workspace = ws
            break
        end
    end

    -- check if the path is part of a workspace
    local is_workspace = workspace ~= nil and workspace:is_project(project_name)
    if is_workspace then
        local filename = Session.session_filename(tostring(workspace_path), project_name)
        return {
            path = config.sessions_directory .. filename,
            project = Project.new(project_name, workspace)
        }
    -- check if the path was manually added as a project
    else
        local projects = Project.get_projects()
        for _, proj in ipairs(projects) do
            -- check if the path of this project is the path of some workspace
            if path:parent() == proj.workspace.path and project_name == proj.name then
                local filename = Session.session_filename(tostring(proj.workspace.path), proj.name)
                return {
                    path = config.sessions_directory .. filename,
                    project = proj
                }
            end
        end
    end

    return nil
end

-- Returns the session filename for project
---@param workspace_path string The path to workspace
---@param project_name string Name of project
---@return string
---@nodiscard
function Session.session_filename(workspace_path, project_name)
    local path_hash = utils._fnv1a(workspace_path)
    --return string.format("%s_%u.vim", project_name, path_hash)
    return string.format("%s__%s", path_hash, project_name)
end

-- Ensures sessions directory is available
---@return boolean
function Session._ensure_sessions_directory()
    return vim.fn.mkdir(tostring(config.sessions_directory), "p") == 1
end

-- Attempts to store the session
---@param spath string Path to the project root
---@return boolean
function Session.store(spath)
    Session._ensure_sessions_directory()
    local session_info = Session.info(spath)
    if session_info == nil then return false end
    return Session.store_to_session_file(tostring(session_info.path))
end

-- Attempts to store to session file
---@param spath string Path to the session file
---@returns boolean
function Session.store_to_session_file(spath)
    if config.store_hooks.pre ~= nil then config.store_hooks.pre(spath) end
    -- TODO: correctly indicate errors here!
    vim.cmd("mksession! " .. spath)
    if config.store_hooks.post ~= nil then config.store_hooks.post(spath) end
    return true
end

-- Attempts to restore a session
---@param spath string Path to the project root
---@return boolean
function Session.restore(spath)
    Session._ensure_sessions_directory()
    local session_info = Session.info(spath)
    if session_info == nil or not session_info.path:is_file() then return false end
    return Session.restore_from_session_file(tostring(session_info.path))
end

-- Attempts to restore a session from session file
---@param spath string Path to session file
---@return boolean
function Session.restore_from_session_file(spath)
    if config.restore_hooks.pre ~= nil then config.restore_hooks.pre(spath) end
    -- TODO: correctly indicate errors here!
    vim.cmd("silent! source " .. spath)
    if config.restore_hooks.post ~= nil then config.restore_hooks.post(spath) end
    return true
end

-- Get latest session
---@return nil | Path
---@nodiscard
function Session.latest()
    local latest_session = nil
    local latest_timestamp = 0

    for _, filename in ipairs(vim.fn.readdir(tostring(config.sessions_directory))) do
        local session = config.sessions_directory .. filename
        local timestamp = vim.fn.getftime(tostring(session))
        if timestamp > latest_timestamp then
            latest_session = session
            latest_timestamp = timestamp
        end
    end
    return latest_session
end

-- Restore latest session
---@return boolean
function Session.restore_latest()
    local latest_session = Session.latest()
    if latest_session == nil then return false end
    return Session.restore_from_session_file(tostring(latest_session))
end

return Session
