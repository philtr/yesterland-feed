# Repository Guidelines

## Project Structure & Module Organization
- Ruby service with a single entrypoint: `application.rb` hosts a tiny HTTP server that fetches Yesterland’s “What’s New” page and emits an RSS feed.
- Tests live in `test_application.rb`; fixtures in `test/fixtures/whatsnew.html`.
- Temporary artifacts may appear as `tmp_feed.xml` when experimenting locally; keep generated files out of commits unless needed.

## Build, Test, and Development Commands
- Run the service locally: `ruby application.rb` (listens on `HOST`/`PORT`, defaults `0.0.0.0:4567`).
- Override behavior with env vars: `PORT=8080 FEED_LIMIT=25 ruby application.rb`. `SOURCE_URL` can be pointed at alternate HTML for debugging.
- Execute the test suite: `ruby test_application.rb`.
- To exercise parsing manually, call helpers in `irb` with `require_relative './application'` and invoke `fetch_and_build_feed`.

## Coding Style & Naming Conventions
- Ruby, 2-space indentation, snake_case for methods and variables, SCREAMING_SNAKE_CASE for constants (match `SOURCE_URL`, `FETCH_INTERVAL`, etc.).
- Prefer small, pure helper methods (see `decode_html_entities`, `escape_xml`) and keep side effects near `start_server`.
- Use standard library only; avoid adding gems unless necessary.
- When adding HTML parsing, prefer explicit regex/scan or a lightweight parser; keep entity decoding consistent with `EXTRA_ENTITY_MAP`.

## Testing Guidelines
- Framework: Minitest (built-in). Add tests to `test_application.rb` and fixtures under `test/fixtures`.
- Name tests descriptively (`test_builds_rss_from_fixture_with_limit_and_valid_xml`) and assert both content and structure (e.g., using `REXML::Document`).
- For new behaviors, include a fixture snippet that reproduces the HTML shape and assert feed output strings and XML validity.

## Commit & Pull Request Guidelines
- Follow concise, present-tense commits (similar to existing history): imperative mood and scope-focused, e.g., “Handle missing pub dates.”
- PRs should explain the change, mention affected endpoints/flags (`PORT`, `FEED_LIMIT`), and include test output snippets (`ruby test_application.rb`).
- If altering the feed format or parsing rules, summarize the before/after behavior and any impacts on consumers.

## Security & Configuration Tips
- Network access is limited to fetching `SOURCE_URL`; avoid arbitrary outbound requests.
- Sanitize any new output via `escape_xml`; keep entity decoding bounded (current loop runs 5 passes to prevent runaway decoding).
- If introducing threads or sockets, respect the existing mutex around feed updates to avoid serving partial data.
