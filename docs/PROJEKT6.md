# Projekt 6 – ASK 2024/2025

## Temat

Zaprojektować w języku **VHDL** układ obliczający funkcje:

- \(\cos(x)\)
- \(\arccos(x)\)

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

Zakres: ok. \([-8, 8)\).

## Mapa pamięci operacyjnej

| Adres | Nazwa        | Znaczenie                                      |
|-------|--------------|------------------------------------------------|
| 0     | `MEM_OPCODE` | `0` = cos, `1` = arccos                        |
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
                 [cos_unit]                     [arccos_unit]
                 CORDIC rotacja                 arctan2(√(1-x²), x)
                                                      |
                                          [sqrt_unit] + [atan_unit]
```

### Algorytmy

- **cos(x)** – CORDIC w trybie rotacji kołowej (64 iteracje), z redukcją kąta do \([-\pi/2,\pi/2]\) i korektą znaku.
- **arccos(x)** – \(\arccos(x)=\operatorname{atan2}\!\big(\sqrt{1-x^2},\,x\big)\) dla \(|x|<1\); brzegi: \(\arccos(1)=0\), \(\arccos(-1)=\pi\). Pierwiastek: Newton–Raphson; arctan: CORDIC vectoring.

## Struktura plików

```
vhdl/
  ask_types_pkg.vhd      – typy, format Q4.124, mapa pamięci
  cordic_pkg.vhd         – tablica atan(2^-i), stałe π, 1/K
  cos_unit.vhd           – obliczanie cos
  sqrt_unit.vhd          – pierwiastek (Newton)
  atan_unit.vhd          – arctan(y/x) CORDIC
  arccos_unit.vhd        – obliczanie arccos
  memory.vhd             – pamięć operacyjna (2 porty)
  math_subprogram.vhd    – podprogram (subroutine)
  main.vhd               – program główny
  tb_main.vhd            – testbench
Makefile
docs/PROJEKT6.md
```

## Uruchomienie symulacji

```bash
make sim
```

## Protokół wywołania podprogramu

1. Program główny zapisuje `OPCODE` i `ARG` do pamięci.
2. Ustawia impuls `start` (1 takt zegara).
3. Podprogram ustawia `STATUS=BUSY`, czyta komórki, liczy, zapisuje `RESULT`.
4. Podprogram ustawia `STATUS=DONE` (lub `ERROR` poza domeną arccos) i zgłasza `done`.
