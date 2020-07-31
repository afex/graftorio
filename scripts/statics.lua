local single_set = {
  ["seed"] = false,
  ["mods"] = false
}

gauges.tick = prometheus.gauge("factorio_tick", "game tick")
gauges.players_online = prometheus.gauge("factorio_online_players", "online players")
gauges.seed = prometheus.gauge("factorio_seed", "seed", {"surface"})
gauges.mods = prometheus.gauge("factorio_mods", "mods", {"name", "version"})

local lib = {
  on_nth_tick = {
    [600] = function(event)
      local gauges = gauges
      local table_size = table_size
      gauges.tick:set(event.tick)

      if not single_set.seed then
        for _, surface in pairs(game.surfaces) do
          gauges.seed:set(surface.map_gen_settings.seed, {surface.name})
        end
        single_set.seed = true
      end

      if not single_set.mods then
        for name, version in pairs(game.active_mods) do
          gauges.mods:set(name, {version})
        end
        single_set.mods = true
      end

      gauges.players_online:set(table_size(game.connected_players))
    end
  }
}
return lib
