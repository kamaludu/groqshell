# CONTRACT.md — Provider Contract  
Documento bilingue: Italiano / English  
GroqBash 1.0.0

---

# 🇮🇹 Sezione Italiana — Contratto Provider

Questo documento definisce il **contratto ufficiale** per creare provider esterni compatibili con GroqBash.  
Un *provider* è uno script Bash che implementa un backend alternativo all’API Groq (es. Gemini, OpenAI, ecc.).

I provider vengono caricati da:

```
extras/providers/<nome>.sh
```

e sono **codice eseguito nella shell dell’utente**.

---

## 1. Requisiti del file provider

Un provider deve:

- essere un file regolare (`-f`)
- non essere un symlink
- essere di proprietà dell’utente corrente
- non essere scrivibile da gruppo/mondo
- risiedere in una directory non world‑writable

GroqBash verifica automaticamente questi requisiti tramite `extras/security/verify.sh`.

---

## 2. Nome del provider

Il nome del provider è il nome del file senza estensione:

```
extras/providers/gemini.sh  → provider "gemini"
```

---

## 3. Funzioni obbligatorie

Ogni provider deve implementare **tre funzioni**, con nome basato sul provider:

### `buildpayload_<provider>()`
- Riceve variabili globali impostate da GroqBash (prompt, system, temperature, max tokens, ecc.)
- Deve costruire il payload JSON (o equivalente)
- Deve scrivere il payload su stdout
- Non deve eseguire comandi esterni non necessari

### `callapi_<provider>()`
- Esegue la richiesta API **non‑streaming**
- Deve leggere il payload da stdin
- Deve stampare la risposta completa su stdout
- Deve restituire codice 0 in caso di successo

### `callapistreaming_<provider>()`
- Esegue la richiesta API in modalità **streaming**
- Deve stampare i chunk in tempo reale
- Deve terminare con codice 0

---

## 4. Variabili garantite da GroqBash

GroqBash garantisce al provider:

- `GROQ_API_KEY`
- `MODEL`
- `SYSTEM_PROMPT`
- `USER_PROMPT`
- `TEMPERATURE`
- `MAX_TOKENS`
- `CURLBASEOPTS[@]` (array con opzioni curl sicure)
- `TMPDIR` sicuro

Il provider **non deve modificare** queste variabili.

---

## 5. Regole di comportamento

Un provider **NON deve**:

- cambiare directory (`cd`)
- modificare variabili globali di GroqBash
- scrivere file con permessi insicuri
- produrre output non JSON su stdout (eccetto streaming)
- usare `eval`
- usare `/tmp`
- eseguire comandi non necessari

---

## 6. Esempio minimo

```sh
buildpayload_gemini() {
    printf '{"model":"%s","messages":[{"role":"user","content":"%s"}]}' \
        "$MODEL" "$USER_PROMPT"
}

callapi_gemini() {
    curl "${CURLBASEOPTS[@]}" \
         -H "Authorization: Bearer $GROQ_API_KEY" \
         -d @- \
         "https://api.example.com/v1/chat/completions"
}

callapistreaming_gemini() {
    curl "${CURLBASEOPTS[@]}" \
         -N \
         -H "Authorization: Bearer $GROQ_API_KEY" \
         -d @- \
         "https://api.example.com/v1/chat/completions/stream"
}
```

# 📎 Note finali
Questo contratto garantisce che tutti i provider siano coerenti, sicuri e compatibili con GroqBash.  

---

# 🇬🇧 English Section — Provider Contract

This document defines the **official contract** for creating external providers compatible with GroqBash.  
A *provider* is a Bash script implementing an alternative backend to the Groq API (e.g., Gemini, OpenAI, etc.).

Providers are loaded from:

```
extras/providers/<name>.sh
```

and are **code executed in the user’s shell**.

---

## 1. Provider file requirements

A provider must:

- be a regular file (`-f`)
- not be a symlink
- be owned by the current user
- not be group/world writable
- reside in a non‑world‑writable directory

GroqBash validates these conditions via `extras/security/verify.sh`.

---

## 2. Provider name

The provider name is the filename without extension:

```
extras/providers/gemini.sh  → provider "gemini"
```

---

## 3. Required functions

Each provider must implement **three functions**, named after the provider:

### `buildpayload_<provider>()`
- Receives global variables set by GroqBash (prompt, system, temperature, max tokens, etc.)
- Must build the JSON payload (or equivalent)
- Must write the payload to stdout
- Must avoid unnecessary external commands

### `callapi_<provider>()`
- Performs the **non‑streaming** API request
- Must read the payload from stdin
- Must print the full response to stdout
- Must return exit code 0 on success

### `callapistreaming_<provider>()`
- Performs the **streaming** API request
- Must print chunks in real time
- Must exit with code 0

---

## 4. Variables guaranteed by GroqBash

GroqBash guarantees the provider:

- `GROQ_API_KEY`
- `MODEL`
- `SYSTEM_PROMPT`
- `USER_PROMPT`
- `TEMPERATURE`
- `MAX_TOKENS`
- `CURLBASEOPTS[@]` (secure curl options array)
- secure `TMPDIR`

The provider **must not modify** these variables.

---

## 5. Behavioral rules

A provider **MUST NOT**:

- change directory (`cd`)
- modify GroqBash global variables
- write files with unsafe permissions
- output non‑JSON data to stdout (except streaming)
- use `eval`
- use `/tmp`
- execute unnecessary commands

---

## 6. Minimal example

```sh
buildpayload_gemini() {
    printf '{"model":"%s","messages":[{"role":"user","content":"%s"}]}' \
        "$MODEL" "$USER_PROMPT"
}

callapi_gemini() {
    curl "${CURLBASEOPTS[@]}" \
         -H "Authorization: Bearer $GROQ_API_KEY" \
         -d @- \
         "https://api.example.com/v1/chat/completions"
}

callapistreaming_gemini() {
    curl "${CURLBASEOPTS[@]}" \
         -N \
         -H "Authorization: Bearer $GROQ_API_KEY" \
         -d @- \
         "https://api.example.com/v1/chat/completions/stream"
}
```

---

# 📎 Final Notes
This contract ensures that all providers remain consistent, secure, and compatible with GroqBash.
