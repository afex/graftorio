local power = require("scripts/power")
local plugin = require("scripts/plugins")

local interface = {
  power_rescan_networks = function()
    power.rescan_worlds()
  end,
  get_plugin_events = function()
    return plugin.get_events()
  end,
  get_prometheus = function()
    return prometheus
  end
}

return {
  add_remote_interface = function()
    if not remote.interfaces["graftorio"] then
      remote.add_interface("graftorio", interface)
    end
  end
}
