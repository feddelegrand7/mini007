
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

After initialising the `ellmer` LLM object, creating the Agent is
straightforward:

``` r
polar_bear_researcher <- Agent$new(
  name = "POLAR BEAR RESEARCHER",
  instruction = "You are an expert in polar bears, you task is to collect information about polar bears.",
  llm_object = openai_4_1_mini
)
```

Each created Agent has an `agent_id` (among other meta information):

``` r
polar_bear_researcher$agent_id
#> [1] "f47583f5-944d-4793-bad4-29eb696c933e"
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
#> Yes, polar bears can be dangerous for humans. They are powerful predators and 
#> are known to be aggressive if they feel threatened or are hungry. Polar bears 
#> are the largest land carnivores, with adult males weighing between 900 to 1,600
#> pounds (410 to 720 kg), and they have strong jaws and sharp claws. Because they
#> live in remote Arctic regions where human presence is limited, encounters are 
#> rare, but when they do occur, polar bears can pose a significant threat to 
#> human safety. It is important for people in polar bear habitats to take 
#> precautions, such as carrying deterrents and avoiding surprise encounters, to 
#> minimize the risk of attacks.
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
#> Yes, polar bears can be dangerous for humans. They are powerful predators and 
#> are known to be aggressive if they feel threatened or are hungry. Polar bears 
#> are the largest land carnivores, with adult males weighing between 900 to 1,600
#> pounds (410 to 720 kg), and they have strong jaws and sharp claws. Because they
#> live in remote Arctic regions where human presence is limited, encounters are 
#> rare, but when they do occur, polar bears can pose a significant threat to 
#> human safety. It is important for people in polar bear habitats to take 
#> precautions, such as carrying deterrents and avoiding surprise encounters, to 
#> minimize the risk of attacks.
```

Or the `ellmer` way:

``` r
polar_bear_researcher$llm_object
#> <Chat OpenAI/gpt-4.1-mini turns=3 tokens=36/131 $0.00>
#> ── system [0] ──────────────────────────────────────────────────────────────────
#> You are an expert in polar bears, you task is to collect information about polar bears.
#> ── user [36] ───────────────────────────────────────────────────────────────────
#> Are polar bears dangerous for humans?
#> ── assistant [131] ─────────────────────────────────────────────────────────────
#> Yes, polar bears can be dangerous for humans. They are powerful predators and are known to be aggressive if they feel threatened or are hungry. Polar bears are the largest land carnivores, with adult males weighing between 900 to 1,600 pounds (410 to 720 kg), and they have strong jaws and sharp claws. Because they live in remote Arctic regions where human presence is limited, encounters are rare, but when they do occur, polar bears can pose a significant threat to human safety. It is important for people in polar bear habitats to take precautions, such as carrying deterrents and avoiding surprise encounters, to minimize the risk of attacks.
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
#>     agent_id: 8da36dee-f15a-49da-ba98-edfa95eeb029
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
#>     agent_id: 91301051-ea22-41e4-b2b9-ed82832ed6ba
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
#>     agent_id: 997f9209-bac2-45e1-bf07-de8968e2a5c2
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

In order now to execute the workflow, we just need to call the `invoke`
method which will behind the scene delegate the prompts to suitable
Agents and retrieve back the final information:

``` r
response <- lead_agent$invoke("Tell me about the economic situation in Algeria, summarize it in 3 bullet points, then translate it into German.")
```

``` r
response
#> - Das Wirtschaftswachstum Algeriens ist bescheiden, mit einem Anstieg des BIP 
#> um etwa 2-3 %, hauptsächlich getragen von Öl- und Gaseinfuhren.  
#> - Die Arbeitslosenquote ist hoch, insbesondere bei Jugendlichen, mit Raten 
#> zwischen 12-15 %.  
#> - Die Wirtschaft ist stark von Kohlenwasserstoffen abhängig (über 90 % der 
#> Exporte), neben den Sektoren Landwirtschaft und Dienstleistungen.
```

If you want to inspect the multi-agents orchestration, you have access
to the `agents_interaction` object:

``` r
lead_agent$agents_interaction
#> [[1]]
#> [[1]]$agent_id
#> 8da36dee-f15a-49da-ba98-edfa95eeb029
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
#> [1] "Research the current economic situation in Algeria, including key indicators like GDP growth, unemployment rate, and major sectors."
#> 
#> [[1]]$response
#> As of early 2024, Algeria's GDP growth is modest at around 2-3%, driven by oil 
#> and gas exports. The unemployment rate remains high, approximately 12-15%, 
#> particularly among youth. Key sectors include hydrocarbons (over 90% of 
#> exports), agriculture, and services.
#> 
#> 
#> [[2]]
#> [[2]]$agent_id
#> 91301051-ea22-41e4-b2b9-ed82832ed6ba
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
#> [1] "Summarize the findings into 3 concise bullet points that capture the main aspects of Algeria's economic situation."
#> 
#> [[2]]$response
#> - Algeria's economic growth is modest, with GDP increasing around 2-3%, mainly 
#> supported by oil and gas exports.  
#> - Unemployment is high, especially among youth, with rates between 12-15%.  
#> - The economy is heavily reliant on hydrocarbons (over 90% of exports), 
#> alongside agriculture and services sectors.
#> 
#> 
#> [[3]]
#> [[3]]$agent_id
#> 997f9209-bac2-45e1-bf07-de8968e2a5c2
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
#> - Das Wirtschaftswachstum Algeriens ist bescheiden, mit einem Anstieg des BIP 
#> um etwa 2-3 %, hauptsächlich getragen von Öl- und Gaseinfuhren.  
#> - Die Arbeitslosenquote ist hoch, insbesondere bei Jugendlichen, mit Raten 
#> zwischen 12-15 %.  
#> - Die Wirtschaft ist stark von Kohlenwasserstoffen abhängig (über 90 % der 
#> Exporte), neben den Sektoren Landwirtschaft und Dienstleistungen.
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
#> [1] "89adf885-9007-44ce-add1-2f5b02084dc2"
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
#> If you were Algerian, you might sing "Ya Rayah" under the rain, while a flower 
#> might "sing" the gentle melody of "Fleur d'Algérie."
#> 
#> 
#> [[2]]
#> [[2]]$agent_id
#> [1] "9f6b97f1-8c52-4357-acdc-9bb3b860a337"
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
#> If you were Algerian, you might enjoy singing "Zina" by Souad Massi when 
#> running under the rain and "Azzam" by Cheb Khaled when admiring a flower.
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
#> [1] "89adf885-9007-44ce-add1-2f5b02084dc2"
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
#> If you were Algerian, you might sing "Ya Rayah" under the rain, while a flower 
#> might "sing" the gentle melody of "Fleur d'Algérie."
#> 
#> 
#> [[1]]$responses[[2]]
#> [[1]]$responses[[2]]$agent_id
#> [1] "9f6b97f1-8c52-4357-acdc-9bb3b860a337"
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
#> If you were Algerian, you might enjoy singing "Zina" by Souad Massi when 
#> running under the rain and "Azzam" by Cheb Khaled when admiring a flower.
```

## Code of Conduct

Please note that the mini007 project is released with a [Contributor
Code of
Conduct](https://contributor-covenant.org/version/2/1/CODE_OF_CONDUCT.html).
By contributing to this project, you agree to abide by its terms.
