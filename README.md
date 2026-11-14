# Projekt 5 ASK – sin(x) / arcsin(x) w VHDL

Implementacja układu VHDL obliczającego **sin(x)** oraz **arcsin(x)** na argumentach **128-bitowych** (fixed-point Q4.124).

Obliczenia są wydzielone jako **podprogram** wywoływany z programu głównego; argumenty i wyniki przekazywane są przez **komórki pamięci operacyjnej**.

## Szybki start

```bash
make sim
```

Wymagany GHDL (VHDL-2008).

## Dokumentacja

- Zarys koncepcji (z wyjaśnieniem): [docs/KONCEPCJA.md](docs/KONCEPCJA.md)
- Tutorial testowania: [docs/TUTORIAL_TESTOWANIE.md](docs/TUTORIAL_TESTOWANIE.md)
- Architektura i mapa pamięci: [docs/PROJEKT5.md](docs/PROJEKT5.md)
