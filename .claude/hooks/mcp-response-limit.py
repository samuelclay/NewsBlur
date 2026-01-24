#!/usr/bin/env python3
"""
MCP Response Size Limit Hook

Intercepts MCP tool responses and blocks those over 5,000 estimated tokens.
Saves the full response to a temp file for manual access.
"""
import json
import sys
import os
import tempfile
import uuid
from datetime import datetime

TOKEN_LIMIT = 5000
CHARS_PER_TOKEN = 4  # Rough estimate

def estimate_tokens(text):
    """Estimate token count based on character count."""
    return len(text) // CHARS_PER_TOKEN

def main():
    try:
        input_data = json.load(sys.stdin)
    except json.JSONDecodeError:
        sys.exit(0)  # Allow on parse error

    tool_name = input_data.get("tool_name", "")

    # Only process MCP tools
    if not tool_name.startswith("mcp__"):
        sys.exit(0)

    tool_response = input_data.get("tool_response", {})
    response_str = json.dumps(tool_response, indent=2, default=str)
    estimated_tokens = estimate_tokens(response_str)

    if estimated_tokens > TOKEN_LIMIT:
        # Generate unique filename
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        unique_id = uuid.uuid4().hex[:8]
        safe_tool_name = tool_name.replace("__", "-").replace("/", "-")
        filename = f"mcp_response_{safe_tool_name}_{timestamp}_{unique_id}.json"
        filepath = os.path.join(tempfile.gettempdir(), filename)

        # Save full response to file
        with open(filepath, 'w') as f:
            json.dump({
                "tool_name": tool_name,
                "tool_input": input_data.get("tool_input", {}),
                "tool_response": tool_response,
                "estimated_tokens": estimated_tokens,
                "timestamp": datetime.now().isoformat()
            }, f, indent=2, default=str)

        # Block with file path in message
        output = {
            "hookSpecificOutput": {
                "hookEventName": "PostToolUse",
                "decision": "block",
                "reason": f"MCP response too large (~{estimated_tokens:,} tokens, limit is {TOKEN_LIMIT:,}). Full response saved to: {filepath}"
            }
        }
        print(json.dumps(output))
        sys.exit(0)

    # Allow smaller responses
    sys.exit(0)

if __name__ == "__main__":
    main()
