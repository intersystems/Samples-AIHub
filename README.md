# Samples-AIHub

This repository contains various examples for how to use the two main parts of AI Hub: the [ObjectScript SDK](https://docs.intersystems.com/iris20263/csp/docbook/DocBook.UI.Page.cls?KEY=BAIHUB_sdk), which provides an API for agents to call regular ObjectScript methods as tools, and the [`iris-mcp-server`](https://docs.intersystems.com/iris20263/csp/docbook/DocBook.UI.Page.cls?KEY=BAIHUB_mcp), which allows clients to call tools exposed by InterSystems IRIS as MCP endpoints.

## Getting Started

To load the examples in this repository:

```objectscript
USER> Do $SYSTEM.OBJ.ImportDir("/path/to/examples/objectscript/cls", "*.cls", "ck", .errors, 1)
```

## Prerequisites

- An InterSystems IRIS instance with [AI Hub](https://docs.intersystems.com/iris20263/csp/docbook/DocBook.UI.Page.cls?KEY=BAIHUB_overview). To download an AI Hub-enabled kit, go to [downloads.intersystems.com](https://downloads.intersystems.com/).
- While not strictly required, most of the examples in this repository (with the exception of the [`/mcp/calculator`](/objectscript/cls/Sample/MCP/Service/MCP_Service_README.md) example) assume that you have at least tried the Quickstart examples for both the [ObjectScript SDK](https://docs.intersystems.com/iris20263/csp/docbook/DocBook.UI.Page.cls?KEY=BAIHUB_sdk#BAIHUB_quickstart) and [MCP Server](https://docs.intersystems.com/iris20263/csp/docbook/DocBook.UI.Page.cls?KEY=BAIHUB_mcp#BAIHUB_mcp_quickstart) from the documentation.

## Directory Structure


In [`/objectscript/cls/Sample/AI`](/objectscript/cls/Sample/AI):
- [`Tools`](/objectscript/cls/Sample/AI/Tools/) and [`ToolSet`](/objectscript/cls/Sample/AI/ToolSet/) - Example [tools](https://docs.intersystems.com/iris20263/csp/docbook/DocBook.UI.Page.cls?KEY=BAIHUB_sdk#BAIHUB_tools).
- [`Agent`](/objectscript/cls/Sample/AI/Agent/) - Example [Agents](https://docs.intersystems.com/iris20263/csp/docbook/DocBook.UI.Page.cls?KEY=BAIHUB_sdk#BAIHUB_agents). These examples create agents [declaratively](https://docs.intersystems.com/iris20263/csp/docbook/DocBook.UI.Page.cls?KEY=BAIHUB_sdk#BAIHUB_agent_declarative) by creating subclasses of `%AI.Agent` with defined class parameters.
- [`Skill`](/objectscript/cls/Sample/AI/Skill/) - Examples of how to define and use [skills](https://docs.intersystems.com/iris20263/csp/docbook/DocBook.UI.Page.cls?KEY=BAIHUB_sdk#BAIHUB_skills).
- [`Policies`](/objectscript/cls/Sample/AI/Policies/) - Examples of how to create [policies](https://docs.intersystems.com/iris20263/csp/docbook/DocBook.UI.Page.cls?KEY=BAIHUB_sdk#BAIHUB_policies) to audit tool calls.
- [`Examples`](/objectscript/cls/Sample/AI/Examples/) - A sampler of various examples that uses one or more of the previous concepts.
- [`Proglang`](/objectscript/cls/Sample/AI/Proglang/) - A "Programming Language Professsor" agent and includes an MCP service example. You should refer to the [Calculator example](/objectscript/cls/Sample/MCP/Service) before exploring this one.
- [`Orders`](/objectscript/cls/Sample/AI/Orders/) - Helper classes and scaffolding for other examples.
- [`Utils.cls`](/objectscript/cls/Sample/AI/Utils.cls) - Helper functions for the various examples.

In [`/objectscript/cls/Sample/MCP/Service`](/objectscript/cls/Sample/MCP/Service):
- [`MCP_Service_README.md`](/objectscript/cls/Sample/MCP/Service/MCP_Service_README.md) - Instructions for how to expose a simple calculator MCP endpoint in InterSystems IRIS.
- [`Calculator.cls`](/objectscript/cls/Sample/MCP/Service/Calculator.cls) - A basic example of an MCP service class which uses the tools defined in [`ToolSet\BasicMath.cls`](\objectscript\cls\Sample\AI\ToolSet\BasicMath.cls).