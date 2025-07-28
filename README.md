
<!-- README.md is generated from README.Rmd. Please edit that file -->

# mini007 <a><img src='man/figures/mini007cute.png' align="right" height="200" /></a>

<!-- badges: start -->

<!-- badges: end -->

`mini007` provides a lightweight and extensible framework multi-agents
orchestration processes capable of decomposing complex tasks and
assigning them to specialized agents.

Each `agent` is an extension of an `ellmer` object. `mini007` relies
heavily on the excellent `ellmer` package but aims to make it easy to
create a process where multiple specialized agents help each other in
order to execute a task.

`mini007` provides two types of agents:

- A normal `Agent` containing a name and an instruction,
- and a `LeadAgent` which will take a complex prompt, split it, assign
  to the adequate agents and retrieve the response.

#### Highlights

🧠 Memory and identity for each agent via `uuid` and message history.

⚙️ Built-in task decomposition and delegation via `LLM`.

🔄 Agent-to-agent orchestration with result chaining.

🌐 Compatible with any OpenAI-style chat model via `ellmer`.

You can install the development version of `mini007` like so:

``` r
devtools::install_github("feddelegrand7/mini007")
```

### Creating an Agent

Creating an agent is really easy, you need to provide the `OpenAI` API
key and the `model` name. Note that at the moment, only `OpenAI` models
are supported but if needed, feel free to open an issue:

``` r
library(mini007)
```

``` r
polar_bear_researcher <- Agent$new(
  name = "POLAR BEAR RESEARCHER",
  instruction = "You are an expert in polar bears, you task is to collect information about polar bears.",
  model = "gpt-4.1-mini", 
  api_key = Sys.getenv("OPENAI_API_KEY")
)
```

Each created Agent has an `agent_id`, a `name` and an `instruction`.

``` r
polar_bear_researcher$agent_id
#> [1] "3302e693-393f-487c-bca9-5c8761c0f0a9"
```

``` r
polar_bear_researcher$name
#> [1] "POLAR BEAR RESEARCHER"
```

``` r
polar_bear_researcher$instruction
#> [1] "You are an expert in polar bears, you task is to collect information about polar bears."
```

As mentioned previously, in a technical term, an Agent is an extension
of an `ellmer` object. You can execute the following in order to access
the underlying `ellmer` object:

``` r
polar_bear_researcher$llm_object
#> <Chat OpenAI/gpt-4.1-mini turns=1 tokens=0/0 $0.00>
#> ── system [0] ──────────────────────────────────────────────────────────────────
#> You are an expert in polar bears, you task is to collect information about polar bears.
```

You can tweak the `llm_object` the same way as an `ellmer` object (set a
structured output, define a set of tools and so on).

An agent can provide the answer to a prompt using the `invoke` method:

``` r
polar_bear_researcher$invoke("Are polar bears dangerous for humans?")
#> [1] "Yes, polar bears can be dangerous to humans. As apex predators, they are powerful and capable hunters. While polar bears generally avoid human contact, they may become aggressive if they feel threatened, are surprised, or if they are hungry. Attacks on humans, although rare, have occurred, especially in areas where humans and polar bears share habitat.\n\nKey points about polar bear danger to humans:\n\n1. **Predatory Behavior**: Polar bears primarily hunt seals but may view humans as prey in extreme circumstances, especially when food is scarce.\n\n2. **Territoriality and Protection**: A mother polar bear with cubs is particularly defensive and can be highly aggressive to protect her young.\n\n3. **Habitat Overlap**: In Arctic regions where humans live or work, encounters with polar bears are more common, increasing the risk of dangerous encounters.\n\n4. **Precautions**: People in polar bear territory are advised to carry deterrents such as bear spray, use proper safety protocols, and avoid attracting bears with food.\n\nIn summary, while polar bears don't typically seek out humans as prey, they are potentially dangerous due to their size, strength, and predatory nature, and caution should always be exercised in polar bear habitats."
```

You can also retrieve a list that displays the history of the agent:

``` r
polar_bear_researcher$messages
#> [[1]]
#> [[1]]$role
#> [1] "system"
#> 
#> [[1]]$content
#> [1] "You are an expert in polar bears, you task is to collect information about polar bears."
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
#> [1] "Yes, polar bears can be dangerous to humans. As apex predators, they are powerful and capable hunters. While polar bears generally avoid human contact, they may become aggressive if they feel threatened, are surprised, or if they are hungry. Attacks on humans, although rare, have occurred, especially in areas where humans and polar bears share habitat.\n\nKey points about polar bear danger to humans:\n\n1. **Predatory Behavior**: Polar bears primarily hunt seals but may view humans as prey in extreme circumstances, especially when food is scarce.\n\n2. **Territoriality and Protection**: A mother polar bear with cubs is particularly defensive and can be highly aggressive to protect her young.\n\n3. **Habitat Overlap**: In Arctic regions where humans live or work, encounters with polar bears are more common, increasing the risk of dangerous encounters.\n\n4. **Precautions**: People in polar bear territory are advised to carry deterrents such as bear spray, use proper safety protocols, and avoid attracting bears with food.\n\nIn summary, while polar bears don't typically seek out humans as prey, they are potentially dangerous due to their size, strength, and predatory nature, and caution should always be exercised in polar bear habitats."
```

Or the `ellmer` way:

``` r
polar_bear_researcher$llm_object
#> <Chat OpenAI/gpt-4.1-mini turns=3 tokens=36/246 $0.00>
#> ── system [0] ──────────────────────────────────────────────────────────────────
#> You are an expert in polar bears, you task is to collect information about polar bears.
#> ── user [36] ───────────────────────────────────────────────────────────────────
#> Are polar bears dangerous for humans?
#> ── assistant [246] ─────────────────────────────────────────────────────────────
#> Yes, polar bears can be dangerous to humans. As apex predators, they are powerful and capable hunters. While polar bears generally avoid human contact, they may become aggressive if they feel threatened, are surprised, or if they are hungry. Attacks on humans, although rare, have occurred, especially in areas where humans and polar bears share habitat.
#> 
#> Key points about polar bear danger to humans:
#> 
#> 1. **Predatory Behavior**: Polar bears primarily hunt seals but may view humans as prey in extreme circumstances, especially when food is scarce.
#> 
#> 2. **Territoriality and Protection**: A mother polar bear with cubs is particularly defensive and can be highly aggressive to protect her young.
#> 
#> 3. **Habitat Overlap**: In Arctic regions where humans live or work, encounters with polar bears are more common, increasing the risk of dangerous encounters.
#> 
#> 4. **Precautions**: People in polar bear territory are advised to carry deterrents such as bear spray, use proper safety protocols, and avoid attracting bears with food.
#> 
#> In summary, while polar bears don't typically seek out humans as prey, they are potentially dangerous due to their size, strength, and predatory nature, and caution should always be exercised in polar bear habitats.
```

### Creating a multi-agents orchestraction

We can create as many Agents as we want, the `LeadAgent` will dispatch
the instructions to the agents and provide with the final answer back.
Let’s create two other Agents, a `summarizer` and a `translator`:

``` r

researcher <- Agent$new(
  name = "researcher",
  instruction = "You are a research assistant. Your job is to answer factual questions with detailed and accurate information. Do not answer with more than 2 lines",
  model = "gpt-4.1-mini",
  api_key = Sys.getenv("OPENAI_API_KEY")
)

summarizer <- Agent$new(
  name = "summarizer",
  instruction = "You are agent designed to summarise a give text into 3 distinct bullet points.",
  model = "gpt-4.1-mini", 
  api_key = Sys.getenv("OPENAI_API_KEY")
)

translator <- Agent$new(
  name = "translator",
  instruction = "Your role is to translate a text from English to German",
  model = "gpt-4.1-mini", 
  api_key = Sys.getenv("OPENAI_API_KEY")
)
```

Now, the most important part is to create a `LeadAgent`:

``` r
lead_agent <- LeadAgent$new(
  name = "Leader", 
  model = "gpt-4.1-mini", 
  api_key = Sys.getenv("OPENAI_API_KEY")
)
```

Note that the `LeadAgent` cannot receive an `instruction` as it has
already the necessary instructions.

Next, we need to assign the Agents to `LeadAgent`, we do it as follows:

``` r
lead_agent$register_agents(c(researcher, summarizer, translator))
lead_agent$agents
#> $`c5026e39-21fb-468d-b739-15e128a2b4b9`
#> <Agent>
#>   Public:
#>     agent_id: c5026e39-21fb-468d-b739-15e128a2b4b9
#>     clone: function (deep = FALSE) 
#>     initialize: function (name, instruction, model, verbose = FALSE, api_key = NULL) 
#>     instruction: You are a research assistant. Your job is to answer fact ...
#>     invoke: function (prompt) 
#>     llm_object: Chat, R6
#>     messages: list
#>     name: researcher
#>   Private:
#>     .add_assistant_message: function (message, type = "assistant") 
#>     .add_message: function (message, type) 
#>     .add_user_message: function (message, type = "user") 
#> 
#> $`e83902b7-133f-4595-947d-a5b6a8ec492c`
#> <Agent>
#>   Public:
#>     agent_id: e83902b7-133f-4595-947d-a5b6a8ec492c
#>     clone: function (deep = FALSE) 
#>     initialize: function (name, instruction, model, verbose = FALSE, api_key = NULL) 
#>     instruction: You are agent designed to summarise a give text into 3 d ...
#>     invoke: function (prompt) 
#>     llm_object: Chat, R6
#>     messages: list
#>     name: summarizer
#>   Private:
#>     .add_assistant_message: function (message, type = "assistant") 
#>     .add_message: function (message, type) 
#>     .add_user_message: function (message, type = "user") 
#> 
#> $`096c581b-86e8-44c4-a442-05c073c9cd77`
#> <Agent>
#>   Public:
#>     agent_id: 096c581b-86e8-44c4-a442-05c073c9cd77
#>     clone: function (deep = FALSE) 
#>     initialize: function (name, instruction, model, verbose = FALSE, api_key = NULL) 
#>     instruction: Your role is to translate a text from English to German
#>     invoke: function (prompt) 
#>     llm_object: Chat, R6
#>     messages: list
#>     name: translator
#>   Private:
#>     .add_assistant_message: function (message, type = "assistant") 
#>     .add_message: function (message, type) 
#>     .add_user_message: function (message, type = "user")
```

You can see from above that the above defined Agents are now assigned to
the `LeadAgent`.

In order now to execute the workflow, we just need to call the `invoke`
method which will behind the scene delegate the prompts to suitable
Agents and retrieve back the final information:

``` r
response <- lead_agent$invoke("Tell me about the economic situation in Algeria, summarize it in 3 bullet points, then translate it into German.")
```

``` r
response
#> [1] "- Das BIP-Wachstum Algeriens für 2024 wird auf etwa 2,5 % prognostiziert.  \n- Die Inflation wird voraussichtlich rund 6 % betragen, mit Arbeitslosenquoten zwischen 11 und 12 %.  \n- Die Wirtschaft wird hauptsächlich von den kohlenwasserstoffbasierten Sektoren (Öl und Gas) angetrieben, daneben spielen Landwirtschaft und Bergbau eine Rolle."
```

If you want to inspect the multi-agents orchestration, you have access
to the `agents_interaction` object:

``` r
lead_agent$agents_interaction
#> [[1]]
#> [[1]]$agent_id
#> [1] "c5026e39-21fb-468d-b739-15e128a2b4b9"
#> 
#> [[1]]$agent_name
#> [1] "researcher"
#> 
#> [[1]]$prompt
#> [1] "1. Research the current economic situation in Algeria, including key indicators such as GDP growth, inflation rate, unemployment, and major industries."
#> 
#> [[1]]$response
#> [1] "Algeria's 2024 GDP growth is projected at around 2.5%, with inflation near 6%, and unemployment rates about 11-12%. Key industries include hydrocarbons (oil and gas, which dominate the economy), agriculture, and mining."
#> 
#> 
#> [[2]]
#> [[2]]$agent_id
#> [1] "e83902b7-133f-4595-947d-a5b6a8ec492c"
#> 
#> [[2]]$agent_name
#> [1] "summarizer"
#> 
#> [[2]]$prompt
#> [1] "2. Summarize the researched information into 3 concise bullet points."
#> 
#> [[2]]$response
#> [1] "- Algeria's GDP growth for 2024 is projected at approximately 2.5%.  \n- Inflation is expected to be around 6%, with unemployment rates between 11-12%.  \n- The economy is primarily driven by hydrocarbons (oil and gas), alongside agriculture and mining sectors."
#> 
#> 
#> [[3]]
#> [[3]]$agent_id
#> [1] "096c581b-86e8-44c4-a442-05c073c9cd77"
#> 
#> [[3]]$agent_name
#> [1] "translator"
#> 
#> [[3]]$prompt
#> [1] "3. Translate the 3 bullet points summary into German."
#> 
#> [[3]]$response
#> [1] "- Das BIP-Wachstum Algeriens für 2024 wird auf etwa 2,5 % prognostiziert.  \n- Die Inflation wird voraussichtlich rund 6 % betragen, mit Arbeitslosenquoten zwischen 11 und 12 %.  \n- Die Wirtschaft wird hauptsächlich von den kohlenwasserstoffbasierten Sektoren (Öl und Gas) angetrieben, daneben spielen Landwirtschaft und Bergbau eine Rolle."
```

The above example is extremely simple, the usefulness of `mini007` would
shine in more complex processes where a multi-agent sequential
orchestration has a higher value added.

## Code of Conduct

Please note that the mini007 project is released with a [Contributor
Code of
Conduct](https://contributor-covenant.org/version/2/1/CODE_OF_CONDUCT.html).
By contributing to this project, you agree to abide by its terms.
