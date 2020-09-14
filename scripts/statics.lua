local translate = require("scripts/translation")
gauges.tick = prometheus.gauge("factorio_tick", "game tick")
gauges.players_online = prometheus.gauge("factorio_online_players", "online players")
gauges.seed = prometheus.gauge("factorio_seed", "seed", {"surface"})
gauges.mods = prometheus.gauge("factorio_mods", "mods", {"name", "version"})

gauges.pollution_production_input = prometheus.gauge("factorio_pollution_production_input", "pollutions produced", {"name", "localised_name"})
gauges.pollution_production_output = prometheus.gauge("factorio_pollution_production_output", "pollutions consumed", {"name", "localised_name"})

local lib = {
  events = {
    [defines.events.on_tick] = function(event)
      if event.tick % 600 == 520 then
        local gauges = gauges
        local table_size = table_size

        gauges.tick:set(event.tick)
        gauges.players_online:set(table_size(game.connected_players))

        for _, surface in pairs(game.surfaces) do
          gauges.seed:set(surface.map_gen_settings.seed, {surface.name})
        end

        for name, version in pairs(game.active_mods) do
          gauges.mods:set(1, {name, version})
        end

        local stats = {
          {game.pollution_statistics, gauges.pollution_production_input, gauges.pollution_production_output, "entity-name"}
        }

        for _, stat in pairs(stats) do
          for name, n in pairs(stat[1].input_counts) do
            translate.translate(
              {stat[4] .. "." .. name},
              function(translated)
                stat[2]:set(n, {name, translated})
              end
            )
          end

          for name, n in pairs(stat[1].output_counts) do
            translate.translate(
              {stat[4] .. "." .. name},
              function(translated)
                stat[3]:set(n, {name, translated})
              end
            )
          end
        end
      end
    end
  }
}
return lib
