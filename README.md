
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
#> [1] "3eb4b97b-f1eb-42e4-9c98-0f62befbb81e"
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
#> Yes, polar bears can be dangerous to humans as they are powerful predators and 
#> may attack if threatened or hungry.
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
#> Yes, polar bears can be dangerous to humans as they are powerful predators and 
#> may attack if threatened or hungry.
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
#>     agent_id: 991d41d8-9a68-43b9-bf25-0f7c6d1bd8d5
#>     broadcast_history: list
#>     clear_and_summarise_messages: function () 
#>     clone: function (deep = FALSE) 
#>     initialize: function (name, instruction, llm_object) 
#>     instruction: You are a research assistant. Your job is to answer fact ...
#>     invoke: function (prompt) 
#>     llm_object: Chat, R6
#>     messages: active binding
#>     model_name: gpt-4.1-mini
#>     model_provider: OpenAI
#>     name: researcher
#>     truncate_messages_history: function (n = 5) 
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
#>     agent_id: 05acf77c-5e1a-4b20-bf4f-4512b174c65c
#>     broadcast_history: list
#>     clear_and_summarise_messages: function () 
#>     clone: function (deep = FALSE) 
#>     initialize: function (name, instruction, llm_object) 
#>     instruction: You are agent designed to summarise a give text into 3 d ...
#>     invoke: function (prompt) 
#>     llm_object: Chat, R6
#>     messages: active binding
#>     model_name: gpt-4.1-mini
#>     model_provider: OpenAI
#>     name: summarizer
#>     truncate_messages_history: function (n = 5) 
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
#>     agent_id: cbe9df6b-25ea-41e9-986d-8e81fa9494d9
#>     broadcast_history: list
#>     clear_and_summarise_messages: function () 
#>     clone: function (deep = FALSE) 
#>     initialize: function (name, instruction, llm_object) 
#>     instruction: Your role is to translate a text from English to German
#>     invoke: function (prompt) 
#>     llm_object: Chat, R6
#>     messages: active binding
#>     model_name: gpt-4.1-mini
#>     model_provider: OpenAI
#>     name: translator
#>     truncate_messages_history: function (n = 5) 
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
#> 991d41d8-9a68-43b9-bf25-0f7c6d1bd8d5
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
#> [1] "Research the current economic situation in Algeria, including key factors such as GDP growth, main industries, unemployment rate, and any recent economic challenges or developments."
#> 
#> 
#> [[2]]
#> [[2]]$agent_id
#> 05acf77c-5e1a-4b20-bf4f-4512b174c65c
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
#> [1] "Summarize the researched information into 3 concise bullet points highlighting the most important aspects."
#> 
#> 
#> [[3]]
#> [[3]]$agent_id
#> cbe9df6b-25ea-41e9-986d-8e81fa9494d9
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
#> [1] "Translate the 3 bullet points from English into German accurately."
```

Now, in order now to execute the workflow, we just need to call the
`invoke` method which will behind the scene delegate the prompts to
suitable Agents and retrieve back the final information:

``` r
response <- lead_agent$invoke("Tell me about the economic situation in Algeria, summarize it in 3 bullet points, then translate it into German.")
```

``` r
response
#> - Das BIP-Wachstum Algeriens im Jahr 2024 ist moderat und liegt bei etwa 2-3 %,
#> wobei es stark von Kohlenwasserstoffen abhängt, die etwa 95 % seiner Exporte 
#> ausmachen.  
#> - Wichtige Wirtschaftssektoren sind Energie, Landwirtschaft und 
#> Dienstleistungen, wobei die Arbeitslosigkeit mit etwa 11-12 % hoch ist und 
#> insbesondere die Jugend betrifft.  
#> - Das Land steht vor Herausforderungen wie schwankenden Ölpreisen, Inflation 
#> und anhaltenden Bemühungen zur Diversifizierung der Wirtschaft angesichts 
#> sozialer Unruhen und globaler wirtschaftlicher Belastungen.
```

If you want to inspect the multi-agents orchestration, you have access
to the `agents_interaction` object:

``` r
lead_agent$agents_interaction
#> [[1]]
#> [[1]]$agent_id
#> 991d41d8-9a68-43b9-bf25-0f7c6d1bd8d5
#> 
#> [[1]]$agent_name
#> [1] "researcher"
#> 
#> [[1]]$model_name
#> [1] "gpt-4.1-mini"
#> 
#> [[1]]$model_provider
#> [1] "OpenAI"
#> 
#> [[1]]$prompt
#> [1] "Research the current economic situation in Algeria, including key factors such as GDP growth, main industries, unemployment rate, and any recent economic challenges or developments."
#> 
#> [[1]]$response
#> Algeria's 2024 GDP growth is modest, around 2-3%, reliant on hydrocarbons (oil 
#> and gas account for ~95% of exports). Main sectors: energy, agriculture, and 
#> services. Unemployment remains high at ~11-12%, especially among youth. Recent 
#> challenges include fluctuating oil prices, inflation, and efforts to diversify 
#> the economy amid social unrest and global economic pressures.
#> 
#> [[1]]$edited_by_hitl
#> [1] FALSE
#> 
#> 
#> [[2]]
#> [[2]]$agent_id
#> 05acf77c-5e1a-4b20-bf4f-4512b174c65c
#> 
#> [[2]]$agent_name
#> [1] "summarizer"
#> 
#> [[2]]$model_name
#> [1] "gpt-4.1-mini"
#> 
#> [[2]]$model_provider
#> [1] "OpenAI"
#> 
#> [[2]]$prompt
#> [1] "Summarize the researched information into 3 concise bullet points highlighting the most important aspects."
#> 
#> [[2]]$response
#> - Algeria's 2024 GDP growth is modest, around 2-3%, heavily dependent on 
#> hydrocarbons, which constitute approximately 95% of its exports.  
#> - Key economic sectors include energy, agriculture, and services, with 
#> unemployment high at about 11-12%, particularly affecting youth.  
#> - The country faces challenges such as fluctuating oil prices, inflation, and 
#> ongoing efforts to diversify its economy amid social unrest and global economic
#> pressures.
#> 
#> [[2]]$edited_by_hitl
#> [1] FALSE
#> 
#> 
#> [[3]]
#> [[3]]$agent_id
#> cbe9df6b-25ea-41e9-986d-8e81fa9494d9
#> 
#> [[3]]$agent_name
#> [1] "translator"
#> 
#> [[3]]$model_name
#> [1] "gpt-4.1-mini"
#> 
#> [[3]]$model_provider
#> [1] "OpenAI"
#> 
#> [[3]]$prompt
#> [1] "Translate the 3 bullet points from English into German accurately."
#> 
#> [[3]]$response
#> - Das BIP-Wachstum Algeriens im Jahr 2024 ist moderat und liegt bei etwa 2-3 %,
#> wobei es stark von Kohlenwasserstoffen abhängt, die etwa 95 % seiner Exporte 
#> ausmachen.  
#> - Wichtige Wirtschaftssektoren sind Energie, Landwirtschaft und 
#> Dienstleistungen, wobei die Arbeitslosigkeit mit etwa 11-12 % hoch ist und 
#> insbesondere die Jugend betrifft.  
#> - Das Land steht vor Herausforderungen wie schwankenden Ölpreisen, Inflation 
#> und anhaltenden Bemühungen zur Diversifizierung der Wirtschaft angesichts 
#> sozialer Unruhen und globaler wirtschaftlicher Belastungen.
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
#> [1] "05246f62-bb7c-4d03-9d42-a692d0a48b51"
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
#> If you were Algerian, you might enjoy singing "Ya Rayah" while running under 
#> the rain, and if you were a flower, perhaps you'd prefer humming with the soft 
#> patter of raindrops as your melody.
#> 
#> 
#> [[2]]
#> [[2]]$agent_id
#> [1] "4118916b-2546-4f62-8df7-92c811ad8f65"
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
#> You might enjoy singing "Ya Rayah" by Rachid Taha when running under the rain 
#> and "Lily" by Khaled if you like a flower.
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
#> [1] "05246f62-bb7c-4d03-9d42-a692d0a48b51"
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
#> If you were Algerian, you might enjoy singing "Ya Rayah" while running under 
#> the rain, and if you were a flower, perhaps you'd prefer humming with the soft 
#> patter of raindrops as your melody.
#> 
#> 
#> [[1]]$responses[[2]]
#> [[1]]$responses[[2]]$agent_id
#> [1] "4118916b-2546-4f62-8df7-92c811ad8f65"
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
#> You might enjoy singing "Ya Rayah" by Rachid Taha when running under the rain 
#> and "Lily" by Khaled if you like a flower.
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
#> Current weather in Algiers: Sunny with a temperature of 35 degrees Celsius and 
#> no precipitation.
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
You can use the `judge_and_chose_best_response` method as follows:

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

best_answer <- stylist_lead_agent$judge_and_chose_best_response(
  "what's the best way to wear a blue kalvin klein shirt in winter with a pink pair of trousers?"
)

best_answer
#> $proposals
#> $proposals[[1]]
#> $proposals[[1]]$agent_id
#> [1] "b561cef1-7e3f-4631-9b53-ddef3099e606"
#> 
#> $proposals[[1]]$agent_name
#> [1] "stylist"
#> 
#> $proposals[[1]]$response
#> Layer the blue Calvin Klein shirt with a neutral-toned (like gray or navy) 
#> sweater or blazer, add a matching scarf for warmth, and wear neutral shoes to 
#> balance the bold pink trousers.
#> 
#> 
#> $proposals[[2]]
#> $proposals[[2]]$agent_id
#> [1] "ebe499b1-77b3-44c1-9e7f-0d5ab5daa3c5"
#> 
#> $proposals[[2]]$agent_name
#> [1] "stylist2"
#> 
#> $proposals[[2]]$response
#> Pair the blue Calvin Klein shirt and pink trousers with a neutral-colored (gray
#> or navy) sweater or blazer and complete the look with stylish boots or loafers 
#> for a chic winter outfit.
#> 
#> 
#> 
#> $chosen_response
#> Layer the blue Calvin Klein shirt with a neutral-toned (like gray or navy) 
#> sweater or blazer, add a matching scarf for warmth, and wear neutral shoes to 
#> balance the bold pink trousers.
```

## Code of Conduct

Please note that the mini007 project is released with a [Contributor
Code of
Conduct](https://contributor-covenant.org/version/2/1/CODE_OF_CONDUCT.html).
By contributing to this project, you agree to abide by its terms.
