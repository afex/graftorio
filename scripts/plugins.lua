local script_data = {
  events = {}
}

local function get_event(name)
  local events = script_data.events
  if not events[name] then
    events[name] = script.generate_event_name()
  end

  return events[name]
end

local lib = {
  on_load = function()
    script_data = global.custom_events or script_data
  end,
  on_init = function()
    global.custom_events = global.custom_events or script_data
    -- create the event
    get_event("graftorio_add_stats")
  end,
  events = {
    [defines.events.on_tick] = function(event)
      if event.tick % 600 == 300 then
        script.raise_event(
          get_event("graftorio_add_stats"),
          {
            tick = event.tick,
            prometheus = prometheus
          }
        )
      end
    end
  },
  get_events = function()
    return script_data.events
  end
}
return lib
