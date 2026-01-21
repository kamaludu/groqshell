![GroqBash](https://img.shields.io/badge/_GroqBash_-00aa55?style=for-the-badge&label=%E2%9E%9C&labelColor=004d00)
![CLI](https://img.shields.io/badge/CLI-green?&logo=gnu-bash&logoColor=white)
![License: GPLv3](https://img.shields.io/badge/License-GPLv3-green.svg)

# GroqBash

**GroqBash** — *Wrapper Bash sicuro, portabile e dinamico per l’API OpenAI‑compatibile di Groq.*

![single-file](https://img.shields.io/badge/single--file-yes-green?style=plastic) <mark>&nbsp;GroqBash è un singolo file Bash auto‑contenuto.&nbsp; </mark>  
Puoi scaricarlo, renderlo eseguibile e usarlo immediatamente, senza installazione.

**GroqBash** fornisce un’interfaccia CLI semplice, sicura e robusta per chiamare l’API Groq da ambienti Unix‑like, inclusi **Linux**, **macOS**, **WSL** e **Termux**. Gestisce dinamicamente la whitelist dei modelli tramite l’endpoint ufficiale, salva automaticamente output lunghi, e mette la sicurezza al centro del design.

![ShellCheck](https://github.com/kamaludu/groqbash/actions/workflows/shellcheck.yml/badge.svg)
![Smoke Tests](https://github.com/kamaludu/groqbash/actions/workflows/smoke.yml/badge.svg)
---

>
>  ![English](https://img.shields.io/badge/EN-English-white?style=flat)  
> **English is not my first language.**  
> Please feel free to use simple English; I will do my best to respond clearly.
> 

## Caratteristiche principali

- **Refresh modelli ufficiale** tramite `GET https://api.groq.com/openai/v1/models`.  
- **Whitelist dinamica**: nessun modello hardcoded, nessun fallback nascosto.  
- **Sicurezza**: nessun uso di `/tmp`, permessi `600` su file sensibili, nessun `eval`.  
- **Compatibilità Termux** e ambienti POSIX‑like.  
- **Diagnostica** con `--debug` e modalità `--dry-run`.  
- **Salvataggio automatico** dell’output oltre una soglia configurabile.  
- **Opzioni CLI** per selezione modello, default persistente, system prompt, temperatura e token massimi.

---

## Requisiti

**Minimi**
- `bash`
- `curl`

**Consigliati**
- `jq` (parsing JSON)
- `python3` (fsync opzionale)
- coreutils standard (`mktemp`, `df`, `mv`, `chmod`, `head`, `sed`, `awk`)

---

## Installazione

Per le istruzioni di installazione dettagliate, le dipendenze raccomandate e i comandi di verifica, vedi il file **[INSTALL](INSTALL.md)** nel repository.

---

## Nota su file temporanei e percorso di output

Lo script crea tutti i file temporanei sotto `$TMPDIR` (fallback: `~/.cache/groq_tmp`) e non usa la directory di sistema `/tmp` per i temporanei interni. Se passi `--out /percorso/file`, lo script tenterà di creare la directory di destinazione; se questa non è creabile o scrivibile (es. `/tmp` su alcuni ambienti), lo script stamperà l’output su terminale con un messaggio esplicito. Per compatibilità, preferisci percorsi sotto la tua home o `$TMPDIR`.

---

## Dipendenze e fallback

Per dettagli completi sulle dipendenze e sul comportamento dei fallback (`jq` → preferito; `python3` → fallback sicuro; sed/grep → ultima risorsa), consulta `INSTALL.md`.

---

## Uso rapido ed esempi

Prompt diretto
```sh
./groqbash "scrivi una poesia in italiano"
```

Input da file
```sh
./groqbash -f prompt.txt
```

Pipe
```sh
echo "spiegami la relatività" | ./groqbash
```

Esempio con modello specifico
```sh
./groqbash -m llama-3.3-70b-versatile "scrivi un saggio breve"
```

Dry run (mostra payload JSON)
```sh
./groqbash --dry-run "ciao"
```

---

## Opzioni principali
| **Opzione** | Descrizione |
|---|---|
| **-m, --model <name>** | Seleziona il modello da usare |
| 👉 **--refresh-models** | Aggiorna la whitelist dai modelli ufficiali Groq |
| **--list-models** | Mostra i modelli disponibili (whitelist) |
| **--set-default <model>** | Imposta il modello predefinito persistente |
| **--system <text>** | System prompt (ruolo system) |
| **--temp <value>** | Temperature (default 1.0) |
| **--max <n>** | Max tokens (default 4096) |
| **--save / --nosave** | Forza salvataggio o stampa su stdout |
| **--out <path>** | Percorso file o directory per salvataggi |
| **--threshold <n>** | Soglia caratteri per auto‑salvataggio (default 1000) |
| **--debug** | Abilita diagnostica estesa |
| **--dry-run** | Mostra payload senza inviare |
| **--quiet** | Output minimale |
| **--version** | Mostra versione |


## Configurazione, gestione modelli e comportamento

### File di configurazione
- ~/.config/groq/models.txt — whitelist aggiornata (ricreata ad ogni refresh).  
- ~/.config/groq/default_model — modello predefinito persistente (validato contro la whitelist).

### Politica di selezione modello (precedenza)
1. -m/--model (CLI)  
2. ~/.config/groq/default_model (se presente nella whitelist)  
3. variabile d’ambiente GROQ_MODEL (se valida)  
4. auto‑select basato su policy (solo se whitelist non vuota)  
- Se la whitelist è vuota lo script fallisce esplicitamente e richiede --refresh-models.

### Refresh modelli
Esegui:
```sh
./groqbash --refresh-models
```
- Scarica la lista ufficiale via API autenticata.  
- Svuota e ricostruisce models.txt.  
- Stampa diagnostica concisa; con --debug mostra dettagli aggiuntivi.

---

### Codici di uscita e significato

| Codice | Significato                                                                 |
|-------:|------------------------------------------------------------------------------|
| **0**  | Successo: richiesta completata, output stampato o salvato.                  |
| **1**  | Errore generico: argomenti non validi, file non leggibile, configurazione.  |
| **2**  | Errore di rete / curl: DNS, timeout, connessione rifiutata.                 |
| **3**  | Errore HTTP/API: l’endpoint ha risposto con codice 4xx/5xx.                 |
| **4**  | Nessun contenuto testuale estratto dalla risposta (errore di parsing).      |

---

## Sicurezza, privacy e best practice

- Non salvare la tua API key in repository pubblici.  
- Permessi: i file sensibili sono creati con permessi 600.  
- Nessuna esecuzione dell’output generato dal modello.  
- Nessun fallback a modelli deprecati: se la whitelist è vuota lo script termina con errore per evitare comportamenti imprevedibili.  
- Diagnostica: usa --debug solo su ambienti sicuri (può mostrare parti di risposta grezza).

---

## Licenza

GPLv3 — vedi [LICENSE](LICENSE.md) nel repository per i dettagli.

---

### Note

Parti del codice e della documentazione di GroqBash sono state sviluppate con il supporto di strumenti di intelligenza artificiale, utilizzati come assistenti alla scrittura e al refactoring.  
La progettazione, l’architettura e le decisioni tecniche restano interamente curate a mano.

---

### Contatti
- Autore: Cristian Evangelisti  
- Email: opensource​@​cevangel.​anonaddy.​me
- Repository: https://github.com/kamaludu/groqbash

---
