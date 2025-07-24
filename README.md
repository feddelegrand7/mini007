
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
#> [1] "256b9095-d69c-4d50-b8b3-fddfe7d29119"
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
#> [1] "Yes, polar bears can be dangerous for humans. They are large, powerful predators and are known to be aggressive, especially when they feel threatened, are hungry, or are protecting their young. While polar bear attacks on humans are relatively rare due to the remote and harsh environments in which polar bears live, such encounters can be fatal. It is important for people in polar bear habitats, such as Arctic regions, to take precautions and follow safety guidelines to minimize the risk of conflicts with these animals."
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
#> [1] "Yes, polar bears can be dangerous for humans. They are large, powerful predators and are known to be aggressive, especially when they feel threatened, are hungry, or are protecting their young. While polar bear attacks on humans are relatively rare due to the remote and harsh environments in which polar bears live, such encounters can be fatal. It is important for people in polar bear habitats, such as Arctic regions, to take precautions and follow safety guidelines to minimize the risk of conflicts with these animals."
```

Or the `ellmer` way:

``` r
polar_bear_researcher$llm_object
#> <Chat OpenAI/gpt-4.1-mini turns=3 tokens=36/98 $0.00>
#> ── system [0] ──────────────────────────────────────────────────────────────────
#> You are an expert in polar bears, you task is to collect information about polar bears.
#> ── user [36] ───────────────────────────────────────────────────────────────────
#> Are polar bears dangerous for humans?
#> ── assistant [98] ──────────────────────────────────────────────────────────────
#> Yes, polar bears can be dangerous for humans. They are large, powerful predators and are known to be aggressive, especially when they feel threatened, are hungry, or are protecting their young. While polar bear attacks on humans are relatively rare due to the remote and harsh environments in which polar bears live, such encounters can be fatal. It is important for people in polar bear habitats, such as Arctic regions, to take precautions and follow safety guidelines to minimize the risk of conflicts with these animals.
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
  instruction = "You are a French translator. Only translate the input text into natural French without changing meaning.",
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
#> $`0eedcb7f-208c-4568-b6a3-316ce9ccf7e7`
#> <Agent>
#>   Public:
#>     agent_id: 0eedcb7f-208c-4568-b6a3-316ce9ccf7e7
#>     clone: function (deep = FALSE) 
#>     initialize: function (name, instruction, model, verbose = TRUE, api_key = NULL) 
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
#> $`44ba1558-5ce4-4034-be4b-bef04f18b7b1`
#> <Agent>
#>   Public:
#>     agent_id: 44ba1558-5ce4-4034-be4b-bef04f18b7b1
#>     clone: function (deep = FALSE) 
#>     initialize: function (name, instruction, model, verbose = TRUE, api_key = NULL) 
#>     instruction: You are a French translator. Only translate the input te ...
#>     invoke: function (prompt) 
#>     llm_object: Chat, R6
#>     messages: list
#>     name: summarizer
#>   Private:
#>     .add_assistant_message: function (message, type = "assistant") 
#>     .add_message: function (message, type) 
#>     .add_user_message: function (message, type = "user") 
#> 
#> $`624515ce-400d-4239-97d3-4ea34f88c2d0`
#> <Agent>
#>   Public:
#>     agent_id: 624515ce-400d-4239-97d3-4ea34f88c2d0
#>     clone: function (deep = FALSE) 
#>     initialize: function (name, instruction, model, verbose = TRUE, api_key = NULL) 
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
#> [1] "- Das BIP-Wachstum Algeriens liegt Anfang 2024 bei etwa 2-3 % und zeigt eine Erholung von früheren Herausforderungen.  \n- Die Inflation ist moderat bei 5-6 %, während die Arbeitslosigkeit mit 11-12 % relativ hoch bleibt.  \n- Die Wirtschaft wird hauptsächlich von Rohstoffen getragen, mit wachsendem Beitrag aus den Landwirtschafts- und Fertigungssektoren."
```

If you want to inspect the multi-agents orchestration, you have access
to the `agents_interaction` object:

``` r
lead_agent$agents_interaction
#> [[1]]
#> [[1]]$agent_id
#> [1] "0eedcb7f-208c-4568-b6a3-316ce9ccf7e7"
#> 
#> [[1]]$agent_name
#> [1] "researcher"
#> 
#> [[1]]$prompt
#> [1] "- Research the current economic situation in Algeria, including key indicators such as GDP growth, inflation, employment rates, and major sectors driving the economy."
#> 
#> [[1]]$response
#> [1] "As of early 2024, Algeria's GDP growth is estimated around 2-3%, recovering from past challenges; inflation is moderate at about 5-6%. The unemployment rate remains high near 11-12%, with hydrocarbons (oil and gas) as the major economic driver, alongside growing efforts in agriculture and manufacturing diversification."
#> 
#> 
#> [[2]]
#> [[2]]$agent_id
#> [1] "0eedcb7f-208c-4568-b6a3-316ce9ccf7e7"
#> 
#> [[2]]$agent_name
#> [1] "researcher"
#> 
#> [[2]]$prompt
#> [1] "- Summarize the researched information into 3 clear and concise bullet points."
#> 
#> [[2]]$response
#> [1] "- Algeria's GDP growth is around 2-3% in early 2024, showing recovery from previous challenges.  \n- Inflation is moderate at 5-6%, while unemployment remains relatively high at 11-12%.  \n- The economy is primarily driven by hydrocarbons, with growing contributions from agriculture and manufacturing sectors."
#> 
#> 
#> [[3]]
#> [[3]]$agent_id
#> [1] "624515ce-400d-4239-97d3-4ea34f88c2d0"
#> 
#> [[3]]$agent_name
#> [1] "translator"
#> 
#> [[3]]$prompt
#> [1] "- Translate the 3 bullet points summary from English into German."
#> 
#> [[3]]$response
#> [1] "- Das BIP-Wachstum Algeriens liegt Anfang 2024 bei etwa 2-3 % und zeigt eine Erholung von früheren Herausforderungen.  \n- Die Inflation ist moderat bei 5-6 %, während die Arbeitslosigkeit mit 11-12 % relativ hoch bleibt.  \n- Die Wirtschaft wird hauptsächlich von Rohstoffen getragen, mit wachsendem Beitrag aus den Landwirtschafts- und Fertigungssektoren."
```

The above example is extremely simple, the usefulness of `mini007` would
shine in more complex processes where a multi-agent sequential
orchestration has a higher value added.

## Code of Conduct

Please note that the mini007 project is released with a [Contributor
Code of
Conduct](https://contributor-covenant.org/version/2/1/CODE_OF_CONDUCT.html).
By contributing to this project, you agree to abide by its terms.
