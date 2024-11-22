---
title: LangChain Custom Tool (Confluence) 
tags: Python langchain Confluence
author: nakamasato
slide: false
---
# Custom Toolの実装方法

https://python.langchain.com/v0.1/docs/modules/tools/custom_tools/

# CustomTool

```py
import os
from typing import Optional, Type

from atlassian import Confluence
from langchain.callbacks.manager import (
    AsyncCallbackManagerForToolRun,
    CallbackManagerForToolRun,
)
from langchain_core.tools import BaseTool
from pydantic import BaseModel

HIGHLIGHT_START = "@@@hl@@@"
HIGHLIGHT_END = "@@@endhl@@@"

class Page(BaseModel):
    title: str
    url: str


class SearchInput(BaseModel):
    keyword: str
    limit: int


class ConfluenceSearchTool(BaseTool):
    name: str = "confluence_search"
    description: str = "Search Confluence pages by keyword"
    args_schema: Type[BaseModel] = SearchInput

    def _run(self, keyword: str, limit: int, run_manager: Optional[CallbackManagerForToolRun] = None) -> str:
        """Search Confluence for a query."""
        cql = [f"text ~ '{keyword}'"]
        res = self.metadata["confluence"].cql(cql=cql, limit=limit)
        print(res)
        pages = [
            Page(
                title=r["title"].replace(HIGHLIGHT_START, "*").replace(HIGHLIGHT_END, "*"),
                url=os.path.join(self.metadata["confluence_url"], r["url"].lstrip("/")),
            )
            for r in res["results"]
        ]
        return """以下のページを見つけました:
""" + "\n".join([f"{i+1}. <{r.url}|{r.title}>" for i, r in enumerate(pages)])

    async def _arun(self, query: str, run_manager: Optional[AsyncCallbackManagerForToolRun] = None) -> str:
        """Use the tool asynchronously."""
        raise NotImplementedError("confluence_search does not support async")


def get_confluence_search_tool() -> ConfluenceSearchTool:
    """New instance of ConfluenceSearchTool.
    CONFLUENCE_URL, ATLASSIAN_USERNAME, and ATLASSIAN_PASSWORD must be set in the environment.
    """
    return ConfluenceSearchTool(
        metadata={
            "confluence": Confluence(
                url=os.environ["CONFLUENCE_URL"],
                username=os.environ["ATLASSIAN_USERNAME"],
                password=os.environ["ATLASSIAN_PASSWORD"],
            ),
            "confluence_url": os.environ["CONFLUENCE_URL"],
        },
    )
```

# 試す

```py
if __name__ == "__main__":
    from langchain_chroma import Chroma
    from langchain_core.messages import AIMessage
    from langchain_openai import ChatOpenAI, OpenAIEmbeddings
    from langgraph.prebuilt import ToolNode

    llm = ChatOpenAI(model="gpt-4o-mini")

    tools = [get_confluence_search_tool(vector_store)]
    TOOL_NODE = ToolNode(tools)
    message_with_single_tool_call = AIMessage(
        content="",
        tool_calls=[
            {
                "name": "confluence_search",
                "args": {"keyword": "Test", "limit": 5},
                "id": "tool_call_id",
                "type": "tool_call",
            }
        ],
    )
    print(TOOL_NODE.invoke({"messages": [message_with_single_tool_call]}))  # manual call
    llm_with_tools = llm.bind_tools(tools)
    chain = llm_with_tools
    print(chain.invoke("メール機能 Spec").tool_calls)  # automatic call
    print(TOOL_NODE.invoke({"messages": [chain.invoke("Search for Test")]}))  # automatic call
```

# Ref

- https://github.com/langchain-ai/langchain/issues/6828

