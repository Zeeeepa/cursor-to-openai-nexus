#!/usr/bin/env python3
"""
Cursor-To-OpenAI-Nexus Example Script

This script demonstrates how to use the Cursor-To-OpenAI-Nexus service
with the OpenAI Python client library.
"""

import os
import argparse
from openai import OpenAI

def main():
    # Parse command line arguments
    parser = argparse.ArgumentParser(description="Cursor-To-OpenAI-Nexus Example")
    parser.add_argument("--api-key", default=os.environ.get("CURSOR_API_KEY", "sk-cursor-api-key"),
                        help="API key for the Cursor-To-OpenAI-Nexus service")
    parser.add_argument("--base-url", default=os.environ.get("CURSOR_BASE_URL", "http://localhost:3010/v1"),
                        help="Base URL for the Cursor-To-OpenAI-Nexus service")
    parser.add_argument("--model", default="claude-3.7-sonnet-thinking",
                        help="Model to use for the completion")
    parser.add_argument("--prompt", default="Explain quantum computing in simple terms.",
                        help="Prompt to send to the model")
    parser.add_argument("--stream", action="store_true",
                        help="Whether to stream the response")
    args = parser.parse_args()

    # Initialize the OpenAI client
    client = OpenAI(
        api_key=args.api_key,
        base_url=args.base_url
    )

    print(f"Sending request to {args.model}...")
    print(f"Prompt: {args.prompt}")
    print("-" * 50)

    if args.stream:
        # Stream the response
        stream = client.chat.completions.create(
            model=args.model,
            messages=[
                {"role": "user", "content": args.prompt}
            ],
            stream=True
        )

        # Print the response as it comes in
        for chunk in stream:
            if chunk.choices[0].delta.content is not None:
                print(chunk.choices[0].delta.content, end="")
        print("\n")
    else:
        # Get the full response at once
        response = client.chat.completions.create(
            model=args.model,
            messages=[
                {"role": "user", "content": args.prompt}
            ],
            stream=False
        )

        # Print the response
        print(response.choices[0].message.content)
        print("-" * 50)
        print(f"Model: {response.model}")
        print(f"Completion tokens: {response.usage.completion_tokens}")
        print(f"Prompt tokens: {response.usage.prompt_tokens}")
        print(f"Total tokens: {response.usage.total_tokens}")

if __name__ == "__main__":
    main()

