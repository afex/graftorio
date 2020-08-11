local translate = {
  config = {
    batch_size = 15
  }
}

local script_data = {
  translations = {},
  translation_request = {},
  translation_in_progress = {},
  proxies = {}
}

local table_size = table_size
local proxies = {}

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
    proxies = {}
  }
  if not global.translation_script then
    global.translation_script = script_data
  end
end

translate.events = {
  [defines.events.on_tick] = function(event)
    if event.tick % 20 == 0 and table_size(script_data.translation_request) > 0 then
      if table_size(game.connected_players) > 0 then
        local i = 1
        local remove = {}
        local json_to_table = game.json_to_table
        for _, player in pairs(game.connected_players) do
          for r, cb in pairs(script_data.translation_request) do
            if not remove[r] then
              if i == translate.config.batch_size then
                break
              end
              if r:sub(1, 1) == "{" or r:sub(1, 1) == "[" then
                player.request_translation(json_to_table(r))
              else
                player.request_translation(r)
              end
              script_data.translation_in_progress[r] = cb
              remove[r] = true
              i = i + 1
            end
          end
        end

        for k, _ in pairs(remove) do
          script_data.translation_request[k] = nil
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
    if not event.translated then
      -- retry
      if event.localised_string[1]:find("item%-name.") ~= nil then
        local replaced = event.localised_string[1]:gsub("item%-name%.", "entity-name.")
        script_data.proxies[game.table_to_json({replaced})] = str
        game.players[event.player_index].request_translation({replaced})
        return
      end
      result = event.localised_string[1]:gsub("entity%-name%.", ""):gsub("technology%-name%.", ""):gsub("recipe%-name%.", ""):gsub("item%-name%.", ""):gsub("fluid%-name%.", "")
    end
    if script_data.proxies[str] then
      local old_str = str
      str = script_data.proxies[str]
      script_data.proxies[old_str] = nil
    end
    script_data.translations[str] = result
    if #script_data.translation_in_progress and script_data.translation_in_progress[str] and #script_data.translation_in_progress[str] then
      for idx, cb in pairs(script_data.translation_in_progress[str]) do
        cb(result)
      end
    end
    script_data.translation_in_progress[str] = nil
  end
}

return translate
