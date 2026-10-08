from app.services.ai_news_service import parse_feed


def test_parse_feed_keeps_source_date_and_safe_https_link():
    content = b"""<?xml version="1.0"?>
    <rss version="2.0"><channel><item>
      <title>New AI model</title>
      <link>https://example.com/news/model</link>
      <description>&lt;p&gt;An official &lt;b&gt;model&lt;/b&gt; update.&lt;/p&gt;</description>
      <pubDate>Wed, 07 Oct 2026 12:00:00 +0000</pubDate>
    </item><item><title>Unsafe</title><link>javascript:alert(1)</link></item>
    </channel></rss>"""

    items = parse_feed(content, "Example AI")

    assert items == [
        {
            "title": "New AI model",
            "summary": "An official model update.",
            "url": "https://example.com/news/model",
            "published_at": "2026-10-07T12:00:00+00:00",
            "source": "Example AI",
        }
    ]