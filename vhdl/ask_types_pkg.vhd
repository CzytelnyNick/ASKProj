--------------------------------------------------------------------------------
-- Projekt 6 ASK 2024/2025
-- Pakiet typów, mapy pamięci i kodów błędów
-- Format danych: signed fixed-point Q4.124 (128 bitów)
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

    constant MEM_ADDR_WIDTH : integer := 4;
    constant MEM_DEPTH      : integer := 16;
    subtype mem_addr_t is unsigned(MEM_ADDR_WIDTH - 1 downto 0);

    ----------------------------------------------------------------
    -- Mapa komórek pamięci operacyjnej
    ----------------------------------------------------------------
    constant MEM_OPCODE  : mem_addr_t := to_unsigned(0, MEM_ADDR_WIDTH);
    -- 0 = cos(x), 1 = arccos(x)
    constant MEM_ARG     : mem_addr_t := to_unsigned(1, MEM_ADDR_WIDTH);
    constant MEM_RESULT  : mem_addr_t := to_unsigned(2, MEM_ADDR_WIDTH);
    constant MEM_STATUS  : mem_addr_t := to_unsigned(3, MEM_ADDR_WIDTH);
    -- STATUS: bit0=done, bit1=error, bit2=busy
    constant MEM_ERRCODE : mem_addr_t := to_unsigned(4, MEM_ADDR_WIDTH);
    -- szczegółowy kod błędu (patrz ERR_* poniżej)

    constant OPCODE_COS    : word128_t := to_signed(0, DATA_WIDTH);
    constant OPCODE_ARCCOS : word128_t := to_signed(1, DATA_WIDTH);

    ----------------------------------------------------------------
    -- STATUS (bity w słowie MEM_STATUS)
    ----------------------------------------------------------------
    constant ST_IDLE_VAL  : word128_t := to_signed(0, DATA_WIDTH);
    constant ST_BUSY_VAL  : word128_t := to_signed(4, DATA_WIDTH);  -- bit2
    constant ST_DONE_VAL  : word128_t := to_signed(1, DATA_WIDTH);  -- bit0
    constant ST_ERROR_VAL : word128_t := to_signed(3, DATA_WIDTH);  -- done+error

    ----------------------------------------------------------------
    -- Kody błędów (MEM_ERRCODE) – główny mechanizm diagnostyki
    ----------------------------------------------------------------
    constant ERR_OK         : word128_t := to_signed(0, DATA_WIDTH);
    -- Brak błędu
    constant ERR_BAD_OPCODE : word128_t := to_signed(1, DATA_WIDTH);
    -- Nieznany OPCODE (różny od 0/1)
    constant ERR_DOMAIN     : word128_t := to_signed(2, DATA_WIDTH);
    -- arccos: |x| > 1 (poza dziedziną)
    constant ERR_BUSY       : word128_t := to_signed(3, DATA_WIDTH);
    -- Ponowne wywołanie podprogramu w trakcie pracy
    constant ERR_RANGE      : word128_t := to_signed(4, DATA_WIDTH);
    -- cos: argument poza bezpiecznym zakresem redukcji kąta
    constant ERR_INTERNAL   : word128_t := to_signed(5, DATA_WIDTH);
    -- Błąd wewnętrzny (np. ujemny argument pierwiastka)

    type mem_array_t is array (0 to MEM_DEPTH - 1) of word128_t;

    function real_to_q124(r : real) return word128_t;
    function q124_to_real(q : word128_t) return real;
    function mul_q124(a, b : word128_t) return word128_t;
    function abs_q124(a : word128_t) return word128_t;

    -- Czy STATUS oznacza błąd (bit1)
    function status_is_error(s : word128_t) return boolean;
    function status_is_done(s : word128_t) return boolean;

end package ask_types_pkg;

package body ask_types_pkg is

    function real_to_q124(r : real) return word128_t is
        variable scaled  : real;
        variable result  : word128_t;
        variable bit_val : real;
        variable neg     : boolean := false;
    begin
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

    function status_is_error(s : word128_t) return boolean is
    begin
        return s(1) = '1';
    end function;

    function status_is_done(s : word128_t) return boolean is
    begin
        return s(0) = '1';
    end function;

end package body ask_types_pkg;
