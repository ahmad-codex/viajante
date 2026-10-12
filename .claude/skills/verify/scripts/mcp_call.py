"""Drive the checkout's stdio MCP server the way a client does, one session per run.

    drive.sh <run-dir> <label> python .claude/skills/verify/scripts/mcp_call.py \
        <tool> '<json args>' [<tool> '<json args>' ...]

Starts `viajante-mcp` from the same venv, lists tools, then calls each tool in order on
one session (so verify_answer sees the earlier searches' ledger). Prints one JSON line
per step to stdout: {"step", "tool", "args", "is_error", "structured", "text"}, where
"text" is the list of text blocks when there is no structured content (lookup_airports
returns one block per airport; an error is one block). Exit 1
if any call is an MCP error, 0 otherwise. The server inherits VIAJANTE_STATE_DIR.
"""

import asyncio
import json
import os
import sys
from pathlib import Path

from mcp import ClientSession
from mcp.client.stdio import StdioServerParameters, stdio_client


def emit(record: dict) -> None:
    print(json.dumps(record, ensure_ascii=False), flush=True)


async def main(pairs: list) -> int:
    server = str(Path(sys.executable).with_name("viajante-mcp"))
    params = StdioServerParameters(command=server, env=dict(os.environ))
    failed = False
    async with stdio_client(params) as (read, write):
        async with ClientSession(read, write) as session:
            init = await session.initialize()
            emit({"step": "initialize", "server": init.server_info.model_dump()})
            tools = (await session.list_tools()).tools
            emit({"step": "list_tools", "tools": sorted(t.name for t in tools)})
            for tool, args in pairs:
                result = await session.call_tool(tool, args)
                texts = [getattr(c, "text", "") for c in result.content]
                failed |= bool(result.is_error)
                emit(
                    {
                        "step": "call_tool",
                        "tool": tool,
                        "args": args,
                        "is_error": result.is_error,
                        "structured": result.structured_content,
                        "text": texts if result.structured_content is None else None,
                    }
                )
    return 1 if failed else 0


if __name__ == "__main__":
    argv = sys.argv[1:]
    if not argv or len(argv) % 2:
        sys.exit("usage: mcp_call.py <tool> '<json args>' [<tool> '<json args>' ...]")
    calls = [(argv[i], json.loads(argv[i + 1])) for i in range(0, len(argv), 2)]
    sys.exit(asyncio.run(main(calls)))
