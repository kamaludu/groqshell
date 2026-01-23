[![GroqBash](https://img.shields.io/badge/_GroqBash_-00aa55?style=for-the-badge&label=%E2%9E%9C&labelColor=004d00)](README.md)

# INSTALLATION &nbsp; [![Italian](https://img.shields.io/badge/IT-Versione_italiana-00aa55?style=flat)](INSTALL.md) 


This document explains how to install GroqBash, configure your environment, verify the installation, and understand how temporary files, output paths, and exit codes work.

GroqBash is a **single Bash script**, secure and self‑contained, designed for **single‑user environments** (Linux, macOS, WSL, Termux).

---

# 1. Requirements and Dependencies

## Required
- **bash**
- **curl**
- **coreutils** (mktemp, chmod, mv, mkdir, head, sed, awk, grep)
- **jq**

## Recommended
- **python3** — fallback for fsync and serialization (optional)
- **sha256sum / shasum** — for optional security extras

## Locale and encoding
GroqBash requires a UTF‑8 environment.

If needed:

`sh
export LC_ALL=C.UTF-8
export LANG=C.UTF-8
`

---

# 2. Installation

## Download the script

`sh
curl -O https://raw.githubusercontent.com/kamaludu/groqbash/main/bin/groqbash
`

## Make it executable

`sh
chmod +x groqbash
`

## (Optional but recommended) Install into your PATH

`sh
mkdir -p "$HOME/.local/bin"
mv groqbash "$HOME/.local/bin/groqbash"
export PATH="$HOME/.local/bin:$PATH"
`

## Set your API key

`sh
export GROQ_API_KEY="gsk_XXXXXXXXXXXXXXXX"
`

## Verify installation

`sh
groqbash --version
`

---

# 3. Installing Extras (optional)

Extras include:

- additional documentation  
- external providers  
- security tools  
- JSON/SSE test suite  

Install everything with:

`sh
groqbash --install-extras
`

Extras **do not modify core behavior**.

---

# 4. Temporary File Behavior

- GroqBash **never uses `/tmp`** for internal temporary files.  
- Temporary directories are created using:
  - `mktemp -d`
  - permissions `700`
  - inside `$GROQBASHTMPDIR` or a safe fallback under the user’s home

- With `--debug`, temporary files are **not removed** to help inspection.

---

# 5. Output Path (`--out`)

- When using `--out /path/to/file`, GroqBash:
  - attempts to create the directory  
  - checks safety and permissions  
  - saves the file with restrictive permissions (`600`)

- If the directory is unsafe or unwritable:
  - GroqBash **does not** fall back to `/tmp`
  - prints the output to the terminal
  - shows a clear warning

**Recommendation:** use paths under your home directory or `$GROQBASHTMPDIR`.

---

# 6. Basic Usage and Examples

Simple prompt:

`sh
groqbash "write a bash function that..."
`

Pipe input:

`sh
echo "Explain this code" | groqbash
`

Input from file:

`sh
groqbash -f input.txt
`

Force saving:

`sh
groqbash --save --out output.txt "long text..."
`

Dry run (show JSON payload):

`sh
groqbash --dry-run "hello"
`

Provider (if extras installed):

`sh
groqbash --provider gemini "translate this"
`

---

# 7. Exit Codes

| Code | Meaning                                                                   |
|------|---------------------------------------------------------------------------|
| **0** | Success                                                                   |
| **1** | Generic error (arguments, file, configuration)                            |
| **2** | Network / curl error                                                      |
| **3** | HTTP/API error (4xx/5xx)                                                  |
| **4** | No textual content extracted (parsing error)                              |

**Operational notes**
- Code 2 → automatic retries (DNS, timeout, connection refused)  
- Code 3 → no retries (API errors, authorization, rate limits)  
- With `--debug`, full logs are kept in the runtime tmpdir

---

# 8. Troubleshooting and Recommended Tests

## Verify JSON payload

`sh
groqbash --dry-run "Test payload with \"quotes\" and newlines\nand unicode: € ✓"
`

## Pipe input

`sh
echo "Explain this code" | groqbash
`

## Invalid API key

`sh
GROQ_API_KEY="invalid" groqbash "hello" || echo "exit:$?"
`

## Test without jq

Temporarily hide jq:

`sh
mv /usr/bin/jq /usr/bin/jq.bak
groqbash --dry-run "test"
mv /usr/bin/jq.bak /usr/bin/jq
`

---

# 9. Common Issues

- **cannot create destination directory**  
  → the path passed to `--out` is unsafe or unwritable

- **Output not saved but present in tmp**  
  → `mv` failed; check the tmpdir shown in the logs

- **Strange characters / invalid JSON**  
  → ensure UTF‑8 locale and jq/python3 availability

---

# 10. Termux Installation Example

`sh
pkg update
pkg install -y bash curl jq python
mkdir -p "$HOME/.local/bin"
mv groqbash "$HOME/.local/bin/groqbash"
chmod +x "$HOME/.local/bin/groqbash"
export PATH="$HOME/.local/bin:$PATH"
export GROQ_API_KEY="gsk_..."
groqbash --version
`

---

# 11. Final Notes

- GroqBash is designed for **single‑user environments**.  
- Providers and extras are **optional** and must live in safe directories.  
- Model output is **never executed** as shell commands.  
- For full security details, see **SECURITY.md**.
