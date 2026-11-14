# Zarys koncepcji – Projekt 6 ASK (cos / arccos, VHDL)

Dokument opisuje **dlaczego** układ jest zbudowany tak, a nie inaczej, oraz **jak** działa od wywołania podprogramu aż do wyniku.

---

## 1. Cel i wymagania

Zadanie: zaprojektować w VHDL układ liczący:

- \(\cos(x)\)
- \(\arccos(x)\)

przy trzech twardych warunkach z treści projektu:

1. **128-bitowa** reprezentacja argumentów (i wyników),
2. obliczenia jako **podprogram** (subroutine) wywoływany z programu głównego,
3. argumenty i wyniki przekazywane przez **wybrane komórki pamięci operacyjnej**.

Koncepcja: **program główny** + **pamięć** z ustaloną mapą + **podprogram**, który czyta/zapisuje tylko tę pamięć i wewnątrz odpala jednostki `cos` / `arccos`.

---

## 2. Idea ogólna (model „procesor + procedura”)

```text
  program główny          pamięć operacyjna         podprogram
  ──────────────          ─────────────────         ──────────
  1. włóż argumenty  -->  [OPCODE][ARG][...]
  2. CALL (start)    ----------------------------->  czyta pamięć
  3. czekaj na DONE  <-----------------------------  liczy, pisze RESULT
  4. odczytaj wynik  <--  [RESULT][STATUS]
```

To nie jest kalkulator na pinach, tylko **wywołanie procedury przez pamięć**.

---

## 3. Reprezentacja liczb: Q4.124

Na 128 bitach wybrano **stałoprzecinkowy signed Q4.124**:

| Bity        | Rola                          |
|-------------|-------------------------------|
| 127         | znak                           |
| 126…124     | część całkowita (3 bity)       |
| 123…0       | część ułamkowa (124 bity)      |

\[
\text{wartość} = \frac{N_{\text{signed}}}{2^{124}}
\]

Zakres ok. \([-8, 8)\) wystarcza na kąty po redukcji oraz na \(\cos\in[-1,1]\), \(\arccos\in[0,\pi]\).

---

## 4. Architektura blokowa

```text
                    ┌─────────────────────────────────────────┐
                    │                 main                     │
                    └───────────────┬─────────────────────────┘
                                    │ port A
                    ┌───────────────▼─────────────────────────┐
                    │           memory (RAM 128-bit)           │
                    │  0:OPCODE  1:ARG  2:RESULT  3:STATUS     │
                    └───────────────┬─────────────────────────┘
                                    │ port B
                    ┌───────────────▼─────────────────────────┐
                    │          math_subprogram                 │
                    └───────┬─────────────────────┬───────────┘
                            │                     │
                   ┌────────▼────────┐   ┌────────▼─────────┐
                   │    cos_unit     │   │   arccos_unit    │
                   │ CORDIC rotation │   │  atan2(√, x)     │
                   └─────────────────┘   └────┬───────┬─────┘
                                              │       │
                                        ┌─────▼──┐ ┌──▼──────┐
                                        │ sqrt   │ │ atan    │
                                        │ Newton │ │ CORDIC  │
                                        └────────┘ └─────────┘
```

---

## 5. Mapa pamięci i protokół

| Adres | Nazwa | Zawartość |
|------:|-------|-----------|
| 0 | OPCODE | `0` = cos, `1` = arccos |
| 1 | ARG | argument \(x\) (Q4.124) |
| 2 | RESULT | wynik (Q4.124) |
| 3 | STATUS | bit0 = done, bit1 = error, bit2 = busy |

1. Main zapisuje OPCODE i ARG → impuls `start`.
2. Podprogram: STATUS=BUSY → czyta pamięć → liczy → RESULT → STATUS=DONE/`ERROR` → `done`.
3. Main odczytuje RESULT i STATUS.

---

## 6. Algorytm \(\cos(x)\) – CORDIC

### Redukcja kąta

1. Sprowadź \(x\) do \((-\pi,\pi]\) przez \(\pm 2\pi\).
2. Jeśli \(x > \pi/2\): \(x := \pi - x\), zapamiętaj negację (bo \(\cos(\pi-a)=-\cos(a)\)).
3. Jeśli \(x < -\pi/2\): \(x := -\pi - x\), zapamiętaj negację.

### Tryb rotacji

Start: \(x_0=1/K\), \(y_0=0\), \(z_0=\alpha\).

Iteracje CORDIC jak zwykle; po zakończeniu **\(x_n \approx \cos(\alpha)\)** (przy starcie od \(1/K\)). Zastosuj zapamiętany znak.

64 iteracje – kompromis precyzja/czas.

---

## 7. Algorytm \(\arccos(x)\)

Domena \([-1,1]\), wynik w \([0,\pi]\).

- \(|x|>1\) → błąd,
- \(x=1\) → \(0\),
- \(x=-1\) → \(\pi\),
- \(|x|<1\):

\[
\arccos(x) = \operatorname{atan2}\big(\sqrt{1-x^2},\, x\big)
\]

**Intuicja:** w trójkącie jednostkowym kąt między osią X a punktem \((x,\sqrt{1-x^2})\) to właśnie \(\arccos(x)\).

Kroki: \(x^2\) → \(1-x^2\) → \(\sqrt{\cdot}\) (Newton) → `atan_unit(x, y=√)` → normalizacja do \([0,\pi]\).

---

## 8. Dlaczego FSM?

Jedna iteracja CORDIC/Newtona na takt, sygnały `start`/`done`/`busy` — model „procedura trwa wiele cykli”, czytelny dydaktycznie.

---

## 9. Przykład przepływu

**\(\cos(\pi/3)\)**: OPCODE=0, ARG=π/3 → CORDIC → RESULT≈0.5.

**\(\arccos(0.5)\)**: OPCODE=1 → \(\sqrt{0.75}=\sqrt{3}/2\) → \(\operatorname{atan2}(\sqrt{3}/2,\,0.5)=\pi/3\).

---

## 10. Pliki

| Koncepcja | Plik |
|-----------|------|
| Typy, Q4.124, adresy RAM | `ask_types_pkg.vhd` |
| Stałe CORDIC / π / 1/K | `cordic_pkg.vhd` |
| cos | `cos_unit.vhd` |
| sqrt | `sqrt_unit.vhd` |
| arctan | `atan_unit.vhd` |
| arccos | `arccos_unit.vhd` |
| RAM | `memory.vhd` |
| Podprogram | `math_subprogram.vhd` |
| Program główny | `main.vhd` |
| Weryfikacja | `tb_main.vhd` |

---

## 11. Podsumowanie

Projekt realizuje \(\cos\) i \(\arccos\) na 128-bitowym fixed-point jako **procedurę sprzętową**: main wkłada argumenty do RAM i woła podprogram; podprogram wybiera CORDIC (\(\cos\)) albo \(\operatorname{atan2}(\sqrt{1-x^2},x)\) (\(\arccos\)), zapisuje wynik do pamięci i zgłasza zakończenie.
