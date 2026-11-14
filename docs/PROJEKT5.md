# Projekt 5 – ASK 2024/2025

## Temat

Zaprojektować w języku **VHDL** układ obliczający funkcje:

- \(\sin(x)\)
- \(\arcsin(x)\)

Argumenty reprezentowane są na **128 bitach**.

## Wymagania z treści zadania

1. Obliczenia zrealizowane jako **podprogram** wywoływany z programu głównego.
2. Argumenty i wyniki przekazywane przez **wybrane komórki pamięci operacyjnej**.

## Format danych – Q4.124 (128 bitów)

| Pole              | Bity       | Opis                                      |
|-------------------|------------|-------------------------------------------|
| znak              | 127        | bit znaku (uzupełnienie do 2)             |
| część całkowita   | 126 … 124  | 3 bity                                    |
| część ułamkowa    | 123 … 0    | 124 bity                                  |

\[
\text{wartość} = \frac{\text{interpretacja całkowita (signed)}}{2^{124}}
\]

Zakres: ok. \([-8, 8)\). Wystarczający dla kątów po redukcji oraz wyników \(\sin/\arcsin\) w \([-1,1]\) / \([-\pi/2,\pi/2]\).

## Mapa pamięci operacyjnej

| Adres | Nazwa        | Znaczenie                                      |
|-------|--------------|------------------------------------------------|
| 0     | `MEM_OPCODE` | `0` = sin, `1` = arcsin                        |
| 1     | `MEM_ARG`    | argument \(x\) (128 bit)                       |
| 2     | `MEM_RESULT` | wynik (128 bit)                                |
| 3     | `MEM_STATUS` | bit0=done, bit1=error, bit2=busy               |

## Architektura

```
  [program główny / main]
           |  zapis OPCODE + ARG, impuls start
           v
  [pamięć operacyjna]  <----->  [podprogram math_subprogram]
                                      |
                      +---------------+---------------+
                      |                               |
                 [sin_unit]                     [arcsin_unit]
                 CORDIC rotacja                 arctan(x/√(1-x²))
                                                      |
                                          [sqrt_unit] + [atan_unit]
```

### Algorytmy

- **sin(x)** – CORDIC w trybie rotacji kołowej (64 iteracje), z redukcją kąta do \([-\pi/2,\pi/2]\).
- **arcsin(x)** – \(\arcsin(x)=\arctan\!\big(x/\sqrt{1-x^2}\big)\) dla \(|x|<1\); przypadki brzegowe \(\pm 1\) zwracają \(\pm\pi/2\). Pierwiastek: Newton–Raphson; arctan: CORDIC vectoring.

## Struktura plików

```
vhdl/
  ask_types_pkg.vhd      – typy, format Q4.124, mapa pamięci
  cordic_pkg.vhd         – tablica atan(2^-i), stałe π, 1/K
  sin_unit.vhd           – obliczanie sin
  sqrt_unit.vhd          – pierwiastek (Newton)
  atan_unit.vhd          – arctan(y/x) CORDIC
  arcsin_unit.vhd        – obliczanie arcsin
  memory.vhd             – pamięć operacyjna (2 porty)
  math_subprogram.vhd    – podprogram (subroutine)
  main.vhd               – program główny
  tb_main.vhd            – testbench
Makefile
docs/PROJEKT5.md
```

## Uruchomienie symulacji

Wymagany [GHDL](https://ghdl.github.io/ghdl/) (VHDL-2008):

```bash
make sim
```

Samą analizę / elaborację:

```bash
make analyze
make elaborate
```

## Protokół wywołania podprogramu

1. Program główny zapisuje `OPCODE` i `ARG` do pamięci.
2. Ustawia impuls `start` (1 takt zegara).
3. Podprogram ustawia `STATUS=BUSY`, czyta komórki, liczy, zapisuje `RESULT`.
4. Podprogram ustawia `STATUS=DONE` (lub `ERROR` poza domeną arcsin) i zgłasza `done`.

## Wyniki testów (GHDL)

| Test                 | Błąd bezwzględny (orientacyjnie) |
|----------------------|----------------------------------|
| sin(0), sin(π)       | ~1e-19                           |
| sin(π/6), sin(π/2)   | 0 … 1e-16                        |
| sin(1)               | ~1e-9                            |
| arcsin(0.5), ±1      | 0 … 1e-16                        |
| arcsin(√2/2)         | ~1e-16                           |
