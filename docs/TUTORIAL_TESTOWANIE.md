# Tutorial: jak przetestować Projekt 6 (cos / arccos w VHDL)

---

## 1. Co jest potrzebne

| Narzędzie | Do czego |
|-----------|----------|
| **GHDL** | kompilacja i symulacja VHDL |
| **Make** | wygodne komendy (`make sim`) |
| **git** | pobranie projektu |
| **GTKWave** *(opcjonalnie)* | podgląd przebiegów `.ghw` |

---

## 2. Pobranie projektu

```bash
git clone https://github.com/CzytelnyNick/ASKProj.git
cd ASKProj
git checkout cursor/projekt5-sin-arcsin-vhdl-88fc
```

> Nazwa brancha historyczna; zawartość to **Projekt 6** (cos/arccos).

---

## 3. Instalacja GHDL

```bash
# Ubuntu / Debian / WSL
sudo apt update
sudo apt install -y ghdl make
# opcjonalnie:
sudo apt install -y gtkwave
```

---

## 4. Najszybszy test

```bash
make sim
```

Oczekiwany sukces:

```text
==== Projekt 6 ASK: cos / arccos (128-bit Q4.124) ====
[TEST] cos(0)  ...
[TEST] arccos(0.5)  ...
==== Wszystkie testy zakonczone ====
```

bez `FAIL` / `assertion error`.

---

## 5. Co jest testowane?

| Funkcja | Argument | Oczekiwany wynik |
|---------|----------|------------------|
| cos | 0 | 1 |
| cos | π/6 | √3/2 |
| cos | π/4 | √2/2 |
| cos | π/3 | 0.5 |
| cos | π/2 | 0 |
| cos | π | −1 |
| cos | −π/3 | 0.5 |
| cos | 1.0 | cos(1) |
| arccos | 1 | 0 |
| arccos | 0.5 | π/3 |
| arccos | 0 | π/2 |
| arccos | −0.5 | 2π/3 |
| arccos | −1 | π |
| arccos | √2/2 | π/4 |

---

## 6. Własny test

W `vhdl/tb_main.vhd` w procesie `stim`:

```vhdl
run_case("cos(2)", OPCODE_COS, 2.0, cos(2.0), 1.0e-5,
         clk, go, demo_opcode, demo_arg, result_out, status_out, finished);

run_case("arccos(0.25)", OPCODE_ARCCOS, 0.25, arccos(0.25), 1.0e-4,
         clk, go, demo_opcode, demo_arg, result_out, status_out, finished);
```

Potem: `make sim`.

---

## 7. GTKWave (opcjonalnie)

```bash
gtkwave tb_main.ghw
```

Przydatne sygnały: `go`, `finished`, `demo_opcode`, `demo_arg`, `result_out`, `status_out`.

---

## 8. Mapa pamięci

| Adres | Komórka | Rola |
|------:|---------|------|
| 0 | OPCODE | 0 = cos, 1 = arccos |
| 1 | ARG | argument x |
| 2 | RESULT | wynik |
| 3 | STATUS | bit0=done, bit1=error, bit2=busy |

---

## 9. Checklista

- [ ] `make sim` bez FAIL
- [ ] W logu są testy **cos** i **arccos**
- [ ] Potrafisz wskazać: podprogram, pamięć, program główny
