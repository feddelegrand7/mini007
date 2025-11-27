#' Agent Tools Usage Examples
#'
#' This file contains comprehensive examples of how to use the Agent tool system,
#' inspired by crewAI's approach to tool registration and usage.

# Basic Tool Registration Example
basic_tool_registration_example <- function() {
  library(ellmer)

  # Create an LLM object
  openai_4_1_mini <- ellmer::chat(
    name = "openai/gpt-4.1-mini",
    api_key = Sys.getenv("OPENAI_API_KEY"),
    echo = "none"
  )

  # Create a file management agent
  file_agent <- Agent$new(
    name = "file_manager",
    instruction = paste(
      "You are a file management assistant.",
      "You can help users navigate directories, read files, and manage their file system.",
      "Always provide clear feedback about the operations you perform."
    ),
    llm_object = openai_4_1_mini
  )

  # Register predefined tools
  file_agent$register_tools(list(
    change_directory_tool(),
    list_files_tool(),
    read_file_tool(),
    write_file_tool()
  ))

  # List registered tools
  file_agent$list_tools()

  # Example interaction
  response <- file_agent$invoke("List all files in the current directory and then read the README.md file if it exists")
  cat("Agent Response:", response)

  return(file_agent)
}

# Custom Tool Creation Example
custom_tool_example <- function() {
  library(ellmer)

  # Create a weather tool (mock implementation)
  weather_tool <- create_tool(
    name = "get_weather",
    description = "Get current weather information for a specified location",
    parameters = ellmer::type_object(
      location = ellmer::type_string(
        description = "The city or location to get weather for",
        required = TRUE
      ),
      units = ellmer::type_string(
        description = "Temperature units: celsius or fahrenheit. Defaults to celsius.",
        required = FALSE
      )
    ),
    fn = function(location, units = "celsius") {
      # Mock weather data (in real implementation, would call weather API)
      temp <- if (units == "fahrenheit") "72°F" else "22°C"

      list(
        success = TRUE,
        location = location,
        temperature = temp,
        condition = "Sunny",
        humidity = "65%",
        units = units
      )
    }
  )

  # Create a calculation tool
  calculator_tool <- create_tool(
    name = "calculate",
    description = "Perform basic arithmetic operations",
    parameters = ellmer::type_object(
      expression = ellmer::type_string(
        description = "Mathematical expression to evaluate (e.g., '2 + 3 * 4')",
        required = TRUE
      )
    ),
    fn = function(expression) {
      tryCatch({
        # Safely evaluate mathematical expressions
        result <- eval(parse(text = expression))
        list(
          success = TRUE,
          expression = expression,
          result = result
        )
      }, error = function(e) {
        list(
          success = FALSE,
          expression = expression,
          error = paste("Invalid expression:", e$message)
        )
      })
    }
  )

  # Create agent with custom tools
  openai_4_1_mini <- ellmer::chat(
    name = "openai/gpt-4.1-mini",
    api_key = Sys.getenv("OPENAI_API_KEY"),
    echo = "none"
  )

  assistant <- Agent$new(
    name = "multi_tool_assistant",
    instruction = paste(
      "You are a helpful assistant with access to weather and calculation tools.",
      "Use the appropriate tools to answer user questions accurately."
    ),
    llm_object = openai_4_1_mini
  )

  # Register custom tools
  assistant$register_tools(list(weather_tool, calculator_tool))

  # Example interactions
  cat("=== Weather Query ===\n")
  response1 <- assistant$invoke("What's the weather like in Paris?")
  cat("Response:", response1, "\n\n")

  cat("=== Calculation Query ===\n")
  response2 <- assistant$invoke("Calculate the result of 15 * 8 + 32")
  cat("Response:", response2, "\n\n")

  return(assistant)
}

# Advanced Tool Management Example
advanced_tool_management_example <- function() {
  library(ellmer)

  openai_4_1_mini <- ellmer::chat(
    name = "openai/gpt-4.1-mini",
    api_key = Sys.getenv("OPENAI_API_KEY"),
    echo = "none"
  )

  # Create agent
  agent <- Agent$new(
    name = "adaptive_assistant",
    instruction = "You are an adaptive assistant that can use different sets of tools based on the task at hand.",
    llm_object = openai_4_1_mini
  )

  # Register initial tools
  file_tools <- list(
    change_directory_tool(),
    list_files_tool(),
    read_file_tool()
  )

  agent$register_tools(file_tools)
  cat("Initial tools registered:\n")
  agent$list_tools()

  # Add more tools dynamically
  write_tool <- write_file_tool()
  agent$register_tools(write_tool)

  cat("\\nAfter adding write tool:\n")
  agent$list_tools()

  # Remove specific tools
  agent$remove_tools("change_directory")

  cat("\\nAfter removing change_directory tool:\n")
  agent$list_tools()

  # Clear all tools
  agent$clear_tools()

  cat("\\nAfter clearing all tools:\n")
  agent$list_tools()

  return(agent)
}

# Multi-Agent Tool Sharing Example
multi_agent_tool_sharing_example <- function() {
  library(ellmer)

  openai_4_1_mini <- ellmer::chat(
    name = "openai/gpt-4.1-mini",
    api_key = Sys.getenv("OPENAI_API_KEY"),
    echo = "none"
  )

  # Create shared tools
  file_tools <- list(
    read_file_tool(),
    write_file_tool(),
    list_files_tool()
  )

  # Create specialized agents with different tool combinations

  # File analyzer - read-only operations
  file_analyzer <- Agent$new(
    name = "file_analyzer",
    instruction = paste(
      "You are a file analysis specialist.",
      "You can read and analyze file contents but cannot modify files.",
      "Provide detailed analysis and insights about file contents."
    ),
    llm_object = openai_4_1_mini$clone()
  )
  file_analyzer$register_tools(list(read_file_tool(), list_files_tool()))

  # File manager - full file operations
  file_manager <- Agent$new(
    name = "file_manager",
    instruction = paste(
      "You are a file management specialist.",
      "You can read, write, and organize files.",
      "Help users manage their file system efficiently."
    ),
    llm_object = openai_4_1_mini$clone()
  )
  file_manager$register_tools(file_tools)

  # Content creator - writing focused
  content_creator <- Agent$new(
    name = "content_creator",
    instruction = paste(
      "You are a content creation specialist.",
      "You focus on writing and creating new files.",
      "Generate high-quality content and save it to files."
    ),
    llm_object = openai_4_1_mini$clone()
  )
  content_creator$register_tools(list(write_file_tool(), read_file_tool()))

  # Demonstrate different capabilities
  cat("=== File Analyzer Capabilities ===\n")
  file_analyzer$list_tools()

  cat("\\n=== File Manager Capabilities ===\n")
  file_manager$list_tools()

  cat("\\n=== Content Creator Capabilities ===\n")
  content_creator$list_tools()

  return(list(
    analyzer = file_analyzer,
    manager = file_manager,
    creator = content_creator
  ))
}

# Tool Error Handling Example
tool_error_handling_example <- function() {
  library(ellmer)

  # Create a tool that demonstrates error handling
  robust_file_tool <- create_tool(
    name = "robust_file_reader",
    description = "Read file with comprehensive error handling and validation",
    parameters = ellmer::type_object(
      file_path = ellmer::type_string(
        description = "Path to the file to read",
        required = TRUE
      ),
      max_size_mb = ellmer::type_string(
        description = "Maximum file size in MB. Defaults to 10MB.",
        required = FALSE
      )
    ),
    fn = function(file_path, max_size_mb = "10") {
      # Input validation
      if (is.null(file_path) || file_path == "") {
        return(list(
          success = FALSE,
          error = "File path cannot be empty",
          details = "Please provide a valid file path"
        ))
      }

      # Check if file exists
      if (!file.exists(file_path)) {
        return(list(
          success = FALSE,
          error = "File not found",
          file_path = file_path,
          suggestion = "Check the file path and ensure the file exists"
        ))
      }

      # Check if it's a directory
      if (file.info(file_path)$isdir) {
        return(list(
          success = FALSE,
          error = "Path is a directory, not a file",
          file_path = file_path,
          suggestion = "Use list_files tool for directory contents"
        ))
      }

      # Check file size
      max_size <- as.numeric(max_size_mb) * 1024 * 1024  # Convert to bytes
      file_size <- file.size(file_path)

      if (file_size > max_size) {
        return(list(
          success = FALSE,
          error = "File too large",
          file_size_mb = round(file_size / (1024 * 1024), 2),
          max_allowed_mb = as.numeric(max_size_mb),
          suggestion = "Use a larger max_size_mb or process the file in chunks"
        ))
      }

      # Try to read the file
      tryCatch({
        content <- readLines(file_path, warn = FALSE)

        list(
          success = TRUE,
          file_path = normalizePath(file_path),
          content = paste(content, collapse = "\\n"),
          lines = length(content),
          size_mb = round(file_size / (1024 * 1024), 3),
          encoding = "UTF-8"
        )
      }, error = function(e) {
        list(
          success = FALSE,
          error = "Failed to read file",
          details = e$message,
          file_path = file_path,
          suggestion = "Check file permissions and encoding"
        )
      })
    }
  )

  openai_4_1_mini <- ellmer::chat(
    name = "openai/gpt-4.1-mini",
    api_key = Sys.getenv("OPENAI_API_KEY"),
    echo = "none"
  )

  agent <- Agent$new(
    name = "robust_assistant",
    instruction = paste(
      "You are an assistant with robust error handling capabilities.",
      "When operations fail, explain what went wrong and provide helpful suggestions."
    ),
    llm_object = openai_4_1_mini
  )

  agent$register_tools(robust_file_tool)

  # Test with various scenarios
  cat("=== Testing with non-existent file ===\n")
  response1 <- agent$invoke("Read the file 'nonexistent.txt'")
  cat("Response:", response1, "\n\n")

  cat("=== Testing with directory path ===\n")
  response2 <- agent$invoke("Read the file '.' (current directory)")
  cat("Response:", response2, "\n\n")

  return(agent)
}