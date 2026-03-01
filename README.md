# Elucidate Recovery – v4.8 Stable

Elucidate Recovery is a modular Bash‑based recovery helper designed for learning, experimentation, and safe testing with user‑owned files. It provides a clean, color‑coded interface for extracting supported formats into hash material that can be used with standard recovery tools.

This version (v4.8) focuses on stability, clarity, and predictable behavior across Linux, Termux, and Raspberry Pi environments.

---

## ✨ Features

- Color‑coded, menu‑driven interface  
- Modular extractor system  
- Supports multiple common encrypted formats  
- Automatic search for matching files  
- Clean output and TTY‑friendly formatting  
- Works on:
  - Kali Linux  
  - Termux (Android)  
  - Raspberry Pi OS  
- Includes test files for safe practice

---

## 📁 Supported Formats

Elucidate Recovery v4.8 supports extraction for:

- ZIP archives  
- PDF documents  
- RAR archives  
- 7‑Zip archives  
- Microsoft Office files (`.docx`, `.xlsx`, `.pptx`)  
- SSH private keys (`id_rsa`)  
- BitLocker containers (`.bek`, `.fve`, `.img`)  
- Wi‑Fi capture files (`.cap`, `.pcap`)  

Wi‑Fi extraction uses the correct handshake extractor for EAPOL‑based captures.

---

## 🧩 How It Works

1. Choose a file type from the menu  
2. The script searches your project directory for matching files  
3. You select the file you want to process  
4. The script runs the correct extractor for that format  
5. Output is saved in a clean, readable format for further analysis  

The goal is to make the workflow simple, predictable, and educational.

---

## 📦 Installation

Clone the repository:

```bash
git clone https://github.com/Blahhacrunxh/elucidate-recovery
cd elucidate-recovery
