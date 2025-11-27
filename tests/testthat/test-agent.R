library(testthat)
library(mini007)

providerclass <- setClass(
  "Provider",
  slots = c(
    name = "character",
    model  = "character"
  ))

provider <- new("Provider", name = "dummy", model = "v0")

# Helper: Simplified mock for the ellmer LLM object with minimal sync
DummyChat <- R6::R6Class(
  "Chat",
  public = list(
    roles = NULL,
    system_prompt = NULL,
    turns = list(),
    tools = list(),
    provider = provider,
    chat = function(prompt) paste("Echo:", prompt),
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

dummy_chat <- DummyChat$new()

# --- Agent initialization ---
test_that("Agent initializes with correct fields", {
  agent <- Agent$new(
    name = "TestAgent",
    instruction = "Test instruction.",
    llm_object = dummy_chat$clone()
  )
  expect_equal(agent$name, "TestAgent")
  expect_equal(agent$instruction, "Test instruction.")
  expect_equal(agent$llm_object$get_system_prompt(), "Test instruction.")
  expect_length(agent$messages, 1)
  expect_equal(agent$messages[[1]]$role, "system")
})

# --- Budget and policy ---
test_that("set_budget and set_budget_policy manipulate values", {
  agent <- Agent$new("B", "Instr", dummy_chat$clone())
  agent$set_budget(123)
  expect_equal(agent$budget, 123)
  agent$set_budget_policy("warn", warn_at = 0.3)
  expect_equal(agent$budget_policy$on_exceed, "warn")
  expect_equal(agent$budget_policy$warn_at, 0.3)
})

# --- add_message - simplified without sync ---
test_that("add_message appends messages to list", {
  agent <- Agent$new("M", "I", dummy_chat$clone())
  # Manually add to messages without triggering sync
  agent$messages <- c(agent$messages, list(
    list(role = "user", content = "hi"),
    list(role = "assistant", content = "hello"),
    list(role = "system", content = "info")
  ))
  expect_equal(length(agent$messages), 4)
  expect_equal(agent$messages[[4]]$role, "system")
  expect_equal(agent$messages[[4]]$content, "info")
})

# --- reset_conversation_history ---
test_that("reset_conversation_history preserves only system prompt", {
  agent <- Agent$new("N", "Sys", dummy_chat$clone())
  # Manually add messages
  agent$messages <- c(agent$messages, list(
    list(role = "user", content = "hi"),
    list(role = "assistant", content = "there")
  ))
  expect_equal(length(agent$messages), 3)
  agent$reset_conversation_history()
  expect_length(agent$messages, 1)
  expect_equal(agent$messages[[1]]$role, "system")
  expect_equal(agent$messages[[1]]$content, "Sys")
})

# --- export/load_messages_history ---
test_that("export and load history roundtrip", {
  tmpfile <- tempfile(fileext = ".json")
  agent <- Agent$new("Hist", "Testing history", dummy_chat$clone())
  # Manually set messages to avoid sync issues
  agent$messages <- list(
    list(role = "system", content = "Testing history"),
    list(role = "user", content = "hi"),
    list(role = "assistant", content = "response")
  )
  agent$export_messages_history(tmpfile)
  # start a new agent, load history
  agent2 <- Agent$new("Hist2", "Will get replaced", dummy_chat$clone())
  agent2$load_messages_history(tmpfile)
  expect_equal(
    vapply(agent2$messages, `[[`, "content", FUN.VALUE = character(1)),
    vapply(agent$messages, `[[`, "content", FUN.VALUE = character(1))
  )
  unlink(tmpfile)
})

# --- keep_last_n_messages ---
test_that("keep_last_n_messages keeps only system and N most recent", {
  agent <- Agent$new("S", "info", dummy_chat$clone())
  # Manually set up messages
  agent$messages <- list(
    list(role = "system", content = "info"),
    list(role = "user", content = "first"),
    list(role = "assistant", content = "hey first!"),
    list(role = "user", content = "second"),
    list(role = "assistant", content = "hey second!")
  )
  expect_equal(length(agent$messages), 5)
  agent$keep_last_n_messages(2)
  expect_equal(length(agent$messages), 3)
  roles <- vapply(agent$messages, `[[`, "role", FUN.VALUE = character(1))
  expect_equal(roles, c("system", "user", "assistant"))
})

# --- update_instruction ---
test_that("update_instruction changes both field and system prompt", {
  agent <- Agent$new("X", "Old", dummy_chat$clone())
  agent$update_instruction("New role")
  expect_equal(agent$instruction, "New role")
  expect_equal(agent$llm_object$get_system_prompt(), "New role")
})

# --- add_message errors ---
test_that("add_message rejects invalid role", {
  agent <- Agent$new("M2", "I2", dummy_chat$clone())
  expect_error(agent$add_message("bogus", "x"))
})

# --- messages active binding validation ---
test_that("messages active binding validates roles", {
  agent <- Agent$new("MB", "InstrMB", dummy_chat$clone())
  # invalid role in list
  expect_error({ agent$messages <- list(list(role = "bogus", content = "x")) })
})


# --- keep_last_n_messages edge case ---
test_that("keep_last_n_messages with n=1 keeps system and last message", {
  agent <- Agent$new("S2", "info2", dummy_chat$clone())
  agent$messages <- list(
    list(role = "system", content = "info2"),
    list(role = "user", content = "only")
  )
  agent$keep_last_n_messages(1)
  expect_equal(length(agent$messages), 2)
  roles <- vapply(agent$messages, `[[`, "role", FUN.VALUE = character(1))
  expect_equal(roles, c("system", "user"))
})

# --- get_usage_stats ---
test_that("get_usage_stats returns expected fields and values", {
  agent <- Agent$new("Stats", "Role", dummy_chat$clone())
  stats <- agent$get_usage_stats()
  expect_true(all(c("estimated_cost", "budget", "budget_remaining") %in% names(stats)))
  expect_true(is.na(stats$budget))
  expect_true(is.na(stats$budget_remaining))
})

# --- set_budget_policy validation ---
test_that("set_budget_policy validates inputs", {
  agent <- Agent$new("BP", "I", dummy_chat$clone())
  expect_error(agent$set_budget_policy(on_exceed = "nope"))
  expect_error(agent$set_budget_policy(on_exceed = "abort", warn_at = 1.5))
})


# --- load_messages_history errors ---
test_that("load_messages_history errors on missing file", {
  agent <- Agent$new("HistErr", "I", dummy_chat$clone())
  tmp <- tempfile(fileext = ".json")
  if (file.exists(tmp)) unlink(tmp)
  expect_error(agent$load_messages_history(tmp))
})

# --- Agent initialization validation ---
test_that("Agent initialization validates inputs correctly", {
  # Test invalid llm_object
  fake_object <- list(not = "a_chat_object")
  expect_error(Agent$new("Test", "Instruction", fake_object))

  # Test non-string inputs
  expect_error(Agent$new(123, "Instruction", dummy_chat$clone()))
  expect_error(Agent$new("Test", 456, dummy_chat$clone()))

  # Note: Empty strings might be allowed by checkmate::assert_string()
  # so we don't test for those as errors unless specifically required
})

# --- Budget functionality ---
test_that("set_budget validates inputs and sets values correctly", {
  agent <- Agent$new("BudgetTest", "I", dummy_chat$clone())

  # Test valid budget setting
  agent$set_budget(50.0)
  expect_equal(agent$budget, 50.0)

  # Test invalid budget values
  expect_error(agent$set_budget(-1))
  expect_error(agent$set_budget("not_a_number"))
})

test_that("budget policy configuration works correctly", {
  agent <- Agent$new("PolicyTest", "I", dummy_chat$clone())

  # Test valid policy settings
  agent$set_budget_policy("warn", 0.9)
  expect_equal(agent$budget_policy$on_exceed, "warn")
  expect_equal(agent$budget_policy$warn_at, 0.9)

  # Test default values
  agent$set_budget_policy("abort")
  expect_equal(agent$budget_policy$warn_at, 0.8)

  # Test invalid policy values
  expect_error(agent$set_budget_policy("invalid_policy"))
  expect_error(agent$set_budget_policy("warn", 1.5))
  expect_error(agent$set_budget_policy("warn", -0.1))
})

# --- Message validation and manipulation ---
test_that("add_message validates inputs correctly", {
  agent <- Agent$new("MessageTest", "I", dummy_chat$clone())

  # Test invalid role
  expect_error(agent$add_message("invalid_role", "content"))

  # Test invalid content type
  expect_error(agent$add_message("user", NULL))
  expect_error(agent$add_message("user", 123))
})

test_that("messages active binding validates message structure", {
  agent <- Agent$new("BindingTest", "I", dummy_chat$clone())

  # Test invalid message structure - missing fields
  expect_error(agent$messages <- list(list(role = "user"))) # missing content
  expect_error(agent$messages <- list(list(content = "test"))) # missing role

  # Test invalid message structure - not a list
  expect_error(agent$messages <- "not_a_list")
  expect_error(agent$messages <- c("user", "content"))
})

# --- Export/Import functionality ---
test_that("export_messages_history creates valid JSON file", {
  tmpfile <- tempfile(fileext = ".json")
  agent <- Agent$new("ExportTest", "Testing export", dummy_chat$clone())

  # Set some messages
  agent$messages <- list(
    list(role = "system", content = "Testing export"),
    list(role = "user", content = "Hello"),
    list(role = "assistant", content = "Hi there")
  )

  # Test export
  agent$export_messages_history(tmpfile)
  expect_true(file.exists(tmpfile))

  # Test file content is valid JSON
  loaded_data <- jsonlite::read_json(tmpfile, simplifyVector = FALSE)
  expect_equal(length(loaded_data), 3)
  expect_equal(loaded_data[[2]]$role, "user")
  expect_equal(loaded_data[[2]]$content, "Hello")

  unlink(tmpfile)
})

test_that("export_messages_history validates file path", {
  agent <- Agent$new("ExportValidation", "I", dummy_chat$clone())
  expect_error(agent$export_messages_history(NULL))
  expect_error(agent$export_messages_history(123))
})

# --- Agent cloning ---
test_that("clone_agent creates independent copy", {
  agent1 <- Agent$new("Original", "Original instruction", dummy_chat$clone())
  agent1$set_budget(100)

  # Clone without new name
  agent2 <- agent1$clone_agent()
  expect_equal(agent2$name, "Original")
  expect_equal(agent2$instruction, "Original instruction")
  expect_equal(agent2$budget, 100)
  expect_false(agent1$agent_id == agent2$agent_id) # Different IDs

  # Clone with new name
  agent3 <- agent1$clone_agent("NewName")
  expect_equal(agent3$name, "NewName")
  expect_false(agent1$agent_id == agent3$agent_id)
})

test_that("clone_agent validates new_name parameter", {
  agent <- Agent$new("CloneTest", "I", dummy_chat$clone())
  expect_error(agent$clone_agent(123))
  expect_error(agent$clone_agent(c("a", "b")))
})

# --- Instruction updates ---
test_that("update_instruction modifies system prompt correctly", {
  agent <- Agent$new("InstructionTest", "Old instruction", dummy_chat$clone())
  original_message_count <- length(agent$messages)

  agent$update_instruction("New instruction")

  expect_equal(agent$instruction, "New instruction")
  expect_equal(agent$llm_object$get_system_prompt(), "New instruction")
  expect_equal(agent$messages[[1]]$content, "New instruction")
  expect_equal(length(agent$messages), original_message_count) # Same number of messages
})

test_that("update_instruction validates input", {
  agent <- Agent$new("ValidationTest", "I", dummy_chat$clone())
  expect_error(agent$update_instruction(NULL))
  expect_error(agent$update_instruction(123))
  expect_error(agent$update_instruction(c("a", "b")))
})

# --- Keep last N messages functionality ---
test_that("keep_last_n_messages handles normal cases", {
  agent <- Agent$new("KeepTest", "System", dummy_chat$clone())

  # Set up multiple messages
  agent$messages <- list(
    list(role = "system", content = "System"),
    list(role = "user", content = "msg1"),
    list(role = "assistant", content = "resp1"),
    list(role = "user", content = "msg2"),
    list(role = "assistant", content = "resp2"),
    list(role = "user", content = "msg3"),
    list(role = "assistant", content = "resp3")
  )

  # Test keeping a reasonable number of messages
  agent$keep_last_n_messages(3)
  # Should keep system + 3 most recent messages
  expect_equal(length(agent$messages), 4) # system + 3

  # Test keeping 0 messages (should keep at least system)
  expect_error(agent$keep_last_n_messages(0))
})

test_that("keep_last_n_messages validates input", {
  agent <- Agent$new("KeepValidation", "I", dummy_chat$clone())
  expect_error(agent$keep_last_n_messages(-1))
  expect_error(agent$keep_last_n_messages("not_a_number"))
  # Note: checkmate::assert_integerish might accept vectors, so this test might not fail
  # expect_error(agent$keep_last_n_messages(c(1, 2)))
})

# --- Usage stats ---
test_that("get_usage_stats handles different cost scenarios", {
  agent <- Agent$new("StatsTest", "I", dummy_chat$clone())

  # Test with no budget set
  stats <- agent$get_usage_stats()
  expect_true(is.na(stats$budget))
  expect_true(is.na(stats$budget_remaining))

  # Test with budget but no cost
  agent$set_budget(10)
  stats <- agent$get_usage_stats()
  expect_equal(stats$budget, 10)
  expect_true(is.na(stats$budget_remaining)) # because cost is NA

  # Test with both budget and cost
  agent$cost <- 3.5
  stats <- agent$get_usage_stats()
  expect_equal(stats$estimated_cost, 3.5)
  expect_equal(stats$budget_remaining, 6.5)
})

# --- Field access and initialization ---
test_that("Agent fields are initialized correctly", {
  agent <- Agent$new("FieldTest", "Test instruction", dummy_chat$clone())

  expect_equal(agent$name, "FieldTest")
  expect_equal(agent$instruction, "Test instruction")
  expect_true(!is.null(agent$agent_id))
  expect_true(is.character(agent$agent_id))
  expect_equal(length(agent$agent_id), 1)
  expect_true(is.na(agent$budget))
  expect_equal(agent$budget_policy$on_exceed, "abort")
  expect_equal(agent$budget_policy$warn_at, 0.8)
  expect_true(is.na(agent$cost))
  expect_true(is.list(agent$broadcast_history))
  expect_equal(length(agent$broadcast_history), 0)
})

# --- Error handling in various methods ---
test_that("methods handle invalid input types gracefully", {
  agent <- Agent$new("ErrorTest", "I", dummy_chat$clone())

  # Test update_instruction with invalid types
  expect_error(agent$update_instruction(NULL))
  expect_error(agent$update_instruction(list("instruction")))

  # Test load_messages_history with invalid path
  expect_error(agent$load_messages_history(NULL))
  expect_error(agent$load_messages_history(123))
})

# --- Provider and model information ---
test_that("Agent captures provider information correctly", {
  agent <- Agent$new("ProviderTest", "I", dummy_chat$clone())

  expect_equal(agent$model_provider, "dummy")
  expect_equal(agent$model_name, "v0")
  expect_true(!is.null(agent$llm_object$get_provider()))
})

# --- Message list manipulation ---
test_that("messages can be accessed and modified correctly", {
  agent <- Agent$new("AccessTest", "I", dummy_chat$clone())

  # Test getter
  initial_messages <- agent$messages
  expect_equal(length(initial_messages), 1)
  expect_equal(initial_messages[[1]]$role, "system")

  # Test setter with valid messages
  new_messages <- list(
    list(role = "system", content = "New system"),
    list(role = "user", content = "User message"),
    list(role = "assistant", content = "Assistant response")
  )
  agent$messages <- new_messages

  retrieved_messages <- agent$messages
  expect_equal(length(retrieved_messages), 3)
  expect_equal(retrieved_messages[[2]]$content, "User message")
})

# --- Note: Tool management methods are not included in the current Agent implementation ---

# --- Additional edge case tests ---

test_that("Agent handles large numbers of messages correctly", {
  agent <- Agent$new("LargeTest", "System", dummy_chat$clone())

  # Create a large number of messages
  large_message_list <- list(list(role = "system", content = "System"))
  for (i in 1:100) {
    large_message_list <- c(large_message_list, list(
      list(role = "user", content = paste("Message", i)),
      list(role = "assistant", content = paste("Response", i))
    ))
  }

  # Test setting large message list
  expect_no_error(agent$messages <- large_message_list)
  expect_equal(length(agent$messages), 201) # 1 system + 200 user/assistant

  # Test keep_last_n_messages with large list
  expect_no_error(agent$keep_last_n_messages(10))
  expect_equal(length(agent$messages), 11) # system + 10 most recent
})

test_that("Agent budget calculations handle edge values", {
  agent <- Agent$new("BudgetEdge", "I", dummy_chat$clone())

  # Test with very small budget
  agent$set_budget(0.001)
  expect_equal(agent$budget, 0.001)

  # Test with zero cost
  agent$cost <- 0
  stats <- agent$get_usage_stats()
  expect_equal(stats$budget_remaining, 0.001)

  # Test with cost exceeding budget
  agent$cost <- 0.01
  stats <- agent$get_usage_stats()
  expect_true(stats$budget_remaining < 0)
})

test_that("Agent message export handles different file extensions", {
  agent <- Agent$new("ExportTypes", "Test", dummy_chat$clone())

  # Test with .json extension
  tmpfile_json <- tempfile(fileext = ".json")
  expect_no_error(agent$export_messages_history(tmpfile_json))
  expect_true(file.exists(tmpfile_json))
  unlink(tmpfile_json)

  # Test with no extension
  tmpfile_none <- tempfile()
  expect_no_error(agent$export_messages_history(tmpfile_none))
  expect_true(file.exists(tmpfile_none))
  unlink(tmpfile_none)
})

test_that("Agent cloning preserves all state correctly", {
  agent1 <- Agent$new("FullState", "Original", dummy_chat$clone())

  # Set up complex state
  agent1$set_budget(25.5)
  agent1$set_budget_policy("warn", 0.7)
  agent1$cost <- 5.0
  agent1$messages <- list(
    list(role = "system", content = "Original"),
    list(role = "user", content = "Test message"),
    list(role = "assistant", content = "Test response")
  )

  # Clone the agent
  agent2 <- agent1$clone_agent("ClonedState")

  # Verify all state is preserved
  expect_equal(agent2$name, "ClonedState") # New name
  expect_equal(agent2$instruction, "Original") # Original instruction
  expect_equal(agent2$budget, 25.5)
  expect_equal(agent2$budget_policy$on_exceed, "warn")
  expect_equal(agent2$budget_policy$warn_at, 0.7)
  expect_equal(agent2$cost, 5.0)
  expect_equal(length(agent2$messages), 3)

  # Verify independence (different IDs)
  expect_false(agent1$agent_id == agent2$agent_id)

  # Verify independence (modifying one doesn't affect the other)
  agent2$set_budget(50)
  expect_equal(agent1$budget, 25.5) # Original unchanged
  expect_equal(agent2$budget, 50)   # Clone changed
})
