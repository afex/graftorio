prometheus = require("prometheus/prometheus")
require("utility")
local handler = require("event_handler")
local translate = require("scripts/translation")
local await_export = false

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
handler.add_lib(translate)

-- Keep as last to export it all
handler.add_lib(
  {
    ["on_nth_tick"] = {
      [600] = function(event)
        if translate.in_progress() then
          await_export = true
        else
          doExport()
          await_export = false
        end
      end
    },
    events = {
      [defines.events.on_tick] = function(event)
        if event.tick % 30 == 0 and await_export and not translate.in_progress() then
          doExport()
          await_export = false
        end
      end
    }
  }
)
