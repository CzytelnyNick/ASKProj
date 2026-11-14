--------------------------------------------------------------------------------
-- Podprogram obliczeniowy (subroutine) – wywoływany z programu głównego
--
-- Interfejs przez pamięć operacyjną (zgodnie z wymaganiem projektu):
--   MEM_OPCODE  – 0 = cos(x), 1 = arccos(x)
--   MEM_ARG     – argument 128-bit (Q4.124)
--   MEM_RESULT  – wynik 128-bit (Q4.124)
--   MEM_STATUS  – status (busy / done / error)
--
-- Protokół wywołania:
--   1. Program główny zapisuje OPCODE i ARG
--   2. Program główny ustawia start='1' na 1 takt
--   3. Podprogram ustawia STATUS=BUSY, czyta pamięć, liczy, zapisuje RESULT
--   4. Podprogram ustawia STATUS=DONE (lub ERROR) i done='1'
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ask_types_pkg.all;
use work.cordic_pkg.all;

entity math_subprogram is
    port (
        clk      : in  std_logic;
        rst      : in  std_logic;
        start    : in  std_logic;
        done     : out std_logic;
        mem_we   : out std_logic;
        mem_addr : out mem_addr_t;
        mem_wdata: out word128_t;
        mem_rdata: in  word128_t
    );
end entity math_subprogram;

architecture rtl of math_subprogram is

    type state_t is (
        ST_IDLE,
        ST_SET_BUSY,
        ST_RD_OPCODE,
        ST_RD_ARG,
        ST_DISPATCH,
        ST_COS_START,
        ST_COS_WAIT,
        ST_ARCCOS_START,
        ST_ARCCOS_WAIT,
        ST_WR_RESULT,
        ST_WR_STATUS,
        ST_DONE
    );
    signal state : state_t := ST_IDLE;

    signal opcode_r  : word128_t := (others => '0');
    signal arg_r     : word128_t := (others => '0');
    signal result_r  : word128_t := (others => '0');
    signal err_flag  : std_logic := '0';

    signal cos_start     : std_logic := '0';
    signal cos_done      : std_logic;
    signal cos_busy      : std_logic;
    signal cos_result    : word128_t;

    signal arccos_start  : std_logic := '0';
    signal arccos_done   : std_logic;
    signal arccos_busy   : std_logic;
    signal arccos_err    : std_logic;
    signal arccos_result : word128_t;

    signal done_r        : std_logic := '0';
    signal mem_we_r      : std_logic := '0';
    signal mem_addr_r    : mem_addr_t := (others => '0');
    signal mem_wdata_r   : word128_t := (others => '0');

begin

    done      <= done_r;
    mem_we    <= mem_we_r;
    mem_addr  <= mem_addr_r;
    mem_wdata <= mem_wdata_r;

    u_cos : entity work.cos_unit
        port map (
            clk    => clk,
            rst    => rst,
            start  => cos_start,
            arg_in => arg_r,
            result => cos_result,
            done   => cos_done,
            busy   => cos_busy
        );

    u_arccos : entity work.arccos_unit
        port map (
            clk    => clk,
            rst    => rst,
            start  => arccos_start,
            arg_in => arg_r,
            result => arccos_result,
            done   => arccos_done,
            busy   => arccos_busy,
            err    => arccos_err
        );

    process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state        <= ST_IDLE;
                done_r       <= '0';
                mem_we_r     <= '0';
                mem_addr_r   <= (others => '0');
                mem_wdata_r  <= (others => '0');
                opcode_r     <= (others => '0');
                arg_r        <= (others => '0');
                result_r     <= (others => '0');
                err_flag     <= '0';
                cos_start    <= '0';
                arccos_start <= '0';
            else
                mem_we_r     <= '0';
                cos_start    <= '0';
                arccos_start <= '0';
                done_r       <= '0';

                case state is
                    when ST_IDLE =>
                        if start = '1' then
                            state <= ST_SET_BUSY;
                        end if;

                    when ST_SET_BUSY =>
                        mem_we_r    <= '1';
                        mem_addr_r  <= MEM_STATUS;
                        mem_wdata_r <= ST_BUSY_VAL;
                        state       <= ST_RD_OPCODE;

                    when ST_RD_OPCODE =>
                        mem_addr_r <= MEM_OPCODE;
                        state      <= ST_RD_ARG;

                    when ST_RD_ARG =>
                        opcode_r   <= mem_rdata;
                        mem_addr_r <= MEM_ARG;
                        state      <= ST_DISPATCH;

                    when ST_DISPATCH =>
                        arg_r <= mem_rdata;
                        if opcode_r = OPCODE_COS then
                            state <= ST_COS_START;
                        elsif opcode_r = OPCODE_ARCCOS then
                            state <= ST_ARCCOS_START;
                        else
                            err_flag <= '1';
                            result_r <= Q_ZERO;
                            state    <= ST_WR_RESULT;
                        end if;

                    when ST_COS_START =>
                        cos_start <= '1';
                        state     <= ST_COS_WAIT;

                    when ST_COS_WAIT =>
                        if cos_done = '1' then
                            result_r <= cos_result;
                            err_flag <= '0';
                            state    <= ST_WR_RESULT;
                        end if;

                    when ST_ARCCOS_START =>
                        arccos_start <= '1';
                        state        <= ST_ARCCOS_WAIT;

                    when ST_ARCCOS_WAIT =>
                        if arccos_done = '1' then
                            result_r <= arccos_result;
                            err_flag <= arccos_err;
                            state    <= ST_WR_RESULT;
                        end if;

                    when ST_WR_RESULT =>
                        mem_we_r    <= '1';
                        mem_addr_r  <= MEM_RESULT;
                        mem_wdata_r <= result_r;
                        state       <= ST_WR_STATUS;

                    when ST_WR_STATUS =>
                        mem_we_r   <= '1';
                        mem_addr_r <= MEM_STATUS;
                        if err_flag = '1' then
                            mem_wdata_r <= ST_ERROR_VAL;
                        else
                            mem_wdata_r <= ST_DONE_VAL;
                        end if;
                        state <= ST_DONE;

                    when ST_DONE =>
                        done_r <= '1';
                        state  <= ST_IDLE;

                    when others =>
                        state <= ST_IDLE;
                end case;
            end if;
        end if;
    end process;

end architecture rtl;
