summarize_targets <- function(ind_file, tar_names) {
  ind_tbl <- tar_meta(c(all_of(tar_names))) %>%
    select(tar_name = name, filepath = path, hash = data) %>%
    mutate(filepath = unlist(filepath))

  readr::write_csv(ind_tbl, ind_file)
  return(ind_file)
}
