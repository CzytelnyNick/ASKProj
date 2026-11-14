--------------------------------------------------------------------------------
-- Testbench – weryfikacja sin(x) i arcsin(x) (Projekt 5 ASK)
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
    signal demo_opcode : word128_t := (others => '0');
    signal demo_arg    : word128_t := (others => '0');
    signal result_out  : word128_t;
    signal status_out  : word128_t;
    signal finished    : std_logic;

    constant CLK_PERIOD : time := 10 ns;
    signal sim_done     : boolean := false;

    procedure pulse_go(
        signal go_s : out std_logic;
        signal clk_s : in std_logic
    ) is
    begin
        wait until rising_edge(clk_s);
        go_s <= '1';
        wait until rising_edge(clk_s);
        go_s <= '0';
    end procedure;

    procedure run_case(
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
        signal fin_s     : in std_logic
    ) is
        variable got   : real;
        variable diff  : real;
        variable L     : line;
    begin
        wait until rising_edge(clk_s);
        opc_s <= opcode;
        arg_s <= real_to_q124(arg_r);
        pulse_go(go_s, clk_s);

        wait until fin_s = '1' for 5 ms;
        assert fin_s = '1'
            report "TIMEOUT: " & name
            severity failure;

        wait until rising_edge(clk_s);
        got  := q124_to_real(res_s);
        diff := abs(got - expect);

        write(L, string'("[TEST] "));
        write(L, name);
        write(L, string'("  arg="));
        write(L, arg_r);
        write(L, string'("  got="));
        write(L, got);
        write(L, string'("  expect="));
        write(L, expect);
        write(L, string'("  |err|="));
        write(L, diff);
        writeline(output, L);

        assert diff <= tol
            report "FAIL: " & name & " error too large"
            severity error;

        -- Status bit0 (done) powinien być ustawiony; bit1 = error tylko poza domeną
        assert sts_s(0) = '1'
            report "FAIL: " & name & " STATUS.done not set"
            severity error;
    end procedure;

begin

    uut : entity work.main
        port map (
            clk         => clk,
            rst         => rst,
            go          => go,
            demo_opcode => demo_opcode,
            demo_arg    => demo_arg,
            result_out  => result_out,
            status_out  => status_out,
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

        write(L, string'("==== Projekt 5 ASK: sin / arcsin (128-bit Q4.124) ===="));
        writeline(output, L);

        ----------------------------------------------------------------
        -- sin(x)
        ----------------------------------------------------------------
        run_case("sin(0)", OPCODE_SIN, 0.0, 0.0, 1.0e-6,
                 clk, go, demo_opcode, demo_arg, result_out, status_out, finished);

        run_case("sin(pi/6)", OPCODE_SIN, MATH_PI / 6.0, 0.5, 1.0e-5,
                 clk, go, demo_opcode, demo_arg, result_out, status_out, finished);

        run_case("sin(pi/4)", OPCODE_SIN, MATH_PI / 4.0, sqrt(0.5), 1.0e-5,
                 clk, go, demo_opcode, demo_arg, result_out, status_out, finished);

        run_case("sin(pi/2)", OPCODE_SIN, MATH_PI / 2.0, 1.0, 1.0e-5,
                 clk, go, demo_opcode, demo_arg, result_out, status_out, finished);

        run_case("sin(pi)", OPCODE_SIN, MATH_PI, 0.0, 1.0e-4,
                 clk, go, demo_opcode, demo_arg, result_out, status_out, finished);

        run_case("sin(-pi/6)", OPCODE_SIN, -MATH_PI / 6.0, -0.5, 1.0e-5,
                 clk, go, demo_opcode, demo_arg, result_out, status_out, finished);

        run_case("sin(1.0)", OPCODE_SIN, 1.0, sin(1.0), 1.0e-5,
                 clk, go, demo_opcode, demo_arg, result_out, status_out, finished);

        ----------------------------------------------------------------
        -- arcsin(x)
        ----------------------------------------------------------------
        run_case("arcsin(0)", OPCODE_ARCSIN, 0.0, 0.0, 1.0e-5,
                 clk, go, demo_opcode, demo_arg, result_out, status_out, finished);

        run_case("arcsin(0.5)", OPCODE_ARCSIN, 0.5, MATH_PI / 6.0, 1.0e-4,
                 clk, go, demo_opcode, demo_arg, result_out, status_out, finished);

        run_case("arcsin(-0.5)", OPCODE_ARCSIN, -0.5, -MATH_PI / 6.0, 1.0e-4,
                 clk, go, demo_opcode, demo_arg, result_out, status_out, finished);

        run_case("arcsin(1)", OPCODE_ARCSIN, 1.0, MATH_PI / 2.0, 1.0e-6,
                 clk, go, demo_opcode, demo_arg, result_out, status_out, finished);

        run_case("arcsin(-1)", OPCODE_ARCSIN, -1.0, -MATH_PI / 2.0, 1.0e-6,
                 clk, go, demo_opcode, demo_arg, result_out, status_out, finished);

        run_case("arcsin(sqrt(2)/2)", OPCODE_ARCSIN, sqrt(0.5), MATH_PI / 4.0, 1.0e-4,
                 clk, go, demo_opcode, demo_arg, result_out, status_out, finished);

        write(L, string'("==== Wszystkie testy zakonczone ===="));
        writeline(output, L);

        sim_done <= true;
        wait;
    end process;

end architecture sim;
