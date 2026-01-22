[![GroqBash](https://img.shields.io/badge/_GroqBash_-00aa55?style=for-the-badge&label=%E2%9E%9C&labelColor=004d00)](README.md)
![CLI](https://img.shields.io/badge/CLI-green?&logo=gnu-bash&logoColor=grey)
[![License: GPLv3](https://img.shields.io/badge/License-GPLv3-green.svg)](LICENSE)
![ShellCheck](https://github.com/kamaludu/groqbash/actions/workflows/shellcheck.yml/badge.svg)
![Smoke Tests](https://github.com/kamaludu/groqbash/actions/workflows/smoke.yml/badge.svg)

# GroqBash &nbsp; [![English](https://img.shields.io/badge/EN-English_version-orange?style=flat)](README-en.md) 

**GroqBash**  *wrapper CLI sicuro e Bash‑first per l’API Chat Completions compatibile OpenAI di Groq.*

GroqBash è un **singolo script Bash**, auto‑contenuto e facilmente verificabile.  
Puoi scaricarlo, renderlo eseguibile, esportare la tua API key e iniziare subito a usarlo.

Funziona su ambienti Unix‑like: **Linux**, **macOS**, **WSL**, **Termux**.

---

## Caratteristiche principali

- **Lista modelli dinamica** tramite `GET https://api.groq.com/openai/v1/models`  
  – nessun modello hardcoded, nessun fallback nascosto.  
- **Sicurezza by design**  
  – nessun uso di `/tmp` per i temporanei interni, nessun `eval`, permessi restrittivi sui file sensibili.  
- **Bash‑first**  
  – dipendenza esplicita da Bash, con logica chiara e verificabile.  
- **Streaming e non‑streaming**  
  – output in tempo reale o completo a fine risposta.  
- **Salvataggio automatico**  
  – per output lunghi oltre una soglia configurabile.  
- **Gestione modelli**  
  – refresh, lista, default persistente, auto‑selezione basata su policy.  
- **Extras opzionali**  
  – provider, utility, documentazione, strumenti avanzati di sicurezza e test.

---

## Modello di minaccia (versione breve)

GroqBash è progettato per **ambienti single‑user** (laptop, Termux, shell personale), non per server multi‑tenant ostili.

- I provider sono **codice eseguito nella tua shell**. Devono risiedere in directory di tua proprietà e non scrivibili da altri.  
- Variabili d’ambiente come `GROQBASHEXTRASDIR` e `GROQBASHTMPDIR` sono considerate **configurazione fidata**.  
- Lo script **non esegue mai** l’output del modello come comandi.  
- Rischi TOCTOU e limiti del parsing JSON/SSE sono documentati e accettabili per uno script Bash hardenizzato.

Per dettagli completi, vedi **SECURITY.md**.

---

## Requisiti

**Minimi**

- `bash`
- `curl`
- coreutils standard (`mktemp`, `chmod`, `mv`, `mkdir`, `head`, `sed`, `awk`, `grep`)

**Consigliati**

- `jq` (parsing JSON)
- `python3` (fsync opzionale)
- `sha256sum` o `shasum` (per gli extras di sicurezza)

---

## Installazione

Per istruzioni dettagliate, dipendenze e comandi di verifica, vedi **[INSTALL.md](INSTALL.md)**.

In breve:

`sh
chmod +x groqbash
export GROQ_API_KEY="gsk_xxxxxxxxxxxxxxxxx"
./groqbash --help
`

Extras opzionali (docs, provider, sicurezza, test):

`sh
./groqbash --install-extras
`

---

## Uso rapido

Prompt diretto:

`sh
./groqbash "scrivi una breve poesia in italiano"
`

Input da file:

`sh
./groqbash -f prompt.txt
`

Pipe:

`sh
echo "spiegami la relatività" | ./groqbash
`

Modello specifico:

`sh
./groqbash -m llama-3.3-70b-versatile "scrivi un saggio breve"
`

Dry run (mostra il payload JSON):

`sh
./groqbash --dry-run "ciao"
`

Provider (se extras installati):

`sh
./groqbash --provider gemini "traduci questo"
`

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
  – lista modelli dinamica (ricreata a ogni refresh).  
- `~/.config/groq/default_model`  
  – modello predefinito persistente.

### Precedenza selezione modello

1. `-m/--model`  
2. `default_model` (se valido)  
3. `GROQ_MODEL` (se valido)  
4. Auto‑selezione basata su policy  

Se la lista modelli è vuota, GroqBash fallisce e richiede `--refresh-models`.

### Refresh modelli

`sh
./groqbash --refresh-models
`

Scarica la lista ufficiale, ricostruisce `models.txt`, mostra diagnostica (più dettagli con `--debug`).

---

## File temporanei e percorsi output

- GroqBash **non usa mai `/tmp`** per i temporanei interni.  
- I temporanei runtime sono creati con `mktemp -d` e permessi `700`.  
- I file salvati hanno permessi restrittivi (es. `600`).  
- Con `--out`, GroqBash crea la directory se possibile; altrimenti stampa su terminale con messaggio esplicito.

---

## Extras avanzati (opzionali)

Gli extras non modificano il comportamento del core.

### Sicurezza

- `extras/security/verify.sh`  
  – verifica provider, permessi, symlink, owner, checksum.  
- `extras/security/validate-env.sh`  
  – controlla `GROQBASHEXTRASDIR`, `GROQBASHTMPDIR`, strumenti richiesti.

Esecuzione:

`sh
extras/security/verify.sh
extras/security/validate-env.sh
`

### Test

- `extras/test/json-sse-suite.sh`  
  – test per escaping JSON e parsing SSE (senza chiamate API reali).

---

## Note di sicurezza e limitazioni

- **Nessun eval**.  
- **Nessuna esecuzione dell’output del modello**.  
- **Provider = codice**: mantieni `extras/providers` sicuro e non scrivibile da altri.  
- **Variabili d’ambiente = configurazione fidata**.  
- **Parsing JSON/SSE**: robusto per uso normale, non un parser completo.  
- **TOCTOU**: mitigato ma non eliminabile in Bash.

Per dettagli completi, vedi **SECURITY.md**.

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
`
