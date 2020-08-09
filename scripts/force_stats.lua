local translate = require("scripts/translation")
gauges.evolution = prometheus.gauge("factorio_evolution", "evolution", {"force", "type"})

gauges.item_production_input = prometheus.gauge("factorio_item_production_input", "items produced", {"force", "name", "localised_name"})
gauges.item_production_output = prometheus.gauge("factorio_item_production_output", "items consumed", {"force", "name", "localised_name"})
gauges.fluid_production_input = prometheus.gauge("factorio_fluid_production_input", "fluids produced", {"force", "name", "localised_name"})
gauges.fluid_production_output = prometheus.gauge("factorio_fluid_production_output", "fluids consumed", {"force", "name", "localised_name"})
gauges.kill_count_input = prometheus.gauge("factorio_kill_count_input", "kills", {"force", "name", "localised_name"})
gauges.kill_count_output = prometheus.gauge("factorio_kill_count_output", "losses", {"force", "name", "localised_name"})
gauges.entity_build_count_input = prometheus.gauge("factorio_entity_build_count_input", "entities placed", {"force", "name", "localised_name"})
gauges.entity_build_count_output = prometheus.gauge("factorio_entity_build_count_output", "entities removed", {"force", "name", "localised_name"})

gauges.items_launched = prometheus.gauge("factorio_items_launched_total", "items launched in rockets", {"force", "name", "localised_name"})

local lib = {
  on_nth_tick = {
    [600] = function(event)
      local gauges = gauges

      -- reset research gauge
      gauges.research_queue = renew_gauge(gauges.research_queue, "factorio_research_queue", "research", {"force", "name", "level", "index", "localised_name"})
      gauges.logistic_network_items =
        renew_gauge(gauges.logistic_network_items, "factorio_logistics_items", "Items in logistics", {"force", "surface", "network_idx", "name", "localised_name"})
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
        local previous = force.previous_research
        if previous then
          translate.translate(
            previous.localised_name,
            function(translated)
              gauges.research_queue:set(previous.researched and 1 or 0, {force_name, name, previous.level, -1, translated})
            end
          )
        end
        local levels = {}
        for idx, tech in pairs(force.research_queue or {force.current_research}) do
          levels[tech.name] = levels[tech.name] and levels[tech.name] + 1 or tech.level
          translate.translate(
            tech.localised_name,
            function(translated)
              gauges.research_queue:set(idx == 1 and force.research_progress or 0, {force_name, name, levels[tech.name], idx, translated})
            end
          )
        end

        local stats = {
          {force.item_production_statistics, gauges.item_production_input, gauges.item_production_output, "item-name"},
          {force.fluid_production_statistics, gauges.fluid_production_input, gauges.fluid_production_output, "fluid-name"},
          {force.kill_count_statistics, gauges.kill_count_input, gauges.kill_count_output, "entity-name"},
          {force.entity_build_count_statistics, gauges.entity_build_count_input, gauges.entity_build_count_output, "entity-name"}
        }

        for _, stat in pairs(stats) do
          for name, n in pairs(stat[1].input_counts) do
            translate.translate(
              {stat[4] .. "." .. name},
              function(translated)
                stat[2]:set(n, {force_name, name, translated})
              end
            )
          end

          for name, n in pairs(stat[1].output_counts) do
            translate.translate(
              {stat[4] .. "." .. name},
              function(translated)
                stat[3]:set(n, {force_name, name, translated})
              end
            )
          end
        end

        for name, n in pairs(force.items_launched) do
          translate.translate(
            {"item." .. name},
            function(translated)
              gauges.items_launched:set(n, {force_name, name, translated})
            end
          )
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
              translate.translate(
                {"item-name." .. name},
                function(translated)
                  gauges.logistic_network_items:set(v, {force_name, surface, idx, name, translated})
                end
              )
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
