# Agent Tools System

A comprehensive tool registration and management system for R agents, inspired by crewAI's approach to extending agent capabilities.

## Overview

The Agent Tools System allows you to:
- Register predefined tools with agents
- Create custom tools for specific use cases
- Manage tool lifecycles (add, remove, list, clear)
- Share tools across multiple agents
- Handle errors gracefully in tool operations

## Quick Start

```r
library(ellmer)

# Create an LLM object
openai_4_1_mini <- ellmer::chat(
  name = "openai/gpt-4.1-mini",
  api_key = Sys.getenv("OPENAI_API_KEY"),
  echo = "none"
)

# Create an agent
agent <- Agent$new(
  name = "file_assistant",
  instruction = "You are a helpful file management assistant.",
  llm_object = openai_4_1_mini
)

# Register predefined tools
agent$register_tools(list(
  change_directory_tool(),
  list_files_tool(),
  read_file_tool()
))

# Use the agent with tools
response <- agent$invoke("List all files in the current directory")
```

## Predefined Tools

### File Management Tools

#### `change_directory_tool()`
Changes the current working directory.

**Parameters:**
- `path` (string, required): Directory path to change to

**Example:**
```r
agent$register_tools(change_directory_tool())
agent$invoke("Change to the Documents folder")
```

#### `list_files_tool()`
Lists files and directories in a specified path.

**Parameters:**
- `path` (string, optional): Directory to list (defaults to current directory)
- `show_hidden` (boolean, optional): Show hidden files (defaults to FALSE)
- `full_names` (boolean, optional): Return full paths (defaults to FALSE)

**Example:**
```r
agent$register_tools(list_files_tool())
agent$invoke("Show me all files including hidden ones in /home/user")
```

#### `read_file_tool()`
Reads the contents of text files.

**Parameters:**
- `file_path` (string, required): Path to file to read
- `max_lines` (string, optional): Maximum number of lines to read

**Example:**
```r
agent$register_tools(read_file_tool())
agent$invoke("Read the first 10 lines of config.txt")
```

#### `write_file_tool()`
Writes content to files.

**Parameters:**
- `file_path` (string, required): Path where to write the file
- `content` (string, required): Content to write
- `append` (boolean, optional): Whether to append or overwrite (defaults to FALSE)

**Example:**
```r
agent$register_tools(write_file_tool())
agent$invoke("Create a README.md file with project documentation")
```

## Creating Custom Tools

Use the `create_tool()` helper function to create custom tools:

```r
# Create a simple calculator tool
calculator_tool <- create_tool(
  name = "calculator",
  description = "Perform basic arithmetic operations",
  parameters = ellmer::type_object(
    expression = ellmer::type_string(
      description = "Mathematical expression to evaluate",
      required = TRUE
    )
  ),
  fn = function(expression) {
    tryCatch({
      result <- eval(parse(text = expression))
      list(success = TRUE, result = result)
    }, error = function(e) {
      list(success = FALSE, error = e$message)
    })
  }
)

# Register with agent
agent$register_tools(calculator_tool)
```

## Tool Management Methods

### `register_tools(tools)`
Register one or more tools with the agent.

```r
agent$register_tools(list(tool1, tool2))
# or
agent$register_tools(single_tool)
```

### `remove_tools(tool_names)`
Remove specific tools by name.

```r
agent$remove_tools(c("calculator", "weather"))
```

### `list_tools()`
Display all registered tools.

```r
agent$list_tools()
```

### `clear_tools()`
Remove all registered tools.

```r
agent$clear_tools()
```

## Advanced Patterns

### Tool Sharing Between Agents

```r
# Create shared tools
file_tools <- list(
  read_file_tool(),
  write_file_tool(),
  list_files_tool()
)

# Specialized agents with different tool combinations
analyzer <- Agent$new(...)
analyzer$register_tools(list(read_file_tool(), list_files_tool()))

manager <- Agent$new(...)
manager$register_tools(file_tools)  # All file tools
```

### Error Handling in Tools

```r
robust_tool <- create_tool(
  name = "robust_operation",
  description = "Operation with comprehensive error handling",
  parameters = ellmer::type_object(...),
  fn = function(param) {
    # Validate inputs
    if (invalid_input) {
      return(list(
        success = FALSE,
        error = "Invalid input",
        suggestion = "Try using a different value"
      ))
    }

    # Perform operation with error handling
    tryCatch({
      result <- perform_operation(param)
      list(success = TRUE, result = result)
    }, error = function(e) {
      list(
        success = FALSE,
        error = e$message,
        details = "Additional context about the error"
      )
    })
  }
)
```

### Dynamic Tool Management

```r
# Add tools based on context
if (user_needs_file_ops) {
  agent$register_tools(file_tools)
}

if (user_needs_calculations) {
  agent$register_tools(math_tools)
}

# Remove tools when no longer needed
agent$remove_tools("temporary_tool")
```

## Best Practices

### Tool Design
1. **Clear descriptions**: Make tool purposes obvious to the LLM
2. **Robust error handling**: Always handle edge cases gracefully
3. **Meaningful return values**: Provide structured, informative responses
4. **Parameter validation**: Validate all inputs before processing

### Tool Naming
- Use descriptive, action-oriented names
- Follow consistent naming conventions
- Avoid conflicts with built-in functions

### Error Messages
- Be specific about what went wrong
- Provide actionable suggestions
- Include relevant context information

### Performance
- Validate inputs early to fail fast
- Use appropriate data structures for return values
- Consider memory usage for large operations

## Integration with ellmer

The tool system integrates seamlessly with ellmer's Tool objects:

```r
# Tools are automatically registered with the underlying LLM
agent$register_tools(my_tools)

# The LLM can now call these tools during conversations
response <- agent$invoke("Use the calculator tool to compute 15 * 23")

# Tool usage appears in message history
agent$messages  # Shows tool requests and results
```

## Examples

See `agent-tools-examples.R` for comprehensive examples including:
- Basic tool registration
- Custom tool creation
- Advanced tool management
- Multi-agent tool sharing
- Error handling patterns

## Comparison with crewAI

This R implementation provides similar capabilities to crewAI's Python tool system:

| Feature | crewAI (Python) | This Implementation (R) |
|---------|----------------|------------------------|
| Tool Registration | `tools=[tool1, tool2]` | `register_tools(list(tool1, tool2))` |
| Custom Tools | `@tool` decorator | `create_tool()` helper |
| Error Handling | Built-in validation | Comprehensive error responses |
| Parameter Typing | Pydantic schemas | ellmer type objects |
| Tool Management | Static registration | Dynamic add/remove/clear |

## Troubleshooting

### Common Issues

1. **Tool not recognized**: Ensure tool is properly registered with `register_tools()`
2. **Parameter errors**: Check parameter types match ellmer type definitions
3. **Function errors**: Implement proper error handling in tool functions
4. **LLM integration**: Verify ellmer object supports tools

### Debugging Tools

```r
# Check registered tools
agent$list_tools()

# Inspect tool definitions
str(agent$tools)

# Check LLM object tool integration
agent$llm_object  # Should show registered tools
```