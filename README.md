[![GroqBash](https://img.shields.io/badge/_GroqBash_-00aa55?style=for-the-badge&label=%E2%9E%9C&labelColor=004d00)](README.md)
[![CLI](https://img.shields.io/badge/CLI-green?&logo=gnu-bash&logoColor=grey)](#)
[![License: GPLv3](https://img.shields.io/badge/License-GPLv3-green.svg)](LICENSE)
[![ShellCheck](https://github.com/kamaludu/groqbash/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/kamaludu/groqbash/actions/workflows/shellcheck.yml)
[![Smoke Tests](https://github.com/kamaludu/groqbash/actions/workflows/smoke.yml/badge.svg)](https://github.com/kamaludu/groqbash/actions/workflows/smoke.yml)

# GroqBash &nbsp; [![English](https://img.shields.io/badge/EN-English_version-orange?style=flat)](README-en.md)

**GroqBash** — *wrapper CLI sicuro, Bash‑first e completamente auditabile per l’API Chat Completions compatibile OpenAI di Groq.*

GroqBash è un **singolo script Bash**, auto‑contenuto, leggibile e verificabile.  
Scaricalo, rendilo eseguibile, esporta la tua API key e inizia subito a usarlo.

Compatibile con ambienti Unix‑like: **Linux**, **macOS**, **WSL**, **Termux**.

---

## Caratteristiche principali

- **Lista modelli dinamica**  
  tramite `GET https://api.groq.com/openai/v1/models`  
  → nessun modello hardcoded, nessun fallback nascosto.

- **Sicurezza by design**  
  → nessun uso di `/tmp`, nessun `eval`, permessi restrittivi, controlli provider robusti.

- **Bash‑first**  
  → logica chiara, nessuna dipendenza non necessaria.

- **Streaming e non‑streaming**  
  → output in tempo reale o completo a fine risposta.

- **Salvataggio automatico**  
  → per output lunghi oltre una soglia configurabile.

- **Gestione modelli avanzata**  
  → refresh, lista, default persistente, auto‑selezione basata su policy.

- **Extras opzionali**  
  → provider, documentazione estesa, strumenti di sicurezza, test.

---

## Modello di minaccia (versione breve)

GroqBash è progettato per **ambienti single‑user** (laptop, Termux, shell personale).

- I provider sono **codice eseguito nella tua shell**: devono risiedere in directory sicure e non scrivibili da altri.  
- Variabili come `GROQBASHEXTRASDIR` e `GROQBASHTMPDIR` sono considerate **configurazione fidata**.  
- Lo script **non esegue mai** l’output del modello.  
- I rischi TOCTOU e i limiti del parsing JSON/SSE sono mitigati e documentati.

Per dettagli completi: **[SECURITY](SECURITY.md)**.

---

## Requisiti

**Minimi**

- `bash`
- `curl`
- coreutils (`mktemp`, `chmod`, `mv`, `mkdir`, `head`, `sed`, `awk`, `grep`)

**Consigliati**

- `jq` (parsing JSON)
- `python3` (fsync opzionale)
- `sha256sum` o `shasum` (per extras di sicurezza)

---

## Installazione

Istruzioni dettagliate in **[INSTALL](INSTALL.md)**.

In breve:

```sh
chmod +x groqbash
export GROQ_API_KEY="gsk_xxxxxxxxxxxxxxxxx"
./groqbash --help
```

Extras opzionali (docs, provider, sicurezza, test):

```sh
./groqbash --install-extras
```

---

## Uso rapido

Prompt diretto:

```sh
./groqbash "scrivi una breve poesia in italiano"
```

Input da file:

```sh
./groqbash -f prompt.txt
```

Pipe:

```sh
echo "spiegami la relatività" | ./groqbash
```

Modello specifico:

```sh
./groqbash -m llama-3.3-70b-versatile "scrivi un saggio breve"
```

Dry run (mostra il payload JSON):

```sh
./groqbash --dry-run "ciao"
```

Provider (se extras installati):

```sh
./groqbash --provider gemini "traduci questo"
```

---

## Opzioni principali

| Opzione                        | Descrizione                                              |
|--------------------------------|----------------------------------------------------------|
| `-m, --model <name>`           | Seleziona il modello                                     |
| `-f <file>`                    | Legge il prompt da file                                  |
| `--system <text>`              | Imposta il system prompt                                 |
| `--temp <value>`               | Temperature (default: `1.0`)                             |
| `--max <n>`                    | Max tokens (default: `4096`)                             |
| `--refresh-models`             | Aggiorna la lista modelli da Groq                        |
| `--list-models`                | Mostra i modelli disponibili                             |
| `--set-default <model>`        | Imposta il modello predefinito persistente               |
| `--auto-default-policy <p>`    | `preferred` \| `alpha`                                   |
| `--provider <name>`            | Usa un provider esterno                                  |
| `--provider`                   | Selezione provider interattiva                           |
| `--install-extras`             | Installa extras (docs, utils, provider, sicurezza, test) |
| `--save` / `--nosave`          | Forza salvataggio o stampa                               |
| `--out <path>`                 | Percorso file o directory                                |
| `--threshold <n>`              | Soglia auto‑salvataggio (default: `1000`)                |
| `--dry-run`                    | Mostra payload e termina                                 |
| `--quiet`                      | Output minimale                                           |
| `--debug`                      | Debug esteso + conserva temporanei                       |
| `--version`                    | Mostra versione                                           |
| `-h, --help`                   | Mostra l’help (da extras/docs/help.txt se presente)      |

---

## Configurazione e comportamento modelli

### File di configurazione

- `~/.config/groq/models.txt`  
  → lista modelli dinamica (ricreata a ogni refresh).  
- `~/.config/groq/default_model`  
  → modello predefinito persistente.

### Precedenza selezione modello

1. `-m/--model`  
2. `default_model`  
3. `GROQ_MODEL`  
4. Auto‑selezione basata su policy  

Se la lista modelli è vuota: errore → richiede `--refresh-models`.

### Refresh modelli

```sh
./groqbash --refresh-models
```

Scarica la lista ufficiale, ricostruisce `models.txt`, mostra diagnostica (più dettagli con `--debug`).

---

## File temporanei e percorsi output

- GroqBash **non usa mai `/tmp`**.  
- I temporanei runtime sono creati con `mktemp -d` e permessi `700`.  
- I file salvati hanno permessi restrittivi (`600`).  
- Con `--out`, GroqBash crea la directory se possibile; altrimenti stampa su terminale.

---

## Extras avanzati (opzionali)

Gli extras non modificano il comportamento del core.

### Sicurezza

- `extras/security/verify.sh`  
  → verifica provider, permessi, symlink, owner, checksum.  
- `extras/security/validate-env.sh`  
  → controlla `GROQBASHEXTRASDIR`, `GROQBASHTMPDIR`, strumenti richiesti.

Esecuzione:

```sh
extras/security/verify.sh
extras/security/validate-env.sh
```

### Test

- `extras/test/json-sse-suite.sh`  
  → test per escaping JSON e parsing SSE (senza chiamate API reali).

---

## Note di sicurezza e limitazioni

- **Nessun eval**.  
- **Nessuna esecuzione dell’output del modello**.  
- **Provider = codice**: mantieni `extras/providers` sicuro.  
- **Variabili d’ambiente = configurazione fidata**.  
- **Parsing JSON/SSE**: robusto ma non un parser completo.  
- **TOCTOU**: mitigato ma non eliminabile in Bash.

Per dettagli completi: **SECURITY.md**.

---

## Codici di uscita

| Codice | Significato                                                                 |
|--------|------------------------------------------------------------------------------|
| 0      | Successo                                                                      |
| 1      | Errore generico (argomenti, file, configurazione)                             |
| 2      | Errore di rete / curl                                                         |
| 3      | Errore HTTP/API (4xx/5xx)                                                     |
| 4      | Nessun contenuto testuale estratto (errore parsing)                           |

---

## Licenza

GroqBash è distribuito sotto licenza **GNU GPL v3**.  
Vedi **LICENSE** per il testo completo.

---

## Note

Parte del codice e della documentazione è stata redatta con l’assistenza di strumenti di IA.  
L’architettura e le decisioni tecniche restano curate manualmente.

---

## Contatti

- Autore: Cristian Evangelisti  
- Email: opensource​@​cevangel.​anonaddy.​me  
- Repository: https://github.com/kamaludu/groqbash
