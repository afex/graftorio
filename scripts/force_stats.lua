gauges.evolution = prometheus.gauge("factorio_evolution", "evolution", {"force", "type"})

gauges.item_production_input = prometheus.gauge("factorio_item_production_input", "items produced", {"force", "name"})
gauges.item_production_output = prometheus.gauge("factorio_item_production_output", "items consumed", {"force", "name"})
gauges.fluid_production_input = prometheus.gauge("factorio_fluid_production_input", "fluids produced", {"force", "name"})
gauges.fluid_production_output = prometheus.gauge("factorio_fluid_production_output", "fluids consumed", {"force", "name"})
gauges.kill_count_input = prometheus.gauge("factorio_kill_count_input", "kills", {"force", "name"})
gauges.kill_count_output = prometheus.gauge("factorio_kill_count_output", "losses", {"force", "name"})
gauges.entity_build_count_input = prometheus.gauge("factorio_entity_build_count_input", "entities placed", {"force", "name"})
gauges.entity_build_count_output = prometheus.gauge("factorio_entity_build_count_output", "entities removed", {"force", "name"})

gauges.items_launched = prometheus.gauge("factorio_items_launched_total", "items launched in rockets", {"force", "name"})

local lib = {
  on_nth_tick = {
    [600] = function(event)
      local gauges = gauges

      -- reset research gauge
      gauges.research_queue = renew_gauge(gauges.research_queue, "factorio_research_queue", "research", {"force", "name", "level", "index"})
      gauges.logistic_network_items = renew_gauge(gauges.logistic_network_items, "factorio_logistics_items", "Items in logistics", {"force", "surface", "network_idx", "name"})
      gauges.logistic_network_bots = renew_gauge(gauges.logistic_network_bots, "factorio_logistics_bots", "Bots in logistic networks", {"force", "surface", "network_idx", "type"})

      for _, force in pairs(game.forces) do
        local force_name = force.name
        local evolution = {
          {force.evolution_factor, "total"},
          {force.evolution_factor_by_pollution, "by_polution"},
          {force.evolution_factor_by_time, "by_time"},
          {force.evolution_factor_by_killing_spawners, "by_killing_spawners"}
        }
        for _, stat in pairs(evolution) do
          gauges.evolution:set(stat[1], {force_name, stat[2]})
        end

        -- Levels dont get matched properly so store and save
        local levels = {}
        for idx, tech in pairs(force.research_queue) do
          local cur_level = 1
          if tech.upgrade then
            levels[tech.name] = levels[tech.name] and levels[tech.name] + 1 or tech.level
            cur_level = levels[tech.name]
          end
          gauges.research_queue:set(idx == 1 and force.research_progress or 0, {force_name, tech.name, cur_level, idx})
        end

        local stats = {
          {force.item_production_statistics, gauges.item_production_input, gauges.item_production_output},
          {force.fluid_production_statistics, gauges.fluid_production_input, gauges.fluid_production_output},
          {force.kill_count_statistics, gauges.kill_count_input, gauges.kill_count_output},
          {force.entity_build_count_statistics, gauges.entity_build_count_input, gauges.entity_build_count_output}
        }

        for _, stat in pairs(stats) do
          for name, n in pairs(stat[1].input_counts) do
            stat[2]:set(n, {force_name, name})
          end

          for name, n in pairs(stat[1].output_counts) do
            stat[3]:set(n, {force_name, name})
          end
        end

        for name, n in pairs(force.items_launched) do
          gauges.items_launched:set(n, {force_name, name})
        end

        local bot_stats = {
          "available_logistic_robots",
          "all_logistic_robots",
          "available_construction_robots",
          "all_construction_robots"
        }
        for surface, networks in pairs(force.logistic_networks) do
          for idx, network in pairs(networks) do
            for name, n in pairs(network.get_contents()) do
              local v = (n + 2 ^ 31) % 2 ^ 32 - 2 ^ 31
              gauges.logistic_network_items:set(v, {force_name, surface, idx, name})
            end
            for _, src in pairs(bot_stats) do
              gauges.logistic_network_bots:set(network[src], {force_name, surface, idx, src})
            end
            local charging = 0
            local waiting_for_charge = 0
            for _, cell in pairs(network.cells) do
              charging = charging + cell.charging_robot_count
              waiting_for_charge = waiting_for_charge + cell.to_charge_robot_count
            end
            gauges.logistic_network_bots:set(charging, {force_name, surface, idx, "charging_bots"})
            gauges.logistic_network_bots:set(waiting_for_charge, {force_name, surface, idx, "waiting_for_charge"})
          end
        end
      end
    end
  }
}

return lib
