local power = require("scripts/power")

local interface = {
  power_rescan_networks = function()
    power.rescan_worlds()
  end
}

return {
  add_remote_interface = function()
    if not remote.interfaces["graftorio"] then
      remote.add_interface("graftorio", interface)
    end
  end
}