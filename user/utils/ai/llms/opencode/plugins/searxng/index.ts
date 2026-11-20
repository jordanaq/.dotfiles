import { Plugin, type WebSearch } from "@opencode/plugin"
import type { WebSearchDefinition, WebSearchEditor } from "@opencode/plugin/promise/websearch"

interface SearxngResult {
  readonly url: string
  readonly title: string
  readonly content: string
}

interface SearxngResponse {
  readonly results: readonly unknown[]
}

type SearchContext = Parameters<WebSearchDefinition["execute"]>[1]

function isSearxngResponse(data: unknown): data is SearxngResponse {
  return (
    typeof data === "object" &&
    data !== null &&
    "results" in data &&
    Array.isArray(data.results)
  )
}

function isSearxngResult(result: unknown): result is SearxngResult {
  return (
    typeof result === "object" &&
    result !== null &&
    "url" in result &&
    typeof result.url === "string" &&
    /^https?:\/\//i.test(result.url) &&
    "title" in result &&
    typeof result.title === "string" &&
    "content" in result &&
    typeof result.content === "string"
  )
}

const provider: WebSearchDefinition = {
  id: "searxng",
  name: "SearXNG",
  async execute(
    { query }: WebSearch.ProviderInput,
    { signal }: SearchContext,
  ): Promise<readonly WebSearch.Result[]> {
    const url: URL = new URL("http://127.0.0.1:8889/search")
    url.search = new URLSearchParams({ q: query, format: "json" }).toString()

    try {
      const response: Response = await fetch(url, {
        signal: AbortSignal.any([signal, AbortSignal.timeout(15_000)]),
      })
      if (!response.ok) throw new Error(`HTTP ${response.status}`)

      const data: unknown = await response.json()
      if (!isSearxngResponse(data)) throw new Error("Invalid search response")

      return data.results
        .filter(isSearxngResult)
        .slice(0, 8)
        .map(({ url, title, content }: SearxngResult): WebSearch.Result => ({
          url,
          title,
          content,
          time: {},
        }))
    } catch (error: unknown) {
      if (signal.aborted) throw error
      throw new Error("SearXNG search through the local proxy failed", { cause: error })
    }
  },
}

const plugin: Plugin.Plugin = Plugin.define({
  id: provider.id,
  async setup(ctx: Plugin.Context): Promise<void> {
    await ctx.websearch.transform((editor: WebSearchEditor): void => {
      editor.add(provider)
      editor.default.set(provider.id)
    })
  },
})

export default plugin
