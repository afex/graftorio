# graftorio

visualize metrics from your factorio game in grafana

## Installation

- install the "graftorio" mod via the game client
- install docker
- download the latest release from the github releases page, and extract it into the location you want to host your prometheus and grafana databases
- if not using windows, edit `docker-compose.yml` and uncomment the correct path to your factorio install
- using a terminal, run `docker-compose up`
- load `localhost:3000` in a browser
- login with admin:admin and create a prometheus data source using the exact string `http://prometheus:9090` as its address.
- enable mod and load up your game
- use grafana to define dashboard
