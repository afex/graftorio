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

local function collect_production()
  local gauges = gauges
  local item_prototypes = game.item_prototypes
  local entity_prototypes = game.entity_prototypes
  local fluid_prototypes = game.fluid_prototypes

  -- reset research gauge
  gauges.research_queue = renew_gauge(gauges.research_queue, "factorio_research_queue", "research", {"force", "name", "level", "index", "localised_name"})
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

    local researched_queue = global.last_research and global.last_research[force_name] or false
    if researched_queue then
      translate.translate(
        researched_queue.localised_name,
        function(translated)
          gauges.research_queue:set(researched_queue.researched and 1 or 0, {force_name, researched_queue.name, researched_queue.level, -1, translated})
        end
      )
    end

    -- Levels dont get matched properly so store and save
    local levels = {}
    for idx, tech in pairs(force.research_queue or {force.current_research}) do
      levels[tech.name] = levels[tech.name] and levels[tech.name] + 1 or tech.level
      translate.translate(
        tech.localised_name,
        function(translated)
          gauges.research_queue:set(idx == 1 and force.research_progress or 0, {force_name, tech.name, levels[tech.name], idx, translated})
        end
      )
    end

    local stats = {
      {force.item_production_statistics, gauges.item_production_input, gauges.item_production_output, item_prototypes},
      {force.fluid_production_statistics, gauges.fluid_production_input, gauges.fluid_production_output, fluid_prototypes},
      {force.kill_count_statistics, gauges.kill_count_input, gauges.kill_count_output, entity_prototypes},
      {force.entity_build_count_statistics, gauges.entity_build_count_input, gauges.entity_build_count_output, entity_prototypes}
    }

    for _, stat in pairs(stats) do
      for name, n in pairs(stat[1].input_counts) do
        translate.translate(
          stat[4][name].localised_name,
          function(translated)
            stat[2]:set(n, {force_name, name, translated})
          end
        )
      end

      for name, n in pairs(stat[1].output_counts) do
        translate.translate(
          stat[4][name].localised_name,
          function(translated)
            stat[3]:set(n, {force_name, name, translated})
          end
        )
      end
    end

    for name, n in pairs(force.items_launched) do
      if item_prototypes[name] then
        translate.translate(
          item_prototypes[name].localised_name,
          function(translated)
            gauges.items_launched:set(n, {force_name, name, translated})
          end
        )
      else
        gauges.items_launched:set(n, {force_name, name, name})
      end
    end
  end
end

local function collect_networks()
  local gauges = gauges
  local item_prototypes = game.item_prototypes
  gauges.logistic_network_items =
    renew_gauge(
    gauges.logistic_network_items,
    "factorio_logistics_items",
    "Items in logistics",
    {"force", "surface", "network_idx", "name", "localised_name", "point_type", "request_type"}
  )
  gauges.logistic_network_bots =
    renew_gauge(gauges.logistic_network_bots, "factorio_logistics_bots", "Bots in logistic networks", {"force", "surface", "network_idx", "type", "network_type", "network_name"})
  for _, force in pairs(game.forces) do
    local force_name = force.name
    local bot_stats = {
      "available_logistic_robots",
      "all_logistic_robots",
      "available_construction_robots",
      "all_construction_robots"
    }
    for surface, networks in pairs(force.logistic_networks) do
      for idx, network in pairs(networks) do
        local charging = 0
        local waiting_for_charge = 0
        local net_type = nil

        for _, cell in pairs(network.cells) do
          charging = charging + cell.charging_robot_count
          waiting_for_charge = waiting_for_charge + cell.to_charge_robot_count
          if not net_type then
            net_type = {cell.owner.type, cell.owner.localised_name}
          end
        end
        translate.translate(
          net_type[2],
          function(translated)
            gauges.logistic_network_bots:set(charging, {force_name, surface, idx, "charging_bots", net_type[1], translated})
            gauges.logistic_network_bots:set(waiting_for_charge, {force_name, surface, idx, "waiting_for_charge", net_type[1], translated})
            gauges.logistic_network_bots:set(network.robot_limit, {force_name, surface, idx, "robot_limit", net_type[1], translated})
          end
        )

        for name, n in pairs(network.get_contents()) do
          local v = (n + 2 ^ 31) % 2 ^ 32 - 2 ^ 31
          if item_prototypes[name] then
            translate.translate(
              item_prototypes[name].localised_name,
              function(translated)
                gauges.logistic_network_items:set(v, {force_name, surface, idx, name, translated, "contents"})
              end
            )
          else
            gauges.logistic_network_items:set(v, {force_name, surface, idx, name, name, "contents"})
          end
        end

        -- Collect the pickups and deliveries
        for point_type, point_list in pairs({provider = network.provider_points, requester = network.requester_points, storage = network.storage_points}) do
          local pickup = {}
          local deliver = {}
          for _, point in pairs(point_list) do
            for name, qty in pairs(point.targeted_items_pickup) do
              pickup[name] = (pickup[name] or 0) + qty
            end
            for name, qty in pairs(point.targeted_items_deliver) do
              deliver[name] = (deliver[name] or 0) + qty
            end
          end

          for request_type, values in pairs({["pickup"] = pickup, ["deliver"] = deliver}) do
            for name, qty in pairs(values) do
              if item_prototypes[name] then
                translate.translate(
                  item_prototypes[name].localised_name,
                  function(translated)
                    gauges.logistic_network_items:set(qty, {force_name, surface, idx, name, translated, point_type, request_type})
                  end
                )
              else
                gauges.logistic_network_items:set(qty, {force_name, surface, idx, name, name, point_type, request_type})
              end
            end
          end
        end

        for _, src in pairs(bot_stats) do
          translate.translate(
            net_type[2],
            function(translated)
              gauges.logistic_network_bots:set(network[src], {force_name, surface, idx, src, net_type[1], translated})
            end
          )
        end
      end
    end
  end
end

local lib = {
  events = {
    [defines.events.on_research_finished] = function(event)
      local research = event.research
      if not global.last_research then
        global.last_research = {}
      end

      local level = research.level
      -- Previous research is incorrect lvl if it has more than one research
      if level > 1 then
        level = level - 1
      end

      global.last_research[research.force.name] = {
        researched = 1,
        name = research.name,
        localised_name = research.localised_name,
        level = level
      }
    end,
    [defines.events.on_tick] = function(event)
      local rest = event.tick % 600
      if rest == 0 then
        collect_production()
      elseif rest == 40 then
        collect_networks()
      end
    end
  }
}

return lib
