
# GroqBash 1.0.0 — Release Notes  
**Data / Date:** 2026‑01‑23  
**Stato / Status:** Stable – Production Ready  

---

## 🇮🇹 Sezione Italiana

### ✨ Novità principali
- Script singolo, auto‑contenuto e verificabile  
- Lista modelli dinamica tramite Groq Models API  
- Sicurezza avanzata: nessun `/tmp`, nessun `eval`, permessi restrittivi  
- Modalità streaming e non‑streaming  
- Salvataggio automatico oltre soglia configurabile  
- Sistema provider estensibile (`extras/providers/`)  
- Help esterno (`extras/docs/help.txt`)  
- Debug esteso con preservazione dei temporanei  
- Documentazione completa (README, INSTALL, SECURITY, CHANGELOG)

---

### 🔐 Sicurezza
- Controlli provider: owner, permessi, symlink, checksum  
- Mitigazione TOCTOU tramite `stat`/`find`  
- Tempdir sicuro (`700`), file salvati con permessi restrittivi (`600`)  
- Nessuna esecuzione dell’output del modello  
- Strumenti dedicati:
  - `extras/security/verify.sh`
  - `extras/security/validate-env.sh`

---

### 🧩 Sistema Provider
- Provider esterni in `extras/providers/`  
- Funzioni richieste:
  - `buildpayload_PROVIDER`
  - `callapi_PROVIDER`
  - `callapistreaming_PROVIDER`
- Esempio incluso: `gemini.sh`

---

### 🛠️ Miglioramenti tecnici
- Hardening del provider loader  
- Parsing JSON/SSE più robusto  
- Unificazione opzioni curl tramite array  
- DRY‑RUN centralizzato  
- Inizializzazione coerente del tmpdir  
- Rimozione fallback legacy  
- Fix SC2086, SC2015, SC2012  
- Migliorata auto‑selezione modelli

---

### ⚠️ Limitazioni note
- Parsing JSON/SSE non è un parser completo  
- Rischi TOCTOU non eliminabili in Bash  
- Provider = codice eseguito nella shell  

---

### 📎 Note
Alcune parti della documentazione sono state redatte con l’assistenza di strumenti di IA.  
L’architettura e le decisioni finali restano curate manualmente.

---

## 🇬🇧 English Section

### ✨ Key Highlights
- Single, self‑contained, auditable script  
- Dynamic model list via Groq Models API  
- Advanced security: no `/tmp`, no `eval`, strict permissions  
- Streaming and non‑streaming modes  
- Automatic saving above configurable threshold  
- Extensible provider system (`extras/providers/`)  
- External help (`extras/docs/help.txt`)  
- Extended debug mode with preserved temp files  
- Full documentation (README, INSTALL, SECURITY, CHANGELOG)

---

### 🔐 Security
- Provider checks: owner, permissions, symlink, checksum  
- TOCTOU mitigation via `stat`/`find`  
- Secure tempdir (`700`), saved files with restrictive perms (`600`)  
- Model output is never executed  
- Dedicated tools:
  - `extras/security/verify.sh`
  - `extras/security/validate-env.sh`

---

### 🧩 Provider System
- External providers in `extras/providers/`  
- Required functions:
  - `buildpayload_PROVIDER`
  - `callapi_PROVIDER`
  - `callapistreaming_PROVIDER`
- Example included: `gemini.sh`

---

### 🛠️ Technical Improvements
- Provider loader hardening  
- More robust JSON/SSE parsing  
- Unified curl options via array  
- Centralized DRY‑RUN  
- Consistent tmpdir initialization  
- Removal of legacy fallbacks  
- Fixes for SC2086, SC2015, SC2012  
- Improved model auto‑selection logic

---

### ⚠️ Known Limitations
- JSON/SSE parsing is not a full parser  
- TOCTOU risks cannot be fully eliminated in Bash  
- Providers = code executed in your shell  

---

### 📎 Notes
Some documentation sections were drafted with the assistance of AI tools.  
Architecture and final decisions remain manually curated.
