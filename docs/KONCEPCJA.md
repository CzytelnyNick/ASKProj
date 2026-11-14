# Zarys koncepcji – Projekt 5 ASK (sin / arcsin, VHDL)

Dokument opisuje **dlaczego** układ jest zbudowany tak, a nie inaczej, oraz **jak** działa od wywołania podprogramu aż do wyniku.

---

## 1. Cel i wymagania

Zadanie: zaprojektować w VHDL układ liczący:

- \(\sin(x)\)
- \(\arcsin(x)\)

przy trzech twardych warunkach z treści projektu:

1. **128-bitowa** reprezentacja argumentów (i wyników),
2. obliczenia jako **podprogram** (subroutine) wywoływany z programu głównego,
3. argumenty i wyniki przekazywane przez **wybrane komórki pamięci operacyjnej** (nie przez „gołe” porty matematyczne na zewnątrz podprogramu).

Koncepcja odpowiada na te punkty wprost: jest **program główny**, **pamięć** z ustaloną mapą komórek oraz **podprogram**, który czyta/zapisuje tylko tę pamięć i wewnątrz odpala jednostki `sin` / `arcsin`.

---

## 2. Idea ogólna (model „procesor + procedura”)

Układ naśladuje klasyczny model oprogramowania:

```text
  program główny          pamięć operacyjna         podprogram
  ──────────────          ─────────────────         ──────────
  1. włóż argumenty  -->  [OPCODE][ARG][...]
  2. CALL (start)    ----------------------------->  czyta pamięć
  3. czekaj na DONE  <-----------------------------  liczy, pisze RESULT
  4. odczytaj wynik  <--  [RESULT][STATUS]
```

To nie jest „kalkulator na pinach”, tylko **wywołanie procedury przez pamięć** — dokładnie tak, jak wymaga uwaga w treści projektu (argumenty/wyniki w komórkach RAM).

---

## 3. Reprezentacja liczb: dlaczego Q4.124?

Na 128 bitach można zrobić float albo fixed-point. Wybrano **stałoprzecinkowy signed Q4.124**:

| Bity        | Rola                          |
|-------------|-------------------------------|
| 127         | znak                           |
| 126…124     | część całkowita (3 bity)       |
| 123…0       | część ułamkowa (124 bity)      |

\[
\text{wartość} = \frac{N_{\text{signed}}}{2^{124}}
\]

**Dlaczego tak?**

- Zakres ok. \([-8, 8)\) wystarcza na kąty po redukcji modulo \(2\pi\) oraz na wyniki \(\sin\in[-1,1]\), \(\arcsin\in[-\pi/2,\pi/2]\).
- Mnożenie i przesunięcia w sprzęcie / VHDL są prostsze niż pełny float IEEE.
- Duża część ułamkowa (124 bity) daje bardzo mały błąd przy 64 iteracjach CORDIC.
- Stałe (\(\pi\), \(\pi/2\), \(\operatorname{atan}(2^{-i})\), \(1/K\)) da się włożyć do ROM/pakietu jako stałe 128-bitowe.

Przykłady:

- `1.0`  → bit 124 ustawiony → `0x1000…0`
- `-1.0` → uzupełnienie do 2 → `0xF000…0`
- `0.5`  → bit 123 ustawiony

---

## 4. Architektura blokowa

```text
                    ┌─────────────────────────────────────────┐
                    │                 main                     │
                    │  (program główny: zapis ARG, CALL, odczyt)│
                    └───────────────┬─────────────────────────┘
                                    │ port A
                    ┌───────────────▼─────────────────────────┐
                    │           memory (RAM 128-bit)           │
                    │  0:OPCODE  1:ARG  2:RESULT  3:STATUS     │
                    └───────────────┬─────────────────────────┘
                                    │ port B
                    ┌───────────────▼─────────────────────────┐
                    │          math_subprogram                 │
                    │   (FSM: busy → czytaj → dispatch → done) │
                    └───────┬─────────────────────┬───────────┘
                            │                     │
                   ┌────────▼────────┐   ┌────────▼─────────┐
                   │    sin_unit     │   │   arcsin_unit    │
                   │ CORDIC rotation │   │  tożsamość +    │
                   │ + redukcja kąta │   │  sqrt + atan    │
                   └─────────────────┘   └────┬───────┬─────┘
                                              │       │
                                        ┌─────▼──┐ ┌──▼──────┐
                                        │ sqrt   │ │ atan    │
                                        │ Newton │ │ CORDIC  │
                                        └────────┘ └─────────┘
```

### Role bloków

| Blok | Rola koncepcyjna |
|------|------------------|
| `main` | Program główny – przygotowuje wywołanie i odbiera wynik |
| `memory` | Pamięć operacyjna – jedyny „kontrakt” danych z podprogramem |
| `math_subprogram` | Podprogram – orkiestracja, bez własnej „matematyki biznesowej” |
| `sin_unit` | Rdzeń \(\sin\) |
| `arcsin_unit` | Rdzeń \(\arcsin\) (składa prostsze operacje) |
| `sqrt_unit` / `atan_unit` | Pomocnicze operacje numeryczne |
| `tb_main` | Testbench – generuje bodźce i sprawdza wyniki |

---

## 5. Mapa pamięci i protokół wywołania

### Komórki

| Adres | Nazwa | Zawartość |
|------:|-------|-----------|
| 0 | OPCODE | `0` = sin, `1` = arcsin |
| 1 | ARG | argument \(x\) (Q4.124) |
| 2 | RESULT | wynik (Q4.124) |
| 3 | STATUS | bit0 = done, bit1 = error, bit2 = busy |

### Sekwencja (jak „CALL”)

1. **Main** zapisuje OPCODE i ARG.
2. Main daje impuls `start` (1 takt).
3. **Podprogram** ustawia STATUS = BUSY.
4. Podprogram czyta OPCODE i ARG z pamięci.
5. Na podstawie OPCODE startuje `sin_unit` albo `arcsin_unit`.
6. Po skończeniu zapisuje RESULT.
7. Ustawia STATUS = DONE (albo ERROR, np. arcsin poza \([-1,1]\)) i impuls `done`.
8. Main odczytuje RESULT i STATUS.

Dzięki temu podprogram jest **samodzielną procedurą**: wejście/wyjście wyłącznie przez ustalone adresy RAM.

---

## 6. Algorytm \(\sin(x)\) – CORDIC

### Skąd pomysł?

Szereg Taylora wymaga silni, potęg i wielu mnożeń. W sprzęcie wygodniejszy jest **CORDIC** (COordinate Rotation DIgital Computer): tylko **dodawania, odejmowania i przesunięcia bitowe** oraz tablica kątów \(\operatorname{atan}(2^{-i})\).

### Redukcja kąta

CORDIC dobrze działa dla kąta w okolicy \([-\pi/2,\pi/2]\). Dlatego najpierw:

1. sprowadź \(x\) do \((-\pi,\pi]\) przez \(\pm 2\pi\),
2. jeśli \(x > \pi/2\): użyj \(\sin(x)=\sin(\pi-x)\),
3. jeśli \(x < -\pi/2\): użyj \(\sin(x)=-\sin(x+\pi)\) (i zapamiętaj znak).

### Tryb rotacji (circular rotation)

Start:

\[
x_0 = \frac{1}{K},\quad y_0 = 0,\quad z_0 = \alpha
\]

gdzie \(K\) to wzmocnienie CORDIC (iloczyn \(\sqrt{1+2^{-2i}}\)), a \(1/K\) jest stałą w `cordic_pkg`.

Iteracja \(i = 0\ldots 63\):

\[
\begin{aligned}
x_{i+1} &= x_i - d_i\, y_i\, 2^{-i} \\
y_{i+1} &= y_i + d_i\, x_i\, 2^{-i} \\
z_{i+1} &= z_i - d_i\, \operatorname{atan}(2^{-i})
\end{aligned}
\]

z \(d_i = \operatorname{sign}(z_i)\) (kierunek tak dobrany, by \(z\to 0\)).

Po iteracjach:

\[
y_n \approx \sin(\alpha),\quad x_n \approx \cos(\alpha)
\]

(przy starcie od \(1/K\)).

**Intuicja:** obracasz wektor o znane kąty \(\operatorname{atan}(2^{-i})\), aż „zużyjesz” cały kąt \(\alpha\); współrzędna \(y\) staje się sinusem.

W projekcie: **64 iteracje** — kompromis między precyzją a czasem symulacji (przy 124 bitach ułamka i tak błąd jest rzędu \(10^{-9}\)–\(10^{-16}\)).

---

## 7. Algorytm \(\arcsin(x)\)

### Domenę

\[
\arcsin: [-1,1] \to [-\pi/2,\pi/2]
\]

- \(|x| > 1\) → błąd (STATUS.error),
- \(x = \pm 1\) → wynik \(\pm\pi/2\) (osobna gałąź, bez dzielenia przez 0),
- \(|x| < 1\) → wzór poniżej.

### Tożsamość

\[
\arcsin(x) = \arctan\left(\frac{x}{\sqrt{1-x^2}}\right)
\]

**Dlaczego?** W trójkącie prostokątnym, jeśli przeciwprostokątna = 1 i przeciwległa = \(x\), to przyległa = \(\sqrt{1-x^2}\), a kąt to właśnie \(\arcsin(x)=\arctan(\text{przeciw/\text{przyleg}})\).

### Kroki w układzie

1. \(x^2\) – mnożenie Q4.124,
2. \(1 - x^2\),
3. \(\sqrt{1-x^2}\) – **Newton–Raphson**:
   \[
   y_{n+1} = \frac{1}{2}\left(y_n + \frac{a}{y_n}\right)
   \]
4. \(\arctan(y/x)\) z \(y=x_{\text{arg}}\), \(x=\sqrt{\ldots}\) – **CORDIC vectoring** (napędzanie \(y\to 0\), zbieranie kąta w \(z\)).

`arcsin_unit` jest więc **sterownikiem sekwencyjnym** łączącym `sqrt_unit` i `atan_unit`.

---

## 8. Dlaczego sekwencyjne FSM, a nie kombinacyjnie?

Każda jednostka (`sin`, `sqrt`, `atan`, podprogram, main) to **automat stanów**:

- jeden krok CORDIC / Newtona na takt zegara,
- jasne sygnały `start` / `done` / `busy`,
- łatwa synteza mentalna i symulacja,
- naturalne dopasowanie do modelu „procedura trwa wiele cykli”.

Przy 128-bitowej arytmetyce pełne rozwinięcie 64 iteracji w jeden cykl byłoby ogromne i nieczytelne dydaktycznie.

---

## 9. Przepływ danych – przykład

**Żądanie:** policz \(\sin(\pi/6)\).

1. Main zapisuje `OPCODE=0`, `ARG=π/6` (Q4.124).
2. Impuls `start` → podprogram → STATUS=BUSY.
3. Dispatch → `sin_unit`:
   - redukcja: kąt już w \([-\pi/2,\pi/2]\),
   - 64 iteracje CORDIC,
   - wynik ≈ `0.5`.
4. Zapis `RESULT=0.5`, STATUS=DONE.
5. Main czyta wynik; testbench porównuje z `0.5`.

**Żądanie:** \(\arcsin(0.5)\).

1. OPCODE=1, ARG=0.5.
2. `arcsin_unit`: \(0.5^2=0.25\), \(1-0.25=0.75\), \(\sqrt{0.75}=\sqrt{3}/2\),
3. \(\arctan(0.5 / (\sqrt{3}/2)) = \arctan(1/\sqrt{3}) = \pi/6\).
4. Wynik wraca przez RESULT.

---

## 10. Podział na pliki (mapowanie koncepcji → kod)

| Koncepcja | Plik |
|-----------|------|
| Typy, Q4.124, adresy RAM | `ask_types_pkg.vhd` |
| Stałe CORDIC / π / 1/K | `cordic_pkg.vhd` |
| sin | `sin_unit.vhd` |
| sqrt | `sqrt_unit.vhd` |
| arctan | `atan_unit.vhd` |
| arcsin (składanie) | `arcsin_unit.vhd` |
| RAM | `memory.vhd` |
| Podprogram | `math_subprogram.vhd` |
| Program główny | `main.vhd` |
| Weryfikacja | `tb_main.vhd` |

Świadomy podział: **pakiety = kontrakt danych**, **jednostki funkcyjne = algorytmy**, **subprogram = API pamięciowe**, **main/tb = użycie**.

---

## 11. Założenia i ograniczenia

- Argument \(\sin\) w praktyce sensowny w zakresie, który da się zredukować do \((-\pi,\pi]\) (przy bardzo dużych \(|x|\) redukcja zajmie wiele taktów).
- \(\arcsin\) tylko dla \(x\in[-1,1]\).
- Precyzja zależy od liczby iteracji CORDIC/Newtona i formatu Q; w testach błąd typowo \(< 10^{-8}\).
- Implementacja jest **symulacyjna / dydaktyczna** (GHDL); do FPGA dodałoby się ograniczenia zasobów i ewentualnie potokowanie.

---

## 12. Podsumowanie koncepcji w jednym akapicie

Projekt realizuje funkcje trygonometryczne na 128-bitowym fixed-point jako **procedurę sprzętową**: program główny wkłada argumenty do ustalonych komórek RAM i wywołuje podprogram; podprogram wybiera \(\sin\) (CORDIC + redukcja kąta) albo \(\arcsin\) (tożsamość z pierwiastkiem Newtona i \(\operatorname{arctan}\) CORDIC), zapisuje wynik z powrotem do pamięci i zgłasza zakończenie. Dzięki temu spełnione są wymagania treści zadania, a architektura pozostaje czytelna: pamięć jako interfejs, FSM jako sterowanie, CORDIC jako rdzeń numeryczny.
