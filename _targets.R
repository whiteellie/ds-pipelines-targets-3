library(targets)
library(tarchetypes)
library(tibble)
library(dplyr)
library(retry)

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
# states <- c('WI', 'MN', 'MI')
states <- c('AL','AZ','AR','CA','CO','CT','DE','DC','FL','GA','ID','IL','IN','IA',
          'KS','KY','LA','ME','MD','MA','MI','MN','MS','MO','MT','NE','NV','NH',
          'NJ','NM','NY','NC','ND','OH','OK','OR','PA','RI','SC','SD','TN','TX',
          'UT','VT','VA','WA','WV','WI','WY','AK','HI','GU','PR')
parameter <- c('00060')

# Targets
list(
  # Identify oldest sites
  tar_target(oldest_active_sites, find_oldest_sites(states, parameter)),

  # tar_target(nwis_inventory, get_state_inventory(sites_info = oldest_active_sites, state_abb)), # this was static branching
  # dynamic branching
  tar_target(nwis_inventory,
             oldest_active_sites %>%
               group_by(state_cd) %>%
               tar_group(), # note this!
             iteration = "group"), # since we grouped we don't need to branch by lists

  tar_target(nwis_data,
             retry(get_site_data(site_info=nwis_inventory, state=nwis_inventory$state_cd, parameter=parameter), when="Ugh, the internet data transfer failed!", max_tries=30),
             pattern = map(nwis_inventory)), # pattern turns it into dynamic branching

  tar_target(tally,
             tally_site_obs(nwis_data),
             pattern = map(nwis_data)),

  tar_target(timeseries_png,
             plot_site_data(sprintf("3_visualize/out/timeseries_%s.png", unique(nwis_data$State)), nwis_data, parameter),
             format = "file",
             pattern = map(nwis_data)),

  # # combine tally_[state], the third target in tar_map, no longer needed cause dynamic branching does this combination for us
  # tar_combine(obs_tallies, mapped_by_state_targets$tally, command = combine_obs_tallies(!!!.x)),

  # combiner meant to summarize
  tar_target(
    summary_state_timeseries_csv,
    command = summarize_targets('3_visualize/log/summary_state_timeseries.csv', vec=names(timeseries_png)),
    format="file"
  ),

  # use the combined tallies
  tar_target(
    data_coverage_png,
    plot_data_coverage(tally, "3_visualize/out/data_coverage.png", parameter),
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
