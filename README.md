# graftorio

visualize metrics from your factorio game in grafana

![](https://mods-data.factorio.com/assets/89653f5de75cdb227b5140805d632faf41459eee.png)

## What is this?

[grafana](https://grafana.com/) is an open-source project for rendering time-series metrics. by using graftorio, you can create a dashboard with various charts monitoring aspects of your factorio factory. this dashboard is viewed using a web browser outside of the game client. (works great in a 2nd monitor!)

in order to use graftorio, you need to run the grafana software and a database called [prometheus](https://prometheus.io/) locally. graftorio automates this process using docker, or you can set these up by hand.

## Installation

1. download the latest [release](https://github.com/afex/graftorio/releases), and extract it into the location you want to host the local database
1. [install docker](https://docs.docker.com/install/)
  - if using windows, you will need to be running Windows 10 Pro
1. if using macOS or Linux, open the extracted `docker-compose.yml` in a text editor and uncomment the correct path to your factorio install
1. using a terminal, run `docker-compose up` inside the extracted directory
1. load `localhost:3000` in a browser, you should see the grafana login screen
1. login with admin:admin and create a prometheus data source using the exact string `http://prometheus:9090` as its address, and `10s` as the scrape interval. (don't forget the 's')
1.
1. launch factorio
1. install the "graftorio" mod via the mods menu
1. load up your game, and see your statistics in the grafana dashboard

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
