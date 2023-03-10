# This file is part of CohortProfiles

#' It creates columns to indicate overlaps information
#'
#' @param x table containing the individual for which the overlap indicator to be attached as extra columns
#' @param cdm cdm containing the tables
#' @param cohortTableName name of the cohort that we want to check for overlap
#' @param cohortId cohort definition Id to include it can be a list if multiple
#' @param value value of interest to added it can be number,binary,date or time
#' @param window window to consider events of, from date of reference in table x
#' to date of event at event table
#' @param order last or first date to use for date calculation
#' @param cohortName name to give cohortId
#' @param name naming of the added column
#' @param tablePrefix The stem for the permanent tables that will
#' be created. If NULL, temporary tables will be used throughout.
#'
#' @return table with added columns with overlap information
#' @export
#'
#' @examples
#'
#'\dontrun{
#'   cohort1 <- dplyr::tibble(
#'cohort_definition_id = c(1, 1, 1, 1, 1),
#'subject_id = c(1, 1, 1, 2, 2),
#'cohort_start_date = as.Date(
#'  c(
#'    "2020-01-01",
#'    "2020-01-15",
#'    "2020-01-20",
#'    "2020-01-01",
#'    "2020-02-01"
#'  )
#'),
#'cohort_end_date = as.Date(
#'  c(
#'    "2020-01-01",
#'    "2020-01-15",
#'    "2020-01-20",
#'    "2020-01-01",
#'    "2020-02-01"
#'  )
#')
#')
#'
#'cohort2 <- dplyr::tibble(
#'  cohort_definition_id = c(1, 1, 1, 1, 1, 1, 1),
#'  subject_id = c(1, 1, 1, 2, 2, 2, 1),
#'  cohort_start_date = as.Date(
#'    c(
#'      "2020-01-15",
#'      "2020-01-25",
#'      "2020-01-26",
#'      "2020-01-29",
#'      "2020-03-15",
#'      "2020-01-24",
#'      "2020-02-16"
#'    )
#'  ),
#'  cohort_end_date = as.Date(
#'    c(
#'      "2020-01-15",
#'      "2020-01-25",
#'      "2020-01-26",
#'      "2020-01-29",
#'      "2020-03-15",
#'      "2020-01-24",
#'      "2020-02-16"
#'    )
#'  ),
#')
#'
#'cdm <- mockCohortProfiles(cohort1=cohort1, cohort2=cohort2)
#'
#'result <- cdm$cohort1 %>% addCohortIntersect(cdm = cdm,
#'cohortTableName = "cohort2", value = "date") %>% dplyr::collect()
#'}
#'
addCohortIntersect <- function(x,
                               cdm,
                               cohortTableName,
                               cohortId = NULL,
                               value = c("number", "binary", "date", "time"),
                               window = c(0, NA),
                               order = "first",
                               cohortName = NA,
                               name = "{value}_{tableName}_{window}_{order}",
                               tablePrefix = NULL) {
  ## check for user inputs
  errorMessage <- checkmate::makeAssertCollection()

  xCheck <- inherits(x, "tbl_dbi")
  if (!isTRUE(xCheck)) {
    errorMessage$push("- x is not a table")
  }
  cdmCheck <- inherits(cdm, "cdm_reference")
  if (!isTRUE(cdmCheck)) {
    errorMessage$push("- cdm must be a CDMConnector CDM reference object")
  }
  checkmate::reportAssertions(collection = errorMessage)

  ## check for user inputs
  errorMessage <- checkmate::makeAssertCollection()

  tableCheck <- cohortTableName %in% names(cdm)
  if (!isTRUE(tableCheck)) {
    errorMessage$push("- `cohortTableName` is not found in cdm")
  }
  checkmate::assert_integerish(cohortId, len = 1, null.ok = TRUE)
  checkmate::assert_integerish(window, len = 2, null.ok = TRUE)

  valueCheck <-
    value %>% dplyr::intersect(c("number", "binary", "date", "time")) %>% dplyr::setequal(value)
  if (!isTRUE(valueCheck)) {
    errorMessage$push("- `value` must be either 'count','binary','date' or 'time' ")
  }

  orderCheck <- order %in% c("first", "last")
  if (!isTRUE(orderCheck)) {
    errorMessage$push("- `order` must be either 'first' or 'last' ")
  }


  if (!is.na(cohortName)) {
    if (!isTRUE(length(cohortName) == length(cohortId))) {
      errorMessage$push("- cohortName must contain names for each of cohortId ")
    }
  }

  checkmate::assert_character(name, len = 1)

  checkmate::assertCharacter(
    tablePrefix, len = 1, null.ok = TRUE, add = errorMessage
  )

  checkmate::reportAssertions(collection = errorMessage)





  # define overlapcohort table from cdm containing the events of interests
  overlapCohort <- cdm[[cohortTableName]]

  # get the window as character for the naming of the output columns later
  window_pre <- ifelse(is.na(window[1]),"NA",as.character(window[1]))
  window_post <- ifelse(is.na(window[2]),"NA",as.character(window[2]))

  #generate overlappingcohort using code from getoverlappingcohort
  #filter by cohortId
  if (!is.null(cohortId)) {
    overlapCohort <- overlapCohort %>%
      dplyr::rename(
        "overlap_start_date" = "cohort_start_date",
        "overlap_end_date" = "cohort_end_date",
        "overlap_id" = "cohort_definition_id"
      ) %>% dplyr::filter(.data$overlap_id %in% .env$cohortId)
  } else {
    overlapCohort <- overlapCohort %>%
      dplyr::rename(
        "overlap_start_date" = "cohort_start_date",
        "overlap_end_date" = "cohort_end_date",
        "overlap_id" = "cohort_definition_id"
      )
  }

  result <- x %>%
    dplyr::select("subject_id", "cohort_start_date", "cohort_end_date") %>%
    dplyr::distinct() %>%
    dplyr::inner_join(overlapCohort, by = "subject_id")

  if (!is.na(window[2])) {
    result <- result %>%
      dplyr::mutate(overlap_start_date = as.Date(dbplyr::sql(
        CDMConnector::dateadd(date = "overlap_start_date",
                              number = !!-window[2])
      ))) %>%
      dplyr::filter(.data$cohort_start_date >= .data$overlap_start_date)
  }
  if (!is.na(window[1])) {
    result <- result %>%
      dplyr::mutate(overlap_end_date = as.Date(dbplyr::sql(
        CDMConnector::dateadd(date = "overlap_end_date",
                              number = !!-window[1])
      ))) %>%
      dplyr::filter(.data$cohort_start_date <= .data$overlap_end_date)
  }

  # add count and binary
  if ("number" %in% value | "binary" %in% value) {
    result_cb <- result %>%
      dplyr::select("subject_id",
                    "cohort_start_date",
                    "cohort_end_date",
                    "overlap_id") %>%
      dplyr::group_by(.data$subject_id, .data$cohort_start_date, .data$cohort_end_date, .data$overlap_id) %>%
      dplyr::summarise(number = dplyr::n(), .groups = "drop") %>%
      dplyr::mutate(
        binary = 1,
        overlap_id = as.numeric(.data$overlap_id),
        overlapCohortTableName = .env$cohortTableName
      ) %>%
      dplyr::mutate(
        window_char = paste0("(",.env$window_pre,",",.env$window_post,")")
      ) %>%
      tidyr::pivot_wider(
        names_from = c("overlapCohortTableName", "overlap_id","window_char"),
        values_from = c("number", "binary"),
        names_glue = "{.value}_{overlapCohortTableName}_{window_char}_{overlap_id}",
        values_fill = 0
      )  %>%
      dplyr::right_join(x,
                        by = c("subject_id", "cohort_start_date", "cohort_end_date")) %>%
      dplyr::mutate(dplyr::across(dplyr::starts_with(c(
        "binary", "number"
      )),
      ~ dplyr::if_else(is.na(.x), 0, .x)))

  } else {
    result_cb <- x
  }



  # add date and time
  if ("date" %in% value | "time" %in% value) {

    window <- ifelse(is.na(window),0,window)

    result_dt <- result %>%
      dplyr::select(
        "subject_id",
        "cohort_start_date",
        "cohort_end_date",
        "overlap_id",
        "overlap_start_date"
      ) %>% dplyr::mutate(overlap_start_date = as.Date(dbplyr::sql(
        CDMConnector::dateadd(date = "overlap_start_date",
                              number = !!+window[2])
      ))) %>%
      dplyr::distinct() %>%
      dplyr::group_by(.data$subject_id, .data$overlap_id, .data$cohort_start_date, .data$cohort_end_date) %>%
      dplyr::mutate(
        min_date = min(.data$overlap_start_date),
        max_date = max(.data$overlap_start_date)
      ) %>%
      dplyr::mutate(
        min_time = !!CDMConnector::datediff("cohort_start_date", "min_date", interval = "day"),
        max_time = !!CDMConnector::datediff("cohort_start_date", "max_date", interval = "day")
      ) %>%
      dplyr::ungroup() %>%
      dplyr::select(-"overlap_start_date") %>%
      dplyr::distinct() %>%
      dplyr::mutate(
        overlap_id = as.numeric(.data$overlap_id),
        overlapCohortTableName = .env$cohortTableName
      ) %>%
      dplyr::mutate(
        window_char = paste0("(",.env$window_pre,",",.env$window_post,")")
      ) %>%
      dplyr::mutate(order_var = .env$order) %>%
      tidyr::pivot_wider(
        names_from = c("overlapCohortTableName", "overlap_id","window_char","order_var"),
        values_from = c("min_time", "min_date", "max_time", "max_date"),
        names_glue = "{.value}_{overlapCohortTableName}_{window_char}_{order_var}_{overlap_id}",
        values_fill = NA
      )  %>%
      dplyr::right_join(x,
                        by = c("subject_id", "cohort_start_date", "cohort_end_date"))


    if (order == "first") {
      result_dt <-
        result_dt  %>%
        dplyr::select(-dplyr::starts_with("max_")) %>%
        dplyr::rename_with( ~ stringr::str_remove_all(., "min_"), dplyr::contains("min_"))
    } else
    {
      result_dt <-
        result_dt  %>%
        dplyr::select(-dplyr::starts_with("min_")) %>%
        dplyr::rename_with( ~ stringr::str_remove_all(., "max_"), dplyr::contains("max_"))
    }

  } else {
    result_dt <- x
  }

  #drop columns not needed
  valueDrop <- c("number", "binary", "date", "time") %>%
    dplyr::setdiff(value)


  # join result_cb and result_dt together, tidy up and select
  result_all <-
    result_cb %>% dplyr::inner_join(
      result_dt,
      by = c(
        "subject_id",
        "cohort_definition_id",
        "cohort_start_date",
        "cohort_end_date"
      )
    ) %>% dplyr::select("cohort_definition_id", dplyr::everything()) %>%
    dplyr::select(-dplyr::starts_with(valueDrop))

  if(is.null(tablePrefix)){
    result_all <- result_all %>%
      CDMConnector::computeQuery()
  } else {
    result_all <- result_all %>%
      CDMConnector::computeQuery(name = paste0(tablePrefix,
                                               "_person_sample"),
                                 temporary = FALSE,
                                 schema = attr(cdm, "write_schema"),
                                 overwrite = TRUE)
  }

  return(result_all)


}





