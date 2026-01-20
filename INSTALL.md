# Installazione rapida

Scopo
Questo file spiega come installare e verificare groqbash, le dipendenze raccomandate, le variabili d’ambiente richieste e i codici di uscita che lo script può restituire.

## Prerequisiti e dipendenze

**Richiesti**
- **bash**
- **curl**

**Raccomandati**
- **jq** — per costruzione e parsing JSON robusti (se non presente lo script usa un fallback).
- **python3** — usato come fallback per serializzare/parsing JSON e per fsync; consigliato per maggiore affidabilità.
- **coreutils** — mktemp, df, mv, chmod, awk (disponibili su Linux/macOS/Termux).
- **grep/sed/awk** — utili per fallback best‑effort.

**Nota su locale e encoding**
Lo script assume un ambiente UTF‑8. Se il sistema non ha un locale UTF‑8 disponibile, impostare una locale UTF‑8 prima di eseguire lo script, ad esempio:
```sh
export LC_ALL=C.UTF-8
export LANG=C.UTF-8
```

## Installazione

Scarica lo script
```sh
curl -O https://raw.githubusercontent.com/kamaludu/groqbash/main/bin/groqbash
```

Rendi eseguibile
```sh
chmod +x groqbash
```

Posiziona il binario nel tuo PATH (opzionale, consigliato)
```sh
# esempio utente Linux/macOS
mkdir -p "$HOME/.local/bin"
mv groqbash "$HOME/.local/bin/groqbash"
# assicurati che ~/.local/bin sia nel PATH
export PATH="$HOME/.local/bin:$PATH"
```

Imposta la chiave API
```sh
export GROQ_API_KEY="gsk_XXXXXXXXXXXXX"
```

Verifica installazione
```sh
groqbash --version
```

## Comportamento dei file temporanei e percorso di output

**Politica temporanei**
- Lo script non usa la directory di sistema /tmp per i file temporanei interni. Tutti i temporanei vengono creati sotto $TMPDIR (se non impostato, fallback: ~/.cache/groq_tmp o equivalente).
- Questo garantisce compatibilità con ambienti come Termux e sistemi con /tmp non scrivibile.

**Percorso di output (--out)**
- Se passi --out /percorso/file, lo script tenterà di creare la directory di destinazione e scrivere il file lì.
- Se la directory di destinazione non è creabile o non è scrivibile (es. /tmp su alcuni ambienti), lo script non userà /tmp per i temporanei e stamperà l’output su terminale con un messaggio di errore esplicito.
- Raccomandazione: usare percorsi sotto la home dell’utente o $TMPDIR per garantire che la scrittura abbia successo.

## Uso base ed esempi

Prompt semplice
```sh
groqbash "scrivi una funzione bash che..."
```

Input da pipe
```sh
echo "Spiegami questo codice" | groqbash
```

Input da file
```sh
groqbash -f input.txt
```

Forzare salvataggio su file
```sh
groqbash --save --out /percorso/di/uscita/output.txt "testo lungo..."
```

Dry run (mostra payload JSON senza inviare)
```sh
groqbash --dry-run "ciao"
```

## Codici di uscita e significato

| Codice | Significato                                                                 |
|-------:|------------------------------------------------------------------------------|
| **0**  | Successo: richiesta completata, output stampato o salvato.                  |
| **1**  | Errore generico: argomenti non validi, file non leggibile, configurazione.  |
| **2**  | Errore di rete / curl: DNS, timeout, connessione rifiutata.                 |
| **3**  | Errore HTTP/API: l’endpoint ha risposto con codice 4xx/5xx.                 |
| **4**  | Nessun contenuto testuale estratto dalla risposta (errore di parsing).      |

**Note pratiche**
- In caso di codice 2 lo script effettua retry secondo la configurazione MAX_RETRIES.
- In caso di codice 3 (errori 4xx/5xx) lo script non riprova automaticamente per evitare retry su errori di autorizzazione o limiti.
- I messaggi di errore dettagliati e, se attivo, i log di debug sono scritti nel tmpdir di esecuzione per facilitare il debug.

## Risoluzione problemi e test consigliati

**Verifiche rapide**
- Dry run per controllare il JSON inviato:
```sh
  groqbash --dry-run "Test payload with \"quotes\" and newlines\nand unicode: € ✓"
```
- Pipe input:
```sh
  echo "Spiegami questo codice" | groqbash
```
- Test chiave API non valida (verifica codice 3):
```sh
  GROQ_API_KEY="invalid" groqbash "ciao" || echo "exit:$?"
```
- Test fallback senza jq:
  Temporaneamente rimuovi o nascondi jq e ripeti --dry-run per verificare che il fallback Python venga usato (se python3 è installato).

## Problemi comuni
- Error: cannot create destination directory → il percorso passato a --out non è creabile o non è scrivibile; usare un percorso sotto la home o $TMPDIR.
- **Output non salvato ma presente in tmp** → se mv verso la destinazione fallisce, lo script lascia il file temporaneo nel tmpdir per ispezione; controllare i messaggi di log e il tmpdir mostrato.
- **Caratteri strani o JSON invalido** → assicurarsi che la locale sia UTF‑8 e che jq o python3 siano presenti per i fallback più robusti.

## Esempio INSTALL per Termux
```sh
pkg update
pkg install -y bash curl jq python
# posiziona lo script
mkdir -p "$HOME/.local/bin"
mv groqbash "$HOME/.local/bin/groqbash"
chmod +x "$HOME/.local/bin/groqbash"
export PATH="$HOME/.local/bin:$PATH"
export GROQ_API_KEY="gsk_..."
groqbash --version
```
