--------------------------------------------------------------------------------
-- Program główny – wywołuje podprogram matematyczny przez pamięć operacyjną
-- Demonstracja: obliczenie sin(x) oraz arcsin(x) dla zadanego argumentu
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ask_types_pkg.all;
use work.cordic_pkg.all;

entity main is
    port (
        clk           : in  std_logic;
        rst           : in  std_logic;
        -- Sterowanie z testbencha / otoczenia
        go            : in  std_logic;
        -- Wybór demo: 0 = sin, 1 = arcsin (ładowane do pamięci przed startem)
        demo_opcode   : in  word128_t;
        demo_arg      : in  word128_t;
        -- Wyniki widoczne na zewnątrz
        result_out    : out word128_t;
        status_out    : out word128_t;
        finished      : out std_logic
    );
end entity main;

architecture rtl of main is

    type state_t is (
        ST_IDLE,
        ST_WR_OPCODE,
        ST_WR_ARG,
        ST_CALL,
        ST_WAIT,
        ST_RD_RESULT,
        ST_RD_STATUS,
        ST_FINISH
    );
    signal state : state_t := ST_IDLE;

    signal call_start : std_logic := '0';
    signal call_done  : std_logic;

    -- Port A (main) do pamięci
    signal a_we    : std_logic := '0';
    signal a_addr  : mem_addr_t := (others => '0');
    signal a_wdata : word128_t := (others => '0');
    signal a_rdata : word128_t;

    -- Port B (subprogram)
    signal b_we    : std_logic;
    signal b_addr  : mem_addr_t;
    signal b_wdata : word128_t;
    signal b_rdata : word128_t;

    signal result_r  : word128_t := (others => '0');
    signal status_r  : word128_t := (others => '0');
    signal finished_r: std_logic := '0';

begin

    result_out <= result_r;
    status_out <= status_r;
    finished   <= finished_r;

    u_mem : entity work.memory
        port map (
            clk     => clk,
            rst     => rst,
            a_we    => a_we,
            a_addr  => a_addr,
            a_wdata => a_wdata,
            a_rdata => a_rdata,
            b_we    => b_we,
            b_addr  => b_addr,
            b_wdata => b_wdata,
            b_rdata => b_rdata
        );

    u_sub : entity work.math_subprogram
        port map (
            clk       => clk,
            rst       => rst,
            start     => call_start,
            done      => call_done,
            mem_we    => b_we,
            mem_addr  => b_addr,
            mem_wdata => b_wdata,
            mem_rdata => b_rdata
        );

    process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state      <= ST_IDLE;
                a_we       <= '0';
                a_addr     <= (others => '0');
                a_wdata    <= (others => '0');
                call_start <= '0';
                result_r   <= (others => '0');
                status_r   <= (others => '0');
                finished_r <= '0';
            else
                a_we       <= '0';
                call_start <= '0';
                finished_r <= '0';

                case state is
                    when ST_IDLE =>
                        if go = '1' then
                            state <= ST_WR_OPCODE;
                        end if;

                    when ST_WR_OPCODE =>
                        a_we    <= '1';
                        a_addr  <= MEM_OPCODE;
                        a_wdata <= demo_opcode;
                        state   <= ST_WR_ARG;

                    when ST_WR_ARG =>
                        a_we    <= '1';
                        a_addr  <= MEM_ARG;
                        a_wdata <= demo_arg;
                        state   <= ST_CALL;

                    when ST_CALL =>
                        -- Wywołanie podprogramu
                        call_start <= '1';
                        state      <= ST_WAIT;

                    when ST_WAIT =>
                        if call_done = '1' then
                            a_addr <= MEM_RESULT;
                            state  <= ST_RD_RESULT;
                        end if;

                    when ST_RD_RESULT =>
                        result_r <= a_rdata;
                        a_addr   <= MEM_STATUS;
                        state    <= ST_RD_STATUS;

                    when ST_RD_STATUS =>
                        status_r <= a_rdata;
                        state    <= ST_FINISH;

                    when ST_FINISH =>
                        finished_r <= '1';
                        state      <= ST_IDLE;

                    when others =>
                        state <= ST_IDLE;
                end case;
            end if;
        end if;
    end process;

end architecture rtl;
