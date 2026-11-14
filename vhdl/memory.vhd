--------------------------------------------------------------------------------
-- Pamięć operacyjna – tablica słów 128-bitowych
-- Przez wybrane komórki przekazywane są argumenty i wyniki podprogramu
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ask_types_pkg.all;

entity memory is
    port (
        clk      : in  std_logic;
        rst      : in  std_logic;
        -- Port A: program główny / testbench
        a_we     : in  std_logic;
        a_addr   : in  mem_addr_t;
        a_wdata  : in  word128_t;
        a_rdata  : out word128_t;
        -- Port B: podprogram matematyczny
        b_we     : in  std_logic;
        b_addr   : in  mem_addr_t;
        b_wdata  : in  word128_t;
        b_rdata  : out word128_t
    );
end entity memory;

architecture rtl of memory is
    signal ram : mem_array_t := (others => (others => '0'));
begin

    a_rdata <= ram(to_integer(a_addr));
    b_rdata <= ram(to_integer(b_addr));

    process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                ram <= (others => (others => '0'));
            else
                if a_we = '1' then
                    ram(to_integer(a_addr)) <= a_wdata;
                end if;
                if b_we = '1' then
                    -- Port B ma priorytet przy kolizji (podprogram kończy zapis wyniku)
                    ram(to_integer(b_addr)) <= b_wdata;
                end if;
            end if;
        end if;
    end process;

end architecture rtl;
