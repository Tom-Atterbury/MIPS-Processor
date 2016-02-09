-------------------------------------------------------------------------
-- Unknown Author, Tom Atterbury
-- Department of Electrical and Computer Engineering
-- Iowa State University
-------------------------------------------------------------------------


-- alu.vhd
-------------------------------------------------------------------------
-- DESCRIPTION: This file contains an implementation of a 32-bit ALU.
--
--
-- NOTES:
-- 10/18/2013 created.
-- 11/18/2014 Modified to add SLL capability
-------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.mips32.all;

entity ALU is
  port (rdata1      : in  m32_word;
        rdata2      : in  m32_word;
        alu_code    : in  m32_4bits;
        result      : out m32_word;
        zero        : out m32_1bit);
end entity;

architecture behavior of ALU is
  signal r  : m32_word;
  signal sl : m32_word;
  signal z  : m32_word := "00000000000000000000000000000000";
begin
  P_ALU : process (alu_code, rdata1, rdata2)
    variable code, a, b, sum, diff, slt: integer;
  begin
    -- Pre-calculate arithmetic results
    a := to_integer(signed(rdata1));
    b := to_integer(signed(rdata2));
    sum := a + b;
    diff := a - b;
    if (a < b) then 
      slt := 1; 
    else 
      slt := 0;
    end if;
       
    -- Select the result, convert to signal if necessary
    case (alu_code) is
      when "0000" =>      -- AND
        r <= rdata1 AND rdata2;
      when "0001" =>      -- OR
        r <= rdata1 OR rdata2;
      when "0010" =>      -- add
        r <= std_logic_vector(to_signed(sum, 32));
      when "0110" =>      -- subtract
        r <= std_logic_vector(to_signed(diff, 32));
      when "0111" =>      -- slt
        r <= std_logic_vector(to_unsigned(slt, 32));
	  when "1000" =>      -- SLL
        r <= to_stdlogicvector(to_bitvector(rdata2) sll a);
      when "1100" =>      -- NOR
        r <= rdata1 NOR rdata2;
      when others =>      -- Otherwise, make output to be 0
        r <= (others => '0');
    end case;
  end process;
  
  -- Drive the alu result output
  result <= r;
  
  -- Drive the zero output
  with r select
    zero <= '1' when x"00000000",
 
          '0' when others;
end behavior;
