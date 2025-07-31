
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

openai_llm_object <- ellmer::chat(
  name = "openai/gpt-4.1-mini",
  api_key = Sys.getenv("OPENAI_API_KEY"), 
  echo = "none"
)
```

After initialising the `ellmer` LLM object, creating the Agent is
straightforward:

``` r
polar_bear_researcher <- Agent$new(
  name = "POLAR BEAR RESEARCHER",
  instruction = "You are an expert in polar bears, you task is to collect information about polar bears.",
  llm_object = openai_llm_object
)
```

Each created Agent has an `agent_id` (among other meta information):

``` r
polar_bear_researcher$agent_id
#> [1] "28e71f6a-3432-417d-afba-2db99a62296d"
```

At any time, you can tweak the `llm_object`:

``` r
polar_bear_researcher$llm_object
#> <Chat OpenAI/gpt-4.1-mini turns=1 tokens=0/0 $0.00>
#> ── system [0] ──────────────────────────────────────────────────────────────────
#> You are an expert in polar bears, you task is to collect information about polar bears.
```

An agent can provide the answer to a prompt using the `invoke` method:

``` r
polar_bear_researcher$invoke("Are polar bears dangerous for humans?")
#> Yes, polar bears can be dangerous to humans. They are large, powerful predators
#> and are known to be more aggressive compared to other bear species. Polar bears
#> primarily hunt seals and are adapted to the Arctic environment, but if they 
#> feel threatened or are hungry and see humans as potential prey, they may 
#> attack. 
#> 
#> Encounters between polar bears and humans can be risky, especially in regions 
#> where bears are common and humans venture out for research, hunting, or 
#> tourism. It is important to exercise caution in polar bear habitats by:
#> 
#> - Making noise to alert bears of human presence
#> - Carrying deterrents like bear spray
#> - Avoiding areas with recent bear activity
#> - Traveling in groups
#> - Securing food and waste to avoid attracting bears
#> 
#> Overall, while polar bears do not typically seek out humans as prey, they are 
#> capable of causing serious injury or death and should be respected and handled 
#> with caution.
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
#> Yes, polar bears can be dangerous to humans. They are large, powerful predators
#> and are known to be more aggressive compared to other bear species. Polar bears
#> primarily hunt seals and are adapted to the Arctic environment, but if they 
#> feel threatened or are hungry and see humans as potential prey, they may 
#> attack. 
#> 
#> Encounters between polar bears and humans can be risky, especially in regions 
#> where bears are common and humans venture out for research, hunting, or 
#> tourism. It is important to exercise caution in polar bear habitats by:
#> 
#> - Making noise to alert bears of human presence
#> - Carrying deterrents like bear spray
#> - Avoiding areas with recent bear activity
#> - Traveling in groups
#> - Securing food and waste to avoid attracting bears
#> 
#> Overall, while polar bears do not typically seek out humans as prey, they are 
#> capable of causing serious injury or death and should be respected and handled 
#> with caution.
```

Or the `ellmer` way:

``` r
polar_bear_researcher$llm_object
#> <Chat OpenAI/gpt-4.1-mini turns=3 tokens=36/180 $0.00>
#> ── system [0] ──────────────────────────────────────────────────────────────────
#> You are an expert in polar bears, you task is to collect information about polar bears.
#> ── user [36] ───────────────────────────────────────────────────────────────────
#> Are polar bears dangerous for humans?
#> ── assistant [180] ─────────────────────────────────────────────────────────────
#> Yes, polar bears can be dangerous to humans. They are large, powerful predators and are known to be more aggressive compared to other bear species. Polar bears primarily hunt seals and are adapted to the Arctic environment, but if they feel threatened or are hungry and see humans as potential prey, they may attack. 
#> 
#> Encounters between polar bears and humans can be risky, especially in regions where bears are common and humans venture out for research, hunting, or tourism. It is important to exercise caution in polar bear habitats by:
#> 
#> - Making noise to alert bears of human presence
#> - Carrying deterrents like bear spray
#> - Avoiding areas with recent bear activity
#> - Traveling in groups
#> - Securing food and waste to avoid attracting bears
#> 
#> Overall, while polar bears do not typically seek out humans as prey, they are capable of causing serious injury or death and should be respected and handled with caution.
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
  llm_object = openai_llm_object
)

summarizer <- Agent$new(
  name = "summarizer",
  instruction = "You are agent designed to summarise a give text into 3 distinct bullet points.",
  llm_object = openai_llm_object
)

translator <- Agent$new(
  name = "translator",
  instruction = "Your role is to translate a text from English to German",
  llm_object = openai_llm_object
)
```

Now, the most important part is to create a `LeadAgent`:

``` r
lead_agent <- LeadAgent$new(
  name = "Leader", 
  llm_object = openai_llm_object
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
#>     agent_id: 0fac0f6f-2239-4d57-b993-d9c0830cf9e8
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
#>     agent_id: 18fcaf8b-0c6a-48e6-a72c-11a3bd382bff
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
#>     agent_id: e4c99024-8442-4521-8f5a-87130912ede1
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

In order now to execute the workflow, we just need to call the `invoke`
method which will behind the scene delegate the prompts to suitable
Agents and retrieve back the final information:

``` r
response <- lead_agent$invoke("Tell me about the economic situation in Algeria, summarize it in 3 bullet points, then translate it into German.")
```

``` r
response
#> - Das BIP-Wachstum Algeriens ist mit 2-3 % bescheiden und wird hauptsächlich 
#> durch die Erholung nach COVID vorangetrieben.  
#> - Die Wirtschaft ist stark von Kohlenwasserstoffen abhängig, die über 90 % der 
#> Exporte und 30 % des BIP ausmachen, was zu einer Anfälligkeit gegenüber 
#> Schwankungen der Ölpreise führt.  
#> - Wichtige Herausforderungen sind Arbeitslosigkeit und mangelnde 
#> wirtschaftliche Diversifizierung, während Chancen im Bereich der erneuerbaren 
#> Energien und der Anziehung ausländischer Investitionen bestehen.
```

If you want to inspect the multi-agents orchestration, you have access
to the `agents_interaction` object:

``` r
lead_agent$agents_interaction
#> [[1]]
#> [[1]]$agent_id
#> 0fac0f6f-2239-4d57-b993-d9c0830cf9e8
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
#> [1] "Research the current economic situation in Algeria, including key indicators such as GDP growth, main economic sectors, and recent challenges or opportunities."
#> 
#> [[1]]$response
#> As of early 2024, Algeria's GDP growth is modest, around 2-3%, recovering 
#> post-COVID; the economy heavily relies on hydrocarbons (oil and gas), which 
#> constitute over 90% of exports and 30% of GDP. Challenges include dependence on
#> volatile oil prices, unemployment, and economic diversification, while 
#> opportunities lie in renewable energy development and attracting foreign 
#> investment.
#> 
#> 
#> [[2]]
#> [[2]]$agent_id
#> 18fcaf8b-0c6a-48e6-a72c-11a3bd382bff
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
#> [1] "Summarize the findings into 3 clear and concise bullet points."
#> 
#> [[2]]$response
#> - Algeria's GDP growth is modest at 2-3%, driven largely by post-COVID 
#> recovery.  
#> - The economy is highly dependent on hydrocarbons, accounting for over 90% of 
#> exports and 30% of GDP, creating vulnerability to oil price fluctuations.  
#> - Key challenges include unemployment and lack of economic diversification, 
#> while opportunities exist in renewable energy and foreign investment 
#> attraction.
#> 
#> 
#> [[3]]
#> [[3]]$agent_id
#> e4c99024-8442-4521-8f5a-87130912ede1
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
#> [1] "Translate the 3 bullet points into German accurately."
#> 
#> [[3]]$response
#> - Das BIP-Wachstum Algeriens ist mit 2-3 % bescheiden und wird hauptsächlich 
#> durch die Erholung nach COVID vorangetrieben.  
#> - Die Wirtschaft ist stark von Kohlenwasserstoffen abhängig, die über 90 % der 
#> Exporte und 30 % des BIP ausmachen, was zu einer Anfälligkeit gegenüber 
#> Schwankungen der Ölpreise führt.  
#> - Wichtige Herausforderungen sind Arbeitslosigkeit und mangelnde 
#> wirtschaftliche Diversifizierung, während Chancen im Bereich der erneuerbaren 
#> Energien und der Anziehung ausländischer Investitionen bestehen.
```

The above example is extremely simple, the usefulness of `mini007` would
shine in more complex processes where a multi-agent sequential
orchestration has a higher value added.

## Code of Conduct

Please note that the mini007 project is released with a [Contributor
Code of
Conduct](https://contributor-covenant.org/version/2/1/CODE_OF_CONDUCT.html).
By contributing to this project, you agree to abide by its terms.
