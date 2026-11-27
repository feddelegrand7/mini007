library(testthat)
library(mini007)

# ── Helpers ───────────────────────────────────────────────────────────────────

providerclass <- setClass(
  "Provider",
  slots = c(
    name = "character",
    model  = "character"
  ))

provider <- new("Provider", name = "dummy", model = "v0")

# Chat mock for the router: $chat_structured() returns queued decisions and
# records the prompt and output type it was given.
RouterChat <- R6::R6Class(
  "Chat",
  public = list(
    system_prompt = NULL,
    turns = list(),
    tools = list(),
    provider = provider,
    decisions = list(),
    prompts = list(),
    types = list(),

    chat_structured = function(prompt, type) {
      self$prompts[[length(self$prompts) + 1L]] <- prompt
      self$types[[length(self$types) + 1L]] <- type
      if (length(self$decisions) == 0L) stop("no decision queued")
      out <- self$decisions[[1L]]
      self$decisions <- self$decisions[-1L]
      out
    },
    chat = function(prompt) stop("the router should only classify"),
    get_cost = function() 0.25,
    set_system_prompt = function(value) { self$system_prompt <- value },
    get_system_prompt = function() self$system_prompt,
    set_turns = function(turns) { self$turns <- turns },
    get_turns = function(include_system_prompt = FALSE) {
      if (!include_system_prompt) return(self$turns)
      c(list(ellmer::Turn("system", list(ellmer::ContentText(self$system_prompt)))),
        self$turns)
    },
    register_tools = function(tools) { self$tools <- tools },
    get_provider = function() self$provider
  )
)

# A minimal agent-like route that records the prompts it receives and, when
# streaming, emits one event of its own.
MockRoute <- R6::R6Class(
  "MockRoute",
  public = list(
    name = NULL,
    agent_id = NULL,
    instruction = NULL,
    response = NULL,
    prompts_received = list(),
    initialize = function(name, instruction = paste("I handle", name, "questions.")) {
      self$name <- name
      self$agent_id <- paste0("id-", name)
      self$instruction <- instruction
      self$response <- paste(name, "answer")
    },
    invoke = function(prompt, on_event = NULL) {
      self$prompts_received[[length(self$prompts_received) + 1L]] <- prompt
      if (!is.null(on_event)) on_event(mini007:::new_event("agent_started", self$name))
      self$response
    }
  )
)

decision <- function(route, reason = paste("It is about", route)) {
  list(reason = reason, route = route)
}

new_router <- function(decisions = list(), routes = c("career", "training", "funding")) {
  chat <- RouterChat$new()
  chat$decisions <- decisions
  router <- RouterAgent$new(name = "router", llm_object = chat)
  agents <- lapply(routes, MockRoute$new)
  if (length(agents) > 0) suppressMessages(router$register_agents(agents))
  list(router = router, agents = setNames(agents, routes))
}

# ── Construction and registration ─────────────────────────────────────────────

test_that("RouterAgent is an Agent with a routing system prompt", {
  router <- RouterAgent$new("router", RouterChat$new())
  expect_true(inherits(router, "Agent"))
  expect_match(router$instruction, "request router")
  expect_equal(router$llm_object$get_system_prompt(), router$instruction)
  expect_length(router$agents, 0)
})

test_that("register_agents() accepts one agent or a list, and names become route labels", {
  router <- RouterAgent$new("router", RouterChat$new())
  expect_message(router$register_agents(MockRoute$new("career")), "career")
  suppressMessages(router$register_agents(list(MockRoute$new("training"), MockRoute$new("funding"))))
  expect_equal(router$route_names(), c("career", "training", "funding"))
})

test_that("register_agents() rejects duplicates, 'none' and non-agents", {
  setup <- new_router()
  router <- setup$router

  expect_error(router$register_agents(MockRoute$new("career")), "unique")
  expect_error(router$register_agents(MockRoute$new("none")), "reserved")
  expect_error(router$register_agents(list("career")), "invoke")
  expect_error(
    router$register_agents(list(MockRoute$new("a"), MockRoute$new("b")), descriptions = "only one")
  )
  expect_equal(router$route_names(), c("career", "training", "funding"))
})

test_that("route descriptions default to the agent's role, then its instruction", {
  chat <- RouterChat$new()
  chat$decisions <- list(decision("helper"))
  router <- RouterAgent$new("router", chat)

  # An object exposing a `role` field, as a ReActAgent does.
  with_role <- new.env()
  with_role$name <- "helper"
  with_role$role <- "Short role"
  with_role$instruction <- "Short role plus long ReAct guidance"
  with_role$invoke <- function(prompt) "ok"

  suppressMessages(router$register_agents(list(with_role, MockRoute$new("plain", "Plain instruction"))))
  router$invoke("hi")

  # Agent clones the chat object, so read it back from the router.
  prompt <- router$llm_object$prompts[[1]]
  expect_match(prompt, "- helper: Short role\n", fixed = TRUE)
  expect_false(grepl("ReAct guidance", prompt, fixed = TRUE))
  expect_match(prompt, "- plain: Plain instruction", fixed = TRUE)
})

test_that("custom descriptions replace the defaults", {
  chat <- RouterChat$new()
  chat$decisions <- list(decision("career"))
  router <- RouterAgent$new("router", chat)
  suppressMessages(router$register_agents(
    MockRoute$new("career"),
    descriptions = "Questions about which job fits a person."
  ))

  router$invoke("hello")
  expect_match(router$llm_object$prompts[[1]], "- career: Questions about which job fits a person.", fixed = TRUE)
})

# ── Routing ───────────────────────────────────────────────────────────────────

test_that("invoke() sends the whole prompt to the chosen agent only", {
  setup <- new_router(list(decision("training", "It asks about schools.")))
  router <- setup$router
  prompt <- "Which bootcamps teach UX design, and how much do they cost?"

  answer <- router$invoke(prompt)

  expect_equal(answer, "training answer")
  expect_equal(setup$agents$training$prompts_received, list(prompt))
  expect_length(setup$agents$career$prompts_received, 0)
  expect_length(setup$agents$funding$prompts_received, 0)

  last <- router$last_route()
  expect_equal(last$agent_name, "training")
  expect_equal(last$agent_id, "id-training")
  expect_equal(last$reason, "It asks about schools.")
  expect_false(last$fallback)
  expect_equal(last$response, "training answer")
  expect_equal(router$cost, 0.25)
})

test_that("the LLM is asked to pick among the route labels or 'none'", {
  setup <- new_router(list(decision("funding")))
  router <- setup$router
  router$invoke("How do I pay for college?")

  chat <- router$llm_object
  expect_match(chat$prompts[[1]], "Routes:\n- career: ", fixed = TRUE)
  expect_match(chat$prompts[[1]], "Request:\nHow do I pay for college?", fixed = TRUE)
  route_type <- chat$types[[1]]@properties$route
  expect_equal(route_type@values, c("career", "training", "funding", "none"))
})

test_that("every routed request is kept in routing_history", {
  setup <- new_router(list(decision("career"), decision("funding")))
  router <- setup$router

  expect_null(router$last_route())
  router$invoke("What job fits me?")
  router$invoke("And how do I pay for training?")

  expect_equal(
    vapply(router$routing_history, function(h) h$agent_name, character(1)),
    c("career", "funding")
  )
})

test_that("route() decides without running the agent", {
  setup <- new_router(list(decision("career", "About jobs.")))
  result <- setup$router$route("What job fits me?")

  expect_equal(result$agent_name, "career")
  expect_equal(result$reason, "About jobs.")
  expect_false(result$fallback)
  expect_length(setup$agents$career$prompts_received, 0)
  expect_length(setup$router$routing_history, 0)
})

test_that("a request no route fits is an error without a fallback", {
  setup <- new_router(list(decision("none", "It is about cooking.")))
  err <- expect_error(setup$router$invoke("How do I bake bread?"), class = "mini007_no_route")
  expect_s3_class(err, "mini007_no_route")
  expect_match(conditionMessage(err), "cooking")
})

test_that("a request no route fits goes to the fallback agent when one is set", {
  setup <- new_router(list(decision("none")), routes = c("career", "general"))
  router <- setup$router
  router$set_fallback("general")

  expect_equal(router$invoke("How do I bake bread?"), "general answer")
  expect_true(router$last_route()$fallback)
  expect_equal(router$last_route()$agent_name, "general")
})

test_that("an unknown route from the LLM is an error", {
  setup <- new_router(list(decision("astronaut")))
  expect_error(setup$router$invoke("hi"), "unknown route")
})

test_that("invoke() needs at least one route", {
  router <- RouterAgent$new("router", RouterChat$new())
  expect_error(router$invoke("hi"), "no routes")
})

# ── Managing routes ───────────────────────────────────────────────────────────

test_that("set_fallback() only accepts registered agents", {
  setup <- new_router()
  expect_error(setup$router$set_fallback("nobody"), "nobody")
  setup$router$set_fallback("career")
  expect_equal(setup$router$fallback, "career")
  setup$router$set_fallback(NULL)
  expect_null(setup$router$fallback)
})

test_that("remove_agents() and clear_agents() drop routes and a stale fallback", {
  setup <- new_router()
  router <- setup$router
  router$set_fallback("funding")

  router$remove_agents("funding")
  expect_equal(router$route_names(), c("career", "training"))
  expect_null(router$fallback)

  router$clear_agents()
  expect_length(router$agents, 0)
  expect_equal(router$route_names(), character(0))
})

# ── Streaming ─────────────────────────────────────────────────────────────────

test_that("streaming emits route_selected, the agent's events and router_output", {
  setup <- new_router(list(decision("career", "About jobs.")))
  events <- list()

  answer <- setup$router$invoke("What job fits me?", on_event = function(e) {
    events[[length(events) + 1L]] <<- e
  })

  types <- vapply(events, function(e) e$type, character(1))
  expect_equal(types, c("route_selected", "agent_started", "router_output"))
  expect_equal(events[[1]]$data$agent, "career")
  expect_equal(events[[1]]$data$reason, "About jobs.")
  expect_equal(events[[2]]$data$agent, "career")
  expect_equal(events[[3]]$text, answer)
})
