-------------------------------------------------------------------------
-- Tom Atterbury
-- Department of Electrical and Computer Engineering
-- Iowa State University
-------------------------------------------------------------------------


-- mux2_1.vhd
-------------------------------------------------------------------------
-- DESCRIPTION: This file contains a structural implementation of an
-- M-bit 4-to-1 multiplexer.
--
--
-- NOTES:
-- 12/11/2014 created.
-------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use work.mips32.all;

entity mux4to1 is
  generic(M : Integer := 1);
  port(i_A : in  m32_vector(M-1 downto 0); 
       i_B : in  m32_vector(M-1 downto 0);
       i_C : in  m32_vector(M-1 downto 0);
       i_D : in  m32_vector(M-1 downto 0);
       i_S : in  m32_2bits;
       o_F : out m32_vector(M-1 downto 0));
end mux4to1;

architecture mux of mux4to1 is

begin

  -- Select which string to pass on
  WITH i_S  SELECT
    o_F <= i_A WHEN "00",
           i_B WHEN "01",
           i_C WHEN "10",
           i_D WHEN OTHERS;
  
end mux;
