# graftorio

visualize metrics from your factorio game in grafana

## Installation

- install the "graftorio" mod via the game client
- install docker
- download the latest release from the github releases page, and extract it into the location you want to host your prometheus and grafana databases
- if not using windows, edit `docker-compose.yml` and uncomment the correct path to your factorio install
- using a terminal, run `docker-compose up`
- load `localhost:3000` in a browser
- login with admin:admin and create a prometheus data source using the exact string `http://prometheus:9090` as its address, and `10s` as the scrape interval. (don't forget the 's')
- enable mod and load up your game
- use grafana to define dashboard

## Debugging

### mod

to see if factorio is generating stats, confirm a `game.prom` file exists at the configured exporter volume directory.  when opened, it should look something like this:

```
# HELP factorio_item_production_input items produced
# TYPE factorio_item_production_input gauge
factorio_item_production_input{force="player",name="burner-mining-drill"} 3
factorio_item_production_input{force="player",name="iron-chest"} 1
```

### prometheus

to see if prometheus is scraping the data, load `localhost:9090/targets` in a browser and confirm that the status is "UP"

### grafana

to see if the grafana data source can read correctly, start a new dashboard and add a graph with the query `factorio_item_production_input`. the graph should render the total of every item produced in your game.
