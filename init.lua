--require('mobdebug').start()
require('ui')
collectgarbage('generational')

App = ui.control.broker:new()
App:start()
