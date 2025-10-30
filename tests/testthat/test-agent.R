library(testthat)
library(mini007)

providerclass <- setClass(
  "Provider",
  slots = c(
    name = "character",
    model  = "character"
  ))

provider <- new("Provider", name = "dummy", model = "v0")

# Helper: Minimal mock for the ellmer LLM object
DummyChat <- R6::R6Class(
  "Chat",
  public = list(
    roles = NULL,
    system_prompt = NULL,
    turns = NULL,
    provider = provider,
    chat = function(prompt) paste("Echo:", prompt),
    get_cost = function() 0.0,
    get_tokens = function() data.frame(tokens_total = 1),
    set_system_prompt = function(value) { self$system_prompt <- value },
    get_system_prompt = function() if (!is.null(self$system_prompt)) self$system_prompt else "default",
    set_turns = function(turns) { self$turns <- turns },
    get_provider = function() { self$provider }
  )
)

dummy_chat <- DummyChat$new()


# --- Agent initialization ---
test_that("Agent initializes with correct fields", {
  agent <- Agent$new(
    name = "TestAgent",
    instruction = "Test instruction.",
    llm_object = dummy_chat
  )
  expect_equal(agent$name, "TestAgent")
  expect_equal(agent$instruction, "Test instruction.")
  expect_equal(agent$llm_object$get_system_prompt(), "Test instruction.")
  expect_length(agent$messages, 1)
  expect_equal(agent$messages[[1]]$role, "system")
})

# --- Budget and policy ---
test_that("set_budget and set_budget_policy manipulate values", {
  agent <- Agent$new("B", "Instr", dummy_chat)
  agent$set_budget(123)
  expect_equal(agent$budget, 123)
  agent$set_budget_policy("warn", warn_at = 0.3)
  expect_equal(agent$budget_policy$on_exceed, "warn")
  expect_equal(agent$budget_policy$warn_at, 0.3)
})

# --- add_message ---
test_that("add_message appends correct message roles", {
  agent <- Agent$new("M", "I", dummy_chat)
  agent$add_message("user", "hi")
  agent$add_message("assistant", "hello")
  agent$add_message("system", "info")
  expect_equal(length(agent$messages), 4)
  expect_equal(agent$messages[[4]]$role, "system")
  expect_equal(agent$messages[[4]]$content, "info")
})

# --- reset_conversation_history ---
test_that("reset_conversation_history preserves only system prompt", {
  agent <- Agent$new("N", "Sys", dummy_chat)
  agent$add_message("user", "hi")
  agent$add_message("assistant", "there")
  expect_equal(length(agent$messages), 3)
  agent$reset_conversation_history()
  expect_length(agent$messages, 1)
  expect_equal(agent$messages[[1]]$role, "system")
  expect_equal(agent$messages[[1]]$content, "Sys")
})

# --- generate_execute_r_code (mocked) ---
test_that("generate_execute_r_code returns expected structure", {
  agent <- Agent$new("C", "Use R", dummy_chat)
  result <- agent$generate_execute_r_code(
    code_description = "sum(c(1,2))",
    validate = FALSE,
    execute = FALSE,
    interactive = FALSE
  )
  expect_type(result, "list")
  expect_true("code" %in% names(result))
  expect_equal(result$code, paste0(
    "Echo: Generate R code for the following task. ",
    "Return ONLY the R code without any explanations, markdown formatting, ",
    "or additional text:\n\nsum(c(1,2))"
  )
  )
})

# --- export/load_messages_history ---
test_that("export and load history roundtrip", {
  tmpfile <- tempfile(fileext = ".json")
  agent <- Agent$new("Hist", "Testing history", dummy_chat)
  agent$add_message("user", "hi")
  agent$add_message("assistant", "response")
  agent$export_messages_history(tmpfile)
  # start a new agent, load history
  agent2 <- Agent$new("Hist2", "Will get replaced", dummy_chat)
  agent2$load_messages_history(tmpfile)
  expect_equal(
    vapply(agent2$messages, `[[`, "content", FUN.VALUE = character(1)),
    vapply(agent$messages, `[[`, "content", FUN.VALUE = character(1))
  )
  unlink(tmpfile)
})

# --- keep_last_n_messages ---
test_that("keep_last_n_messages keeps only system and N most recent", {
  agent <- Agent$new("S", "info", dummy_chat)
  agent$add_message("user", "first")
  agent$add_message("assistant", "hey first!")
  agent$add_message("user", "second")
  agent$add_message("assistant", "hey second!")
  expect_equal(length(agent$messages), 5)
  agent$keep_last_n_messages(2)
  expect_equal(length(agent$messages), 3)
  roles <- vapply(agent$messages, `[[`, "role", FUN.VALUE = character(1))
  expect_equal(roles, c("system", "user", "assistant"))
})

# --- update_instruction ---
test_that("update_instruction changes both field and system prompt", {
  agent <- Agent$new("X", "Old", dummy_chat)
  agent$update_instruction("New role")
  expect_equal(agent$instruction, "New role")
  expect_equal(agent$llm_object$get_system_prompt(), "New role")
})
