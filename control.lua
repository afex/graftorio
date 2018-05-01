prometheus = require("prometheus/prometheus")

gauge_item_production_input = prometheus.gauge("item_production_input", "items produced", {"force", "name"})
gauge_item_production_output = prometheus.gauge("item_production_output", "items consumed", {"force", "name"})
gauge_fluid_production_input = prometheus.gauge("fluid_production_input", "fluids produced", {"force", "name"})
gauge_fluid_production_output = prometheus.gauge("fluid_production_output", "fluids consumed", {"force", "name"})

script.on_event(defines.events.on_tick, function(event)
  if event.tick % 600 == 0 then
    for _, player in pairs(game.players) do

      stats = {
        {player.force.item_production_statistics, gauge_item_production_input, gauge_item_production_output},
        {player.force.fluid_production_statistics, gauge_fluid_production_input, gauge_fluid_production_output},
        -- player.force.kill_count_statistics,
        -- player.force.entity_build_count_statistics,
      }

      for _, stat in pairs(stats) do
        for name, n in pairs(stat[1].input_counts) do
          stat[2]:set(n, {player.force.name, name})
        end

        for name, n in pairs(stat[1].output_counts) do
          stat[3]:set(n, {player.force.name, name})
        end
      end
    end

    game.write_file("metrics/game.prom", prometheus.collect(), false)
  end
end)
