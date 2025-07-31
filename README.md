
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
#> [1] "e9605a8f-a536-4a60-910e-91402fad156b"
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
#> Yes, polar bears can be dangerous for humans. They are large, powerful 
#> predators and are known to be aggressive if they feel threatened or are hungry.
#> Polar bears have been involved in attacks on humans, although such incidents 
#> are relatively rare due to the remote and sparsely populated regions they 
#> inhabit.
#> 
#> Key points about polar bears and their potential danger to humans:
#> 
#> 1. **Size and Strength**: Polar bears are the largest land carnivores. Adult 
#> males can weigh between 900 to 1,600 pounds (410 to 720 kg) and stand about 8 
#> to 10 feet tall when on their hind legs. Their size and strength make them 
#> formidable predators.
#> 
#> 2. **Behavior**: They are generally solitary animals but are highly 
#> territorial, especially females with cubs. They may attack humans defensively 
#> or if they mistake a person for prey.
#> 
#> 3. **Habitat**: Polar bears live in Arctic regions, primarily on sea ice, where
#> encounters with humans are infrequent but possible, especially for indigenous 
#> peoples, researchers, and travelers.
#> 
#> 4. **Food Scarcity**: Changes in sea ice due to climate change are affecting 
#> their hunting habits, potentially increasing encounters with humans as bears 
#> search for food.
#> 
#> 5. **Preventive Measures**: People living or traveling in polar bear habitats 
#> are advised to take precautions such as carrying deterrents (like bear spray 
#> and noise makers), traveling in groups, and properly storing food to avoid 
#> attracting bears.
#> 
#> In summary, while polar bears are not typically aggressive toward humans 
#> without provocation, they are capable of causing serious harm and should be 
#> treated with caution and respect in the wild.
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
#> Yes, polar bears can be dangerous for humans. They are large, powerful 
#> predators and are known to be aggressive if they feel threatened or are hungry.
#> Polar bears have been involved in attacks on humans, although such incidents 
#> are relatively rare due to the remote and sparsely populated regions they 
#> inhabit.
#> 
#> Key points about polar bears and their potential danger to humans:
#> 
#> 1. **Size and Strength**: Polar bears are the largest land carnivores. Adult 
#> males can weigh between 900 to 1,600 pounds (410 to 720 kg) and stand about 8 
#> to 10 feet tall when on their hind legs. Their size and strength make them 
#> formidable predators.
#> 
#> 2. **Behavior**: They are generally solitary animals but are highly 
#> territorial, especially females with cubs. They may attack humans defensively 
#> or if they mistake a person for prey.
#> 
#> 3. **Habitat**: Polar bears live in Arctic regions, primarily on sea ice, where
#> encounters with humans are infrequent but possible, especially for indigenous 
#> peoples, researchers, and travelers.
#> 
#> 4. **Food Scarcity**: Changes in sea ice due to climate change are affecting 
#> their hunting habits, potentially increasing encounters with humans as bears 
#> search for food.
#> 
#> 5. **Preventive Measures**: People living or traveling in polar bear habitats 
#> are advised to take precautions such as carrying deterrents (like bear spray 
#> and noise makers), traveling in groups, and properly storing food to avoid 
#> attracting bears.
#> 
#> In summary, while polar bears are not typically aggressive toward humans 
#> without provocation, they are capable of causing serious harm and should be 
#> treated with caution and respect in the wild.
```

Or the `ellmer` way:

``` r
polar_bear_researcher$llm_object
#> <Chat OpenAI/gpt-4.1-mini turns=3 tokens=36/324 $0.00>
#> ── system [0] ──────────────────────────────────────────────────────────────────
#> You are an expert in polar bears, you task is to collect information about polar bears.
#> ── user [36] ───────────────────────────────────────────────────────────────────
#> Are polar bears dangerous for humans?
#> ── assistant [324] ─────────────────────────────────────────────────────────────
#> Yes, polar bears can be dangerous for humans. They are large, powerful predators and are known to be aggressive if they feel threatened or are hungry. Polar bears have been involved in attacks on humans, although such incidents are relatively rare due to the remote and sparsely populated regions they inhabit.
#> 
#> Key points about polar bears and their potential danger to humans:
#> 
#> 1. **Size and Strength**: Polar bears are the largest land carnivores. Adult males can weigh between 900 to 1,600 pounds (410 to 720 kg) and stand about 8 to 10 feet tall when on their hind legs. Their size and strength make them formidable predators.
#> 
#> 2. **Behavior**: They are generally solitary animals but are highly territorial, especially females with cubs. They may attack humans defensively or if they mistake a person for prey.
#> 
#> 3. **Habitat**: Polar bears live in Arctic regions, primarily on sea ice, where encounters with humans are infrequent but possible, especially for indigenous peoples, researchers, and travelers.
#> 
#> 4. **Food Scarcity**: Changes in sea ice due to climate change are affecting their hunting habits, potentially increasing encounters with humans as bears search for food.
#> 
#> 5. **Preventive Measures**: People living or traveling in polar bear habitats are advised to take precautions such as carrying deterrents (like bear spray and noise makers), traveling in groups, and properly storing food to avoid attracting bears.
#> 
#> In summary, while polar bears are not typically aggressive toward humans without provocation, they are capable of causing serious harm and should be treated with caution and respect in the wild.
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
#> $`ded5802b-edc3-4713-864a-e0a8c20bb948`
#> <Agent>
#>   Public:
#>     agent_id: ded5802b-edc3-4713-864a-e0a8c20bb948
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
#> $`b1004844-446a-4542-be8f-38f2aa06f76f`
#> <Agent>
#>   Public:
#>     agent_id: b1004844-446a-4542-be8f-38f2aa06f76f
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
#> $`047e5333-e115-462e-b8f1-204d865863c4`
#> <Agent>
#>   Public:
#>     agent_id: 047e5333-e115-462e-b8f1-204d865863c4
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
#> - Das BIP-Wachstum Algeriens ist mit 2-3 % moderat und wird hauptsächlich vom 
#> Energiesektor getrieben.  
#> - Die Inflation ist moderat (6-7 %), während die Arbeitslosigkeit, insbesondere
#> unter Jugendlichen, mit 12-15 % hoch bleibt.  
#> - Landwirtschaft und Dienstleistungssektor sind kleinere, aber wachsende 
#> Bereiche neben der dominierenden Öl- und Gasindustrie.
```

If you want to inspect the multi-agents orchestration, you have access
to the `agents_interaction` object:

``` r
lead_agent$agents_interaction
#> [[1]]
#> [[1]]$agent_id
#> ded5802b-edc3-4713-864a-e0a8c20bb948
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
#> [1] "Research the current economic situation in Algeria, including key indicators such as GDP growth, inflation, unemployment, and major sectors driving the economy."
#> 
#> [[1]]$response
#> As of early 2024, Algeria's GDP growth is modest, around 2-3%, driven mainly by
#> hydrocarbons which dominate exports and government revenues. Inflation is 
#> moderate at about 6-7%, unemployment remains high, especially among youth, 
#> around 12-15%. Besides oil and gas, agriculture and services are smaller but 
#> growing sectors.
#> 
#> 
#> [[2]]
#> [[2]]$agent_id
#> b1004844-446a-4542-be8f-38f2aa06f76f
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
#> [1] "Summarize the researched information into 3 concise and clear bullet points."
#> 
#> [[2]]$response
#> - Algeria's GDP growth is modest at 2-3%, primarily driven by the hydrocarbon 
#> sector.
#> - Inflation is moderate (6-7%) while unemployment, especially among youth, 
#> remains high at 12-15%.
#> - Agriculture and services are smaller but expanding sectors beyond the 
#> dominant oil and gas industry.
#> 
#> 
#> [[3]]
#> [[3]]$agent_id
#> 047e5333-e115-462e-b8f1-204d865863c4
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
#> [1] "Translate the 3 bullet points into German accurately, maintaining the original meaning."
#> 
#> [[3]]$response
#> - Das BIP-Wachstum Algeriens ist mit 2-3 % moderat und wird hauptsächlich vom 
#> Energiesektor getrieben.  
#> - Die Inflation ist moderat (6-7 %), während die Arbeitslosigkeit, insbesondere
#> unter Jugendlichen, mit 12-15 % hoch bleibt.  
#> - Landwirtschaft und Dienstleistungssektor sind kleinere, aber wachsende 
#> Bereiche neben der dominierenden Öl- und Gasindustrie.
```

The above example is extremely simple, the usefulness of `mini007` would
shine in more complex processes where a multi-agent sequential
orchestration has a higher value added.

## Code of Conduct

Please note that the mini007 project is released with a [Contributor
Code of
Conduct](https://contributor-covenant.org/version/2/1/CODE_OF_CONDUCT.html).
By contributing to this project, you agree to abide by its terms.
