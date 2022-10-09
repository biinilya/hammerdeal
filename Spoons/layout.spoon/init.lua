--- === layout ===
---
--- Autoswich layout according to needs
---
--- Download:
local obj = {}
obj.__index = obj

-- Metadata
obj.name = "layout"
obj.version = "0.0.1"
obj.author = "_author_ <email>"
obj.homepage = ""
obj.license = "MIT - https://opensource.org/licenses/MIT"

--- layout:helloWorld()
--- Method
--- Hello World Spoon Sample
---
--- Parameters:
---  * name - A `string` value
---
--- Returns:
---  * None
---
--- Notes:
---  * None
function obj:helloWorld(name)
  print(string.format('Hello %s from %s', name, self.name))
end

return obj
