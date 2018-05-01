# graftorio

visualize metrics from your factorio game in grafana

## Installation

- install the mod via the game client
- install docker
- download this repo
- if not using windows, edit `docker-compose.yml` and uncomment the correct path to your factorio install
- using a terminal, run `docker-compose up`
- load `localhost:3000` in a browser
- login with admin:admin and create a prometheus data source using `http://exporter:9090` as address
- enable mod and load up your game
- use grafana to define dashboard
