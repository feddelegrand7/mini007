# mini007 0.6.0

#### Bugfix: clearer errors on LLM/tool failures instead of an opaque crash

Two related failures previously surfaced as a cryptic internal error -
`Error in vapply(): ! values must be length 1, but FUN(X[[1]]) result is
length 0` - deep inside `Agent$invoke()`'s message-sync internals, with no
indication of what actually went wrong:

- **The LLM provider itself is unreachable** (network issue, invalid API
  key, provider outage, timeout). `$invoke()` (and every other direct LLM
  call inside `Agent` and `LeadAgent`) now catches the raw provider error and
  raises a clear, actionable message explaining the likely cause, while still
  preserving the original error for debugging.
- **A registered tool call fails** (e.g. the API a tool wraps - like a
  weather service - is down). `ellmer` records this as a result with an
  empty value and an error attached; mini007 was feeding that empty value
  straight into `sprintf()`, which silently produced a zero-length string and
  crashed the vapply() call that assembles message history. `$invoke()` now
  survives this and records the actual tool error (e.g. `"ERROR: connection
  refused: weather API is down"`) in the conversation history instead of
  crashing.

#### Non-blocking Human-In-The-Loop: pause and resume

HITL no longer requires a blocking `readline()` prompt inside an interactive
console. `$set_hitl()` on both `Workflow` and `LeadAgent` gains a `mode`
argument:

- `mode = "console"` (default) — unchanged: blocks on `readline()` exactly as
  before.
- `mode = "pause"` — `$run()` / `$invoke()` return immediately with a
  `mini007_pending` object describing the paused step instead of blocking.
  Inspect it, then call the new `$resume(request_id, action, value)` method
  (`action` is one of `"continue"`, `"edit"`, `"abort"`) to continue
  execution from that point.

This makes HITL usable outside an interactive console - e.g. from a Shiny
app, a Plumber endpoint, or any batch job that needs to persist a paused
run and resume it later.

**New:**
- `Workflow$resume()` / `LeadAgent$resume()`
- `is_pending()` — check whether a value is a paused `mini007_pending` object

**Changed:**
- `Workflow$set_hitl()` / `LeadAgent$set_hitl()` gain a `mode` argument
  (`"console"` default, `"pause"`)

#### Parallel Station Execution for Workflows

Major feature addition enabling 2-4x speedup for independent processing units.

**New Methods:**
- `$set_daemons(n)` — Configure `n` parallel worker processes using `mirai` package
- `$add_parallel_group(from, stations, to, merge_fn)` — Define stations to execute concurrently
  - `from`: predecessor station
  - `stations`: vector of station names to run in parallel
  - `to`: optional successor station (receives merged results)
  - `merge_fn`: custom function to combine parallel results (default: newline concatenation)

**Enhanced Methods:**
- `$visualize()` — Now displays parallel routes in **red with ∥ symbol** to distinguish from sequential routes

**Use Cases:**
- Multi-agent analysis (e.g., technical, business, UX perspectives in parallel)
- Parallel tool calling and independent data transformations
- Ensemble model voting and comparison
- Significant latency reduction for embarrassingly parallel workflows

**Performance:**
- 3 parallel agents: ~3x faster than sequential execution
- Compatible with existing caching, retry, fallback, and HITL features
- Full integration with `Agent` and `WorkflowAgent` handlers

**Documentation:**
- Comprehensive parallel stations section in `workflow.qmd` with working example
- Real-world example in `example_real_llm.R` demonstrating 3 parallel agents analyzing "AI in Healthcare"
- Updated README.Rmd with parallel execution overview

**Technical Details:**
- Built on `mirai` package for reliable async execution
- Each parallel station inherits retry/fallback configuration
- Parallel results automatically cached with same mechanism as sequential stations
- Graceful daemon cleanup and reinitialization

---

# mini007 0.5.0

- Adding the `per-station retry` features to the `Workflow` class
- Adding the `fallback handlers` to the `Workflow` class


# mini007 0.4.0
#### Implementing the `Workflow` class which allows one to have full control over a `workflow` of agents
#### Adding new methods:
- `share_context_with()`

# mini007 0.3.0
#### Adding new methods to work with `tools`: 
- `register_tools()`
- `list_tools()`
- `remove_tools()`
- `clear_tools()`
- `generate_and_register_tool()` 

#### Adding the `agents_dialog()` methods that allows 2 agents to interact with each other in order to come up with a better outcome. 



# mini007 0.2.2

- Fixing syncing issues between `mini007` and `ellmer`

Adding the following new methods: 
- `validate_response()`
- `clone_agent()`



### Deletion

- Deleting the `visualize_plan()` method as the `DiagrammeR` package has many dependencies. 
- Deleting the `add_message` method for compatibility with `ellmer` `Turns`

### Dependency
- Adding `ellmer` as an `import` dependency.

# mini007 0.2.1

- Fixing bug in the `generate_execute_r_code()` method. 

# mini007 0.2.0

- Setting `messages` as an `active` `R6` field. It is now possible to modify the `messages` that will be used by the `LLM` object through a `list` object. The `list` object will be automatically converted to the corresponding `ellmer` `Turns`. 

Adding the following new methods: 
- `keep_last_n_messages()`
- `update_instruction()`
- `clear_and_summarise_messages()`
- `judge_and_choose_best_response()`
- `set_budget()`
- `export_messages_history()` and `load_messages_history()`
- `reset_conversation_history()`
- `add_message()`
- `generate_execute_r_code()`
- `visualize_plan()`
- `set_budget_policy()`

Adding the following new parameters: 
- Adding the `force_regenerate_plan` boolean parameter to the `invoke` method of the `LeadAgent`, this will allow taking into account if the `LeadAgent` has already generated a plan or not. If a plan is detected, no need to generate the plan from scratch, except if the user set the `force_generate_plan` to `TRUE`.

Deleting the following method:
- `delegate_prompt()`, not needed anymore as the `generate_plan()` method has the same behavior. 

# mini007 0.1.0

* Initial CRAN submission.
