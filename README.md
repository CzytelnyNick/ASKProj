# Projekt 5 ASK – sin(x) / arcsin(x) w VHDL

Implementacja układu VHDL obliczającego **sin(x)** oraz **arcsin(x)** na argumentach **128-bitowych** (fixed-point Q4.124).

Obliczenia są wydzielone jako **podprogram** wywoływany z programu głównego; argumenty i wyniki przekazywane są przez **komórki pamięci operacyjnej**.

## Szybki start

```bash
make sim
```

Wymagany GHDL (VHDL-2008).

## Dokumentacja

Szczegóły architektury, mapy pamięci i wyników testów: [docs/PROJEKT5.md](docs/PROJEKT5.md)
