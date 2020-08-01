local events = {}

local function get_event(name)
  if not events[name] then
    events[name] = script.generate_event_name()
  end

  return events[name]
end

local lib = {
  on_init = function()
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
    return events
  end
}
return lib
