# Contribuire a GroqShell

Grazie per l'interesse a contribuire a GroqShell. Questo documento spiega come proporre modifiche, segnalare bug e inviare pull request in modo efficace.

## Prima di iniziare
- Leggi il `README.md` e `INSTALL.md` per comprendere lo scopo e il funzionamento dello script.
- Controlla le issue aperte per evitare duplicati.

## Segnalare un bug
1. Crea una nuova issue usando il template fornito in `.github/ISSUE_TEMPLATE.md`.
2. Fornisci:
   - versione dello script (`./bin/groqshell --version`)
   - sistema operativo e ambiente (es. Termux, Ubuntu 22.04, macOS)
   - passi per riprodurre il problema
   - output di debug se rilevante (`--debug`)

## Proporre una feature
- Apri una issue descrivendo il caso d'uso e il valore aggiunto.
- Se la feature è approvata, crea una branch dedicata: `git checkout -b feat/nome-feature`.

## Linee guida per le pull request
- Crea una branch per ogni modifica: `feat/...`, `fix/...`, `docs/...`.
- Mantieni i commit piccoli e descrittivi.
- Aggiorna `CHANGELOG.md` con una voce sintetica per la modifica proposta.
- Includi test manuali o istruzioni per la verifica (es. `tests/smoke.sh`).
- Usa il template per pull request in `.github/PULL_REQUEST_TEMPLATE.md`.

## Stile di codice
- Bash POSIX‑compatible dove possibile.
- Evita `eval`.
- Preferisci comandi portabili (`mktemp`, `sed`, `awk`, `grep`).
- Documenta le funzioni complesse con commenti chiari.

## Test e qualità
- Esegui `shellcheck` sullo script prima di aprire la PR (se disponibile).
- Esegui `tests/smoke.sh` per verificare l'integrità base.

## Licenza
Contribuendo accetti che il tuo codice venga rilasciato sotto **GPLv3**.
