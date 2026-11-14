--------------------------------------------------------------------------------
-- Testbench Projekt 6 – nacisk na testy błędów
-- Sekcje:
--   A) błędy (domena, OPCODE, zakres, BUSY)
--   B) poprawne cos / arccos (regresja)
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use std.textio.all;
use work.ask_types_pkg.all;
use work.cordic_pkg.all;

entity tb_main is
end entity tb_main;

architecture sim of tb_main is

    signal clk         : std_logic := '0';
    signal rst         : std_logic := '1';
    signal go          : std_logic := '0';
    signal go_busy     : std_logic := '0';
    signal demo_opcode : word128_t := (others => '0');
    signal demo_arg    : word128_t := (others => '0');
    signal result_out  : word128_t;
    signal status_out  : word128_t;
    signal errcode_out : word128_t;
    signal finished    : std_logic;

    constant CLK_PERIOD : time := 10 ns;
    signal sim_done     : boolean := false;

    procedure pulse_go(
        signal go_s  : out std_logic;
        signal clk_s : in  std_logic
    ) is
    begin
        wait until rising_edge(clk_s);
        go_s <= '1';
        wait until rising_edge(clk_s);
        go_s <= '0';
    end procedure;

    procedure run_ok(
        constant name    : in string;
        constant opcode  : in word128_t;
        constant arg_r   : in real;
        constant expect  : in real;
        constant tol     : in real;
        signal clk_s     : in std_logic;
        signal go_s      : out std_logic;
        signal opc_s     : out word128_t;
        signal arg_s     : out word128_t;
        signal res_s     : in word128_t;
        signal sts_s     : in word128_t;
        signal err_s     : in word128_t;
        signal fin_s     : in std_logic
    ) is
        variable got  : real;
        variable diff : real;
        variable L    : line;
    begin
        wait until rising_edge(clk_s);
        opc_s <= opcode;
        arg_s <= real_to_q124(arg_r);
        pulse_go(go_s, clk_s);

        wait until fin_s = '1' for 5 ms;
        assert fin_s = '1' report "TIMEOUT OK: " & name severity failure;
        wait until rising_edge(clk_s);

        got  := q124_to_real(res_s);
        diff := abs(got - expect);

        write(L, string'("[OK]    "));
        write(L, name);
        write(L, string'("  got="));
        write(L, got);
        write(L, string'("  expect="));
        write(L, expect);
        write(L, string'("  |err|="));
        write(L, diff);
        write(L, string'("  ERRCODE="));
        write(L, integer'image(to_integer(err_s(7 downto 0))));
        writeline(output, L);

        assert diff <= tol
            report "FAIL OK-path: " & name & " bad result"
            severity error;
        assert status_is_done(sts_s) and (not status_is_error(sts_s))
            report "FAIL OK-path: " & name & " STATUS should be DONE without ERROR"
            severity error;
        assert err_s = ERR_OK
            report "FAIL OK-path: " & name & " ERRCODE should be 0"
            severity error;
    end procedure;

    procedure run_err(
        constant name       : in string;
        constant opcode     : in word128_t;
        constant arg_r      : in real;
        constant expect_code: in word128_t;
        signal clk_s        : in std_logic;
        signal go_s         : out std_logic;
        signal opc_s        : out word128_t;
        signal arg_s        : out word128_t;
        signal res_s        : in word128_t;
        signal sts_s        : in word128_t;
        signal err_s        : in word128_t;
        signal fin_s        : in std_logic
    ) is
        variable L : line;
    begin
        wait until rising_edge(clk_s);
        opc_s <= opcode;
        arg_s <= real_to_q124(arg_r);
        pulse_go(go_s, clk_s);

        wait until fin_s = '1' for 5 ms;
        assert fin_s = '1' report "TIMEOUT ERR: " & name severity failure;
        wait until rising_edge(clk_s);

        write(L, string'("[ERROR] "));
        write(L, name);
        write(L, string'("  arg="));
        write(L, arg_r);
        write(L, string'("  STATUS=0x"));
        write(L, to_hstring(sts_s(7 downto 0)));
        write(L, string'("  ERRCODE="));
        write(L, integer'image(to_integer(err_s(7 downto 0))));
        write(L, string'("  expect_code="));
        write(L, integer'image(to_integer(expect_code(7 downto 0))));
        write(L, string'("  RESULT="));
        write(L, q124_to_real(res_s));
        writeline(output, L);

        assert status_is_done(sts_s)
            report "FAIL ERR: " & name & " STATUS.done not set"
            severity error;
        assert status_is_error(sts_s)
            report "FAIL ERR: " & name & " STATUS.error not set"
            severity error;
        assert err_s = expect_code
            report "FAIL ERR: " & name & " wrong ERRCODE"
            severity error;
        assert res_s = Q_ZERO
            report "FAIL ERR: " & name & " RESULT should be 0 on error"
            severity error;
    end procedure;

begin

    uut : entity work.main
        port map (
            clk         => clk,
            rst         => rst,
            go          => go,
            go_busy     => go_busy,
            demo_opcode => demo_opcode,
            demo_arg    => demo_arg,
            result_out  => result_out,
            status_out  => status_out,
            errcode_out => errcode_out,
            finished    => finished
        );

    clk <= not clk after CLK_PERIOD / 2 when not sim_done else '0';

    stim : process
        variable L : line;
    begin
        rst <= '1';
        wait for 50 ns;
        rst <= '0';
        wait for 20 ns;

        write(L, string'("==== Projekt 6: TESTY BLEDOW (priorytet) ===="));
        writeline(output, L);

        ----------------------------------------------------------------
        -- A1. ERR_DOMAIN – arccos poza [-1,1]
        ----------------------------------------------------------------
        run_err("arccos(+1.1) DOMAIN", OPCODE_ARCCOS, 1.1, ERR_DOMAIN,
                clk, go, demo_opcode, demo_arg, result_out, status_out, errcode_out, finished);

        run_err("arccos(-1.1) DOMAIN", OPCODE_ARCCOS, -1.1, ERR_DOMAIN,
                clk, go, demo_opcode, demo_arg, result_out, status_out, errcode_out, finished);

        run_err("arccos(+2.0) DOMAIN", OPCODE_ARCCOS, 2.0, ERR_DOMAIN,
                clk, go, demo_opcode, demo_arg, result_out, status_out, errcode_out, finished);

        run_err("arccos(-2.0) DOMAIN", OPCODE_ARCCOS, -2.0, ERR_DOMAIN,
                clk, go, demo_opcode, demo_arg, result_out, status_out, errcode_out, finished);

        run_err("arccos(+7.0) DOMAIN", OPCODE_ARCCOS, 7.0, ERR_DOMAIN,
                clk, go, demo_opcode, demo_arg, result_out, status_out, errcode_out, finished);

        ----------------------------------------------------------------
        -- A2. ERR_BAD_OPCODE – nieznana operacja
        ----------------------------------------------------------------
        run_err("opcode=2 BAD_OPCODE", to_signed(2, 128), 0.5, ERR_BAD_OPCODE,
                clk, go, demo_opcode, demo_arg, result_out, status_out, errcode_out, finished);

        run_err("opcode=99 BAD_OPCODE", to_signed(99, 128), 0.0, ERR_BAD_OPCODE,
                clk, go, demo_opcode, demo_arg, result_out, status_out, errcode_out, finished);

        run_err("opcode=-1 BAD_OPCODE", to_signed(-1, 128), 0.25, ERR_BAD_OPCODE,
                clk, go, demo_opcode, demo_arg, result_out, status_out, errcode_out, finished);

        ----------------------------------------------------------------
        -- A3. ERR_RANGE – cos z |arg| > 7
        ----------------------------------------------------------------
        run_err("cos(+7.5) RANGE", OPCODE_COS, 7.5, ERR_RANGE,
                clk, go, demo_opcode, demo_arg, result_out, status_out, errcode_out, finished);

        run_err("cos(-7.5) RANGE", OPCODE_COS, -7.5, ERR_RANGE,
                clk, go, demo_opcode, demo_arg, result_out, status_out, errcode_out, finished);

        ----------------------------------------------------------------
        -- A4. ERR_BUSY – drugie wywołanie w trakcie pracy
        ----------------------------------------------------------------
        write(L, string'("[ERROR] cos BUSY - drugie go w trakcie obliczen"));
        writeline(output, L);

        wait until rising_edge(clk);
        demo_opcode <= OPCODE_COS;
        demo_arg    <= real_to_q124(1.0);
        wait until rising_edge(clk);
        go <= '1';
        wait until rising_edge(clk);
        go <= '0';

        -- Poczekaj aż podprogram na pewno jest zajęty, potem drugie start
        wait for 200 ns;
        wait until rising_edge(clk);
        go_busy <= '1';
        wait until rising_edge(clk);
        go_busy <= '0';

        wait until finished = '1' for 5 ms;
        assert finished = '1' report "TIMEOUT ERR_BUSY" severity failure;
        wait until rising_edge(clk);

        write(L, string'("[ERROR] cos BUSY  STATUS=0x"));
        write(L, to_hstring(status_out(7 downto 0)));
        write(L, string'("  ERRCODE="));
        write(L, integer'image(to_integer(errcode_out(7 downto 0))));
        writeline(output, L);

        assert status_is_error(status_out)
            report "FAIL ERR_BUSY: STATUS.error not set"
            severity error;
        assert errcode_out = ERR_BUSY
            report "FAIL ERR_BUSY: expected ERRCODE=3"
            severity error;
        assert result_out = Q_ZERO
            report "FAIL ERR_BUSY: RESULT should be 0"
            severity error;

        ----------------------------------------------------------------
        -- A5. Granice dziedziny OK (nie błąd): arccos(±1)
        ----------------------------------------------------------------
        write(L, string'("==== Granice dziedziny (OK, nie blad) ===="));
        writeline(output, L);

        run_ok("arccos(+1) edge", OPCODE_ARCCOS, 1.0, 0.0, 1.0e-6,
               clk, go, demo_opcode, demo_arg, result_out, status_out, errcode_out, finished);
        run_ok("arccos(-1) edge", OPCODE_ARCCOS, -1.0, MATH_PI, 1.0e-6,
               clk, go, demo_opcode, demo_arg, result_out, status_out, errcode_out, finished);

        ----------------------------------------------------------------
        -- B. Regresja – poprawne wyniki
        ----------------------------------------------------------------
        write(L, string'("==== Regresja cos / arccos (sciezka OK) ===="));
        writeline(output, L);

        run_ok("cos(0)", OPCODE_COS, 0.0, 1.0, 1.0e-5,
               clk, go, demo_opcode, demo_arg, result_out, status_out, errcode_out, finished);
        run_ok("cos(pi/3)", OPCODE_COS, MATH_PI / 3.0, 0.5, 1.0e-5,
               clk, go, demo_opcode, demo_arg, result_out, status_out, errcode_out, finished);
        run_ok("cos(pi)", OPCODE_COS, MATH_PI, -1.0, 1.0e-5,
               clk, go, demo_opcode, demo_arg, result_out, status_out, errcode_out, finished);
        run_ok("arccos(0.5)", OPCODE_ARCCOS, 0.5, MATH_PI / 3.0, 1.0e-4,
               clk, go, demo_opcode, demo_arg, result_out, status_out, errcode_out, finished);
        run_ok("arccos(0)", OPCODE_ARCCOS, 0.0, MATH_PI / 2.0, 1.0e-4,
               clk, go, demo_opcode, demo_arg, result_out, status_out, errcode_out, finished);
        run_ok("arccos(-0.5)", OPCODE_ARCCOS, -0.5, 2.0 * MATH_PI / 3.0, 1.0e-4,
               clk, go, demo_opcode, demo_arg, result_out, status_out, errcode_out, finished);

        write(L, string'("==== Testy bledow i regresji zakonczone ===="));
        writeline(output, L);

        sim_done <= true;
        wait;
    end process;

end architecture sim;
