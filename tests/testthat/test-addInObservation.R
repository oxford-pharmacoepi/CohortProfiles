test_that("addInObservation, input length and type", {
  cdm <- mockCohortProfiles(seed = 11, patient_size = 10, earliest_observation_start_date = as.Date("2010-01-01"), latest_observation_start_date = as.Date("2022-01-01"))

  expect_error(addInObservation(2,cdm))
  expect_error(addInObservation(cdm$cohort2,"cdm"))
  expect_error(addInObservation(cdm$concept_ancestor,cdm))
  expect_error(addInObservation(cdm$cohort1,cdm,observationAt = 3))
  expect_error(addInObservation(cdm$cohort1,cdm,observationAt = "2002-01-02"))
  expect_error(addInObservation(cdm$cohort1,cdm,observationAt = c("cohort","cohort_end")))
  expect_error(addInObservation(cdm$cohort2,cdm,name = 3))
  expect_error(addInObservation(cdm$cohort2,cdm,name = c("name1","name2")))

  DBI::dbDisconnect(attr(cdm, "dbcon"), shutdown = TRUE)
})

test_that("addInObservation, cohort and condition_occurrence", {
  cdm <- mockCohortProfiles(seed = 11, patient_size = 10, earliest_observation_start_date = as.Date("2010-01-01"), latest_observation_start_date = as.Date("2022-01-01"))

  result1 <- addInObservation(cdm$cohort1,cdm)
  expect_true("in_observation" %in% colnames(result1))
  expect_true(all(result1 %>% dplyr::select(in_observation) %>% dplyr::pull() == c(1,1,0,1)))
  result2 <- addInObservation(cdm$cohort2,cdm)


  expect_true("in_observation" %in% colnames(result2))
  expect_true(all(result2 %>% dplyr::select(in_observation) %>% dplyr::pull() == c(1,0,1,1,1)))

  result3 <- addInObservation(cdm$cohort1 %>% dplyr::rename(person_id = subject_id),cdm)
  expect_true("in_observation" %in% colnames(result3))
  expect_true(all(result1 %>% dplyr::select(in_observation) %>% dplyr::pull() == result3 %>% dplyr::select(in_observation) %>% dplyr::pull()))
  result4 <- addInObservation(cdm$condition_occurrence,cdm,observationAt = "condition_start_date")
  expect_true("in_observation" %in% colnames(result4))
  expect_true(all(result4 %>% dplyr::select(in_observation) %>% dplyr::pull() == c(0,1,0,1,0,0,0,0,0,0)))

  DBI::dbDisconnect(attr(cdm, "dbcon"), shutdown = TRUE)
})

test_that("addInObservation, parameters", {
  cdm <- mockCohortProfiles(seed = 11, patient_size = 10, earliest_observation_start_date = as.Date("2010-01-01"), latest_observation_start_date = as.Date("2022-01-01"))

  result1 <- addInObservation(cdm$condition_occurrence,cdm,observationAt = "condition_end_date",name="observ")
  expect_true("observ" %in% colnames(result1))
  expect_false("in_observation" %in% colnames(result1))

  expect_true(all(result1 %>% dplyr::select(observ) %>% dplyr::pull() == c(0,1,1,1,0,0,0,0,0,1)))

  DBI::dbDisconnect(attr(cdm, "dbcon"), shutdown = TRUE)
})

