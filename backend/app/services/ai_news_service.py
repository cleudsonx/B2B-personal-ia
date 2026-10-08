import asyncio
import time
from datetime import timezone
from email.utils import parsedate_to_datetime
from html.parser import HTMLParser
from typing import Any
from xml.etree import ElementTree

import httpx


FEED_SOURCES = (
    {
        "name": "Google AI",
        "url": "https://blog.google/innovation-and-ai/technology/ai/rss/",
    },
    {
        "name": "Meta AI Research",
        "url": "https://engineering.fb.com/category/ai-research/feed/",
    },
)
CACHE_SECONDS = 900
_cache: dict[str, Any] | None = None
_cache_created_at = 0.0
_cache_lock = asyncio.Lock()


class _TextExtractor(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.parts: list[str] = []

    def handle_data(self, data: str) -> None:
        text = data.strip()
        if text:
            self.parts.append(text)


def _plain_text(value: str) -> str:
    parser = _TextExtractor()
    parser.feed(value)
    return " ".join(" ".join(parser.parts).split())[:360]


def _iso_date(value: str | None) -> str | None:
    if not value:
        return None
    try:
        parsed = parsedate_to_datetime(value)
    except (TypeError, ValueError, OverflowError):
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone(timezone.utc).isoformat()


def parse_feed(content: bytes, source: str, limit: int = 8) -> list[dict[str, str | None]]:
    root = ElementTree.fromstring(content)
    items: list[dict[str, str | None]] = []

    for entry in root.findall(".//item")[:limit]:
        title = (entry.findtext("title") or "").strip()
        link = (entry.findtext("link") or "").strip()
        if not title or not link or not link.startswith("https://"):
            continue
        items.append(
            {
                "title": title,
                "summary": _plain_text(entry.findtext("description") or ""),
                "url": link,
                "published_at": _iso_date(entry.findtext("pubDate")),
                "source": source,
            }
        )
    return items


async def _fetch_source(
    client: httpx.AsyncClient, source: dict[str, str]
) -> tuple[list[dict[str, str | None]], dict[str, str]]:
    try:
        response = await client.get(source["url"])
        response.raise_for_status()
        items = parse_feed(response.content, source["name"])
        return items, {"name": source["name"], "status": "ok"}
    except (httpx.HTTPError, ElementTree.ParseError, ValueError):
        return [], {"name": source["name"], "status": "unavailable"}


async def get_ai_news() -> dict[str, Any]:
    global _cache, _cache_created_at

    if _cache is not None and time.monotonic() - _cache_created_at < CACHE_SECONDS:
        return _cache

    async with _cache_lock:
        if _cache is not None and time.monotonic() - _cache_created_at < CACHE_SECONDS:
            return _cache

        async with httpx.AsyncClient(timeout=8.0, follow_redirects=True) as client:
            results = await asyncio.gather(
                *(_fetch_source(client, source) for source in FEED_SOURCES)
            )

        items = [item for feed_items, _ in results for item in feed_items]
        items.sort(key=lambda item: item["published_at"] or "", reverse=True)
        result = {
            "items": items,
            "sources": [status for _, status in results],
            "updated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        }

        if items or _cache is None:
            _cache = result
            _cache_created_at = time.monotonic()
        else:
            result = {**_cache, "stale": True}
        return result