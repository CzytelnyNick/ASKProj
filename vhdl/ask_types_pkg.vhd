--------------------------------------------------------------------------------
-- Projekt 6 ASK 2024/2025
-- Pakiet typów i mapy pamięci operacyjnej
-- Format danych: signed fixed-point Q4.124 (128 bitów)
--   bit 127      – znak
--   bity 126..124 – część całkowita (3 bity)
--   bity 123..0   – część ułamkowa (124 bity)
-- Wartość = interpretacja_całkowita / 2^124
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package ask_types_pkg is

    constant DATA_WIDTH    : integer := 128;
    constant FRAC_BITS     : integer := 124;
    constant INT_BITS      : integer := DATA_WIDTH - FRAC_BITS;  -- 4
    constant CORDIC_ITERS  : integer := 64;

    subtype word128_t is signed(DATA_WIDTH - 1 downto 0);
    subtype uword128_t is unsigned(DATA_WIDTH - 1 downto 0);

    -- Szerokość adresu pamięci operacyjnej (słowa 128-bitowe)
    constant MEM_ADDR_WIDTH : integer := 4;
    constant MEM_DEPTH      : integer := 16;
    subtype mem_addr_t is unsigned(MEM_ADDR_WIDTH - 1 downto 0);

    ----------------------------------------------------------------
    -- Mapa komórek pamięci operacyjnej (interfejs podprogramu)
    ----------------------------------------------------------------
    constant MEM_OPCODE  : mem_addr_t := to_unsigned(0, MEM_ADDR_WIDTH);
    -- 0 = cos(x), 1 = arccos(x)
    constant MEM_ARG     : mem_addr_t := to_unsigned(1, MEM_ADDR_WIDTH);
    constant MEM_RESULT  : mem_addr_t := to_unsigned(2, MEM_ADDR_WIDTH);
    constant MEM_STATUS  : mem_addr_t := to_unsigned(3, MEM_ADDR_WIDTH);
    -- STATUS: bit0=done, bit1=error (domena / NaN), bit2=busy

    constant OPCODE_COS    : word128_t := to_signed(0, DATA_WIDTH);
    constant OPCODE_ARCCOS : word128_t := to_signed(1, DATA_WIDTH);

    constant ST_IDLE_VAL  : word128_t := to_signed(0, DATA_WIDTH);
    constant ST_BUSY_VAL  : word128_t := to_signed(4, DATA_WIDTH);  -- bit2
    constant ST_DONE_VAL  : word128_t := to_signed(1, DATA_WIDTH);  -- bit0
    constant ST_ERROR_VAL : word128_t := to_signed(3, DATA_WIDTH);  -- done+error

    -- Typ tablicy pamięci
    type mem_array_t is array (0 to MEM_DEPTH - 1) of word128_t;

    -- Funkcje pomocnicze konwersji (symulacja / testbench)
    function real_to_q124(r : real) return word128_t;
    function q124_to_real(q : word128_t) return real;

    -- Mnożenie Q4.124 * Q4.124 -> Q4.124
    function mul_q124(a, b : word128_t) return word128_t;

    -- Wartość bezwzględna
    function abs_q124(a : word128_t) return word128_t;

end package ask_types_pkg;

package body ask_types_pkg is

    function real_to_q124(r : real) return word128_t is
        variable scaled  : real;
        variable result  : word128_t;
        variable bit_val : real;
        variable neg     : boolean := false;
    begin
        -- Skalowanie bit po bicie (unikanie przepełnienia integer 32-bit)
        scaled := r;
        result := (others => '0');
        if scaled < 0.0 then
            neg    := true;
            scaled := -scaled;
        end if;
        for i in DATA_WIDTH - 2 downto 0 loop
            bit_val := real(2.0 ** (i - FRAC_BITS));
            if scaled >= bit_val then
                result(i) := '1';
                scaled := scaled - bit_val;
            end if;
        end loop;
        if neg then
            result := -result;
        end if;
        return result;
    end function;

    function q124_to_real(q : word128_t) return real is
        variable result : real := 0.0;
        variable neg    : boolean := false;
        variable v      : word128_t;
    begin
        v := q;
        if v(DATA_WIDTH - 1) = '1' then
            neg := true;
            v := -v;
        end if;
        for i in DATA_WIDTH - 2 downto 0 loop
            if v(i) = '1' then
                result := result + real(2.0 ** (i - FRAC_BITS));
            end if;
        end loop;
        if neg then
            result := -result;
        end if;
        return result;
    end function;

    function mul_q124(a, b : word128_t) return word128_t is
        variable prod : signed(2 * DATA_WIDTH - 1 downto 0);
    begin
        prod := a * b;
        -- Iloczyn ma 2*FRAC bitów ułamkowych; bierzemy Q4.124
        return prod(FRAC_BITS + DATA_WIDTH - 1 downto FRAC_BITS);
    end function;

    function abs_q124(a : word128_t) return word128_t is
    begin
        if a(DATA_WIDTH - 1) = '1' then
            return -a;
        else
            return a;
        end if;
    end function;

end package body ask_types_pkg;
