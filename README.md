
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

You can install the development version of `mini007` like so:

``` r
devtools::install_github("feddelegrand7/mini007")
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
#> [1] "371721b6-b4dd-467b-b0bc-63ea4f0962f1"
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
#> Yes, polar bears can be dangerous to humans as they are large predators and may
#> attack if threatened or hungry.
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
#> Yes, polar bears can be dangerous to humans as they are large predators and may
#> attack if threatened or hungry.
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
#> Yes, polar bears can be dangerous to humans as they are large predators and may attack if threatened or hungry.
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
lead_agent$agents
#> [[1]]
#> <Agent>
#>   Public:
#>     agent_id: db08eb26-2110-4128-98d7-c2beea1b08f0
#>     broadcast_history: list
#>     clone: function (deep = FALSE) 
#>     initialize: function (name, instruction, llm_object) 
#>     instruction: You are a research assistant. Your job is to answer fact ...
#>     invoke: function (prompt) 
#>     llm_object: Chat, R6
#>     messages: list
#>     model_name: gpt-4.1-mini
#>     model_provider: OpenAI
#>     name: researcher
#>   Private:
#>     .add_assistant_message: function (message, type = "assistant") 
#>     .add_message: function (message, type) 
#>     .add_user_message: function (message, type = "user") 
#> 
#> [[2]]
#> <Agent>
#>   Public:
#>     agent_id: 20760285-4b1b-48cf-a7df-7ffb60eea2b0
#>     broadcast_history: list
#>     clone: function (deep = FALSE) 
#>     initialize: function (name, instruction, llm_object) 
#>     instruction: You are agent designed to summarise a give text into 3 d ...
#>     invoke: function (prompt) 
#>     llm_object: Chat, R6
#>     messages: list
#>     model_name: gpt-4.1-mini
#>     model_provider: OpenAI
#>     name: summarizer
#>   Private:
#>     .add_assistant_message: function (message, type = "assistant") 
#>     .add_message: function (message, type) 
#>     .add_user_message: function (message, type = "user") 
#> 
#> [[3]]
#> <Agent>
#>   Public:
#>     agent_id: 408c25c6-0a05-4c2e-8ec0-288e95844e37
#>     broadcast_history: list
#>     clone: function (deep = FALSE) 
#>     initialize: function (name, instruction, llm_object) 
#>     instruction: Your role is to translate a text from English to German
#>     invoke: function (prompt) 
#>     llm_object: Chat, R6
#>     messages: list
#>     model_name: gpt-4.1-mini
#>     model_provider: OpenAI
#>     name: translator
#>   Private:
#>     .add_assistant_message: function (message, type = "assistant") 
#>     .add_message: function (message, type) 
#>     .add_user_message: function (message, type = "user")
```

Before executing your prompt, you can ask the `LeadAgent` to generate a
plan so that you can see which `Agent` will be used for which prompt,
you can do it as follows:

``` r
prompt_to_execute <- "Tell me about the economic situation in Algeria, summarize it in 3 bullet points, then translate it into German."

plan <- lead_agent$generate_plan(prompt_to_execute)
plan
#> [[1]]
#> [[1]]$agent_id
#> db08eb26-2110-4128-98d7-c2beea1b08f0
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
#> [1] "Research the current economic situation in Algeria, focusing on key indicators like GDP growth, unemployment rate, and major industries."
#> 
#> 
#> [[2]]
#> [[2]]$agent_id
#> 20760285-4b1b-48cf-a7df-7ffb60eea2b0
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
#> [1] "Summarize the researched information into three concise bullet points highlighting the main aspects of Algeria's economy."
#> 
#> 
#> [[3]]
#> [[3]]$agent_id
#> 408c25c6-0a05-4c2e-8ec0-288e95844e37
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
#> [1] "Translate the three bullet points summary into German accurately."
```

Now, in order now to execute the workflow, we just need to call the
`invoke` method which will behind the scene delegate the prompts to
suitable Agents and retrieve back the final information:

``` r
response <- lead_agent$invoke("Tell me about the economic situation in Algeria, summarize it in 3 bullet points, then translate it into German.")
```

``` r
response
#> NULL
```

If you want to inspect the multi-agents orchestration, you have access
to the `agents_interaction` object:

``` r
lead_agent$agents_interaction
#> [[1]]
#> [[1]]$agent_id
#> db08eb26-2110-4128-98d7-c2beea1b08f0
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
#> [1] "Research the current economic situation in Algeria, focusing on key indicators like GDP growth, unemployment rate, and major industries."
#> 
#> [[1]]$response
#> As of early 2024, Algeria's GDP growth is modest, around 2-3%, recovering from 
#> oil revenue fluctuations; unemployment remains high at approximately 12-14%, 
#> especially among youth. Key industries include hydrocarbons (oil and gas), 
#> agriculture, and mining.
#> 
#> [[1]]$edited_by_hitl
#> [1] FALSE
#> 
#> 
#> [[2]]
#> [[2]]$agent_id
#> 20760285-4b1b-48cf-a7df-7ffb60eea2b0
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
#> [1] "Summarize the researched information into three concise bullet points highlighting the main aspects of Algeria's economy."
#> 
#> [[2]]$response
#> - Algeria's GDP growth is modest at 2-3% in early 2024, showing recovery from 
#> oil revenue fluctuations.  
#> - Unemployment remains high, particularly among youth, at around 12-14%.  
#> - The economy is driven by key sectors including hydrocarbons (oil and gas), 
#> agriculture, and mining.
#> 
#> [[2]]$edited_by_hitl
#> [1] FALSE
#> 
#> 
#> [[3]]
#> [[3]]$agent_id
#> 408c25c6-0a05-4c2e-8ec0-288e95844e37
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
#> [1] "Translate the three bullet points summary into German accurately."
#> 
#> [[3]]$response
#> - Das BIP-Wachstum Algeriens liegt Anfang 2024 moderat bei 2-3 % und zeigt eine
#> Erholung von Schwankungen der Öleinnahmen.  
#> - Die Arbeitslosigkeit bleibt hoch, besonders unter Jugendlichen, und beträgt 
#> etwa 12-14 %.  
#> - Die Wirtschaft wird von wichtigen Sektoren wie Kohlenwasserstoffen (Öl und 
#> Gas), Landwirtschaft und Bergbau angetrieben.
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
```

``` r
lead_agent$broadcast(prompt = "If I were Algerian, which song would I like to sing when running under the rain? how about a flower?")
#> [[1]]
#> [[1]]$agent_id
#> [1] "3f8dc0aa-6197-4d67-90e4-6286dadc5c8a"
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
#> If you were Algerian, you might sing "Ya Rayah" when running under the rain, 
#> and if you were a flower, perhaps "El Bent El Shalabeya," both expressing 
#> longing and beauty in unique ways.
#> 
#> 
#> [[2]]
#> [[2]]$agent_id
#> [1] "9621f7d4-b968-4db4-8bf8-abec203f590f"
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
#> You might enjoy singing "Abdel Kader" by Khaled or "Ya Rayah," and for a 
#> flower, perhaps "Lili Boujarah" celebrating beauty and nature.
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
#> [1] "3f8dc0aa-6197-4d67-90e4-6286dadc5c8a"
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
#> If you were Algerian, you might sing "Ya Rayah" when running under the rain, 
#> and if you were a flower, perhaps "El Bent El Shalabeya," both expressing 
#> longing and beauty in unique ways.
#> 
#> 
#> [[1]]$responses[[2]]
#> [[1]]$responses[[2]]$agent_id
#> [1] "9621f7d4-b968-4db4-8bf8-abec203f590f"
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
#> You might enjoy singing "Abdel Kader" by Khaled or "Ya Rayah," and for a 
#> flower, perhaps "Lili Boujarah" celebrating beauty and nature.
```

## Code of Conduct

Please note that the mini007 project is released with a [Contributor
Code of
Conduct](https://contributor-covenant.org/version/2/1/CODE_OF_CONDUCT.html).
By contributing to this project, you agree to abide by its terms.
