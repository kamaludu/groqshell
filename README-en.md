[![GroqBash](https://img.shields.io/badge/_GroqBash_-00aa55?style=for-the-badge&label=%E2%9E%9C&labelColor=004d00)](README.md)
![CLI](https://img.shields.io/badge/CLI-green?&logo=gnu-bash&logoColor=grey)
[![License: GPLv3](https://img.shields.io/badge/License-GPLv3-green.svg)](LICENSE)
[![ShellCheck](https://github.com/kamaludu/groqbash/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/kamaludu/groqbash/actions/workflows/shellcheck.yml)
[![Smoke Tests](https://github.com/kamaludu/groqbash/actions/workflows/smoke.yml/badge.svg)](https://github.com/kamaludu/groqbash/actions/workflows/smoke.yml)


# GroqBash &nbsp; [![Italian](https://img.shields.io/badge/IT-Versione_italiana-00aa55?style=flat)](README.md) 


**GroqBash** — *secure, Bash‑first CLI wrapper for Groq’s OpenAI‑compatible Chat Completions API.*

GroqBash is a **single Bash script**, self‑contained and auditable.  
You can download it, make it executable, export your API key, and start using it immediately.

It targets Unix‑like environments: **Linux**, **macOS**, **WSL**, **Termux**.

> ![English](https://img.shields.io/badge/EN-English-orange?style=flat)  
> English is not my first language.  
> Please feel free to use simple English; I will do my best to respond clearly.

---

## Key features

- **Dynamic model list** via `GET https://api.groq.com/openai/v1/models`  
  – no hardcoded models, no hidden fallbacks.  
- **Safe by design**  
  – no `/tmp` usage for internal temporaries, no `eval`, strict permissions on sensitive files.  
- **Bash‑first**  
  – explicit dependency on Bash, with clear, auditable logic.  
- **Streaming and non‑streaming** output modes.  
- **Automatic saving** of long outputs beyond a configurable threshold.  
- **Model management**  
  – refresh, list, set default, and policy‑based auto‑selection.  
- **Extras** (optional)  
  – provider modules, utilities, docs, and advanced security/test helpers.

---

## Threat model (short version)

GroqBash is designed for **single‑user environments** (your laptop, your Termux, your shell account), not for hostile multi‑tenant servers.

- Provider modules are **code executed in your shell**. They must live in directories owned by you and not writable by others.  
- Environment variables like `GROQBASHEXTRASDIR` and `GROQBASHTMPDIR` are treated as **trusted configuration**, not as untrusted input.  
- The script does **not** execute model output as shell commands.  
- Residual TOCTOU risks and JSON/SSE parsing limitations are documented; they are acceptable for a hardened Bash script in a single‑user context.

For more details, see **SECURITY.md**.

---

## Requirements

**Minimum**

- `bash`
- `curl`
- standard coreutils (`mktemp`, `chmod`, `mv`, `mkdir`, `head`, `sed`, `awk`, `grep`)

**Recommended**

- `jq` (JSON parsing for diagnostics and future robustness)
- `python3` (fsync helper, optional)
- `sha256sum` or `shasum` (for optional extras/security helpers)

---

## Installation

For detailed installation instructions, recommended dependencies, and verification commands, see **[INSTALL.md](INSTALL.md)**.

In short:

`sh
chmod +x groqbash
export GROQ_API_KEY="gsk_xxxxxxxxxxxxxxxxx"
./groqbash --help
`

Optional extras (docs, providers, security/test helpers) can be installed via:

`sh
./groqbash --install-extras
`

---

## Quick usage

Prompt from CLI:

`sh
./groqbash "write a short poem in Italian"
`

Input from file:

`sh
./groqbash -f prompt.txt
`

Pipe:

`sh
echo "explain relativity" | ./groqbash
`

Specific model:

`sh
./groqbash -m llama-3.3-70b-versatile "write a short essay"
`

Dry run (show JSON payload without sending):

`sh
./groqbash --dry-run "hello"
`

Provider example (if extras installed):

`sh
./groqbash --provider gemini "translate this"
`

---

## Main options

| Option                         | Description                                              |
|--------------------------------|----------------------------------------------------------|
| `-m, --model <name>`           | Select model (e.g. `llama-3.3-70b-versatile`)           |
| `-f <file>`                    | Read prompt from file                                   |
| `--system <text>`              | Set system prompt                                       |
| `--temp <value>`               | Temperature (default: `1.0`)                            |
| `--max <n>`                    | Max tokens (default: `4096`)                            |
| `--refresh-models`             | Refresh model list from Groq Models API                 |
| `--list-models`                | Show available models                                   |
| `--set-default <model>`       | Set persistent default model                            |
| `--auto-default-policy <p>`    | `preferred` \| `alpha` (default: `preferred`)           |
| `--provider <name>`            | Use external provider module (extras/providers)         |
| `--provider`                   | Interactive provider selection                          |
| `--install-extras`             | Install extras (docs, utils, providers, security, test) |
| `--save` / `--nosave`          | Force save or force print to terminal                   |
| `--out <path>`                 | Output file or directory                                |
| `--threshold <n>`              | Auto-save threshold (default: `1000` chars)            |
| `--dry-run`                    | Print payload and exit                                  |
| `--quiet`                      | Minimal output                                          |
| `--debug`                      | Verbose debug + keep temp files                         |
| `--version`                    | Print version                                           |
| `-h, --help`                   | Show help (from extras/docs/help.txt if available)      |

---

## Configuration and model behavior

### Config files

- `~/.config/groq/models.txt`  
  – dynamic model list (rebuilt on each `--refresh-models`).  
- `~/.config/groq/default_model`  
  – persistent default model (validated against the model list).

### Model selection precedence

1. `-m/--model` (CLI)  
2. `~/.config/groq/default_model` (if present and valid)  
3. `GROQ_MODEL` environment variable (if valid)  
4. Auto‑selection based on policy (`preferred` / `alpha`) when the list is non‑empty  

If the model list is empty, GroqBash fails explicitly and asks you to run `--refresh-models`.

### Refreshing models

`sh
./groqbash --refresh-models
`

- Fetches the official model list from Groq’s API.  
- Rebuilds `models.txt`.  
- Prints concise diagnostics; with `--debug` it shows more details.

---

## Temporary files and output paths

- GroqBash **never uses `/tmp`** for its internal temporaries.  
- Runtime temp directories are created via `mktemp -d` with `chmod 700`.  
- By default, temp data lives under a secure directory (e.g. `$GROQBASHTMPDIR` or a safe fallback).  
- Saved outputs are written with restrictive permissions (e.g. `600`).

If you pass `--out /path`, GroqBash will:

- try to create the directory if needed,  
- refuse unsafe or unwritable locations,  
- fall back to printing to the terminal with a clear message if it cannot safely write.

---

## Advanced extras (optional)

These helpers are **optional** and live under `extras/`. They do **not** change core behavior.

### Security helpers

- `extras/security/verify.sh`  
  – checks provider directory and files (owner, permissions, symlinks, optional checksums).  
- `extras/security/validate-env.sh`  
  – validates `GROQBASHEXTRASDIR`, `GROQBASHTMPDIR`, and required tools.

Run them manually:

`sh
extras/security/verify.sh
extras/security/validate-env.sh
`

### Test helpers

- `extras/test/json-sse-suite.sh`  
  – runs a small test suite for JSON escaping and SSE parsing behavior (no real API calls).

---

## Security notes and limitations

- **No eval**: GroqBash does not use `eval` or similar dynamic code execution.  
- **No execution of model output**: responses are printed or saved, never executed as shell.  
- **Provider modules are code**: anything under `extras/providers/` is executed in your shell.  
  - Keep `GROQBASHEXTRASDIR` and its subdirectories:
    - owned by you,  
    - not group/world writable,  
    - not shared with untrusted users.  
- **Environment variables are trusted configuration**:  
  - `GROQBASHEXTRASDIR`, `GROQBASHTMPDIR`, `GROQ_API_KEY`, `GROQ_MODEL` are assumed to be set by you or trusted tooling.  
- **JSON/SSE parsing**:  
  - implemented with `sed`/`awk`/`grep`, robust for normal use but not a full JSON parser.  
  - for critical workflows, prefer non‑streaming mode plus `jq` on the saved output.  
- **TOCTOU**:  
  - residual race conditions are inherent to shell scripts; GroqBash mitigates them with directory and file checks, but cannot eliminate them entirely.

For a more formal description, see **SECURITY.md**.

---

## Exit codes

| Code | Meaning                                                                 |
|------|-------------------------------------------------------------------------|
| 0    | Success: request completed, output printed or saved.                    |
| 1    | Generic error: invalid arguments, unreadable file, configuration issue. |
| 2    | Network / curl error: DNS, timeout, connection refused.                 |
| 3    | HTTP/API error: 4xx/5xx from the endpoint.                              |
| 4    | No textual content extracted (parsing error).                           |

---

## License

GroqBash is released under the **GNU GPL v3**.  
See **LICENSE** for the full text.

---

## Notes

Parts of the code and documentation were developed with the assistance of AI tools, used as refactoring and drafting helpers.  
The architecture, design, and final decisions are curated manually.

---

## Contact

- Author: Cristian Evangelisti  
- Email: opensource​@​cevangel.​anonaddy.​me  
- Repository: https://github.com/kamaludu/groqbash
