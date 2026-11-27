PricedProvider <- methods::setClass(
  "PricedProvider",
  slots = c(name = "character", model = "character")
)

# A minimal ellmer-like chat whose turns are real ellmer Turns, so that
# llm_cost() reads the same token slots as with a real provider.
PricedChat <- R6::R6Class(
  "Chat",
  public = list(
    turns = list(),
    system_prompt = NULL,
    provider_name = "OpenAI",
    model = "gpt-test",
    ellmer_cost = NA_real_,
    initialize = function(model = "gpt-test", provider_name = "OpenAI", ellmer_cost = NA_real_) {
      self$model <- model
      self$provider_name <- provider_name
      self$ellmer_cost <- ellmer_cost
    },
    chat = function(prompt) {
      self$turns <- c(self$turns, list(
        ellmer::Turn("user", list(ellmer::ContentText(prompt))),
        ellmer::Turn("assistant", list(ellmer::ContentText("ok")), tokens = c(1000, 500, 200))
      ))
      "ok"
    },
    get_cost = function(include = "all") self$ellmer_cost,
    get_turns = function(include_system_prompt = FALSE) self$turns,
    set_turns = function(turns) self$turns <- turns,
    set_system_prompt = function(value) self$system_prompt <- value,
    get_system_prompt = function() self$system_prompt,
    register_tools = function(tools) invisible(NULL),
    get_provider = function() PricedProvider(name = self$provider_name, model = self$model)
  )
)

# Each test starts and ends with no registered price.
local_clean_prices <- function(env = parent.frame()) {
  clear_prices()
  do.call(on.exit, list(quote(mini007::clear_prices()), add = TRUE), envir = env)
}

test_that("set_prices() registers, replaces and validates prices", {
  local_clean_prices()
  expect_equal(nrow(get_prices()), 0L)

  set_prices("m1", input = 1, output = 2)
  set_prices(c("m2", "m3"), input = c(3, 4), output = 5, provider = "OpenAI")
  prices <- get_prices()
  expect_equal(prices$model, c("m1", "m2", "m3"))
  expect_true(is.na(prices$provider[[1]]))
  expect_equal(prices$output, c(2, 5, 5))

  set_prices("m1", input = 10, output = 20)
  expect_equal(nrow(get_prices()), 3L)
  expect_equal(get_prices()$input[get_prices()$model == "m1"], 10)

  expect_error(set_prices("m", input = -1, output = 1))
  expect_error(set_prices(c("a", "b", "c"), input = c(1, 2), output = 1))
  expect_error(set_prices(NA_character_, input = 1, output = 1))

  clear_prices("m2")
  expect_equal(get_prices()$model, c("m1", "m3"))
  clear_prices()
  expect_equal(nrow(get_prices()), 0L)
})

test_that("a provider-specific price takes precedence over an any-provider price", {
  local_clean_prices()
  set_prices("m", input = 1, output = 1)
  set_prices("m", input = 2, output = 2, provider = "openai")
  expect_equal(nrow(get_prices()), 2L)
  expect_equal(mini007:::lookup_price("OpenAI", "m")$input, 2)
  expect_equal(mini007:::lookup_price("Anthropic", "m")$input, 1)
  expect_null(mini007:::lookup_price("OpenAI", "other"))
})

test_that("llm_cost() falls back to ellmer's cost when no price is registered", {
  local_clean_prices()
  chat <- PricedChat$new(ellmer_cost = 0.42)
  chat$chat("hi")
  expect_equal(llm_cost(chat), 0.42)
  expect_true(is.na(llm_cost(PricedChat$new())))
})

test_that("llm_cost() computes the cost from tokens with a registered price", {
  local_clean_prices()
  chat <- PricedChat$new(ellmer_cost = 99)
  expect_equal(llm_cost(chat), 99)
  set_prices("gpt-test", input = 2, output = 8, cached_input = 1)
  expect_equal(llm_cost(chat), 0)

  chat$chat("hi")
  one <- (1000 * 2 + 500 * 8 + 200 * 1) / 1e6
  expect_equal(llm_cost(chat), one)
  chat$chat("again")
  expect_equal(llm_cost(chat), 2 * one)
  expect_equal(llm_cost(chat, include = "last"), one)

  # Without a cached price, cached tokens are charged at the input price.
  set_prices("gpt-test", input = 2, output = 8)
  expect_equal(llm_cost(chat, include = "last"), (1200 * 2 + 500 * 8) / 1e6)
})

test_that("agents use registered prices for their cost and budget", {
  local_clean_prices()
  agent <- Agent$new("priced", "Be brief.", PricedChat$new())
  agent$invoke("hi")
  expect_true(is.na(agent$cost))

  set_prices("gpt-test", input = 2000, output = 8000)
  agent$invoke("hi again")
  expect_equal(agent$cost, 2 * (1200 * 2000 + 500 * 8000) / 1e6)

  agent$set_budget(1)
  expect_error(agent$invoke("over budget"), "exceeded its budget")
})

test_that("a budget with an unknown model cost warns once instead of failing", {
  local_clean_prices()
  agent <- Agent$new("unpriced", "Be brief.", PricedChat$new())
  agent$set_budget(1)
  expect_message(agent$invoke("hi"), "cannot be enforced")
  expect_no_message(agent$invoke("again"), message = "cannot be enforced")
  expect_no_message(agent$invoke("and again"), message = "cannot be enforced")
})
