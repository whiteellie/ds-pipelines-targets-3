library(targets)
library(tarchetypes)
library(tibble)
library(dplyr)

options(tidyverse.quiet = TRUE)
tar_option_set(packages = c("tidyverse", "dataRetrieval", "urbnmapr", "rnaturalearth", "cowplot", "lubridate"))

# Load functions needed by targets below
source("1_fetch/src/find_oldest_sites.R")
source("1_fetch/src/get_site_data.R")
source("3_visualize/src/map_sites.R")
source("2_process/src/tally_site_obs.R")
source("3_visualize/src/plot_site_data.R")

# Configuration
states <- c('WI','MN','MI', 'IL', 'IN', 'IA')
parameter <- c('00060')

# Targets
list(
  # Identify oldest sites
  tar_target(oldest_active_sites, find_oldest_sites(states, parameter)),

  # # TODO: PULL SITE DATA HERE
  # tar_target(wi_data, get_site_data(oldest_active_sites, states[1], parameter)),
  # tar_target(mn_data, get_site_data(oldest_active_sites, states[2], parameter)),
  # tar_target(mi_data, get_site_data(oldest_active_sites, states[3], parameter)),

  # Static branching with splitting and appliers
  tar_map(
    values = tibble(state_abb = states)%>%
      mutate(state_plot_files = sprintf("3_visualize/out/timeseries_%s.png", state_abb)),
    tar_target(nwis_inventory, get_state_inventory(sites_info = oldest_active_sites, state_abb)),
    tar_target(nwis_data, get_site_data(nwis_inventory, state_abb, parameter)),
    tar_target(tally, tally_site_obs(nwis_data)),
    tar_target(timeseries_png, plot_site_data(state_plot_files, nwis_data, parameter)),
    names = state_abb
    ),

  # Map oldest sites
  tar_target(
    site_map_png,
    map_sites("3_visualize/out/site_map.png", oldest_active_sites),
    format = "file"
  )
)
