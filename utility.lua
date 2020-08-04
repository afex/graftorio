local registry = prometheus.get_registry()
function renew_gauge(gauge, name, help, labels)
  if gauge then
    registry:unregister(gauge)
  end

  gauge = prometheus.gauge(name, help, labels)

  return gauge
end
