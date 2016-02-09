-------------------------------------------------------------------------
-- Zhao Zhang
-- Department of Electrical and Computer Engineering
-- Iowa State University
-------------------------------------------------------------------------


-- regfile.vhd
-------------------------------------------------------------------------
-- DESCRIPTION: This file contains an implementation of a register file
-- for a 32-bit MIPS processor.
--
--
-- NOTES:
-- 10/21/2014 created.
-------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.mips32.all;

entity regfile is
  port(src1   : in  m32_5bits;
       src2   : in  m32_5bits;
       dst    : in  m32_5bits;
       wdata  : in  m32_word;
       rdata1 : out m32_word;
       rdata2 : out m32_word;
       WE     : in  m32_1bit;
       reset  : in  m32_1bit;
       clock  : in  m32_1bit);
end regfile;

architecture behavior of regfile is
  signal reg_array : m32_regval_array;
begin
  -- Register reset/write logic, guarded by clock rising edge
  P_WRITE : process (clock)
    variable r : integer;
  begin
    -- Write/reset logic
    if (falling_edge(clock)) then
      if (reset = '1') then
        for i in 0 to 31 loop
          reg_array(i) <= X"00000000";
        end loop;
      elsif (WE = '1') then
        r := to_integer(unsigned(dst));
        if not (r = 0) then         -- MIPS $0 stores 0
          reg_array(r) <= wdata;
        end if;
      end if;
    end if;
  end process;
  
  -- Register read logic 
  P_READ : process (reg_array, src1, src2)
    variable r1, r2 : integer;
  begin
    r1 := to_integer(unsigned(src1));
    r2 := to_integer(unsigned(src2));
    rdata1 <= reg_array(r1);
    rdata2 <= reg_array(r2);
  end process;
end behavior;

