-------------------------------------------------------------------------
-- Tom Atterbury & Tyler Bennett
-- Department of Electrical and Computer Engineering
-- Iowa State University
-------------------------------------------------------------------------


-- mux2_1.vhd
-------------------------------------------------------------------------
-- DESCRIPTION: This file contains a structural implementation of a 2-to-1 
-- multiplexer.
--
--
-- NOTES:
-- 09/12/2014 created.
-------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use work.mips32.all;

entity mux2to1 is
  generic(M : Integer := 1);
  port(i_A : in  m32_vector(M-1 downto 0); 
       i_B : in  m32_vector(M-1 downto 0);
       i_S : in  m32_1bit;
       o_F : out m32_vector(M-1 downto 0));

end mux2to1;

architecture struct_mux of mux2to1 is

begin

  -- Select which string to pass on
  WITH i_S  SELECT
    o_F <= i_A WHEN '0',
           i_B WHEN OTHERS;
  
end struct_mux;