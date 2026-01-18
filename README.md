![GroqShell](https://img.shields.io/badge/GroqShell-00aa55?style=for-the-badge)
![CLI](https://img.shields.io/badge/CLI-green?style=for-the-badge&logo=gnu-bash&logoColor=white)
![License: GPLv3](https://img.shields.io/badge/License-GPLv3-blue.svg)

# GroqShell

**GroqShell** — *Wrapper Bash sicuro, portabile e dinamico per l’API OpenAI‑compatibile di Groq.*

GroqShell fornisce un’interfaccia CLI semplice, sicura e robusta per chiamare l’API Groq da ambienti Unix‑like, inclusi **Linux**, **macOS**, **WSL** e **Termux**. Gestisce dinamicamente la whitelist dei modelli tramite l’endpoint ufficiale, salva automaticamente output lunghi, e mette la sicurezza al centro del design.

---

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

## Installazione rapida

```sh
curl -O https://raw.githubusercontent.com/kamaludu/groqshell/main/bin/groqshell
chmod +x groqshell
export GROQAPIKEY="gsk_XXXXXXXXXXXXX"
```

Aggiungi export GROQAPIKEY="..." al tuo .bashrc o .profile per persistenza.

---

## Uso rapido ed esempi

Prompt diretto
```sh
./groqshell "scrivi una poesia in italiano"
```

Input da file
```sh
./groqshell -f prompt.txt
```

Pipe
```sh
echo "spiegami la relatività" | ./groqshell
```

Esempio con modello specifico
```sh
./groqshell -m llama-3.3-70b-versatile "scrivi un saggio breve"
```

Dry run (mostra payload JSON)
```sh
./groqshell --dry-run "ciao"
```

---

## Opzioni principali

| Opzione | Descrizione |
|---|---|
| -m, --model <name> | Seleziona il modello da usare |
| --refresh-models | Aggiorna la whitelist dai modelli ufficiali Groq |
| --list-models | Mostra i modelli disponibili (whitelist) |
| --set-default <model> | Imposta il modello predefinito persistente |
| --system <text> | System prompt (ruolo system) |
| --temp <value> | Temperature (default 1.0) |
| --max <n> | Max tokens (default 4096) |
| --save / --nosave | Forza salvataggio o stampa su stdout |
| --out <path> | Percorso file o directory per salvataggi |
| --threshold <n> | Soglia caratteri per auto‑salvataggio (default 1000) |
| --debug | Abilita diagnostica estesa |
| --dry-run | Mostra payload senza inviare |
| --quiet | Output minimale |
| --version | Mostra versione |

---

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
./groqshell --refresh-models
```
- Scarica la lista ufficiale via API autenticata.  
- Svuota e ricostruisce models.txt.  
- Stampa diagnostica concisa; con --debug mostra dettagli aggiuntivi.

---

## Sicurezza, privacy e best practice

- Non salvare la tua API key in repository pubblici.  
- Permessi: i file sensibili sono creati con permessi 600.  
- Nessuna esecuzione dell’output generato dal modello.  
- Nessun fallback a modelli deprecati: se la whitelist è vuota lo script termina con errore per evitare comportamenti imprevedibili.  
- Diagnostica: usa --debug solo su ambienti sicuri (può mostrare parti di risposta grezza).

---

## Licenza

GPLv3 — vedi LICENSE nel repository per i dettagli.

---

### Contatti
- Autore: Cristian Evangelisti  
- Email: opensource​@​cevangel.​anonaddy.​me
- Repository: https://github.com/kamaludu/groqshell

---
