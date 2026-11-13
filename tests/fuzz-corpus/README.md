# Committed mutation corpus

These 26 synthetic inputs were retained by the Windows Native 1,024-iteration
coverage-feedback run recorded on 2026-11-13. They derive from this repository's
Apache-2.0 expanded fixtures, example configuration and synthetic gzip seed.
They increased observed compiler counter coverage; they are not crash findings.
Each JSON wrapper has `mode`, `signal` and base64 `bodyBase64`.

After building the isolated worker, run:

```sh
moon build tests/fuzzcase --target native --enable-coverage
moon run tools/replay_fuzz_corpus.mbtx --target native
```

Replay requires bounded completion without crashes. Invalid input may be
rejected. Successfully admitted telemetry must survive protobuf encode/decode
with exact normalized content. Acceptance counts are reported rather than
frozen, allowing deliberate parser policy changes. No real user telemetry,
secrets or binary executable is included.
