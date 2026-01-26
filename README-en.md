
[![GroqBash](https://img.shields.io/badge/_GroqBash_-00aa55?style=for-the-badge&label=%E2%9E%9C&labelColor=004d00)](README.md)
[![CLI](https://img.shields.io/badge/CLI-green?&logo=gnu-bash&logoColor=grey)](#)
[![License: GPLv3](https://img.shields.io/badge/License-GPLv3-green.svg)](LICENSE)
[![ShellCheck](https://github.com/kamaludu/groqbash/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/kamaludu/groqbash/actions/workflows/shellcheck.yml)
[![Smoke Tests](https://github.com/kamaludu/groqbash/actions/workflows/smoke.yml/badge.svg)](https://github.com/kamaludu/groqbash/actions/workflows/smoke.yml)

# GroqBash &nbsp; [![Italian](https://img.shields.io/badge/IT-Versione_italiana-00aa55?style=flat)](README.md)

**GroqBash** — *secure, Bash‑first CLI wrapper for Groq’s OpenAI‑compatible Chat Completions API.*

GroqBash is a **single Bash script**, self‑contained, auditable, and easy to verify.  
Download it, make it executable, export your API key, and start using it immediately.

It targets Unix‑like environments: **Linux**, **macOS**, **WSL**, **Termux**.

> [![English](https://img.shields.io/badge/EN-English-orange?style=flat)](#)
> English is not my first language.  
> Simple English is welcome — I will always try to respond clearly.

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
- **Optional extras**  
  – provider modules, utilities, docs, and advanced security/test helpers.

---

## Threat model (short version)

GroqBash is designed for **single‑user environments** (your laptop, your Termux, your shell account), not for hostile multi‑tenant servers.

- Provider modules are **code executed in your shell**. They must live in directories owned by you and not writable by others.  
- Environment variables like `GROQBASHEXTRASDIR` and `GROQBASHTMPDIR` are treated as **trusted configuration**, not untrusted input.  
- The script does **not** execute model output as shell commands.  
- Residual TOCTOU risks and JSON/SSE parsing limitations are documented and acceptable for a hardened Bash script.

For full details, see **[SECURITY](SECURITY-en.md)**.

---

## Requirements

**Minimum**

- `bash`
- `curl`
- standard coreutils (`mktemp`, `chmod`, `mv`, `mkdir`, `head`, `sed`, `awk`, `grep`)
- `jq` (JSON parsing)

**Recommended**

- `python3` (optional fsync helper)
- `sha256sum` or `shasum` (for optional security extras)

---

## Installation

Full instructions are available in **[INSTALL](INSTALL-en.md)**.

Quick start:

```sh
chmod +x groqbash
export GROQ_API_KEY="gsk_xxxxxxxxxxxxxxxxx"
./groqbash --help
```

Install optional extras (docs, providers, security, tests):

```sh
./groqbash --install-extras
```

---

## Quick usage

Prompt from CLI:

```sh
./groqbash "write a short poem in Italian"
```

Input from file:

```sh
./groqbash -f prompt.txt
```

Pipe:

```sh
echo "explain relativity" | ./groqbash
```

Specific model:

```sh
./groqbash -m llama-3.3-70b-versatile "write a short essay"
```

Dry run (show JSON payload without sending):

```sh
./groqbash --dry-run "hello"
```

Provider example (if extras installed):

```sh
./groqbash --provider gemini "translate this"
```

---

## Main options

| Option                         | Description                                              |
|--------------------------------|----------------------------------------------------------|
| `-m, --model <name>`           | Select model                                             |
| `-f <file>`                    | Read prompt from file                                   |
| `--system <text>`              | Set system prompt                                       |
| `--temp <value>`               | Temperature (default: `1.0`)                            |
| `--max <n>`                    | Max tokens (default: `4096`)                            |
| `--refresh-models`             | Refresh model list from Groq                            |
| `--list-models`                | Show available models                                   |
| `--set-default <model>`        | Set persistent default model                            |
| `--auto-default-policy <p>`    | `preferred` \| `alpha`                                  |
| `--provider <name>`            | Use external provider module                            |
| `--provider`                   | Interactive provider selection                          |
| `--install-extras`             | Install extras (docs, utils, providers, security, test) |
| `--save` / `--nosave`          | Force save or force print                               |
| `--out <path>`                 | Output file or directory                                |
| `--threshold <n>`              | Auto‑save threshold (default: `1000`)                   |
| `--dry-run`                    | Print payload and exit                                  |
| `--quiet`                      | Minimal output                                          |
| `--debug`                      | Verbose debug + keep temp files                         |
| `--version`                    | Print version                                           |
| `-h, --help`                   | Show help (from extras/docs/help.txt if available)      |

---

## Configuration and model behavior

### Config files

- `~/.config/groq/models.txt`  
  – dynamic model list (rebuilt on each refresh).  
- `~/.config/groq/default_model`  
  – persistent default model.

### Model selection precedence

1. `-m/--model`  
2. `default_model`  
3. `GROQ_MODEL`  
4. Auto‑selection based on policy  

If the model list is empty, GroqBash fails and asks you to run `--refresh-models`.

### Refreshing models

```sh
./groqbash --refresh-models
```

- Fetches the official model list  
- Rebuilds `models.txt`  
- Shows diagnostics (more with `--debug`)

---

## Temporary files and output paths

- GroqBash **never uses `/tmp`** for internal temporaries.  
- Runtime temp directories use `mktemp -d` with `chmod 700`.  
- Saved outputs use restrictive permissions (e.g. `600`).  
- With `--out`, GroqBash creates the directory if possible; otherwise it prints to the terminal.

---

## Advanced extras (optional)

Extras do **not** modify core behavior.

### Security helpers

- `extras/security/verify.sh`  
  – checks provider directory, permissions, symlinks, owner, optional checksums.  
- `extras/security/validate-env.sh`  
  – validates environment and required tools.

Run manually:

```sh
extras/security/verify.sh
extras/security/validate-env.sh
```

### Test helpers

- `extras/test/json-sse-suite.sh`  
  – tests JSON escaping and SSE parsing (no real API calls).

---

## Security notes and limitations

- **No eval**  
- **No execution of model output**  
- **Provider modules are code** — keep `extras/providers` secure  
- **Environment variables are trusted configuration**  
- **JSON/SSE parsing** is robust but not a full parser  
- **TOCTOU** risks are mitigated but cannot be fully eliminated in Bash

See **SECURITY.md** for full details.

---

## Exit codes

| Code | Meaning                                                                 |
|------|-------------------------------------------------------------------------|
| 0    | Success                                                                 |
| 1    | Generic error (arguments, file, configuration)                           |
| 2    | Network / curl error                                                     |
| 3    | HTTP/API error (4xx/5xx)                                                 |
| 4    | No textual content extracted (parsing error)                             |

---

## License

GroqBash is released under the **GNU GPL v3**.  
See **LICENSE** for the full text.

---

## Notes

Parts of the code and documentation were drafted with the assistance of AI tools.  
Architecture and final decisions remain manually curated.

---

## Contact

- Author: Cristian Evangelisti  
- Email: opensource​@​cevangel.​anonaddy.​me  
- Repository: https://github.com/kamaludu/groqbash
