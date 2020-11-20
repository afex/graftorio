local translate = {
  config = {
    batch_size = 15
  }
}

local script_data = {
  translations = {},
  translation_request = {},
  translation_in_progress = {},
  translation_tries = {}
}

local table_size = table_size
local function request_translate(request, callback)
  if not script_data.translation_request[request] then
    script_data.translation_request[request] = {}
  end
  table.insert(script_data.translation_request[request], callback)
end

function translate.translate(request, callback)
  callback = callback or function(args)
      return args
    end

  if type(request) == "table" then
    request = game.table_to_json(request)
  end

  request = game.encode_string(request)

  if script_data.translations[request] then
    return callback(script_data.translations[request])
  end

  request_translate(request, callback)

  return false
end

function translate.in_progress()
  return table_size(script_data.translation_request) > 0 or table_size(script_data.translation_in_progress) > 0
end

function translate.on_load()
  script_data = global.translation_script or script_data
end

function translate.on_init()
  global.translation_script = global.translation_script or script_data
end

function translate.on_configuration_changed(event)
  -- Make sure to reset the script_data
  script_data = {
    translations = {},
    translation_request = {},
    translation_in_progress = {},
    translation_tries = {}
  }
  global.translation_script = script_data
end

translate.events = {
  [defines.events.on_tick] = function(event)
    if event.tick % 20 == 10 and #script_data.translation_in_progress > 0 then
      local remove = {}
      for r, progres in pairs(script_data.translation_in_progress) do
        -- Event took longer than 5 seconds, reschedule
        if event.tick - progres.tick > 60 * 5 then
          if script_data.translation_tries[r] > 5 then
            -- stop trying
            debug("Failed to translate string " .. r)
            table.insert(remove, r)
          else
            script_data.translation_request[r] = progres.callbacks
            table.insert(remove, r)
          end
        end
      end
      for _, i in pairs(remove) do
        script_data.translation_in_progress[i] = nil
      end
    end

    if event.tick % 20 == 0 and table_size(script_data.translation_request) > 0 then
      if table_size(game.connected_players) > 0 then
        local i = 1
        local remove = {}
        local json_to_table = game.json_to_table
        for _, player in pairs(game.connected_players) do
          for request_string, callbacks in pairs(script_data.translation_request) do
            if not remove[request_string] then
              if i == translate.config.batch_size then
                break
              end
              local decoded_string = game.decode_string(request_string)
              if decoded_string:sub(1, 1) == "{" or decoded_string:sub(1, 1) == "[" then
                player.request_translation(json_to_table(decoded_string))
              else
                player.request_translation(decoded_string)
              end
              script_data.translation_in_progress[request_string] = {tick = event.tick, callbacks = callbacks}
              script_data.translation_tries[request_string] = (script_data.translation_tries[request_string] or 0) + 1
              remove[request_string] = true
              i = i + 1
            end
          end
        end

        for key, _ in pairs(remove) do
          script_data.translation_request[key] = nil
        end
      end
    end
  end,
  [defines.events.on_string_translated] = function(event)
    local result = event.result
    local str = event.localised_string
    if type(str) == "table" then
      str = game.table_to_json(str)
    end
    str = game.encode_string(str)
    if not event.translated then
      result = event.localised_string[1]:gsub("entity%-name%.", ""):gsub("technology%-name%.", ""):gsub("recipe%-name%.", ""):gsub("item%-name%.", ""):gsub("fluid%-name%.", "")
    end
    script_data.translations[str] = result
    if #script_data.translation_in_progress and script_data.translation_in_progress[str] and #script_data.translation_in_progress[str].callbacks then
      for _, cb in pairs(script_data.translation_in_progress[str].callbacks) do
        cb(result)
      end
    end
    script_data.translation_in_progress[str] = nil
  end
}

return translate
