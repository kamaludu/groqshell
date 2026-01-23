[![GroqBash](https://img.shields.io/badge/_GroqBash_-00aa55?style=for-the-badge&label=%E2%9E%9C&labelColor=004d00)](README.md)

# INSTALLAZIONE &nbsp; [![English](https://img.shields.io/badge/EN-English_version-orange?style=flat)](INSTALL-en.md) 

Questo documento spiega come installare GroqBash, configurare l’ambiente, verificare la corretta installazione e comprendere il comportamento dei file temporanei, dell’output e dei codici di uscita.

GroqBash è uno **script Bash singolo**, sicuro e auto‑contenuto, progettato per ambienti **single‑user** (Linux, macOS, WSL, Termux).

---

# 1. Prerequisiti e dipendenze

## Richiesti
- **bash**
- **curl**
- **coreutils** (mktemp, chmod, mv, mkdir, head, sed, awk, grep)
- **jq**

## Consigliati
- **python3** — fallback per fsync e serializzazione (opzionale)
- **sha256sum / shasum** — per gli extras di sicurezza

## Locale e encoding
GroqBash richiede un ambiente UTF‑8.

Se necessario:

`sh
export LC_ALL=C.UTF-8
export LANG=C.UTF-8
`

---

# 2. Installazione

## Scarica lo script

`sh
curl -O https://raw.githubusercontent.com/kamaludu/groqbash/main/bin/groqbash
`

## Rendi eseguibile

`sh
chmod +x groqbash
`

## (Opzionale ma consigliato) Installa nel PATH

`sh
mkdir -p "$HOME/.local/bin"
mv groqbash "$HOME/.local/bin/groqbash"
export PATH="$HOME/.local/bin:$PATH"
`

## Imposta la chiave API

`sh
export GROQ_API_KEY="gsk_XXXXXXXXXXXXXXXX"
`

## Verifica installazione

`sh
groqbash --version
`

---

# 3. Installazione degli extras (opzionale)

Gli extras includono:

- documentazione aggiuntiva  
- provider esterni  
- strumenti di sicurezza  
- test suite JSON/SSE  

Installa tutto con:

`sh
groqbash --install-extras
`

Gli extras **non modificano il comportamento del core**.

---

# 4. Comportamento dei file temporanei

- GroqBash **non usa mai `/tmp`** per i temporanei interni.  
- I temporanei vengono creati con:

  - `mktemp -d`  
  - permessi `700`  
  - sotto `$GROQBASHTMPDIR` o un fallback sicuro nella home  

- In modalità `--debug`, i temporanei **non vengono rimossi** per facilitare l’ispezione.

---

# 5. Percorso di output (`--out`)

- Se passi `--out /percorso/file`, GroqBash:
  - tenta di creare la directory  
  - verifica permessi e sicurezza  
  - salva il file con permessi restrittivi (`600`)

- Se la directory non è sicura o non è scrivibile:
  - **non** usa `/tmp`
  - stampa l’output su terminale
  - mostra un messaggio esplicito

**Consiglio:** usa percorsi sotto la tua home o `$GROQBASHTMPDIR`.

---

# 6. Uso base ed esempi

Prompt semplice:

`sh
groqbash "scrivi una funzione bash che..."
`

Input da pipe:

`sh
echo "Spiegami questo codice" | groqbash
`

Input da file:

`sh
groqbash -f input.txt
`

Forzare salvataggio:

`sh
groqbash --save --out output.txt "testo lungo..."
`

Dry run (mostra payload JSON):

`sh
groqbash --dry-run "ciao"
`

Provider (se extras installati):

`sh
groqbash --provider gemini "traduci questo"
`

---

# 7. Codici di uscita

| Codice | Significato                                                                 |
|-------:|------------------------------------------------------------------------------|
| **0**  | Successo                                                                      |
| **1**  | Errore generico (argomenti, file, configurazione)                            |
| **2**  | Errore di rete / curl                                                         |
| **3**  | Errore HTTP/API (4xx/5xx)                                                     |
| **4**  | Nessun contenuto testuale estratto (errore parsing)                           |

**Note operative**
- Codice 2 → retry automatici (timeout, DNS, connessione rifiutata)  
- Codice 3 → nessun retry (errori API, autorizzazione, limiti)  
- Con `--debug`, i log completi sono nel tmpdir runtime

---

# 8. Troubleshooting e test consigliati

## Verifica JSON inviato

`sh
groqbash --dry-run "Test payload with \"quotes\" and newlines\nand unicode: € ✓"
`

## Pipe input

`sh
echo "Spiegami questo codice" | groqbash
`

## API key non valida

`sh
GROQ_API_KEY="invalid" groqbash "ciao" || echo "exit:$?"
`

## Test senza jq

Rinomina temporaneamente jq:

`sh
mv /usr/bin/jq /usr/bin/jq.bak
groqbash --dry-run "test"
mv /usr/bin/jq.bak /usr/bin/jq
`

---

# 9. Problemi comuni

- **cannot create destination directory**  
  → percorso passato a `--out` non sicuro o non scrivibile

- **Output non salvato ma presente nel tmp**  
  → `mv` fallito; controlla il tmpdir mostrato

- **Caratteri strani / JSON invalido**  
  → assicurati di avere locale UTF‑8 e jq/python3 disponibili

---

# 10. Installazione su Termux

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

# 11. Note finali

- GroqBash è progettato per ambienti **single‑user**.  
- Provider e extras sono **opzionali** e devono risiedere in directory sicure.  
- Nessun output del modello viene mai eseguito come comando.  
- Per dettagli sulla sicurezza, vedi **SECURITY.md**.
