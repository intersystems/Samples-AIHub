# Sample MCP Services

In AI Hub, you can expose ObjectScript methods defined in your InterSystems IRIS instance as MCP endpoints accessible to any MCP client. The `iris-mcp-server` binary serves as a bridge (bundled with your InterSystems IRIS installation) between your MCP client and InterSystems IRIS.

This directory contains a sample MCP Service class that exposes the [BasicMath](/objectscript/cls/Sample/AI/ToolSet/BasicMath.cls) toolset.

## InterSystems IRIS Setup

1. Load the sample classes:
   ```objectscript
   USER> Do $system.OBJ.ImportDir("/path/to/examples/objectscript/cls", "*.cls", "ck", .errors, 1)
   ```
2. In the Management Portal go to **System Administration > Security > Applications > MCP Servers**.
3. Click **Create New MCP Server** and specify:
   - Name: `/mcp/calculator`
   - Namespace: `USER` (or your namespace)
   - Dispatch Class: `Sample.MCP.Service.Calculator`
   - Enabled: ✓ Yes
   - Allowed Authentication Methods: **Password** (or **Unauthenticated** for development)
4. Click **Save**.

## `iris-mcp-server` Setup

`iris-mcp-server` acts as a bridge between your MCP client and InterSystems IRIS. To do this, it must first authenticate with the InterSystems IRIS instance ("layer 1") and then facilitate authentication by the MCP client to your InterSystems IRIS MCP endpoint ("layer 2"); the examples below give example configuration files for `iris-mcp-server` for both connections.

For details on the two layers of authentication, see the [AI Hub documentation](https://docs.intersystems.com/iris20263/csp/docbook/DocBook.UI.Page.cls?KEY=BAIHUB_mcp#BAIHUB_authentication).

### Basic Configuration (Unauthenticated endpoint)

This configuration does the following:
- Specifies, in `iris.server`, the following connection information for an InterSystems IRIS instance:
  - Reachable on `localhost`
  - Whose superserver port is  `52773`
  - Authenticate `iris-mcp-server` as the `CSPSystem` user
- Specifies, in `endpoints.path`, the name `/mcp/calculator`, which is the [name of the MCP service endpoint](#intersystems-iris-setup).
- It omits any credentials in `endpoints` because this is for an `Unauthenticated` endpoint.

Create a file called `config.toml` with the following content:

```toml
[mcp]
transport = "stdio"

[[iris]]
name   = "local"
server = { host = "localhost", port = 52773, username = "CSPSystem", password = "SYS" }
pool   = { min = 2, max = 10 }
endpoints = [
  { path = "/mcp/calculator" },
]

[logging]
level  = "debug"
output = "file"
file   = "iris-mcp.log"
```

### Configuration with an Authenticated Endpoint

This configuration does the following:
- `iris.server` - The following connection information for an InterSystems IRIS instance:
  - Reachable on `localhost`
  - Whose superserver port is  `52773`
  - Authenticate `iris-mcp-server` as the `CSPSystem` user
- `endpoints.path` - The name `/mcp/calculator`, which is the [name of the MCP service endpoint](#intersystems-iris-setup).
- `endpoints.username` and `endpoints.password` - The credentials that the MCP client should use to authenticate with the InterSystems IRIS MCP server endpoint. This assumes that you [selected `Password` for the server endpoint's `Allowed Authentication Methods`](#intersystems-iris-setup).

Create a file called `config.toml` with the following content:

```toml
[mcp]
transport = "stdio"

[[iris]]
name   = "local"
server = { host = "localhost", port = 52773, username = "CSPSystem", password = "SYS" }
pool   = { min = 2, max = 10 }
endpoints = [
  { path = "/mcp/calculator", username = "_SYSTEM", password = "SYS" },
]

[logging]
level  = "debug"
output = "file"
file   = "iris-mcp.log"
```

If you want to use a Bearer token instead, use `endpoints.bearer`:

`{ path = "/mcp/calculator", bearer = "mytoken" }`

### Run and Test

```bash
iris-mcp-server --config config.toml run
```

```python
import asyncio
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

async def test():
    params = StdioServerParameters(command="iris-mcp-server", args=["--config", "config.toml", "run"])
    async with stdio_client(params) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()
            tools = await session.list_tools()
            print([t.name for t in tools.tools])
            result = await session.call_tool("mcp_calculator_Add", {"a": 5, "b": 3})
            print(result)

asyncio.run(test())
```