prometheus = require("prometheus/prometheus")
require("utility")
local handler = require("event_handler")
gauges = {}
histograms = {}

-- All the events are split into the 10 second export time (600 ticks)
--
-- export: 0 - 40
-- force_stats: 60, 80
-- trains: 120
-- power: 240
-- plugins: 300
-- statics: 520
--
-- The first few exports are slow since they require the translations

handler.add_lib(require("scripts/statics"))
handler.add_lib(require("scripts/force_stats"))
handler.add_lib(require("scripts/trains"))
handler.add_lib(require("scripts/power"))
handler.add_lib(require("scripts/plugins"))
handler.add_lib(require("scripts/remote"))
handler.add_lib(require("scripts/translation"))

-- Keep as last to export it all
handler.add_lib(require("scripts/export"))
