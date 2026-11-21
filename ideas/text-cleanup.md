# Text cleanup: removing hard line wraps

Implemented in `bin/unwrap-text` (perl, no dependencies). Check the result without speaking:
`pbpaste | bin/speak-selection -n`.

## Rules
| Input | Output | Why |
|---|---|---|
| single `\n` inside a paragraph | space | PDFs, emails, `man` pages and terminals break mid-sentence |
| blank line(s) | paragraph break (kept) | natural pause; also where chunks split |
| `hyper-\nnation` (next char lowercase) | `hypernation` | de-hyphenation |
| `- item`, `* item`, `•`, `1.`, `a)` at line start | kept on its own line | lists shouldn't merge into one run-on sentence |
| every line starts with `>` / `//` / `#` | prefix stripped | quoted email, code comments |
| a line/item without closing punctuation | `.` added | headings and bullets otherwise run straight into the next sentence |
| soft hyphen U+00AD, NBSP, U+2028/2029 | removed / normalized | common PDF leftovers |

## Known limitations (accepted for now)
- **Real compound words split across lines** (`state-\nof-the-art`) lose a hyphen. Without a dictionary there's no way to tell them from line-break hyphens. TTS mostly reads them the same either way.
- **Code blocks** get flattened. Reading code aloud is a non-goal.
- **Tables** turn into run-on text.
- **PDF columns and page headers** have to be fixed upstream: select a single column.

## Chunking (`bin/chunk-text`)
- Chunk 1 = the first sentence only, so speech starts in about 0.1–0.3 s once the model is warm.
- After that, whole paragraphs are packed into chunks of up to 3,500 chars. The API rejects anything over 4,096, and silences between chunks then land on paragraph breaks.
- An oversized paragraph is split at sentence boundaries, then word boundaries. Tested: 10 k chars of unpunctuated text → 3 chunks, each ≤ 3,500.
