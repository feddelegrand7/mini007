
<!-- README.md is generated from README.Rmd. Please edit that file -->

# mini007 <a><img src='man/figures/mini007cute.png' align="right" height="200" /></a>

<!-- badges: start -->

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
#> [1] "92b04520-761d-4d52-9b59-e65faa040c37"
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
#> [1] "Yes, polar bears are dangerous to humans as they are powerful predators and can attack if threatened or hungry."
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
#> [1] "Yes, polar bears are dangerous to humans as they are powerful predators and can attack if threatened or hungry."
```

Or the `ellmer` way:

``` r
polar_bear_researcher$llm_object
#> <Chat OpenAI/gpt-4.1-mini turns=3 tokens=43/21 $0.00>
#> ── system [0] ──────────────────────────────────────────────────────────────────
#> You are an expert in polar bears, you task is to collect information about polar bears. Answer in 1 sentence max.
#> ── user [43] ───────────────────────────────────────────────────────────────────
#> Are polar bears dangerous for humans?
#> ── assistant [21] ──────────────────────────────────────────────────────────────
#> Yes, polar bears are dangerous to humans as they are powerful predators and can attack if threatened or hungry.
```

### Managing Agent Conversation History

##### Only in the development version at the moment

The `clear_and_summarise_messages` method allows you to compress an
agent’s conversation history into a concise summary and clear the
message history while preserving context. This is useful for maintaining
memory efficiency while keeping important conversation context.

``` r
# After several interactions, summarise and clear the conversation history
polar_bear_researcher$clear_and_summarise_messages()
#> ✔ Conversation history summarised and appended to system prompt.
#> ℹ Summary: The user asked if polar bears are dangerous to humans, and the assistant responded that they are ind...
polar_bear_researcher$messages
#> [[1]]
#> [[1]]$role
#> [1] "system"
#> 
#> [[1]]$content
#> [1] "You are an expert in polar bears, you task is to collect information about polar bears. Answer in 1 sentence max. \n\n--- Conversation Summary ---\n The user asked if polar bears are dangerous to humans, and the assistant responded that they are indeed dangerous because they are powerful predators that may attack if threatened or hungry."
```

This method summarises all previous conversations into a paragraph and
appends it to the system prompt, then clears the conversation history.
The agent retains the context but with reduced memory usage.

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
#>     agent_id: 6cc0059f-6f3a-4ce0-91ed-9b4a7f5ce690
#>     broadcast_history: list
#>     budget: NA
#>     clear_and_summarise_messages: function () 
#>     clone: function (deep = FALSE) 
#>     export_messages_history: function (file_path = paste0(getwd(), "/", paste0(self$name, 
#>     generate_r_code: function (code_description, validate = FALSE, execute = FALSE, 
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
#>     update_instruction: function (new_instruction) 
#>   Private:
#>     ._messages: list
#>     .add_assistant_message: function (message, type = "assistant") 
#>     .add_message: function (message, type) 
#>     .add_user_message: function (message, type = "user") 
#>     .set_turns_from_messages: function () 
#> 
#> [[2]]
#> <Agent>
#>   Public:
#>     add_message: function (role, content) 
#>     agent_id: cf260867-666c-467c-b3f7-206aa2cfad50
#>     broadcast_history: list
#>     budget: NA
#>     clear_and_summarise_messages: function () 
#>     clone: function (deep = FALSE) 
#>     export_messages_history: function (file_path = paste0(getwd(), "/", paste0(self$name, 
#>     generate_r_code: function (code_description, validate = FALSE, execute = FALSE, 
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
#>     update_instruction: function (new_instruction) 
#>   Private:
#>     ._messages: list
#>     .add_assistant_message: function (message, type = "assistant") 
#>     .add_message: function (message, type) 
#>     .add_user_message: function (message, type = "user") 
#>     .set_turns_from_messages: function () 
#> 
#> [[3]]
#> <Agent>
#>   Public:
#>     add_message: function (role, content) 
#>     agent_id: ed286459-f432-4c8d-bffb-9f54718e357a
#>     broadcast_history: list
#>     budget: NA
#>     clear_and_summarise_messages: function () 
#>     clone: function (deep = FALSE) 
#>     export_messages_history: function (file_path = paste0(getwd(), "/", paste0(self$name, 
#>     generate_r_code: function (code_description, validate = FALSE, execute = FALSE, 
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
#>     update_instruction: function (new_instruction) 
#>   Private:
#>     ._messages: list
#>     .add_assistant_message: function (message, type = "assistant") 
#>     .add_message: function (message, type) 
#>     .add_user_message: function (message, type = "user") 
#>     .set_turns_from_messages: function ()
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
#> 6cc0059f-6f3a-4ce0-91ed-9b4a7f5ce690
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
#> [1] "Research the current economic situation in Algeria to gather key information and data."
#> 
#> 
#> [[2]]
#> [[2]]$agent_id
#> cf260867-666c-467c-b3f7-206aa2cfad50
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
#> [1] "Summarize the gathered information into 3 concise bullet points highlighting the main aspects of Algeria's economy."
#> 
#> 
#> [[3]]
#> [[3]]$agent_id
#> ed286459-f432-4c8d-bffb-9f54718e357a
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
#> [1] "Translate the 3 bullet points summary into German accurately."
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
#> [1] "- Algeriens Wirtschaft ist stark von Kohlenwasserstoffen abhängig, wobei über 90 % der Exporte aus diesem Sektor stammen, was das Land anfällig für niedrige Ölpreise macht.  \n- Die Regierung fördert aktiv die wirtschaftliche Diversifizierung, mit Schwerpunkt auf Landwirtschaft und erneuerbaren Energien.  \n- Trotz dieser Bemühungen bleibt die Arbeitslosigkeit hoch, insbesondere bei Jugendlichen, mit Raten von etwa 30 %."
```

If you want to inspect the multi-agents orchestration, you have access
to the `agents_interaction` object:

``` r
lead_agent$agents_interaction
#> [[1]]
#> [[1]]$agent_id
#> 6cc0059f-6f3a-4ce0-91ed-9b4a7f5ce690
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
#> [1] "Research the current economic situation in Algeria to gather key information and data."
#> 
#> [[1]]$response
#> [1] "As of mid-2024, Algeria faces economic challenges including low oil prices affecting hydrocarbon revenues, its main income source (over 90% of exports). The government is promoting economic diversification, with efforts in agriculture and renewable energy, but unemployment, especially among youth, remains high around 30%."
#> 
#> [[1]]$edited_by_hitl
#> [1] FALSE
#> 
#> 
#> [[2]]
#> [[2]]$agent_id
#> cf260867-666c-467c-b3f7-206aa2cfad50
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
#> [1] "Summarize the gathered information into 3 concise bullet points highlighting the main aspects of Algeria's economy."
#> 
#> [[2]]$response
#> [1] "- Algeria's economy heavily relies on hydrocarbons, with over 90% of exports coming from this sector, making it vulnerable to low oil prices.  \n- The government is actively promoting economic diversification, focusing on agriculture and renewable energy industries.  \n- Despite these efforts, unemployment remains high, particularly among youth, with rates around 30%."
#> 
#> [[2]]$edited_by_hitl
#> [1] FALSE
#> 
#> 
#> [[3]]
#> [[3]]$agent_id
#> ed286459-f432-4c8d-bffb-9f54718e357a
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
#> [1] "Translate the 3 bullet points summary into German accurately."
#> 
#> [[3]]$response
#> [1] "- Algeriens Wirtschaft ist stark von Kohlenwasserstoffen abhängig, wobei über 90 % der Exporte aus diesem Sektor stammen, was das Land anfällig für niedrige Ölpreise macht.  \n- Die Regierung fördert aktiv die wirtschaftliche Diversifizierung, mit Schwerpunkt auf Landwirtschaft und erneuerbaren Energien.  \n- Trotz dieser Bemühungen bleibt die Arbeitslosigkeit hoch, insbesondere bei Jugendlichen, mit Raten von etwa 30 %."
#> 
#> [[3]]$edited_by_hitl
#> [1] FALSE
```

The above example is extremely simple, the usefulness of `mini007` would
shine in more complex processes where a multi-agent sequential
orchestration has a higher value added.

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
#> [1] "3d77caf7-8bf0-4a47-aad5-8cb96e7dd685"
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
#> [1] "As an Algerian, you might sing \"Ya Rayah\" by Dahmane El Harrachi when running under the rain, and if you were a flower, you might \"sing\" by blooming in gentle silence as rain nourishes your petals."
#> 
#> 
#> [[2]]
#> [[2]]$agent_id
#> [1] "ffc9fe13-47ce-4fb0-a799-8a13ad8189ff"
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
#> [1] "You might enjoy singing \"Ya Rayah\" by Rachid Taha when running under the rain and \"Aïcha\" by Khaled when appreciating a flower."
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
#> [1] "3d77caf7-8bf0-4a47-aad5-8cb96e7dd685"
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
#> [1] "As an Algerian, you might sing \"Ya Rayah\" by Dahmane El Harrachi when running under the rain, and if you were a flower, you might \"sing\" by blooming in gentle silence as rain nourishes your petals."
#> 
#> 
#> [[1]]$responses[[2]]
#> [[1]]$responses[[2]]$agent_id
#> [1] "ffc9fe13-47ce-4fb0-a799-8a13ad8189ff"
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
#> [1] "You might enjoy singing \"Ya Rayah\" by Rachid Taha when running under the rain and \"Aïcha\" by Khaled when appreciating a flower."
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
#> [1] "The weather in Algiers is currently sunny and hot, with a temperature of 35 degrees Celsius and no precipitation."
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

#### Only in the development version at the moment

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
#> [1] "d017cbde-a04c-4fe2-ba29-213f7b763e23"
#> 
#> $proposals[[1]]$agent_name
#> [1] "stylist"
#> 
#> $proposals[[1]]$response
#> [1] "Layer the blue Calvin Klein shirt under a neutral or navy blazer or coat, add a scarf in a complementary shade, and complete the look with brown or black shoes for a stylish winter outfit with pink trousers."
#> 
#> 
#> $proposals[[2]]
#> $proposals[[2]]$agent_id
#> [1] "5f6331fa-b20b-41b6-9e9a-16f71fb45550"
#> 
#> $proposals[[2]]$agent_name
#> [1] "stylist2"
#> 
#> $proposals[[2]]$response
#> [1] "Pair the blue Calvin Klein shirt with a neutral-colored blazer or cardigan, add some stylish shoes and accessories, and consider layering with a scarf to complete a chic winter look."
#> 
#> 
#> 
#> $chosen_response
#> Layer the blue Calvin Klein shirt under a neutral or navy blazer or coat, add a
#> scarf in a complementary shade, and complete the look with brown or black shoes
#> for a stylish winter outfit with pink trousers.
```

## Code of Conduct

Please note that the mini007 project is released with a [Contributor
Code of
Conduct](https://contributor-covenant.org/version/2/1/CODE_OF_CONDUCT.html).
By contributing to this project, you agree to abide by its terms.
