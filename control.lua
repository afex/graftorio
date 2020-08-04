prometheus = require("prometheus/prometheus")
require("utility")
local handler = require("event_handler")

gauges = {}
histograms = {}

function doExport()
  game.write_file("graftorio/game.prom", prometheus.collect(), false)
end

handler.add_lib(require("scripts/statics"))
handler.add_lib(require("scripts/force_stats"))
handler.add_lib(require("scripts/trains"))
handler.add_lib(require("scripts/power"))
handler.add_lib(require("scripts/plugins"))
handler.add_lib(require("scripts/remote"))

-- Keep as last to export it all
handler.add_lib(
  {
    ["on_nth_tick"] = {
      [600] = function(event)
        doExport()
      end
    }
  }
)
