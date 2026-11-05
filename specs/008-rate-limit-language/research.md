# Research: Rate Limiting and Unknown Language Codes

## R1 — Rate limiter

**Decision**: a sliding-window `RateLimiter` actor, one per API, 600 requests per 60 s (the free tier's minutely limit, as the forecast API's `X-RateLimit-Limit`/`-Window` headers state). Each call reserves the earliest start keeping at most 600 starts in any 60 s and sleeps until then.

**Rationale**: reserving synchronously inside the actor keeps concurrent callers ordered without a queue. Separate limiters stop typing in search from delaying a forecast. The hourly (5,000) and daily (10,000) limits are not tracked on device (no persistence, `intent.md`); the service's 429 covers them and is shown as `rateLimited` with retry. No automatic retry after 429: the service does not say when the window resets for geocoding, and the shortest window is a minute.

**Alternatives rejected**: failing fast when the local limit is hit (a burst would show an error the service would not have raised); one shared limiter (search bursts would delay forecasts).

## R2 — Language codes

**Verified live 2026-11-05**: the geocoding API accepts any `language` value with 200 (`xx`, `klingon`, `a b`, `be` in Cyrillic) and then matches like English, so "Мінск" with `xx` finds nothing. Parameters of the wrong type give 400 with `{"error":true,"reason":"..."}`.

**Decision**: validate at the client, the trust boundary for what reaches the API: lower-case the code, take the subtag before `-`/`_`, send it only when it is in `Locale.LanguageCode.isoLanguageCodes` (620 codes, iOS 16+) and not `en`. Verified live: "Минск" with `xx` or `qq` gives the same result as `en` (Minskoye), so dropping an unknown code changes no result, only keeps it off the wire. Retry once without `language` on a 400 when one was sent, so a code the service starts rejecting degrades to an English search instead of an error. A retry on empty results was rejected: with an unknown code the service already matches like English, so it would repeat the same search.
