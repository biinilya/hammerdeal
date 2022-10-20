local M = {}
M.__index = M

M.name = "ui.control"
M.version = "0.1"
M.author = "http://github.com/biinilya"
M.license = "MIT - https://opensource.org/licenses/MIT"

M.app = require('ui.control.app')
M.broker = require('ui.control.broker')
M.layout = require('ui.control.layout')
M.view = require('ui.control.view')
M.mod = M

return M
