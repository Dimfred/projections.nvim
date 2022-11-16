# 🛸 projections.nvim

A tiny **project** + sess**ions** manager for neovim, written in lua. Sessions support is optional.

![Project Telescope](https://user-images.githubusercontent.com/30725674/201514449-64b3a132-2147-4e07-b069-f02e57d389e4.gif)

## 🗺️ Quick Guide

### Terminologies

```yaml
─── W
    ├── A
    │   └── .git
    ├── B
    │   └── .hg
    └── D
         └── E
              └── .svn
```
#### Workspace

A workspace is a directory that contains projects as their children. That's it.
Grandchildrens are not considered projects.

> In the figure above, `W` is a workspace

#### Project

A project is any subdirectory of a workspace which contains a file/directory present in `patterns`.

For instance, if `patterns` is `{ ".git", ".svn", ".hg" }`, then all Git, SVN,
and Mercurial repositories under workspace `W` are considered projects.

> In the figure above, `A`, and `B` are projects. `D` and `E` are **not** projects.

You can get creative with this, `{ "package.json" }`, would classify all `npm` packages as projects.

*See `projections.init.setup`, or the next section for more details on `patterns`*

#### Sessions

This plugin also provides a small, and (completely optional) session manager for projects.
**It is only intended to work with projections' projects!**. See, `:h session` and `projections.session`

## 🔌 Installation

**The table provided to setup consists of default values for the options.**

```lua
use({ 
    'gnikdroy/projections.nvim',
    config = function()
        require("projections").setup({
            workspaces = {                             -- Default workspaces to search for 
                -- "~/dev",                               dev is a workspace. default patterns is used (specified below)
                -- { "~/Documents/dev", { ".git" } },     Documents/dev is a workspace. patterns = { ".git" }
                -- { "~/repos", {} },                     An empty pattern list indicates that all subfolders are considered projects
            },
            patterns = { ".git", ".svn", ".hg" },      -- Default patterns to use if none were specified. These are NOT regexps.
            store_hooks = { pre = nil, post = nil },   -- pre and post hooks for store_session, callable | nil
            restore_hooks = { pre = nil, post = nil }, -- pre and post hooks for restore_session, callable | nil
        })
    end
})
```

## 🛠️ Configuration

`projections` doesn't register commands or keybindings. It leaves you with 100% control.
As this might be inconvenient to some, this section comes with a recommended configuration 
and recipes for different workflows.

### Recommended configuration

The recommended setup does the following:

* Provides a telescope switcher for projects, which can be launched by `<leader>fp`
* Saves project's session automatically on `DirChange` and `VimExit`

```lua
use({
    "gnikdroy/projections.nvim",
    config = function()
        require("projections").setup({})

        -- Bind <leader>p to Telescope find_projects
        -- on select, switch to project's root and attempt to load project's session
        local Workspace = require("projections.workspace")
        require('telescope').load_extension('projections')
        vim.keymap.set("n", "<leader>fp", function()
            local find_projects = require("telescope").extensions.projections.projections
            find_projects({
                action = function(selection)
                    -- chdir is required since there might not be a session file
                    vim.fn.chdir(selection.value)
                    Session.restore(selection.value)
                end,
            })
        end, { desc = "Find projects" })

        -- Autostore session on DirChange and VimExit
        local Session = require("projections.session")
        vim.api.nvim_create_autocmd({ 'DirChangedPre', 'VimLeavePre' }, {
            callback = function() Session.store(vim.loop.cwd()) end,
            desc = "Store project session",
        })
    end
})
```
### Recipes

#### Automatically restore last session

The following lines register automatically restore last session.

```lua
-- If vim was started with arguments, do nothing
-- If in some project's root, attempt to restore's that project's session
-- If not, restore last session
-- If no sessions, do nothing
vim.api.nvim_create_autocmd({ "VimEnter" }, {
    callback = function()
        if vim.fn.argc() ~= 0 then return end
        local session_info = Session.info(vim.loop.cwd())
        if session_info == nil then
            Session.restore_latest()
        else
            Session.restore(vim.loop.cwd())
        end
    end,
    desc = "Restore last session automatically"
})
```

#### Manual Session commands

The following lines register two commands `StoreProjectSession` and `RestoreProjectSession`.
Both of them attempt to store/restore the session if `cwd` is a project directory.

```lua
vim.api.nvim_create_user_command("StoreProjectSession", function()
    Session.store(vim.loop.cwd())
end, {})

vim.api.nvim_create_user_command("RestoreProjectSession", function()
    Session.restore(vim.loop.cwd())
end, {})
```

#### Create AddWorkspace command

The following example creates an `AddWorkspace command`
which adds the current directory to workspaces file. Default set of `patterns` is used.

```lua
-- Add workspace command
vim.api.nvim_create_user_command("AddWorkspace", function() 
    Workspace.add(vim.loop.cwd()) 
end, {})
```

### Intended usage

> You are responsible for creating a clear folder structure for your projects!
While this plugin doesn't force any particularly outrageous folder structure,
it won't work well with a particularly outrageous folder structure either!

`projections` stores information in the following places:

```lua
workspaces = stdpath('data') .. 'projections_workspaces.json'
sessions   = stdpath('cache') .. 'projections_sessions/'
```

## 🔭 About Telescope

**The telescope plugin is intended to be the primary method to switch between projects!**
So expect the usability of this plugin to be greatly compromised if you don't use 
[telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)

That being said, you can create your own project switcher with the exposed functions.

# API

The source files are documented for now. But this section will be completed in due time.
The API is not stable. You might need to spend a couple of minutes every once in a while to update!
That being said, most of the core stuff shouldn't change.

## Interactions with other plugins

Neovim's sessions do not work well with some plugins. For example, if you try `:mksession` with an open
`nvim-tree` window, it will store instructions for an empty buffer in the sessions file.

There are several other plugins that do not work well. There are several methods to deal with this including:

1. Close all such buffers before saving the session. `see pre store hooks`
2. Store all such buffers, and then restore them accordingly. `see post restore hooks`
3. Do nothing and handle the buffers manually, either at store or restore.

**Will such a functionality be present in `projections`?** Hard to say. This is not an easy problem to solve reliably.
Option 2 sounds reasonable, but everyone has different needs.
And since the user knows better than `projections`, I am inclined to push this responsibility to the user as well.
