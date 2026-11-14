# Model błędów – Projekt 6 (cos / arccos)

Obsługa błędów jest **centralną częścią** projektu: każdy niepoprawny przypadek kończy się kontrolowanym statusem w pamięci, bez „wiszącego” podprogramu.

---

## Komórki pamięci związane z błędami

| Adres | Nazwa | Znaczenie |
|------:|-------|-----------|
| 2 | `MEM_RESULT` | wynik; przy błędzie zawsze **0** |
| 3 | `MEM_STATUS` | bit0=`done`, bit1=`error`, bit2=`busy` |
| 4 | `MEM_ERRCODE` | szczegółowy **kod błędu** |

Przy sukcesie: `STATUS = DONE (1)`, `ERRCODE = 0`.  
Przy błędzie: `STATUS = DONE+ERROR (3)`, `ERRCODE ≠ 0`, `RESULT = 0`.

---

## Kody błędów (`MEM_ERRCODE`)

| Kod | Stała | Kiedy |
|----:|-------|-------|
| 0 | `ERR_OK` | brak błędu |
| 1 | `ERR_BAD_OPCODE` | OPCODE inny niż 0 (cos) / 1 (arccos) |
| 2 | `ERR_DOMAIN` | `arccos(x)` dla \|x\| > 1 |
| 3 | `ERR_BUSY` | ponowne wywołanie podprogramu w trakcie pracy |
| 4 | `ERR_RANGE` | `cos(x)` dla \|x\| > 7 (poza bezpiecznym zakresem Q4.124) |
| 5 | `ERR_INTERNAL` | niespójność wewnętrzna (np. 1−x² < 0) |

---

## Gdzie wykrywane są błędy

```text
main
  └─ math_subprogram
        ├─ ERR_BAD_OPCODE   (dispatch)
        ├─ ERR_BUSY         (start w trakcie FSM ≠ IDLE)
        ├─ cos_unit
        │     └─ ERR_RANGE  (|arg| > 7 lub redukcja kąta nie zbiega)
        └─ arccos_unit
              ├─ ERR_DOMAIN (|arg| > 1)
              └─ ERR_INTERNAL (1-x^2 < 0)
```

---

## Protokół przy błędzie

1. Podprogram ustawia `STATUS=BUSY`.
2. Wykrywa warunek błędny.
3. Zapisuje `RESULT=0`.
4. Zapisuje `ERRCODE=<kod>`.
5. Zapisuje `STATUS=DONE|ERROR` (wartość 3).
6. Impuls `done` → program główny odczytuje RESULT, STATUS, ERRCODE.

---

## Testy (priorytet: błędy)

Uruchomienie: `.\sim.bat` (Windows) lub `make sim`.

Sekcja `[ERROR]` w logu obejmuje m.in.:

- `arccos(±1.1)`, `arccos(±2)`, `arccos(7)` → `ERR_DOMAIN`
- `OPCODE=2/99/-1` → `ERR_BAD_OPCODE`
- `cos(±7.5)` → `ERR_RANGE`
- drugie wywołanie w trakcie `cos` → `ERR_BUSY`

Granice `arccos(±1)` **nie są błędami** (zwracają `0` / `π`).
