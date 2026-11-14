# Tutorial: jak przetestować Projekt 5 (sin / arcsin w VHDL)

Ten poradnik przeprowadza Cię od zera: instalacja narzędzi → uruchomienie testów → odczyt wyników → własne przypadki testowe → podgląd fal (opcjonalnie).

---

## 1. Co jest potrzebne

| Narzędzie | Do czego |
|-----------|----------|
| **GHDL** | kompilacja i symulacja VHDL |
| **Make** | wygodne komendy (`make sim`) |
| **git** | pobranie projektu |
| **GTKWave** *(opcjonalnie)* | podgląd przebiegów `.ghw` |

Projekt jest napisany w **VHDL-2008**.

---

## 2. Pobranie projektu

```bash
git clone https://github.com/CzytelnyNick/ASKProj.git
cd ASKProj

# jeśli testujesz branch z PR:
git checkout cursor/projekt5-sin-arcsin-vhdl-88fc
```

Struktura ważna do testów:

```
ASKProj/
├── Makefile              ← komendy build/sim
├── vhdl/
│   ├── … jednostki …
│   └── tb_main.vhd       ← testbench (tu są testy)
└── docs/
```

---

## 3. Instalacja GHDL

### Ubuntu / Debian / WSL

```bash
sudo apt update
sudo apt install -y ghdl make
ghdl --version
```

### macOS (Homebrew)

```bash
brew install ghdl
```

### Windows

Najwygodniej: **WSL2 (Ubuntu)** i instalacja jak wyżej.  
Albo GHDL z [wydania GitHub](https://github.com/ghdl/ghdl/releases) + MinGW.

### Opcjonalnie: GTKWave (fale)

```bash
# Ubuntu/Debian/WSL
sudo apt install -y gtkwave
```

---

## 4. Najszybszy test (zalecane)

Z katalogu głównego repo:

```bash
make sim
```

To kolejno:

1. **analizuje** wszystkie pliki `.vhd` (`ghdl -a`)
2. **elaboruje** testbench `tb_main` (`ghdl -e`)
3. **uruchamia** symulację (`ghdl -r`) i zapisuje fale do `tb_main.ghw`

### Oczekiwany wynik (sukces)

Na końcu powinieneś zobaczyć coś w stylu:

```text
==== Projekt 5 ASK: sin / arcsin (128-bit Q4.124) ====
[TEST] sin(0)  arg=0.0  got=...  expect=0.0  |err|=...
[TEST] sin(pi/6)  ...
...
[TEST] arcsin(sqrt(2)/2)  ...
==== Wszystkie testy zakonczone ====
```

Jeśli któryś test padnie, GHDL wypisze `assertion error` / `FAIL: ...` i zakończy się kodem ≠ 0.

> Ostrzeżenie `NUMERIC_STD.TO_INTEGER: metavalue detected` przy `@0ms` jest nieszkodliwe (stan początkowy przed resetem).

---

## 5. Komendy krok po kroku (bez Make)

Przydatne, gdy chcesz zrozumieć, co robi Makefile:

```bash
mkdir -p work

# 1) Analiza (kompilacja do biblioteki work/)
ghdl -a --std=08 -frelaxed --workdir=work \
  vhdl/ask_types_pkg.vhd \
  vhdl/cordic_pkg.vhd \
  vhdl/sin_unit.vhd \
  vhdl/sqrt_unit.vhd \
  vhdl/atan_unit.vhd \
  vhdl/arcsin_unit.vhd \
  vhdl/memory.vhd \
  vhdl/math_subprogram.vhd \
  vhdl/main.vhd \
  vhdl/tb_main.vhd

# 2) Elaboracja testbencha
ghdl -e --std=08 -frelaxed --workdir=work tb_main

# 3) Symulacja (+ zapis fal)
ghdl -r --std=08 -frelaxed --workdir=work tb_main --wave=tb_main.ghw
```

Sprzątanie:

```bash
make clean
# albo:
rm -rf work tb_main.ghw
```

---

## 6. Co właściwie jest testowane?

Testbench `vhdl/tb_main.vhd` emuluje „program główny”:

1. Zapisuje do pamięci **OPCODE** (`0` = sin, `1` = arcsin) i **ARG**
2. Daje impuls `go` → `main` wywołuje **podprogram**
3. Podprogram liczy i zapisuje **RESULT** / **STATUS**
4. Testbench porównuje wynik z wartością oczekiwaną (`sin`/`arcsin` z `ieee.math_real`)

### Lista wbudowanych przypadków

| Funkcja | Argument | Oczekiwany wynik |
|---------|----------|------------------|
| sin | 0 | 0 |
| sin | π/6 | 0.5 |
| sin | π/4 | √2/2 |
| sin | π/2 | 1 |
| sin | π | 0 |
| sin | −π/6 | −0.5 |
| sin | 1.0 | sin(1) |
| arcsin | 0 | 0 |
| arcsin | ±0.5 | ±π/6 |
| arcsin | ±1 | ±π/2 |
| arcsin | √2/2 | π/4 |

Tolerancje są ustawione w testbenchu (np. `1e-5` dla sin, `1e-4` dla arcsin).

---

## 7. Jak dodać własny test

Otwórz `vhdl/tb_main.vhd` i w procesie `stim` dopisz wywołanie `run_case`, np.:

```vhdl
-- sin(2)  ≈  0.909297...
run_case("sin(2)", OPCODE_SIN, 2.0, sin(2.0), 1.0e-5,
         clk, go, demo_opcode, demo_arg, result_out, status_out, finished);

-- arcsin(0.25)
run_case("arcsin(0.25)", OPCODE_ARCSIN, 0.25, arcsin(0.25), 1.0e-4,
         clk, go, demo_opcode, demo_arg, result_out, status_out, finished);
```

Parametry `run_case`:

1. nazwa testu (string),
2. `OPCODE_SIN` albo `OPCODE_ARCSIN`,
3. argument jako `real`,
4. wartość oczekiwana jako `real`,
5. tolerancja błędu,
6. sygnały (zostaw jak w innych wywołaniach).

Potem:

```bash
make sim
```

### Test błędu domeny arcsin

Dla \(|x| > 1\) podprogram ustawia status błędu. Możesz dodać osobny przypadek sprawdzający `status_out(1) = '1'` (bit error) — obecnie wbudowane testy sprawdzają głównie poprawne wyniki w domenie.

---

## 8. Podgląd fal w GTKWave (opcjonalnie)

Po `make sim` powstaje plik `tb_main.ghw`:

```bash
gtkwave tb_main.ghw
```

W oknie GTKWave:

1. Po lewej rozwiń hierarchię: `tb_main` → `uut` (main) → …
2. Przydatne sygnały do przeciągnięcia:
   - `go`, `finished`
   - `demo_opcode`, `demo_arg`, `result_out`, `status_out`
   - w `u_sub`: stany FSM podprogramu
   - w `u_sin` / `u_arcsin`: `start`, `done`, `result`
3. Zoom na impuls `go` i czekaj aż `finished` = 1 — wtedy wynik jest gotowy.

---

## 9. Jak czytać wynik 128-bitowy ręcznie

Format: **signed Q4.124**

\[
\text{wartość} = \frac{\text{liczba całkowita signed 128-bit}}{2^{124}}
\]

Przykłady stałych z `cordic_pkg.vhd`:

| Stała | Hex (skrót) | Znaczenie |
|-------|-------------|-----------|
| `Q_ONE` | `0x1000…0` | 1.0 |
| `Q_HALF_PI` | `0x1921FB54…` | π/2 |
| `OPCODE_SIN` | `0` | wybór sin |
| `OPCODE_ARCSIN` | `1` | wybór arcsin |

W testbenchu konwersję robią funkcje:

- `real_to_q124(r)` – float → Q4.124  
- `q124_to_real(q)` – Q4.124 → float  

---

## 10. Mapa pamięci (przypomnienie protokołu)

| Adres | Komórka | Rola |
|------:|---------|------|
| 0 | OPCODE | 0 = sin, 1 = arcsin |
| 1 | ARG | argument x |
| 2 | RESULT | wynik |
| 3 | STATUS | bit0=done, bit1=error, bit2=busy |

Przepływ:

```text
main zapisuje OPCODE+ARG → start podprogramu
       → STATUS=BUSY → obliczenia → RESULT → STATUS=DONE
main czyta RESULT i STATUS → finished=1
```

---

## 11. Typowe problemy

| Objaw | Przyczyna / rozwiązanie |
|-------|-------------------------|
| `ghdl: command not found` | Zainstaluj GHDL (`apt install ghdl`) |
| błąd składni / `no declaration` | Upewnij się, że pliki są w kolejności z Makefile; użyj `--std=08` |
| `TIMEOUT` w teście | Symulacja nie doszła do `finished` — sprawdź reset/`go`, albo zwiększ limit w `tb_main` |
| `FAIL: ... error too large` | Zła wartość / za ciasna tolerancja; sprawdź domenę arcsin \(\|x\|\le 1\) |
| wolna symulacja | Normalne przy 128-bitowym dzieleniu (Newton); wbudowane testy i tak kończą się szybko |

---

## 12. Checklista przed oddaniem

- [ ] `make sim` kończy się bez `FAIL` / `assertion error`
- [ ] Widać w logu zarówno testy **sin**, jak i **arcsin**
- [ ] Potrafisz wskazać w kodzie: podprogram, pamięć, program główny
- [ ] (Opcjonalnie) Masz screenshot / log z `make sim` do sprawozdania

Powodzenia!
