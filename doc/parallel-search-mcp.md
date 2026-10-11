# Search the web with Parallel Search MCP

The [Parallel Search MCP](https://docs.parallel.ai/integrations/mcp/search-mcp)
scenario lets you search the web and fetch a page without an account or API key.
Search uses Fast mode. It uses Huginn's existing Agents and is imported separately
from the default scenario.

## Import and run

1. Install and start Huginn using the [normal installation instructions](../README.md#getting-started).
   No additional gems, service, credentials, or model are needed for this scenario.
2. Download [parallel_search_scenario.json](../data/parallel_search_scenario.json).
   In Huginn, select **Scenarios → Import Scenario**, upload the JSON file, review
   the Agents, and confirm the import.
3. Open the **Parallel request** Manual Event Agent. On its Summary page, edit
   the event payload and create an event:

   ```json
   {
     "operation": "search",
     "objective": "Find the official Huginn documentation for creating Agents.",
     "query": "Huginn creating new agent documentation"
   }
   ```

4. Allow the normal event propagation and background workers to process the
   scenario. Open **Parallel web search → Events** to see the response. Successful
   events have `status: 200` and MCP tool content in `body.result.content`.
   Connect downstream Agents to this output to process the results.
5. To fetch a specific page, create another event in **Parallel request**:

   ```json
   {
     "operation": "fetch",
     "url": "https://github.com/huginn/huginn"
   }
   ```

   Open **Parallel page fetch → Events** for the page content. Fetch only pages
   you need; search results already include excerpts.

## How it works

Each input event starts a new MCP session using protocol version `2025-03-26`.
The scenario checks the initialization response, retains its session ID, sends
`notifications/initialized`, and dispatches only the selected tool after the
notification is accepted. The session ID is also reused in the tool arguments.
The Post Agents send JSON to `https://search.parallel.ai/mcp` and identify their
requests with `Huginn Parallel Search scenario` as the User-Agent.

This is a manual workflow for Parallel's JSON responses over Streamable HTTP;
it is not a general MCP client. It does not parse SSE responses, use legacy HTTP
SSE or stdio transports, or provide an LLM tool loop. Only `search` and `fetch`
are accepted operation values. Existing Huginn network timeouts apply.

## Response handling

Check the HTTP `status`, `body.error` (JSON-RPC errors), and
`body.result.isError` (tool errors) before using a response as successful data.
Tool text is available under `body.result.content`; it can include JSON text,
so parse it separately if a downstream Agent needs individual result fields.
Input fields are retained alongside the response.

If no tool event appears, inspect the initialization and notification Agents'
events and logs. An unsuccessful initialization or notification stops dispatch.
The free service has rate limits. On HTTP 429, inspect the response's
`headers.retry_after` when present and wait before creating another request;
the scenario does not automatically retry. Session IDs and fetched content are
stored in Events; the example retains Events for seven days.
