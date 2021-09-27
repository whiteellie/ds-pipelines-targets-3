library(targets)
library(tarchetypes)
library(tibble)
library(dplyr)

options(tidyverse.quiet = TRUE)
tar_option_set(packages = c("tidyverse", "dataRetrieval", "urbnmapr", "rnaturalearth", "cowplot", "lubridate", "leaflet", "leafpop", "htmlwidgets"))

# Load functions needed by targets below
source("1_fetch/src/find_oldest_sites.R")
source("1_fetch/src/get_site_data.R")
source("3_visualize/src/map_sites.R")
source("2_process/src/tally_site_obs.R")
source("3_visualize/src/plot_site_data.R")
source("3_visualize/src/plot_data_coverage.R")
source("2_process/src/summarize_targets.R")
source("3_visualize/src/map_timeseries.R")

# Configuration
states <- c('WI','MN','MI', 'IL', 'IN', 'IA')
parameter <- c('00060')

# Targets

# Static branching with splitting, appliers, and now combiners (this is why it's outside of the list)
mapped_by_state_targets <- tar_map(
  values = tibble(state_abb = states)%>%
    mutate(state_plot_files = sprintf("3_visualize/out/timeseries_%s.png", state_abb)),
  tar_target(nwis_inventory, get_state_inventory(sites_info = oldest_active_sites, state_abb)),
  tar_target(nwis_data, get_site_data(nwis_inventory, state_abb, parameter)),
  tar_target(tally, tally_site_obs(nwis_data)),
  tar_target(timeseries_png, plot_site_data(state_plot_files, nwis_data, parameter), format = "file"),
  names = state_abb,
  unlist = FALSE
)

list(
  # Identify oldest sites
  tar_target(oldest_active_sites, find_oldest_sites(states, parameter)),

  # defined above
  mapped_by_state_targets,

  # combine tally_[state], the third target in tar_map
  tar_combine(obs_tallies, mapped_by_state_targets[3], command = combine_obs_tallies(!!!.x)),

  # combiner meant to summarize
  tar_combine(
    summary_state_timeseries_csv,
    mapped_by_state_targets[4],
    command = summarize_targets('3_visualize/log/summary_state_timeseries.csv', !!!.x),
    format="file"
  ),

  # use the combined tallies
  tar_target(
    data_coverage_png,
    plot_data_coverage(obs_tallies, "3_visualize/out/data_coverage.png", parameter),
    format = "file"),

  # Map oldest sites
  tar_target(
    site_map_png,
    map_sites("3_visualize/out/site_map.png", oldest_active_sites),
    format = "file"
  ),

  tar_target(
    timeseries_map_html,
    map_timeseries(oldest_active_sites, summary_state_timeseries_csv, "3_visualize/out/timeseries_map.html"),
    format = "file")
)
