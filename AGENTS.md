# Repository Guidelines

## Project Structure & Module Organization
- Library code lives under `lib/`: `YesterlandFeed::HtmlFetcher`, `EntryParser`, `RssBuilder`, `FeedService`, and `Server` are composed for SOLID, testable behavior.
- Public load point is `lib/yesterland_feed.rb`; CLI entrypoint is `bin/yesterland_feed`.
- `Gemfile` pins Ruby (3.4.7) and `openssl` (> 3.3.1) to avoid SSL issues.
- Tests reside in `test/`; fixtures live in `test/fixtures/whatsnew.html`.
- Temporary artifacts (e.g., experimental feeds) should stay out of commits unless intentional.

## Build, Test, and Development Commands
- Install deps: `bundle install` (uses `openssl` from Gemfile).
- Run the service: `bin/yesterland_feed` (listens on `HOST`/`PORT`, defaults `0.0.0.0:4567`). Ensure the script is executable (`chmod +x bin/yesterland_feed` if needed).
- Use bundled deps: `bundle exec bin/yesterland_feed`.
- Override behavior with env vars: `PORT=8080 FEED_LIMIT=25 SOURCE_URL=https://example.com/whatsnew.html bin/yesterland_feed`.
- Offline/dev mode: point `SOURCE_URL` at the fixture, e.g., `SOURCE_URL=file://$(pwd)/test/fixtures/whatsnew.html bin/yesterland_feed`.
- If the upstream SSL cert chain fails locally, you can bypass verification for development only: `VERIFY_SSL=0 bin/yesterland_feed`.
- Logging: set `LOG_LEVEL=debug` for verbose output (default `info`); logs go to stderr with timestamps.
- Run tests: `ruby -Itest test/yesterland_feed_test.rb`.
- Explore in `irb`: `require 'yesterland_feed'; YesterlandFeed::FeedService.new.fetch_and_build`.

## Coding Style & Naming Conventions
- Ruby, 2-space indentation, snake_case for methods/variables, SCREAMING_SNAKE_CASE for constants (match `DEFAULT_SOURCE_URL`, `DEFAULT_FEED_LIMIT`).
- Keep responsibilities isolated: parsing in `EntryParser`, output in `RssBuilder`, I/O in `HtmlFetcher`, orchestration in `FeedService`, network concerns in `Server`.
- Use standard library only; avoid adding gems unless necessary. If introducing dependencies, document them and add tests.
- For HTML parsing, prefer explicit regex/scan or a lightweight parser; keep entity decoding consistent with `HtmlUtils::EXTRA_ENTITY_MAP`.

## Testing Guidelines
- Framework: Minitest (built-in). Add tests under `test/` and fixtures in `test/fixtures`.
- Name tests descriptively (`test_builds_rss_from_fixture_with_limit_and_valid_xml`) and assert both content and structure (e.g., via `REXML::Document`).
- For new behaviors, add a fixture snippet mirroring the HTML shape and assert both feed strings and XML validity/edge cases.

## Commit & Pull Request Guidelines
- Follow concise, present-tense commits (similar to existing history): imperative mood and scope-focused, e.g., “Handle missing pub dates.”
- PRs should explain the change, mention affected endpoints/flags (`PORT`, `FEED_LIMIT`, `SOURCE_URL`), and include test output snippets (`ruby -Itest test/yesterland_feed_test.rb`).
- If altering the feed format or parsing rules, summarize the before/after behavior and any impacts on consumers.

## Security & Configuration Tips
- Network access is limited to fetching `SOURCE_URL`; avoid arbitrary outbound requests.
- Sanitize any new output via `HtmlUtils.escape_xml`; keep entity decoding bounded (current loop runs 5 passes to prevent runaway decoding).
- If introducing threads or sockets, respect the existing mutex around feed updates to avoid serving partial data.
