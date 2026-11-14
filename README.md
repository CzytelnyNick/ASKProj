# Projekt 6 ASK – cos(x) / arccos(x) w VHDL

Implementacja układu VHDL obliczającego **cos(x)** oraz **arccos(x)** na argumentach **128-bitowych** (fixed-point Q4.124).

Obliczenia są wydzielone jako **podprogram** wywoływany z programu głównego; argumenty i wyniki przekazywane są przez **komórki pamięci operacyjnej**.

## Szybki start (Windows)

1. Zainstaluj [Git](https://git-scm.com/download/win) oraz **GHDL** (dodaj `bin` do PATH) — szczegóły w tutorialu.
2. Sklonuj repo i uruchom testy:

```powershell
git clone https://github.com/CzytelnyNick/ASKProj.git
cd ASKProj
git checkout cursor/projekt5-sin-arcsin-vhdl-88fc
.\sim.bat
```

Wymagany GHDL (VHDL-2008). `make` na Windows nie jest potrzebny.

## Dokumentacja

- Tutorial testowania (Windows): [docs/TUTORIAL_TESTOWANIE.md](docs/TUTORIAL_TESTOWANIE.md)
- Zarys koncepcji: [docs/KONCEPCJA.md](docs/KONCEPCJA.md)
- Architektura i mapa pamięci: [docs/PROJEKT6.md](docs/PROJEKT6.md)
