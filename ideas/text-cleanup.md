# Text cleanup: removing hard line wraps

Implemented in `bin/unwrap-text` (perl, no dependencies). Check the result without speaking:
`pbpaste | bin/speak-selection -n`.

## Rules
| Input | Output | Why |
|---|---|---|
| single `\n` inside a paragraph | space | PDFs, emails, `man` pages and terminals break mid-sentence |
| blank line(s) | paragraph break (kept) | natural pause; also where chunks split |
| `hyper-\nnation` (next char lowercase) | `hypernation` | de-hyphenation |
| `- item`, `* item`, `•`, `1.`, `a)`, `A.` at line start | kept on its own line | lists shouldn't merge into one run-on sentence |
| `B.`–`Z.` at line start | list item only after a list item or a line ending in `. : ; ! ? …`; otherwise joined | `written\nJ. Smith` is a wrapped initial, not a list |
| every line starts with `>` / `//` / `#` | prefix stripped | quoted email, code comments |
| a line/item without closing punctuation | `.` added | headings and bullets otherwise run straight into the next sentence |
| soft hyphen U+00AD, NBSP, U+2028/2029 | removed / normalized | common PDF leftovers |

## Known limitations (accepted for now)
- **Real compound words split across lines** (`state-\nof-the-art`) lose a hyphen. Without a dictionary there's no way to tell them from line-break hyphens. TTS mostly reads them the same either way.
- **Code blocks** get flattened. Reading code aloud is a non-goal.
- **Tables** turn into run-on text.
- **An initial right after a finished sentence** (`…was done.\nJ. Smith said`) is still taken as a list item `J.`, and an `A.` initial at line start always is.
- **Roman-numeral lists**: `II.` was never a list marker, and `I.` after an unpunctuated line (`Contents\nI. Introduction`) is now joined like an initial. Lettered and numbered lists are unaffected.
- **PDF columns and page headers** have to be fixed upstream: select a single column.

## Chunking (`bin/chunk-text`)
- Chunk 1 = the first sentence only, so speech starts in about 0.1–0.3 s once the model is warm.
- If the first paragraph is a single sentence (a title, which `unwrap-text` turns into `Title.`), chunk 1 is that line plus the first sentence of the next paragraph. Chunk 1's audio must outlast synthesizing chunk 2 (measured: 3,500 chars → 2.8 s; a title alone plays ~1.8 s), or there's a gap after it. Before this, a title was packed into a full chunk and first audio came ~2.7 s later.
- After that, whole paragraphs are packed into chunks of up to 3,500 chars. The API rejects anything over 4,096, and silences between chunks then land on paragraph breaks.
- An oversized paragraph is split at sentence boundaries, then word boundaries; a single token over 3,500 chars (base64, URLs) is cut into 3,500-char pieces. Tested: 10 k chars of unpunctuated text → 3 chunks, each ≤ 3,500.
- If the first sentence is itself over 3,500 chars, there's no fast-start chunk: it goes through the oversized-paragraph path like everything else.
- Sentence splits are undone after common abbreviations (`Mr. Mrs. Ms. Dr. Prof. Sr. Jr. St. vs. cf. Fig. e.g. i.e.`) and single-capital initials (`J.`), so chunk 1 is never just `Dr.`. Side effect: a sentence ending in a capital letter (`World War I.`) is glued to the next one; harmless for TTS.

## Markdown → plain text (`bin/strip-markdown`)
Used on summaries before they're spoken (`-s`) or shown in the `-f text` / `-f dialog` formats.

| Input | Output |
|---|---|
| code fences, horizontal rules | dropped |
| `# heading`, `> quote`, `- item`, `1. item` | the text only |
| `**bold**`, `*italic*`, `_italic_`, `` `code` `` | the text only (`snake_case` words are kept) |
| `[text](url)`, `![alt](src)` | `text`, `alt` |
| `-s` (speech): `TL;DR:` | `In short:` |
| `-s` (speech): a line ending without punctuation | `.` added, so TTS pauses between bullets |
