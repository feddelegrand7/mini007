#' Example: Parallel Station Execution with mirai
#'
#' This example demonstrates how to use the Workflow class with parallel stations.
#' Multiple independent processing units run concurrently, then their results are
#' merged before continuing execution.
#'
#' Parallel execution is useful for:
#' - Running multiple LLM prompts simultaneously for comparison
#' - Executing independent data transformations in parallel
#' - Tool calling with multiple tools at once
#'

library(mirai)
library(glue)

# Source the Workflow class
source("R/Workflow.R")

# ============================================================================
# Example 1: Simple Parallel Processing
# ============================================================================

cat("\n=== Example 1: Simple Parallel Processing ===\n")

wf1 <- Workflow$new(
  name = "parallel_demo",
  description = "Demonstrates parallel station execution"
)

wf1$add_station(
  name = "input",
  handler = function(x) paste0("Processing: ", x)
)

wf1$add_station(
  name = "analyze_sentiment",
  handler = function(x) paste0("Sentiment Analysis -> Positive")
)

wf1$add_station(
  name = "extract_entities",
  handler = function(x) paste0("Entity Extraction -> [Person, Location]")
)

wf1$add_station(
  name = "classify_topic",
  handler = function(x) paste0("Topic Classification -> Technology")
)

wf1$add_station(
  name = "merge_results",
  handler = function(x) paste0("Final merged analysis:\n", x)
)

# Set up parallel execution with 3 workers
wf1$set_daemons(3)

# Define parallel group: input -> [sentiment, entities, topic] -> merge_results
wf1$add_parallel_group(
  from = "input",
  stations = c("analyze_sentiment", "extract_entities", "classify_topic"),
  to = "merge_results"
)

# Add route from merge_results (which has no more routes, so workflow ends)
result1 <- wf1$run("The technology conference was amazing")
cat("\nResult:\n", result1, "\n")

wf1$set_daemons(0)  # Cleanup


# ============================================================================
# Example 2: Parallel with Custom Merge Function
# ============================================================================

cat("\n\n=== Example 2: Custom Merge Function ===\n")

wf2 <- Workflow$new(
  name = "report_generator",
  description = "Generates parallel analyses with custom merge"
)

wf2$add_station(
  name = "query",
  handler = function(x) x
)

wf2$add_station(
  name = "performance_analysis",
  handler = function(x) {
    Sys.sleep(1)  # Simulate work
    "Performance: System is operating at 98% efficiency"
  }
)

wf2$add_station(
  name = "cost_analysis",
  handler = function(x) {
    Sys.sleep(1)
    "Cost: $150K annual spend, 12% below budget"
  }
)

wf2$add_station(
  name = "risk_analysis",
  handler = function(x) {
    Sys.sleep(1)
    "Risk: 2 critical alerts, 5 warnings, 23 info logs"
  }
)

wf2$add_station(
  name = "final_report",
  handler = function(x) paste0("📊 Executive Report\n\n", x)
)

wf2$set_daemons(3)

# Custom merge: format results as a bullet list
custom_merge <- function(results) {
  bullets <- paste0("• ", results, collapse = "\n")
  bullets
}

wf2$add_parallel_group(
  from = "query",
  stations = c("performance_analysis", "cost_analysis", "risk_analysis"),
  to = "final_report",
  merge_fn = custom_merge
)

result2 <- wf2$run("Generate quarterly report")
cat("\nResult:\n", result2, "\n")

wf2$set_daemons(0)


# ============================================================================
# Example 3: Nested Workflow with Parallel Stages
# ============================================================================

cat("\n\n=== Example 3: Multi-Stage Workflow with Parallel ===\n")

wf3 <- Workflow$new(
  name = "multi_stage_pipeline",
  description = "Sequential stages with parallel processing in middle"
)

wf3$add_station(
  name = "load_data",
  handler = function(x) "Data loaded: 1000 records"
)

# Parallel validation stage
wf3$add_station(
  name = "check_schema",
  handler = function(x) "✓ Schema validation passed"
)

wf3$add_station(
  name = "check_duplicates",
  handler = function(x) "✓ No duplicates found"
)

wf3$add_station(
  name = "check_nulls",
  handler = function(x) "✓ Null checks passed"
)

# Parallel processing stage
wf3$add_station(
  name = "normalize",
  handler = function(x) "✓ Data normalized"
)

wf3$add_station(
  name = "enrich",
  handler = function(x) "✓ Data enriched with 5 new features"
)

wf3$add_station(
  name = "finalize",
  handler = function(x) paste0("Pipeline complete:\n", x)
)

wf3$set_daemons(4)

# First parallel group
wf3$add_parallel_group(
  from = "load_data",
  stations = c("check_schema", "check_duplicates", "check_nulls"),
  to = "normalize",
  merge_fn = function(results) {
    paste("Validation results:", paste(results, collapse = " "))
  }
)

# Second parallel group
wf3$add_parallel_group(
  from = "normalize",
  stations = c("enrich"),  # Just one station in this group for demo
  to = "finalize",
  merge_fn = function(results) paste(results, collapse = "\n")
)

result3 <- wf3$run("process_data")
cat("\nResult:\n", result3, "\n")

wf3$set_daemons(0)


# ============================================================================
# Example 4: Parallel with Caching
# ============================================================================

cat("\n\n=== Example 4: Parallel with Result Caching ===\n")

wf4 <- Workflow$new(
  name = "cached_parallel",
  description = "Demonstrates caching with parallel execution",
  use_cache = TRUE
)

wf4$add_station(
  name = "start",
  handler = function(x) x
)

wf4$add_station(
  name = "slow_task_a",
  handler = function(x) {
    Sys.sleep(2)
    "Result from slow task A"
  }
)

wf4$add_station(
  name = "slow_task_b",
  handler = function(x) {
    Sys.sleep(2)
    "Result from slow task B"
  }
)

wf4$add_station(
  name = "end",
  handler = function(x) paste0("Cached results:\n", x)
)

wf4$set_daemons(2)

wf4$add_parallel_group(
  from = "start",
  stations = c("slow_task_a", "slow_task_b"),
  to = "end"
)

cat("First run (will take ~2 seconds due to sleep in parallel tasks):\n")
start_time <- Sys.time()
result4a <- wf4$run("input_data")
elapsed1 <- Sys.time() - start_time
cat("Elapsed time:", format(elapsed1), "\n")

cat("\nSecond run with same input (will be instant due to cache):\n")
start_time <- Sys.time()
result4b <- wf4$run("input_data")
elapsed2 <- Sys.time() - start_time
cat("Elapsed time:", format(elapsed2), "\n")
cat("Speedup: ", round(as.numeric(elapsed1) / as.numeric(elapsed2), 1), "x faster\n")

wf4$set_daemons(0)


# ============================================================================
# Summary
# ============================================================================

cat("\n\n=== Parallel Stations Summary ===\n")
cat(
  "
Key features demonstrated:

1. set_daemons(n)           - Initialize n parallel workers
2. add_parallel_group()     - Define stations to run in parallel
3. Custom merge_fn          - Combine parallel results
4. Caching integration      - Cache works with parallel execution
5. Multi-stage pipelines    - Multiple parallel groups in one workflow

Benefits:
✓ 2-4x speedup for CPU-bound tasks
✓ Reduces latency for independent I/O operations
✓ Integrates with existing retry/fallback logic
✓ Compatible with HITL and caching
✓ Type-safe error handling via mirai
"
)
