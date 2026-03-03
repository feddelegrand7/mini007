#' Testing LLM agent responses
#'
#' This function build on \code{Agent$validate_response()} to provide
#' \pkg{testthat}-style expectations. They are intended to be used inside
#' \code{test_that()} blocks to assert that an LLM's answer meets some
#' validation criteria.
#'
#' @param agent An \code{Agent} object.
#' @param prompt The prompt sent to the agent.
#' @param response An already-generated response.
#' @param validation_criteria A character description of the requirements
#'   that the response must satisfy.
#' @param validation_score Numeric between 0 and 1; the threshold above
#'   which the validation is considered successful.  Defaults to 0.8.
#' @param info Passed through to the underlying \pkg{testthat}
#'   expectation for additional failure information.
#' @param label Passed through to the underlying \pkg{testthat}
#'   expectation for additional failure information.
#' @examples
#' \dontrun{
#' library(testthat)
#' a <- Agent$new("foo", "You are helpful", my_llm)
#' test_that("response mentions Algiers", {
#'   expect_llm_response(a,
#'                       prompt = "What's the capital of Algeria?",
#'                       validation_criteria =
#'                         "must be factual and mention Algiers",
#'                       validation_score = 0.9)
#' })
#' }
#' @export
expect_llm_response <- function(
    agent,
    prompt,
    response,
    validation_criteria,
    validation_score = 0.8,
    label = NULL,
    info = NULL
) {

  validation <- agent$validate_response(
    prompt = prompt,
    response = response,
    validation_criteria = validation_criteria,
    validation_score = validation_score
  )

  testthat::expect_true(validation$valid, info = info, label = label)
}






