--# selene: allow(unused_variable)
---@diagnostic disable: unused-local

-- Assign every window a sigil for quick access.
--
-- A letter or digit is rendered in the titlebar of every window, and actions can be bound
-- inside a "sigil" mode with different modifiers.  For example, with no modifiers, the
-- the sigil key can focus the window.  If the 'enter' action is bound to control-w, then
-- 'control-w c' will focus the window with sigil 'c'.
--
-- The keys 'h', 'j', 'k', and 'l' are reserved for the window west, south, north, and
-- east of the currently focused window in standard Vi-like fashion, and so are not
-- assigned as sigils.
--
-- By default, two keys (other than the sigils) are bound in the mode: escape leaves the
-- mode without doing anything, and '.' sends the sigil key to the focused window.  This
-- allows sending 'control-w' to the underlying window by typing 'control-w .'.
--
-- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/WindowSigils.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/WindowSigils.spoon.zip)
--
-- Usage example:
-- ```
-- sigils = hs.loadSpoon("WindowSigils")
-- sigils:configure({
--   hotkeys = {
--     enter = {{"control"}, "W"}
--   },
--   mode_keys = {
--     [{{'shift'}, 'i'}] = ignore_notification,
--     [{{}, 'v'}]        = paste_as_keystrokes,
--     [{{}, ','}]        = rerun_last_command,
--   },
--   sigil_actions = {
--     [{}]       = focus_window,
--     [{'ctrl'}] = swap_window,
--     [{'alt'}]  = warp_window,
--   }
-- })
-- sigils:start()
-- ```
---@class spoon.WindowSigils
local M = {}
spoon.WindowSigils = M

-- Binds hotkeys for WindowSigils
--
-- Parameters:
--  * mapping - A table containing hotkey objifier/key details for the following items:
--   * enter - Enter the sigil mode
function M:bindHotkeys(mapping, ...) end

-- Bind an extra action to be triggered by a key in the sigil mode.
--
-- Parameters:
--   * mods - The key modifiers
--   * key - The key
--   * action - A function, called with no parameters.
function M:bindModeKey(mods, key, action, ...) end

-- Bind an action to be triggered in the sigil mode when a window's sigil key is pressed.
--
-- Parameters:
--   * mods - The modifiers which must be held to trigger this action.
--   * action - A function which takes a window object and performs this action.
function M:bindSigilAction(mods, action, ...) end

-- Configures the spoon.
--
-- Parameters:
--   * configuration - :
--    * hotkeys
--    * mode_keys - a table of key specs (e.g. {{'shift'}, 'n'}) to functions.  The keys are
--      mapped inside the sigil mode and the key is no longer used as a window sigil.
--    * sigil_actions - a table of mod specs (e.g. {'alt'}) to functions.  When the sigil is
--      used in the sigil mode with the specified modifier pressed, the function is invoked
--      with a window object.
function M:configure(configuration, ...) end

-- Logger object used within the Spoon. Can be accessed to set the default log level for the messages coming from the Spoon.
M.logger = nil

-- A list of windows, in the order sigils are assigned.
function M:orderedWindows() end

-- Rerender all window sigils.
--
-- Parameters:
function M:refresh() end

-- Starts rendering the sigils and handling hotkeys
--
-- Parameters:
function M:start() end

-- Stops rendering the sigils and handling hotkeys
--
-- Parameters:
function M:stop() end

-- Find the window with the given index or sigil.
--
-- Parameters:
--  * sigil - If a number, the index of the window; if a string, the sigil of the window.
--    Can also be 'North', 'East', 'South', or 'West' to find a window related to the
--    currently focused window.
function M:window(sigil, ...) end

