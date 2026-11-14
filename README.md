# Projekt 6 ASK – cos(x) / arccos(x) w VHDL

Implementacja układu VHDL obliczającego **cos(x)** oraz **arccos(x)** na argumentach **128-bitowych** (fixed-point Q4.124).

Obliczenia są wydzielone jako **podprogram** wywoływany z programu głównego; argumenty i wyniki przekazywane są przez **komórki pamięci operacyjnej**.

## Szybki start

```bash
make sim
```

Wymagany GHDL (VHDL-2008).

## Dokumentacja

- Zarys koncepcji (z wyjaśnieniem): [docs/KONCEPCJA.md](docs/KONCEPCJA.md)
- Tutorial testowania: [docs/TUTORIAL_TESTOWANIE.md](docs/TUTORIAL_TESTOWANIE.md)
- Architektura i mapa pamięci: [docs/PROJEKT6.md](docs/PROJEKT6.md)
