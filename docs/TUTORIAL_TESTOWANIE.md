# Tutorial: jak przetestować Projekt 6 (cos / arccos w VHDL) na Windows

---

## 1. Co jest potrzebne

| Narzędzie | Do czego |
|-----------|----------|
| **GHDL** | kompilacja i symulacja VHDL |
| **Git** | pobranie projektu |
| **GTKWave** *(opcjonalnie)* | podgląd przebiegów `.ghw` |

Na Windows **nie musisz** mieć `make` — poniżej są gotowe komendy oraz skrypt `sim.bat`.

---

## 2. Instalacja na Windows

### Krok A – Git

1. Pobierz [Git for Windows](https://git-scm.com/download/win).
2. Zainstaluj (domyślne opcje są OK).
3. Otwórz **PowerShell** lub **Git Bash** i sprawdź:

```powershell
git --version
```

### Krok B – GHDL na Windows (bez instalatora `.exe`)

GHDL **nie ma klasycznego setup.exe**. Na Windows pobierasz **ZIP** i dodajesz `bin` do PATH.

#### Bezpośredni link (zalecane)

Strona wydań: https://github.com/ghdl/ghdl/releases/latest  

Pobierz jeden z plików Windows (scroll w dół do **Assets**):

| Plik | Link bezpośredni |
|------|------------------|
| **mingw64** (najczęściej ten) | https://github.com/ghdl/ghdl/releases/download/v6.0.0/ghdl-mcode-6.0.0-mingw64.zip |
| ucrt64 (alternatywa) | https://github.com/ghdl/ghdl/releases/download/v6.0.0/ghdl-mcode-6.0.0-ucrt64.zip |

> Na liście Assets jest dużo plików Linux/macOS (`.tar.gz`). Szukaj końcówki **`.zip`** i nazwy z `mingw64` albo `ucrt64`.

#### Instalacja krok po kroku

1. Pobierz `ghdl-mcode-6.0.0-mingw64.zip`.
2. Rozpakuj np. do `C:\ghdl\`  
   (wewnątrz powinien być katalog `bin` z `ghdl.exe`).
3. Dodaj do PATH katalog `bin`, np. `C:\ghdl\bin`  
   (jeśli po rozpakowaniu masz `C:\ghdl\ghdl-mcode-...\bin`, dodaj właśnie tę ścieżkę).

Jak dodać PATH w Windows 10/11:

1. Start → wpisz **Zmienne środowiskowe** → *Edytuj zmienne środowiskowe systemowe*
2. *Zmienne środowiskowe…* → w *Zmienne użytkownika* wybierz `Path` → *Edytuj*
3. *Nowy* → wklej ścieżkę do `bin` GHDL → OK
4. **Zamknij i otwórz ponownie** PowerShell:

```powershell
ghdl --version
```

#### Alternatywa: Scoop

```powershell
scoop install ghdl
ghdl --version
```

#### Alternatywa: MSYS2

1. Zainstaluj [MSYS2](https://www.msys2.org/).
2. W terminalu **UCRT64**:

```bash
pacman -S mingw-w64-ucrt-x86_64-ghdl-mcode
```

Dodaj do PATH: `C:\msys64\ucrt64\bin`.

### Krok C – GTKWave (opcjonalnie)

1. Pobierz GTKWave na Windows (np. z https://gtkwave.sourceforge.net/ albo paczki Mirrored/MSYS2).
2. Albo przez MSYS2:

```bash
pacman -S mingw-w64-ucrt-x86_64-gtkwave
```

3. Sprawdź:

```powershell
gtkwave --version
```

---

## 3. Pobranie projektu

W PowerShell / Git Bash:

```powershell
git clone https://github.com/CzytelnyNick/ASKProj.git
cd ASKProj
git checkout cursor/projekt5-sin-arcsin-vhdl-88fc
```

> Nazwa brancha jest historyczna; zawartość to **Projekt 6** (cos/arccos).

---

## 4. Uruchomienie testów

### Sposób 1 – skrypt Windows (najprostszy)

W katalogu projektu (CMD lub PowerShell):

```powershell
.\sim.bat
```

### Sposób 2 – komendy GHDL ręcznie

```powershell
mkdir work -Force

ghdl -a --std=08 -frelaxed --workdir=work `
  vhdl/ask_types_pkg.vhd `
  vhdl/cordic_pkg.vhd `
  vhdl/cos_unit.vhd `
  vhdl/sqrt_unit.vhd `
  vhdl/atan_unit.vhd `
  vhdl/arccos_unit.vhd `
  vhdl/memory.vhd `
  vhdl/math_subprogram.vhd `
  vhdl/main.vhd `
  vhdl/tb_main.vhd

ghdl -e --std=08 -frelaxed --workdir=work tb_main
ghdl -r --std=08 -frelaxed --workdir=work tb_main --wave=tb_main.ghw
```

W **CMD** (bez backticków) użyj jednej linii albo `^` jako kontynuacji.

### Sposób 3 – Make (jeśli masz)

Jeśli zainstalujesz Make (np. przez Scoop: `scoop install make`, albo Git Bash / MSYS2):

```powershell
make sim
```

---

## 5. Oczekiwany wynik (sukces)

```text
==== Projekt 6 ASK: cos / arccos (128-bit Q4.124) ====
[TEST] cos(0)  ...
[TEST] arccos(0.5)  ...
==== Wszystkie testy zakonczone ====
```

bez `FAIL` / `assertion error`.

Ostrzeżenie `NUMERIC_STD.TO_INTEGER: metavalue detected` przy starcie można zignorować.

---

## 6. Co jest testowane?

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

## 7. Własny test

W `vhdl/tb_main.vhd` w procesie `stim` dopisz np.:

```vhdl
run_case("cos(2)", OPCODE_COS, 2.0, cos(2.0), 1.0e-5,
         clk, go, demo_opcode, demo_arg, result_out, status_out, finished);

run_case("arccos(0.25)", OPCODE_ARCCOS, 0.25, arccos(0.25), 1.0e-4,
         clk, go, demo_opcode, demo_arg, result_out, status_out, finished);
```

Potem znowu:

```powershell
.\sim.bat
```

---

## 8. Podgląd fal w GTKWave

Po udanej symulacji powstaje `tb_main.ghw`:

```powershell
gtkwave tb_main.ghw
```

Przydatne sygnały: `go`, `finished`, `demo_opcode`, `demo_arg`, `result_out`, `status_out`.

---

## 9. Mapa pamięci

| Adres | Komórka | Rola |
|------:|---------|------|
| 0 | OPCODE | 0 = cos, 1 = arccos |
| 1 | ARG | argument x |
| 2 | RESULT | wynik |
| 3 | STATUS | bit0=done, bit1=error, bit2=busy |

---

## 10. Typowe problemy na Windows

| Objaw | Rozwiązanie |
|-------|-------------|
| `ghdl` nie jest rozpoznawane | PATH nieustawiony / nieotwarto nowego terminala |
| `.\sim.bat` zablokowany | PowerShell: `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` nie jest potrzebne dla `.bat`; uruchom z CMD albo `.\sim.bat` |
| błędy z backslash / ścieżkami | Pracuj w katalogu projektu; Git Bash też działa |
| brak `make` | Użyj `sim.bat` — Make nie jest wymagany |

---

## 11. Checklista

- [ ] `ghdl --version` działa
- [ ] `.\sim.bat` kończy się bez FAIL
- [ ] W logu są testy **cos** i **arccos**
- [ ] Potrafisz wskazać: podprogram, pamięć, program główny
