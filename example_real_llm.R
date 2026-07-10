#' Real LLM Parallel Execution Example
#'
#' Demonstrates parallel execution with real LLM API calls using the Agent
#' class pattern from Agent.R combined with Workflow parallel stations.
#'
#' Analyzes "AI in Healthcare" from Technical, Business, and UX perspectives
#' in parallel using actual Agent objects with an ellmer-compatible LLM.
#'
#' Requirements:
#'   - ellmer R package: install.packages("ellmer")
#'   - OPENAI_API_KEY environment variable (or other compatible LLM provider)
#'
#' Usage:
#'   Rscript example_real_llm.R
#'   # or in R console:
#'   source("example_real_llm.R")
#'

library(mirai)
source("R/Workflow.R")

# ============================================================================
# Setup - Create LLM Object (following Agent.R pattern)
# ============================================================================

if (!requireNamespace("ellmer", quietly = TRUE)) {
  stop("Install with: install.packages('ellmer')")
}

# Check for API key
api_key <- Sys.getenv("OPENAI_API_KEY")
if (api_key == "") {
  stop("Set OPENAI_API_KEY environment variable with your API key")
}

cat("\n╔════════════════════════════════════════════════════════════════╗\n")
cat("║  Parallel Multi-Agent Analysis with Real LLM API Calls       ║\n")
cat("╚════════════════════════════════════════════════════════════════╝\n\n")

# Create ellmer chat object (compatible with Agent class)
llm <- ellmer::chat(
  name = "openai/gpt-4o-mini",
  api_key = api_key,
  echo = "none"
)

# ============================================================================
# Create Agents (following Agent.R pattern)
# ============================================================================

# Technical perspective agent
technical_agent <- Agent$new(
  name = "technical_analyst",
  instruction = paste(
    "You are a technical expert in AI and software engineering.",
    "Analyze topics from a technical/engineering perspective.",
    "Focus on: implementation details, technology stack, technical challenges.",
    "Keep responses to 2-3 sentences."
  ),
  llm_object = llm
)

# Business perspective agent
business_agent <- Agent$new(
  name = "business_strategist",
  instruction = paste(
    "You are a business strategist and market analyst.",
    "Analyze topics from a business/market perspective.",
    "Focus on: market opportunities, ROI, competitive advantage, business models.",
    "Keep responses to 2-3 sentences."
  ),
  llm_object = llm
)

# UX perspective agent
ux_agent <- Agent$new(
  name = "ux_specialist",
  instruction = paste(
    "You are a UX and product design specialist.",
    "Analyze topics from a user experience perspective.",
    "Focus on: user needs, design considerations, accessibility, user satisfaction.",
    "Keep responses to 2-3 sentences."
  ),
  llm_object = llm
)

# ============================================================================
# Create Workflow with Parallel Execution
# ============================================================================

# Clean up any existing daemons from previous runs
mirai::daemons(0)
Sys.sleep(0.5)

wf <- Workflow$new(
  name = "parallel_multi_agent_analysis",
  description = "Multi-perspective analysis using parallel Agent invocations"
)

# Set up 3 parallel workers for concurrent API calls
wf$set_daemons(3)

# Add input station (passthrough)
wf$add_station(
  "input",
  handler = function(x) x,
  description = "Input topic"
)

# Add three parallel Agent stations
# Note: Agents are invoked by the Workflow via their $invoke() method
wf$add_station(
  "technical_analysis",
  handler = technical_agent,
  description = "Technical perspective"
)

wf$add_station(
  "business_analysis",
  handler = business_agent,
  description = "Business perspective"
)

wf$add_station(
  "ux_analysis",
  handler = ux_agent,
  description = "UX perspective"
)

# Add synthesis station
wf$add_station(
  "synthesis",
  handler = function(x) {
    paste0(
      "═══════════════════════════════════════════\n",
      "MULTI-PERSPECTIVE ANALYSIS REPORT\n",
      "═══════════════════════════════════════════\n\n",
      x
    )
  },
  description = "Synthesis"
)

# Define parallel group: input -> [technical, business, ux] -> synthesis
wf$add_parallel_group(
  from = "input",
  stations = c("technical_analysis", "business_analysis", "ux_analysis"),
  to = "synthesis",
  merge_fn = function(results) {
    paste0(
      "📱 TECHNICAL PERSPECTIVE:\n",
      results$technical_analysis, "\n\n",
      "💼 BUSINESS PERSPECTIVE:\n",
      results$business_analysis, "\n\n",
      "👤 UX PERSPECTIVE:\n",
      results$ux_analysis
    )
  }
)

# ============================================================================
# Execute Workflow
# ============================================================================

topic <- "Artificial Intelligence in Healthcare"

cat("Topic:", topic, "\n")
cat("Agents: technical_analyst, business_strategist, ux_specialist\n")
cat("Execution: Parallel (3 concurrent LLM calls)\n")
cat("Daemons: 3 workers\n\n")

start_time <- Sys.time()
result <- wf$run(topic)
elapsed <- Sys.time() - start_time

cat("\n")
cat(result)

cat("\n\n")
cat("PERFORMANCE METRICS:\n")
cat("───────────────────────────────\n")
cat("Total time: ", format(elapsed), "\n")
cat("Parallel agents: 3\n")
cat("LLM API calls: 3 concurrent requests\n\n")
cat("Sequential time would be ~3x longer\n")
cat("───────────────────────────────\n\n")

# Cleanup
wf$set_daemons(0)
cat("✓ Complete. Agents and daemons cleaned up.\n")
