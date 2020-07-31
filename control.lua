prometheus = require("prometheus/prometheus")

local handler = require("event_handler")

gauges = {}
histograms = {}

handler.add_lib(require("scripts/statics"))
handler.add_lib(require("scripts/force_stats"))
handler.add_lib(require("scripts/trains"))

handler.add_lib(
  {
    ["on_nth_tick"] = {
      [600] = function(event)
        game.write_file("graftorio/game.prom", prometheus.collect(), false)
      end
    }
  }
)
