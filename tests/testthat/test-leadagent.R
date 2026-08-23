library(testthat)
library(mini007)

# ── Helpers ───────────────────────────────────────────────────────────────────

# S4 class for provider metadata (same as Agent tests use)
providerclass <- setClass(
  "Provider",
  slots = c(
    name = "character",
    model = "character"
  ))

provider <- new("Provider", name = "dummy", model = "v0")

# DummyChat mock with programmable responses (queue-based)
ProgrammableChat <- R6::R6Class(
  "Chat",
  public = list(
    roles = NULL,
    system_prompt = NULL,
    turns = list(),
    tools = list(),
    provider = provider,
    response_queue = list(),
    queue_index = 0L,

    initialize = function() {
      self$response_queue <- list()
      self$queue_index <- 0L
    },

    enqueue_responses = function(...) {
      responses <- list(...)
      for (resp in responses) {
        self$response_queue[[length(self$response_queue) + 1]] <- resp
      }
    },

    chat = function(prompt) {
      self$queue_index <- self$queue_index + 1L
      if (self$queue_index <= length(self$response_queue)) {
        return(self$response_queue[[self$queue_index]])
      }
      # Default fallback
      paste("Echo:", prompt)
    },

    get_cost = function() 2.0,
    get_tokens = function() data.frame(tokens_total = 10),
    set_system_prompt = function(value) { self$system_prompt <- value },
    get_system_prompt = function() if (!is.null(self$system_prompt)) self$system_prompt else "default",
    set_turns = function(turns) { self$turns <- turns },
    get_turns = function(include_system_prompt = FALSE) { return(self$turns) },
    register_tools = function(tools) { self$tools <- tools },
    get_provider = function() { self$provider }
  )
)

# ── LeadAgent: initialization ────────────────────────────────────────────────

test_that("LeadAgent initializes with correct fields", {
  mock_chat <- ProgrammableChat$new()
  lead <- LeadAgent$new(name = "Leader", llm_object = mock_chat)

  expect_equal(lead$name, "Leader")
  expect_true(is.list(lead$agents))
  expect_length(lead$agents, 0)
  expect_true(is.list(lead$agents_interaction))
  expect_length(lead$agents_interaction, 0)
  expect_true(is.list(lead$plan))
  expect_length(lead$plan, 0)
  expect_null(lead$hitl_steps)
  expect_equal(lead$n_daemons, 0L)
})

test_that("LeadAgent initialization validates inputs", {
  mock_chat <- ProgrammableChat$new()
  expect_error(LeadAgent$new(name = 123, llm_object = mock_chat))
  expect_error(LeadAgent$new(name = "Leader", llm_object = "not_a_chat"))
})

test_that("LeadAgent inherits from Agent", {
  mock_chat <- ProgrammableChat$new()
  lead <- LeadAgent$new(name = "Leader", llm_object = mock_chat)
  expect_s3_class(lead, "R6")
  expect_true(inherits(lead, "Agent"))
})

# ── register_agents ──────────────────────────────────────────────────────────

test_that("register_agents adds agents to the list", {
  mock_chat <- ProgrammableChat$new()
  lead <- LeadAgent$new(name = "Leader", llm_object = mock_chat)

  agent1 <- Agent$new("agent1", "instruction1", mock_chat$clone())
  agent2 <- Agent$new("agent2", "instruction2", mock_chat$clone())

  lead$register_agents(c(agent1, agent2))

  expect_length(lead$agents, 2)
  expect_equal(lead$agents[[1]]$name, "agent1")
  expect_equal(lead$agents[[2]]$name, "agent2")
})

test_that("register_agents accumulates agents across multiple calls", {
  mock_chat <- ProgrammableChat$new()
  lead <- LeadAgent$new(name = "Leader", llm_object = mock_chat)

  agent1 <- Agent$new("a1", "i1", mock_chat$clone())
  agent2 <- Agent$new("a2", "i2", mock_chat$clone())
  agent3 <- Agent$new("a3", "i3", mock_chat$clone())

  lead$register_agents(c(agent1))
  expect_length(lead$agents, 1)

  lead$register_agents(c(agent2, agent3))
  expect_length(lead$agents, 3)
})

test_that("register_agents returns invisible NULL", {
  mock_chat <- ProgrammableChat$new()
  lead <- LeadAgent$new(name = "Leader", llm_object = mock_chat)
  agent <- Agent$new("a", "i", mock_chat$clone())

  result <- lead$register_agents(c(agent))
  expect_null(result)
})

# ── clear_agents ────────────────────────────────────────────────────────────

test_that("clear_agents removes all registered agents", {
  mock_chat <- ProgrammableChat$new()
  lead <- LeadAgent$new(name = "Leader", llm_object = mock_chat)

  agent1 <- Agent$new("a1", "i1", mock_chat$clone())
  agent2 <- Agent$new("a2", "i2", mock_chat$clone())

  lead$register_agents(c(agent1, agent2))
  expect_length(lead$agents, 2)

  lead$clear_agents()
  expect_length(lead$agents, 0)
})

test_that("clear_agents is idempotent", {
  mock_chat <- ProgrammableChat$new()
  lead <- LeadAgent$new(name = "Leader", llm_object = mock_chat)

  lead$clear_agents()
  expect_length(lead$agents, 0)

  lead$clear_agents()
  expect_length(lead$agents, 0)
})

# ── remove_agents ───────────────────────────────────────────────────────────

test_that("remove_agents removes specific agents by ID", {
  mock_chat <- ProgrammableChat$new()
  lead <- LeadAgent$new(name = "Leader", llm_object = mock_chat)

  agent1 <- Agent$new("a1", "i1", mock_chat$clone())
  agent2 <- Agent$new("a2", "i2", mock_chat$clone())
  agent3 <- Agent$new("a3", "i3", mock_chat$clone())

  lead$register_agents(c(agent1, agent2, agent3))
  expect_length(lead$agents, 3)

  id_to_remove <- agent2$agent_id
  lead$remove_agents(id_to_remove)

  expect_length(lead$agents, 2)
  ids <- vapply(lead$agents, function(a) a$agent_id, character(1))
  expect_false(id_to_remove %in% ids)
})

test_that("remove_agents accepts multiple agent IDs", {
  mock_chat <- ProgrammableChat$new()
  lead <- LeadAgent$new(name = "Leader", llm_object = mock_chat)

  agents <- lapply(1:4, function(i) Agent$new(paste0("a", i), paste0("i", i), mock_chat$clone()))
  lead$register_agents(agents)
  expect_length(lead$agents, 4)

  ids_to_remove <- c(agents[[1]]$agent_id, agents[[3]]$agent_id)
  lead$remove_agents(ids_to_remove)

  expect_length(lead$agents, 2)
  remaining_ids <- vapply(lead$agents, function(a) a$agent_id, character(1))
  expect_false(any(ids_to_remove %in% remaining_ids))
})

test_that("remove_agents with invalid IDs does nothing (no error)", {
  mock_chat <- ProgrammableChat$new()
  lead <- LeadAgent$new(name = "Leader", llm_object = mock_chat)

  agent <- Agent$new("a", "i", mock_chat$clone())
  lead$register_agents(c(agent))

  expect_no_error(lead$remove_agents("nonexistent-id"))
  expect_length(lead$agents, 1)
})

test_that("remove_agents validates input type", {
  mock_chat <- ProgrammableChat$new()
  lead <- LeadAgent$new(name = "Leader", llm_object = mock_chat)

  expect_error(lead$remove_agents(123))
  expect_error(lead$remove_agents(NULL))
})

# ── set_hitl ────────────────────────────────────────────────────────────────

test_that("set_hitl sets hitl_steps correctly", {
  mock_chat <- ProgrammableChat$new()
  lead <- LeadAgent$new(name = "Leader", llm_object = mock_chat)

  lead$set_hitl(1)
  expect_equal(lead$hitl_steps, 1L)
})

test_that("set_hitl accepts multiple steps and deduplicates", {
  mock_chat <- ProgrammableChat$new()
  lead <- LeadAgent$new(name = "Leader", llm_object = mock_chat)

  lead$set_hitl(c(1, 2, 2, 3))
  expect_equal(lead$hitl_steps, c(1L, 2L, 3L))
})

test_that("set_hitl coerces integer-like numeric to integer", {
  mock_chat <- ProgrammableChat$new()
  lead <- LeadAgent$new(name = "Leader", llm_object = mock_chat)

  lead$set_hitl(c(1.0, 2.0))
  expect_type(lead$hitl_steps, "integer")
  expect_equal(lead$hitl_steps, c(1L, 2L))
})

test_that("set_hitl validates steps are >= 1", {
  mock_chat <- ProgrammableChat$new()
  lead <- LeadAgent$new(name = "Leader", llm_object = mock_chat)

  expect_error(lead$set_hitl(0))
  expect_error(lead$set_hitl(-1))
})

# ── set_daemons ─────────────────────────────────────────────────────────────

test_that("set_daemons validates input", {
  mock_chat <- ProgrammableChat$new()
  lead <- LeadAgent$new(name = "Leader", llm_object = mock_chat)

  expect_error(lead$set_daemons(-1))
  expect_error(lead$set_daemons("two"))
})

test_that("set_daemons returns self invisibly", {
  mock_chat <- ProgrammableChat$new()
  lead <- LeadAgent$new(name = "Leader", llm_object = mock_chat)

  result <- lead$set_daemons(0)
  expect_identical(result, lead)
})

test_that("set_daemons with n=0 when n_daemons=0 does nothing", {
  mock_chat <- ProgrammableChat$new()
  lead <- LeadAgent$new(name = "Leader", llm_object = mock_chat)

  expect_equal(lead$n_daemons, 0L)
  lead$set_daemons(0)
  expect_equal(lead$n_daemons, 0L)
})

# ── visualize_plan ──────────────────────────────────────────────────────────

test_that("visualize_plan errors when no plan exists", {
  mock_chat <- ProgrammableChat$new()
  lead <- LeadAgent$new(name = "Leader", llm_object = mock_chat)

  expect_error(lead$visualize_plan(), "No plan found")
})

test_that("visualize_plan returns a grViz object when plan exists", {
  mock_chat <- ProgrammableChat$new()
  lead <- LeadAgent$new(name = "Leader", llm_object = mock_chat)

  # Manually set a simple plan
  lead$plan <- list(
    list(
      agent_id = "id1",
      agent_name = "agent1",
      prompt = "task1",
      model_provider = "dummy",
      model_name = "v0"
    ),
    list(
      agent_id = "id2",
      agent_name = "agent2",
      prompt = "task2",
      model_provider = "dummy",
      model_name = "v0"
    )
  )

  result <- lead$visualize_plan()
  expect_true(inherits(result, "grViz") || inherits(result, "htmlwidget"))
})

test_that("visualize_plan DOT output contains agent names", {
  mock_chat <- ProgrammableChat$new()
  lead <- LeadAgent$new(name = "Leader", llm_object = mock_chat)

  lead$plan <- list(
    list(
      agent_id = "id1",
      agent_name = "analyzer",
      prompt = "analyze",
      model_provider = "dummy",
      model_name = "v0"
    ),
    list(
      agent_id = "id2",
      agent_name = "writer",
      prompt = "write",
      model_provider = "dummy",
      model_name = "v0"
    )
  )

  result <- lead$visualize_plan()
  dot <- result$x$diagram
  expect_true(grepl("analyzer", dot))
  expect_true(grepl("writer", dot))
})

# ── invoke: guard clauses ───────────────────────────────────────────────────

test_that("invoke errors when no agents are registered", {
  mock_chat <- ProgrammableChat$new()
  lead <- LeadAgent$new(name = "Leader", llm_object = mock_chat)

  expect_error(lead$invoke("Do something"), "No Agent has been assigned")
})

test_that("invoke validates prompt is a string", {
  mock_chat <- ProgrammableChat$new()
  lead <- LeadAgent$new(name = "Leader", llm_object = mock_chat)

  agent <- Agent$new("a", "i", mock_chat$clone())
  lead$register_agents(c(agent))

  expect_error(lead$invoke(123))
  expect_error(lead$invoke(NULL))
})

# ── generate_plan: guard clauses ────────────────────────────────────────────

test_that("generate_plan errors when no agents registered", {
  mock_chat <- ProgrammableChat$new()
  lead <- LeadAgent$new(name = "Leader", llm_object = mock_chat)

  expect_error(lead$generate_plan("Do something"), "No agents registered")
})

test_that("generate_plan validates prompt is a string", {
  mock_chat <- ProgrammableChat$new()
  lead <- LeadAgent$new(name = "Leader", llm_object = mock_chat)

  agent <- Agent$new("a", "i", mock_chat$clone())
  lead$register_agents(c(agent))

  expect_error(lead$generate_plan(123))
  expect_error(lead$generate_plan(NULL))
})

# ── broadcast: guard clauses ────────────────────────────────────────────────

test_that("broadcast errors when no agents are registered", {
  mock_chat <- ProgrammableChat$new()
  lead <- LeadAgent$new(name = "Leader", llm_object = mock_chat)

  expect_error(lead$broadcast("prompt"), "No agents have been registered")
})

test_that("broadcast errors when parallel=TRUE but n_daemons=0", {
  mock_chat <- ProgrammableChat$new()
  lead <- LeadAgent$new(name = "Leader", llm_object = mock_chat)

  agent <- Agent$new("a", "i", mock_chat$clone())
  lead$register_agents(c(agent))

  expect_error(lead$broadcast("prompt", parallel = TRUE), "daemons")
})

test_that("broadcast validates prompt is a string", {
  mock_chat <- ProgrammableChat$new()
  lead <- LeadAgent$new(name = "Leader", llm_object = mock_chat)

  agent <- Agent$new("a", "i", mock_chat$clone())
  lead$register_agents(c(agent))

  expect_error(lead$broadcast(123))
  expect_error(lead$broadcast(NULL))
})

test_that("broadcast validates parallel parameter", {
  mock_chat <- ProgrammableChat$new()
  lead <- LeadAgent$new(name = "Leader", llm_object = mock_chat)

  agent <- Agent$new("a", "i", mock_chat$clone())
  lead$register_agents(c(agent))

  expect_error(lead$broadcast("prompt", parallel = "yes"))
  expect_error(lead$broadcast("prompt", parallel = 1))
})

test_that("broadcast validates synthesize parameter", {
  mock_chat <- ProgrammableChat$new()
  lead <- LeadAgent$new(name = "Leader", llm_object = mock_chat)

  agent <- Agent$new("a", "i", mock_chat$clone())
  lead$register_agents(c(agent))

  expect_error(lead$broadcast("prompt", synthesize = "yes"))
  expect_error(lead$broadcast("prompt", synthesize = 1))
})

# ── judge_and_choose_best_response: guard clauses ───────────────────────────

test_that("judge_and_choose_best_response errors when no agents registered", {
  mock_chat <- ProgrammableChat$new()
  lead <- LeadAgent$new(name = "Leader", llm_object = mock_chat)

  expect_error(lead$judge_and_choose_best_response("prompt"), "No agents registered")
})

test_that("judge_and_choose_best_response validates prompt is a string", {
  mock_chat <- ProgrammableChat$new()
  lead <- LeadAgent$new(name = "Leader", llm_object = mock_chat)

  agent <- Agent$new("a", "i", mock_chat$clone())
  lead$register_agents(c(agent))

  expect_error(lead$judge_and_choose_best_response(123))
  expect_error(lead$judge_and_choose_best_response(NULL))
})

# ── agents_dialog: guard clauses ────────────────────────────────────────────

test_that("agents_dialog errors when no agents registered", {
  mock_chat <- ProgrammableChat$new()
  lead <- LeadAgent$new(name = "Leader", llm_object = mock_chat)

  expect_error(lead$agents_dialog("prompt", "id1", "id2"), "No agents registered")
})

test_that("agents_dialog errors when agent IDs are identical", {
  mock_chat <- ProgrammableChat$new()
  lead <- LeadAgent$new(name = "Leader", llm_object = mock_chat)

  agent <- Agent$new("a", "i", mock_chat$clone())
  lead$register_agents(c(agent))

  agent_id <- agent$agent_id
  expect_error(lead$agents_dialog("prompt", agent_id, agent_id), "different agents")
})

test_that("agents_dialog errors when agent_1_id not found", {
  mock_chat <- ProgrammableChat$new()
  lead <- LeadAgent$new(name = "Leader", llm_object = mock_chat)

  agent <- Agent$new("a", "i", mock_chat$clone())
  lead$register_agents(c(agent))

  expect_error(lead$agents_dialog("prompt", "unknown-id", agent$agent_id), "not found")
})

test_that("agents_dialog errors when agent_2_id not found", {
  mock_chat <- ProgrammableChat$new()
  lead <- LeadAgent$new(name = "Leader", llm_object = mock_chat)

  agent <- Agent$new("a", "i", mock_chat$clone())
  lead$register_agents(c(agent))

  expect_error(lead$agents_dialog("prompt", agent$agent_id, "unknown-id"), "not found")
})

test_that("agents_dialog validates prompt is a string", {
  mock_chat <- ProgrammableChat$new()
  lead <- LeadAgent$new(name = "Leader", llm_object = mock_chat)

  agent1 <- Agent$new("a1", "i1", mock_chat$clone())
  agent2 <- Agent$new("a2", "i2", mock_chat$clone())
  lead$register_agents(c(agent1, agent2))

  expect_error(lead$agents_dialog(123, agent1$agent_id, agent2$agent_id))
})

test_that("agents_dialog validates agent_1_id is a string", {
  mock_chat <- ProgrammableChat$new()
  lead <- LeadAgent$new(name = "Leader", llm_object = mock_chat)

  agent1 <- Agent$new("a1", "i1", mock_chat$clone())
  agent2 <- Agent$new("a2", "i2", mock_chat$clone())
  lead$register_agents(c(agent1, agent2))

  expect_error(lead$agents_dialog("prompt", 123, agent2$agent_id))
})

test_that("agents_dialog validates agent_2_id is a string", {
  mock_chat <- ProgrammableChat$new()
  lead <- LeadAgent$new(name = "Leader", llm_object = mock_chat)

  agent1 <- Agent$new("a1", "i1", mock_chat$clone())
  agent2 <- Agent$new("a2", "i2", mock_chat$clone())
  lead$register_agents(c(agent1, agent2))

  expect_error(lead$agents_dialog("prompt", agent1$agent_id, 123))
})

test_that("agents_dialog validates max_iterations is positive integer", {
  mock_chat <- ProgrammableChat$new()
  lead <- LeadAgent$new(name = "Leader", llm_object = mock_chat)

  agent1 <- Agent$new("a1", "i1", mock_chat$clone())
  agent2 <- Agent$new("a2", "i2", mock_chat$clone())
  lead$register_agents(c(agent1, agent2))

  expect_error(lead$agents_dialog("prompt", agent1$agent_id, agent2$agent_id, max_iterations = 0))
  expect_error(lead$agents_dialog("prompt", agent1$agent_id, agent2$agent_id, max_iterations = -1))
})

# Note: Tests for broadcast, judge_and_choose_best_response, agents_dialog, and invoke
# that require full Agent$invoke() execution are excluded because they require complex
# mocking of the ellmer LLM object's get_turns() and message handling.
# Guard clause tests above verify input validation for these methods.

# ── Field validation ────────────────────────────────────────────────────────

test_that("LeadAgent fields exist after initialization", {
  mock_chat <- ProgrammableChat$new()
  lead <- LeadAgent$new(name = "Leader", llm_object = mock_chat)

  expect_true(exists(quote(agents), where = lead))
  expect_true(exists(quote(agents_interaction), where = lead))
  expect_true(exists(quote(plan), where = lead))
  expect_true(exists(quote(hitl_steps), where = lead))
  expect_true(exists(quote(dialog_history), where = lead))
  expect_true(exists(quote(broadcast_history), where = lead))
})
