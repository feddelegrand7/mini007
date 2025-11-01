
<!-- README.md is generated from README.Rmd. Please edit that file -->

# mini007 <a><img src='man/figures/mini007cute.png' align="right" height="200" /></a>

<!-- badges: start -->

[![CRAN
status](https://www.r-pkg.org/badges/version/mini007)](https://CRAN.R-project.org/package=mini007)
[![R
badge](https://img.shields.io/badge/Build%20with-♥%20and%20R-blue)](https://github.com/feddelegrand7/mini007)
[![metacran
downloads](https://cranlogs.r-pkg.org/badges/mini007)](https://cran.r-project.org/package=mini007)
[![metacran
downloads](https://cranlogs.r-pkg.org/badges/grand-total/mini007)](https://cran.r-project.org/package=mini007)

<!-- badges: end -->

`mini007` provides a lightweight and extensible framework for
multi-agents orchestration processes capable of decomposing complex
tasks and assigning them to specialized agents.

Each `agent` is an extension of an `ellmer` object. `mini007` relies
heavily on the excellent `ellmer` package but aims to make it easy to
create a process where multiple specialized agents help each other
sequentially in order to execute a task.

`mini007` provides two types of agents:

- A normal `Agent` containing a name and an instruction,
- and a `LeadAgent` which will take a complex prompt, split it, assign
  to the adequate agents and retrieve the response.

#### Highlights

🧠 Memory and identity for each agent via `uuid` and message history.

⚙️ Built-in task decomposition and delegation via `LLM`.

🔄 Agent-to-agent orchestration with result chaining.

🌐 Compatible with any chat model supported by `ellmer`.

🧑 Possibility to set a Human In The Loop (`HITL`) at various execution
steps

You can install `mini007` from `CRAN` with:

``` r
install.packages("mini007")
```

``` r
library(mini007)
```

### Creating an Agent

An Agent is built upon an LLM object created by the `ellmer` package, in
the following examples, we’ll work with the `OpenAI` models, however you
can use any model/combination of models you want:

``` r
# no need to provide the system prompt, it will be set when creating the
# agent (see the 'instruction' parameter)

openai_4_1_mini <- ellmer::chat(
  name = "openai/gpt-4.1-mini",
  api_key = Sys.getenv("OPENAI_API_KEY"), 
  echo = "none"
)
```

After initializing the `ellmer` LLM object, creating the Agent is
straightforward:

``` r
polar_bear_researcher <- Agent$new(
  name = "POLAR BEAR RESEARCHER",
  instruction = "You are an expert in polar bears, you task is to collect information about polar bears. Answer in 1 sentence max.",
  llm_object = openai_4_1_mini
)
```

Each created Agent has an `agent_id` (among other meta information):

``` r
polar_bear_researcher$agent_id
#> [1] "90151673-5c66-4cf2-93eb-9247633bbbd8"
```

At any time, you can tweak the `llm_object`:

``` r
polar_bear_researcher$llm_object
#> <Chat OpenAI/gpt-4.1-mini turns=1 tokens=0/0 $0.00>
#> ── system [0] ──────────────────────────────────────────────────────────────────
#> You are an expert in polar bears, you task is to collect information about polar bears. Answer in 1 sentence max.
```

An agent can provide the answer to a prompt using the `invoke` method:

``` r
polar_bear_researcher$invoke("Are polar bears dangerous for humans?")
#> [1] "Yes, polar bears can be dangerous to humans as they are powerful predators and may attack if threatened or hungry."
```

You can also retrieve a list that displays the history of the agent:

``` r
polar_bear_researcher$messages
#> [[1]]
#> [[1]]$role
#> [1] "system"
#> 
#> [[1]]$content
#> [1] "You are an expert in polar bears, you task is to collect information about polar bears. Answer in 1 sentence max."
#> 
#> 
#> [[2]]
#> [[2]]$role
#> [1] "user"
#> 
#> [[2]]$content
#> [1] "Are polar bears dangerous for humans?"
#> 
#> 
#> [[3]]
#> [[3]]$role
#> [1] "assistant"
#> 
#> [[3]]$content
#> [1] "Yes, polar bears can be dangerous to humans as they are powerful predators and may attack if threatened or hungry."
```

Or the `ellmer` way:

``` r
polar_bear_researcher$llm_object
#> <Chat OpenAI/gpt-4.1-mini turns=3 tokens=43/22 $0.00>
#> ── system [0] ──────────────────────────────────────────────────────────────────
#> You are an expert in polar bears, you task is to collect information about polar bears. Answer in 1 sentence max.
#> ── user [43] ───────────────────────────────────────────────────────────────────
#> Are polar bears dangerous for humans?
#> ── assistant [22] ──────────────────────────────────────────────────────────────
#> Yes, polar bears can be dangerous to humans as they are powerful predators and may attack if threatened or hungry.
```

### Managing Agent Conversation History

The `clear_and_summarise_messages` method allows you to compress an
agent’s conversation history into a concise summary and clear the
message history while preserving context. This is useful for maintaining
memory efficiency while keeping important conversation context.

``` r
# After several interactions, summarise and clear the conversation history
polar_bear_researcher$clear_and_summarise_messages()
#> ✔ Conversation history summarised and appended to system prompt.
#> ℹ Summary: The user asked if polar bears are dangerous to humans, and the expert assistant responded that polar...
polar_bear_researcher$messages
#> [[1]]
#> [[1]]$role
#> [1] "system"
#> 
#> [[1]]$content
#> [1] "You are an expert in polar bears, you task is to collect information about polar bears. Answer in 1 sentence max. \n\n--- Conversation Summary ---\n The user asked if polar bears are dangerous to humans, and the expert assistant responded that polar bears can indeed be dangerous as they are powerful predators capable of attacking when threatened or hungry."
```

This method summarises all previous conversations into a paragraph and
appends it to the system prompt, then clears the conversation history.
The agent retains the context but with reduced memory usage.

#### Keep only the most recent messages with `keep_last_n_messages()`

When a conversation grows long, you can keep just the last N messages
while preserving the system prompt. This helps control token usage
without fully resetting context.

``` r
openai_4_1_mini <- ellmer::chat(
  name = "openai/gpt-4.1-mini",
  api_key = Sys.getenv("OPENAI_API_KEY"),
  echo = "none"
)

agent <- Agent$new(
  name = "history_manager",
  instruction = "You are a concise assistant.",
  llm_object = openai_4_1_mini
)

agent$invoke("What is the capital of Italy?")
#> [1] "The capital of Italy is Rome."
agent$invoke("What is the capital of Germany?")
#> [1] "The capital of Germany is Berlin."
agent$invoke("What is the capital of Algeria?")
#> [1] "The capital of Algeria is Algiers."
agent$messages
#> [[1]]
#> [[1]]$role
#> [1] "system"
#> 
#> [[1]]$content
#> [1] "You are a concise assistant."
#> 
#> 
#> [[2]]
#> [[2]]$role
#> [1] "user"
#> 
#> [[2]]$content
#> [1] "What is the capital of Italy?"
#> 
#> 
#> [[3]]
#> [[3]]$role
#> [1] "assistant"
#> 
#> [[3]]$content
#> [1] "The capital of Italy is Rome."
#> 
#> 
#> [[4]]
#> [[4]]$role
#> [1] "user"
#> 
#> [[4]]$content
#> [1] "What is the capital of Germany?"
#> 
#> 
#> [[5]]
#> [[5]]$role
#> [1] "assistant"
#> 
#> [[5]]$content
#> [1] "The capital of Germany is Berlin."
#> 
#> 
#> [[6]]
#> [[6]]$role
#> [1] "user"
#> 
#> [[6]]$content
#> [1] "What is the capital of Algeria?"
#> 
#> 
#> [[7]]
#> [[7]]$role
#> [1] "assistant"
#> 
#> [[7]]$content
#> [1] "The capital of Algeria is Algiers."
```

``` r
# Keep only the last 2 messages (system prompt is preserved)
agent$keep_last_n_messages(n = 2)
#> ✔ Conversation truncated to last 2 messages.
agent$messages
#> [[1]]
#> [[1]]$role
#> [1] "system"
#> 
#> [[1]]$content
#> [1] "You are a concise assistant."
#> 
#> 
#> [[2]]
#> [[2]]$role
#> [1] "user"
#> 
#> [[2]]$content
#> [1] "What is the capital of Algeria?"
#> 
#> 
#> [[3]]
#> [[3]]$role
#> [1] "assistant"
#> 
#> [[3]]$content
#> [1] "The capital of Algeria is Algiers."
```

### Manually Adding Messages to an Agent’s History

You can inject any message (system, user, or assistant) directly into an
Agent’s history with `add_message(role, content)`. This is helpful to
reconstruct, supplement, or simulate conversation steps.

- **add_message(role, content)**:
  - `role`: “user”, “assistant”, or “system”
  - `content`: The text message to add

``` r
openai_4_1_mini <- ellmer::chat(
  name = "openai/gpt-4.1-mini",
  api_key = Sys.getenv("OPENAI_API_KEY"),
  echo = "none"
)
agent <- Agent$new(
  name = "Pizza expert",
  instruction = "You are a Pizza expert",
  llm_object = openai_4_1_mini
)

# Add a user message, an assistant reply, and a system instruction:
agent$add_message("user", "Where can I find the best pizza in the world?")
#> ✔ Added user message: Where can I find the best pizza in the world?...
agent$add_message("assistant", "You can find the best pizza in the world in Algiers, Algeria. It's tasty and crunchy.")
#> ✔ Added assistant message: You can find the best pizza in the world in Algier...

# View conversation history
agent$messages
#> [[1]]
#> [[1]]$role
#> [1] "system"
#> 
#> [[1]]$content
#> [1] "You are a Pizza expert"
#> 
#> 
#> [[2]]
#> [[2]]$role
#> [1] "user"
#> 
#> [[2]]$content
#> [1] "Where can I find the best pizza in the world?"
#> 
#> 
#> [[3]]
#> [[3]]$role
#> [1] "assistant"
#> 
#> [[3]]$content
#> [1] "You can find the best pizza in the world in Algiers, Algeria. It's tasty and crunchy."
```

This makes it easy to reconstruct or extend sessions, provide custom
context, or insert notes for debugging/testing purposes.

``` r
agent$invoke("What did you say? I didn't understand. could you repeat please")
#> [1] "Certainly! One of the best places to find amazing pizza is in Naples, Italy. Naples is often considered the birthplace of pizza, especially the classic Margherita, known for its fresh ingredients and perfect crust. Many pizza lovers consider Neapolitan pizza to be the gold standard.\n\nOf course, great pizza can be found in many places around the world, each with its own unique style—for example:\n- New York City, USA: Known for its large, foldable slices with a crispy yet chewy crust.\n- Chicago, USA: Famous for deep-dish pizza with a thick, buttery crust and lots of cheese.\n- Rome, Italy: Known for thin, crispy, and rectangular \"pizza al taglio.\"\n\nIf you want, I can recommend some specific pizzerias or styles based on where you are or your preferences!"
```

### Resetting conversation history

If you want to clear the conversation while preserving the current
system prompt, use `reset_conversation_history()`.

``` r
openai_4_1_mini <- ellmer::chat(
  name = "openai/gpt-4.1-mini",
  api_key = Sys.getenv("OPENAI_API_KEY"),
  echo = "none"
)

agent <- Agent$new(
  name = "session_reset",
  instruction = "You are an assistant.",
  llm_object = openai_4_1_mini
)

agent$invoke("Tell me a short fun fact about dates (the fruit).")
#> [1] "Sure! Did you know that date palms can live for over 100 years and continue to produce fruit throughout their long lifespan? That means a single tree can provide delicious dates for generations!"
agent$invoke("And one more.")
#> [1] "Absolutely! Here’s another fun fact: Dates are one of the oldest cultivated fruits in the world, with evidence of their cultivation dating back over 6,000 years in the Middle East!"

# Clear all messages except the system prompt
agent$reset_conversation_history()
#> ✔ Conversation history reset. System prompt preserved.
agent$messages
#> [[1]]
#> [[1]]$role
#> [1] "system"
#> 
#> [[1]]$content
#> [1] "You are an assistant."
```

### Exporting and Loading Agent Conversation History

You can save an agent’s conversation history to a file and reload it
later. This allows you to archive, transfer, or resume agent sessions
across R sessions or machines.

- **export_messages_history(file_path)**: Saves the current conversation
  to a JSON file.
- **load_messages_history(file_path)**: Loads a saved conversation
  history from a JSON file, replacing the agent’s current history.

In both methods, if you omit the `file_path` parameter, a default file
named `"<getwd()>/<agent_name>_messages.json"` is used.

``` r
openai_4_1_mini <- ellmer::chat(
  name = "openai/gpt-4.1-mini",
  api_key = Sys.getenv("OPENAI_API_KEY"),
  echo = "none"
)
agent <- Agent$new(
  name = "session_agent",
  instruction = "You are a persistent researcher.",
  llm_object = openai_4_1_mini
)

# Interact with the agent
agent$invoke("Tell me something interesting about volcanoes.")

# Save the conversation
agent$export_messages_history("volcano_session.json")

# ...Later, or in a new session...
# Restore the conversation
agent$load_messages_history("volcano_session.json")
# agent$messages  # Displays current history
```

### Updating the system instruction during a session

Use `update_instruction(new_instruction)` to change the Agent’s system
prompt mid-session. The first system message and the underlying `ellmer`
system prompt are both updated.

``` r
openai_4_1_mini <- ellmer::chat(
  name = "openai/gpt-4.1-mini",
  api_key = Sys.getenv("OPENAI_API_KEY"),
  echo = "none"
)

agent <- Agent$new(
  name = "reconfigurable",
  instruction = "You are a helpful assistant.",
  llm_object = openai_4_1_mini
)

agent$update_instruction("You are a strictly concise assistant. Answer in one sentence.")
#> ✔ Instruction successfully updated
#> ℹ Old: You are a helpful assistant....
#> ℹ New: You are a strictly concise assistant. Answer in on...

agent$messages
#> [[1]]
#> [[1]]$role
#> [1] "system"
#> 
#> [[1]]$content
#> [1] "You are a strictly concise assistant. Answer in one sentence."
```

### Budget and cost control

You can limit how much an `Agent` is allowed to spend and decide what
should happen as the budget is approached or exceeded. Use
`set_budget()` to define the maximum spend (in USD), and
`set_budget_policy()` to control warnings and over-budget behavior.

- **set_budget(amount_in_usd)**: sets the absolute budget for the agent.
- **set_budget_policy(on_exceed, warn_at)**:
  - **on_exceed**: one of `"abort"`, `"warn"`, or `"ask"`.
    - **abort**: stop with an error when the budget is exceeded.
    - **warn**: emit a warning and continue.
    - **ask**: interactively ask what to do when the budget is exceeded.
  - **warn_at**: a fraction in (0, 1); triggers a one-time warning when
    spending reaches that fraction of the budget (default `0.8`).

``` r
# An API KEY is required to invoke the Agent
openai_4_1_mini <- ellmer::chat(
  name = "openai/gpt-4.1-mini",
  api_key = Sys.getenv("OPENAI_API_KEY"),
  echo = "none"
)

agent <- Agent$new(
  name = "cost_conscious_assistant",
  instruction = "Answer succinctly.",
  llm_object = openai_4_1_mini
)

# Set a 5 USD budget
agent$set_budget(5)

# Warn at 90% of the budget and ask what to do if exceeded
agent$set_budget_policy(on_exceed = "ask", warn_at = 0.9)

# Normal usage
agent$invoke("Give me a one-sentence fun fact about Algeria.")
```

The current policy is echoed when setting the budget. You can update the
policy at any time before or during an interaction lifecycle to adapt to
your workflow’s tolerance for cost overruns.

#### Inspecting usage and estimated cost

Call `get_usage_stats()` to retrieve total tokens, estimated cost, and
budget information (if set).

``` r
stats <- agent$get_usage_stats()
stats
#> $total_tokens
#> [1] 0
#> 
#> $estimated_cost
#> [1] 0
#> 
#> $budget
#> [1] NA
#> 
#> $budget_remaining
#> [1] NA
```

### Generate and execute R code from natural language

`generate_execute_r_code()` lets an `Agent` translate a natural-language
task description into R code, optionally validate its syntax, and
(optionally) execute it.

- **code_description**: a plain-English description of the R code to
  generate.
- **validate**: `TRUE` to run a syntax validation step on the generated
  code first.
- **execute**: `TRUE` to execute the generated code (requires successful
  validation).
- **interactive**: if `TRUE`, shows the code and asks for confirmation
  before executing.
- **env**: environment where code will run when `execute = TRUE`
  (default `globalenv()`).

Safety notes: - Set `validate = TRUE` and review the printed code before
execution. - Keep `interactive = TRUE` to require an explicit
confirmation before running code.

``` r
openai_4_1_mini <- ellmer::chat(
  name = "openai/gpt-4.1-mini",
  api_key = Sys.getenv("OPENAI_API_KEY"),
  echo = "none"
)

r_assistant <- Agent$new(
  name = "R Code Assistant",
  instruction = "You are an expert R programmer.",
  llm_object = openai_4_1_mini
)

# Generate code to summarise the built-in mtcars data frame,
# validate it, then execute after interactive confirmation.
r_assistant$generate_execute_r_code(
  code_description = "Calculate the summary of the mtcars dataframe",
  validate = TRUE,
  execute = TRUE,
  interactive = TRUE, 
  env = globalenv()
)
```

### Creating a multi-agents orchestraction

We can create as many Agents as we want, the `LeadAgent` will dispatch
the instructions to the agents and provide with the final answer back.
Let’s create three Agents, a `researcher`, a `summarizer` and a
`translator`:

``` r

researcher <- Agent$new(
  name = "researcher",
  instruction = "You are a research assistant. Your job is to answer factual questions with detailed and accurate information. Do not answer with more than 2 lines",
  llm_object = openai_4_1_mini
)

summarizer <- Agent$new(
  name = "summarizer",
  instruction = "You are agent designed to summarise a give text into 3 distinct bullet points.",
  llm_object = openai_4_1_mini
)

translator <- Agent$new(
  name = "translator",
  instruction = "Your role is to translate a text from English to German",
  llm_object = openai_4_1_mini
)
```

Now, the most important part is to create a `LeadAgent`:

``` r
lead_agent <- LeadAgent$new(
  name = "Leader", 
  llm_object = openai_4_1_mini
)
```

Note that the `LeadAgent` cannot receive an `instruction` as it has
already the necessary instructions.

Next, we need to assign the Agents to `LeadAgent`, we do it as follows:

``` r
lead_agent$register_agents(c(researcher, summarizer, translator))
#> ✔ Agent(s) successfully registered.
lead_agent$agents
#> [[1]]
#> <Agent>
#>   Public:
#>     add_message: function (role, content) 
#>     agent_id: 4a55b81e-40d0-498b-8c86-6ccbd47a496a
#>     broadcast_history: list
#>     budget: NA
#>     budget_policy: list
#>     budget_warned: NULL
#>     clear_and_summarise_messages: function () 
#>     clone: function (deep = FALSE) 
#>     export_messages_history: function (file_path = paste0(getwd(), "/", paste0(self$name, 
#>     generate_execute_r_code: function (code_description, validate = FALSE, execute = FALSE, 
#>     get_usage_stats: function () 
#>     initialize: function (name, instruction, llm_object, budget = NA) 
#>     instruction: You are a research assistant. Your job is to answer fact ...
#>     invoke: function (prompt) 
#>     keep_last_n_messages: function (n = 2) 
#>     llm_object: Chat, R6
#>     load_messages_history: function (file_path = paste0(getwd(), "/", paste0(self$name, 
#>     messages: active binding
#>     model_name: gpt-4.1-mini
#>     model_provider: OpenAI
#>     name: researcher
#>     reset_conversation_history: function () 
#>     set_budget: function (amount_in_usd) 
#>     set_budget_policy: function (on_exceed = "abort", warn_at = 0.8) 
#>     update_instruction: function (new_instruction) 
#>   Private:
#>     ._messages: list
#>     .add_assistant_message: function (message, type = "assistant") 
#>     .add_message: function (message, type) 
#>     .add_user_message: function (message, type = "user") 
#>     .check_budget: function () 
#>     .set_turns_from_messages: function () 
#>     .validate_r_code: function (r_code) 
#> 
#> [[2]]
#> <Agent>
#>   Public:
#>     add_message: function (role, content) 
#>     agent_id: 79a50152-d275-43be-9a5c-617fcdc443e1
#>     broadcast_history: list
#>     budget: NA
#>     budget_policy: list
#>     budget_warned: NULL
#>     clear_and_summarise_messages: function () 
#>     clone: function (deep = FALSE) 
#>     export_messages_history: function (file_path = paste0(getwd(), "/", paste0(self$name, 
#>     generate_execute_r_code: function (code_description, validate = FALSE, execute = FALSE, 
#>     get_usage_stats: function () 
#>     initialize: function (name, instruction, llm_object, budget = NA) 
#>     instruction: You are agent designed to summarise a give text into 3 d ...
#>     invoke: function (prompt) 
#>     keep_last_n_messages: function (n = 2) 
#>     llm_object: Chat, R6
#>     load_messages_history: function (file_path = paste0(getwd(), "/", paste0(self$name, 
#>     messages: active binding
#>     model_name: gpt-4.1-mini
#>     model_provider: OpenAI
#>     name: summarizer
#>     reset_conversation_history: function () 
#>     set_budget: function (amount_in_usd) 
#>     set_budget_policy: function (on_exceed = "abort", warn_at = 0.8) 
#>     update_instruction: function (new_instruction) 
#>   Private:
#>     ._messages: list
#>     .add_assistant_message: function (message, type = "assistant") 
#>     .add_message: function (message, type) 
#>     .add_user_message: function (message, type = "user") 
#>     .check_budget: function () 
#>     .set_turns_from_messages: function () 
#>     .validate_r_code: function (r_code) 
#> 
#> [[3]]
#> <Agent>
#>   Public:
#>     add_message: function (role, content) 
#>     agent_id: 51412acf-9c8f-4a57-b9f0-d1989bd0cc75
#>     broadcast_history: list
#>     budget: NA
#>     budget_policy: list
#>     budget_warned: NULL
#>     clear_and_summarise_messages: function () 
#>     clone: function (deep = FALSE) 
#>     export_messages_history: function (file_path = paste0(getwd(), "/", paste0(self$name, 
#>     generate_execute_r_code: function (code_description, validate = FALSE, execute = FALSE, 
#>     get_usage_stats: function () 
#>     initialize: function (name, instruction, llm_object, budget = NA) 
#>     instruction: Your role is to translate a text from English to German
#>     invoke: function (prompt) 
#>     keep_last_n_messages: function (n = 2) 
#>     llm_object: Chat, R6
#>     load_messages_history: function (file_path = paste0(getwd(), "/", paste0(self$name, 
#>     messages: active binding
#>     model_name: gpt-4.1-mini
#>     model_provider: OpenAI
#>     name: translator
#>     reset_conversation_history: function () 
#>     set_budget: function (amount_in_usd) 
#>     set_budget_policy: function (on_exceed = "abort", warn_at = 0.8) 
#>     update_instruction: function (new_instruction) 
#>   Private:
#>     ._messages: list
#>     .add_assistant_message: function (message, type = "assistant") 
#>     .add_message: function (message, type) 
#>     .add_user_message: function (message, type = "user") 
#>     .check_budget: function () 
#>     .set_turns_from_messages: function () 
#>     .validate_r_code: function (r_code)
```

Before executing your prompt, you can ask the `LeadAgent` to generate a
plan so that you can see which `Agent` will be used for which prompt,
you can do it as follows:

``` r
prompt_to_execute <- "Tell me about the economic situation in Algeria, summarize it in 3 bullet points, then translate it into German."

plan <- lead_agent$generate_plan(prompt_to_execute)
#> ✔ Plan successfully generated.
plan
#> [[1]]
#> [[1]]$agent_id
#> 4a55b81e-40d0-498b-8c86-6ccbd47a496a
#> 
#> [[1]]$agent_name
#> [1] "researcher"
#> 
#> [[1]]$model_provider
#> [1] "OpenAI"
#> 
#> [[1]]$model_name
#> [1] "gpt-4.1-mini"
#> 
#> [[1]]$prompt
#> [1] "Research the current economic situation in Algeria, including key indicators such as GDP growth, major industries, and challenges faced."
#> 
#> 
#> [[2]]
#> [[2]]$agent_id
#> 79a50152-d275-43be-9a5c-617fcdc443e1
#> 
#> [[2]]$agent_name
#> [1] "summarizer"
#> 
#> [[2]]$model_provider
#> [1] "OpenAI"
#> 
#> [[2]]$model_name
#> [1] "gpt-4.1-mini"
#> 
#> [[2]]$prompt
#> [1] "Summarize the researched information into 3 clear and concise bullet points in English."
#> 
#> 
#> [[3]]
#> [[3]]$agent_id
#> 51412acf-9c8f-4a57-b9f0-d1989bd0cc75
#> 
#> [[3]]$agent_name
#> [1] "translator"
#> 
#> [[3]]$model_provider
#> [1] "OpenAI"
#> 
#> [[3]]$model_name
#> [1] "gpt-4.1-mini"
#> 
#> [[3]]$prompt
#> [1] "Translate the 3 English bullet points into German accurately."
```

Now, in order now to execute the workflow, we just need to call the
`invoke` method which will behind the scene delegate the prompts to
suitable Agents and retrieve back the final information:

``` r
response <- lead_agent$invoke("Tell me about the economic situation in Algeria, summarize it in 3 bullet points, then translate it into German.")
#> 
#> ── Using existing plan ──
#> 
```

``` r
response
#> [1] "- Algeriens Wirtschaft wächst moderat mit 2-3% jährlich, hauptsächlich angetrieben durch den Öl- und Gassektor.  \n- Zu den großen Herausforderungen gehören die wirtschaftliche Diversifizierung zur Verringerung der Abhängigkeit von Kohlenwasserstoffen, hohe Arbeitslosenquoten und Inflationsdruck.  \n- Die Volatilität auf den globalen Energiemärkten hat erhebliche Auswirkungen auf die wirtschaftliche Stabilität Algeriens."
```

If you want to inspect the multi-agents orchestration, you have access
to the `agents_interaction` object:

``` r
lead_agent$agents_interaction
#> [[1]]
#> [[1]]$agent_id
#> 4a55b81e-40d0-498b-8c86-6ccbd47a496a
#> 
#> [[1]]$agent_name
#> [1] "researcher"
#> 
#> [[1]]$model_provider
#> [1] "OpenAI"
#> 
#> [[1]]$model_name
#> [1] "gpt-4.1-mini"
#> 
#> [[1]]$prompt
#> [1] "Research the current economic situation in Algeria, including key indicators such as GDP growth, major industries, and challenges faced."
#> 
#> [[1]]$response
#> [1] "As of 2024, Algeria's GDP growth is moderate, around 2-3% annually, driven by hydrocarbons (oil and gas) which dominate the economy. Key challenges include diversification away from oil dependence, high unemployment, and inflation pressures amid global energy market volatility."
#> 
#> [[1]]$edited_by_hitl
#> [1] FALSE
#> 
#> 
#> [[2]]
#> [[2]]$agent_id
#> 79a50152-d275-43be-9a5c-617fcdc443e1
#> 
#> [[2]]$agent_name
#> [1] "summarizer"
#> 
#> [[2]]$model_provider
#> [1] "OpenAI"
#> 
#> [[2]]$model_name
#> [1] "gpt-4.1-mini"
#> 
#> [[2]]$prompt
#> [1] "Summarize the researched information into 3 clear and concise bullet points in English."
#> 
#> [[2]]$response
#> [1] "- Algeria's economy grows moderately at 2-3% annually, primarily fueled by the oil and gas sector.  \n- Major challenges include economic diversification to reduce reliance on hydrocarbons, high unemployment rates, and inflation pressures.  \n- Global energy market volatility significantly impacts Algeria's economic stability."
#> 
#> [[2]]$edited_by_hitl
#> [1] FALSE
#> 
#> 
#> [[3]]
#> [[3]]$agent_id
#> 51412acf-9c8f-4a57-b9f0-d1989bd0cc75
#> 
#> [[3]]$agent_name
#> [1] "translator"
#> 
#> [[3]]$model_provider
#> [1] "OpenAI"
#> 
#> [[3]]$model_name
#> [1] "gpt-4.1-mini"
#> 
#> [[3]]$prompt
#> [1] "Translate the 3 English bullet points into German accurately."
#> 
#> [[3]]$response
#> [1] "- Algeriens Wirtschaft wächst moderat mit 2-3% jährlich, hauptsächlich angetrieben durch den Öl- und Gassektor.  \n- Zu den großen Herausforderungen gehören die wirtschaftliche Diversifizierung zur Verringerung der Abhängigkeit von Kohlenwasserstoffen, hohe Arbeitslosenquoten und Inflationsdruck.  \n- Die Volatilität auf den globalen Energiemärkten hat erhebliche Auswirkungen auf die wirtschaftliche Stabilität Algeriens."
#> 
#> [[3]]$edited_by_hitl
#> [1] FALSE
```

The above example is extremely simple, the usefulness of `mini007` would
shine in more complex processes where a multi-agent sequential
orchestration has a higher value added.

### Visualizing agent plans with `visualize_plan()`

Sometimes, before running your workflow, it is helpful to view the
orchestration as a visual diagram, showing the sequence of agents and
which prompt each will receive. After generating a plan, you can call
`visualize_plan()`:

This function displays the agents in workflow order as labeled boxes.
Hovering a box reveals the delegated prompt. The visualization uses the
`DiagrammeR` package. If no plan exists, it asks you to generate one
first.

``` r
lead_agent$visualize_plan()
```

## Broadcasting

If you want to compare several `LLM` models, the `LeadAgent` provides a
`broadcast` method that allows you to send a prompt to several different
agents and get the result for each agent back in order to make a
comparison and potentially choose the best agent/model for the defined
prompt:

Let’s go through an example:

``` r
openai_4_1 <- ellmer::chat(
  name = "openai/gpt-4.1",
  api_key = Sys.getenv("OPENAI_API_KEY"), 
  echo = "none"
)

openai_4_1_agent <- Agent$new(
  name = "openai_4_1_agent", 
  instruction = "You are an AI assistant. Answer in 1 sentence max.", 
  llm_object = openai_4_1
)

openai_4_1_nano <- ellmer::chat(
  name = "openai/gpt-4.1-nano",
  api_key = Sys.getenv("OPENAI_API_KEY"), 
  echo = "none"
)

openai_4_1_nano_agent <- Agent$new(
  name = "openai_4_1_nano_agent", 
  instruction = "You are an AI assistant. Answer in 1 sentence max.", 
  llm_object = openai_4_1_nano
)
```

``` r

lead_agent$clear_agents() # removing previous agents
lead_agent$register_agents(c(openai_4_1_agent, openai_4_1_nano_agent))
#> ✔ Agent(s) successfully registered.
```

``` r
lead_agent$broadcast(prompt = "If I were Algerian, which song would I like to sing when running under the rain? how about a flower?")
#> [[1]]
#> [[1]]$agent_id
#> [1] "fbd28c0d-c9ff-4152-8713-78aade315d97"
#> 
#> [[1]]$agent_name
#> [1] "openai_4_1_agent"
#> 
#> [[1]]$model_provider
#> [1] "OpenAI"
#> 
#> [[1]]$model_name
#> [1] "gpt-4.1"
#> 
#> [[1]]$response
#> [1] "If you were Algerian, you might like to sing \"Ya Zina Diri Latay\" when running under the rain, and if you were a flower, perhaps \"Ya Rayah\" to express longing and beauty."
#> 
#> 
#> [[2]]
#> [[2]]$agent_id
#> [1] "d46f8553-2cfb-476d-8a0e-721fa84b4b44"
#> 
#> [[2]]$agent_name
#> [1] "openai_4_1_nano_agent"
#> 
#> [[2]]$model_provider
#> [1] "OpenAI"
#> 
#> [[2]]$model_name
#> [1] "gpt-4.1-nano"
#> 
#> [[2]]$response
#> [1] "As an Algerian, you might enjoy singing \"Ya Rayah\" by Rachid Taha when running under the rain and \"Azzaman\" by Cheb Khaled when thinking of a flower."
```

You can also access the history of the `broadcasting` using the
`broadcast_history` attribute:

``` r
lead_agent$broadcast_history
#> [[1]]
#> [[1]]$prompt
#> [1] "If I were Algerian, which song would I like to sing when running under the rain? how about a flower?"
#> 
#> [[1]]$responses
#> [[1]]$responses[[1]]
#> [[1]]$responses[[1]]$agent_id
#> [1] "fbd28c0d-c9ff-4152-8713-78aade315d97"
#> 
#> [[1]]$responses[[1]]$agent_name
#> [1] "openai_4_1_agent"
#> 
#> [[1]]$responses[[1]]$model_provider
#> [1] "OpenAI"
#> 
#> [[1]]$responses[[1]]$model_name
#> [1] "gpt-4.1"
#> 
#> [[1]]$responses[[1]]$response
#> [1] "If you were Algerian, you might like to sing \"Ya Zina Diri Latay\" when running under the rain, and if you were a flower, perhaps \"Ya Rayah\" to express longing and beauty."
#> 
#> 
#> [[1]]$responses[[2]]
#> [[1]]$responses[[2]]$agent_id
#> [1] "d46f8553-2cfb-476d-8a0e-721fa84b4b44"
#> 
#> [[1]]$responses[[2]]$agent_name
#> [1] "openai_4_1_nano_agent"
#> 
#> [[1]]$responses[[2]]$model_provider
#> [1] "OpenAI"
#> 
#> [[1]]$responses[[2]]$model_name
#> [1] "gpt-4.1-nano"
#> 
#> [[1]]$responses[[2]]$response
#> [1] "As an Algerian, you might enjoy singing \"Ya Rayah\" by Rachid Taha when running under the rain and \"Azzaman\" by Cheb Khaled when thinking of a flower."
```

## Tool specification

As mentioned previously, an `Agent` is an extension of an `ellmer`
object. As such, you can define a tool that will be used, the exact same
way as in `ellmer`. Suppose, we want to get the weather in `Algiers`
through a function (Tool). Let’s first create the `Agents`:

``` r
openai_llm_object <- ellmer::chat(
  name = "openai/gpt-4.1-mini",
  api_key = Sys.getenv("OPENAI_API_KEY"), 
  echo = "none"
)

assistant <- Agent$new(
  name = "assistant",
  instruction = "You are an AI assistant that answers question. Do not answer with more than 1 sentence.",
  llm_object = openai_llm_object
)

weather_assistant <- Agent$new(
  name = "weather_assistant",
  instruction = "You role is to provide weather assistance.",
  llm_object = openai_llm_object
)
```

Now, let’s define the `tool` that we’ll be using, using `ellmer` it’s
quite straightforward:

``` r
get_weather_in_algiers <- ellmer::tool(
  function() {
    "35 degrees Celcius, it's sunny and there's no precipitation."
  },
  name = "get_weather_in_algiers",
  description = "Provide the current weather in Algiers, Algeria."
)
```

Our `tool` defined, the next step is to register it within the suitable
`Agent`, in our case, the `weather_assistant` `Agent`:

``` r
weather_assistant$llm_object$register_tool(get_weather_in_algiers)
```

That’s it, now the last step is to create the `LeadAgent`, register the
`Agents` that we need and call the `invoke` method:

``` r
lead_agent <- LeadAgent$new(
  name = "Leader", 
  llm_object = openai_llm_object
)

lead_agent$register_agents(c(assistant, weather_assistant))
#> ✔ Agent(s) successfully registered.

lead_agent$invoke(
  "Tell me about the economic situation in Algeria, then tell me how's the weather in Algiers?"
)
#> 
#> ── Generating new plan ──
#> 
#> ✔ Plan successfully generated.
#> [1] "The current weather conditions in Algiers are warm and sunny with a temperature of 35 degrees Celsius. There is no precipitation, making it a clear and dry day."
```

## Human In The Loop (HITL)

When executing an LLM workflow that relies on many steps, you can set
`Human In The Loop` (`HITL`) trigger that will check the model’s
response at a specific step. You can define a `HITL` trigger after
defining a `LeadAgent` as follows:

``` r
lead_agent <- LeadAgent$new(
  name = "Leader", 
  llm_object = openai_llm_object
)

lead_agent$set_hitl(steps = 1)
#> ✔ HITL successfully set at step(s) 1.

lead_agent$hitl_steps
#> [1] 1
```

After setting the `HITL` to step 1, the workflow execution will pose and
give the user 3 choices:

1.  Continue the execution of the workflow as it is;
2.  Change manually the answer of the specified step and continue the
    execution of the workflow;
3.  Stop the execution of the workflow (hard error);

Note that you can set a `HITL` at several steps, for example
`lead_agent$set_hitl(steps = c(1, 2))` will set the `HITL` at step 1 and
step 2.

## Judge as a decision process

Sometimes you want to send a prompt to several agents and pick the best
answer. In order to choose the best prompt, you can also rely on the
`Lead` Agent which will act a dudge and pick for you the best answer.
You can use the `judge_and_choose_best_response` method as follows:

``` r
openai_4_1 <- ellmer::chat(
  name = "openai/gpt-4.1",
  api_key = Sys.getenv("OPENAI_API_KEY"),
  echo = "none"
)

stylist_1 <- Agent$new(
  name = "stylist",
  instruction = "You are an AI assistant. Answer in 1 sentence max.",
  llm_object = openai_4_1
)

openai_4_1_nano <- ellmer::chat(
  name = "openai/gpt-4.1-nano",
  api_key = Sys.getenv("OPENAI_API_KEY"),
  echo = "none"
)

stylist_2 <- Agent$new(
  name = "stylist2",
  instruction = "You are an AI assistant. Answer in 1 sentence max.",
  llm_object = openai_4_1_nano
)

openai_4_1_mini <- ellmer::chat(
  name = "openai/gpt-4.1-mini",
  api_key = Sys.getenv("OPENAI_API_KEY"),
  echo = "none"
)

stylist_lead_agent <- LeadAgent$new(
  name = "Stylist Leader",
  llm_object = openai_4_1_mini
)

stylist_lead_agent$register_agents(c(stylist_1, stylist_2))
#> ✔ Agent(s) successfully registered.

best_answer <- stylist_lead_agent$judge_and_choose_best_response(
  "what's the best way to wear a blue kalvin klein shirt in winter with a pink pair of trousers?"
)

best_answer
#> $proposals
#> $proposals[[1]]
#> $proposals[[1]]$agent_id
#> [1] "92ae47ca-4a43-4cb8-a494-aee768cc37c8"
#> 
#> $proposals[[1]]$agent_name
#> [1] "stylist"
#> 
#> $proposals[[1]]$response
#> [1] "Layer your blue Calvin Klein shirt under a neutral-toned (gray, navy, or beige) sweater or blazer, and add coordinated accessories like a scarf or shoes to tie the look together with your pink trousers."
#> 
#> 
#> $proposals[[2]]
#> $proposals[[2]]$agent_id
#> [1] "849c83b7-0b13-40bf-b1ed-79d695d9d3b9"
#> 
#> $proposals[[2]]$agent_name
#> [1] "stylist2"
#> 
#> $proposals[[2]]$response
#> [1] "Pair the blue Calvin Klein shirt with a neutral-colored sweater or blazer and add a stylish coat, along with complementary footwear and accessories, to create a balanced winter look with pink trousers."
#> 
#> 
#> 
#> $chosen_response
#> Pair the blue Calvin Klein shirt with a neutral-colored sweater or blazer and 
#> add a stylish coat, along with complementary footwear and accessories, to 
#> create a balanced winter look with pink trousers.
```

This makes it easy to archive progress and resume complex, context-rich
agent sessions at any time.

## Code of Conduct

Please note that the mini007 project is released with a [Contributor
Code of
Conduct](https://contributor-covenant.org/version/2/1/CODE_OF_CONDUCT.html).
By contributing to this project, you agree to abide by its terms.
