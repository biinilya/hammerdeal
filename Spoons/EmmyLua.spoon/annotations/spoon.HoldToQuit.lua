--# selene: allow(unused_variable)
---@diagnostic disable: unused-local

-- Instead of pressing ⌘Q, hold ⌘Q to close applications.
---@class spoon.HoldToQuit
local M = {}
spoon.HoldToQuit = M

-- Binds hotkeys for HoldToQuit
--
-- Parameters:
--  * mapping - A table containing hotkey modifier/key details for the following items:
--   * show - This will define the quit hotkey
function M:bindHotkeys(mapping, ...) end

-- Default hotkey mapping
M.defaultHotkey = nil

-- Integer containing the duration (in seconds) how long to hold
-- the hotkey. Default 1.
M.duration = nil

-- Hotkey object
M.hotkeyQbj = nil

-- Initialize spoon
--
-- Parameters:
--  * None
function M:init() end

-- Kill the frontmost application
--
-- Parameters:
--  * None
function M.killCurrentApp() end

-- Start timer on keyDown
--
-- Parameters:
--  * None
function M:onKeyDown() end

-- Stop Timer & show alert message
--
-- Parameters:
--  * None
function M:onKeyUp() end

-- Start HoldToQuit with default hotkey
--
-- Parameters:
--  * None
function M:start() end

-- Disable HoldToQuit hotkey
--
-- Parameters:
--  * None
function M:stop() end

-- Timer for counting the holding time
M.timer = nil

