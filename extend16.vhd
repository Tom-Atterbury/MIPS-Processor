-------------------------------------------------------------------------
-- Tom Atterbury
-- Department of Electrical and Computer Engineering
-- Iowa State University
-------------------------------------------------------------------------


-- extend16.vhd
-------------------------------------------------------------------------
-- DESCRIPTION: This file contains a behavioral model to extend both 
-- signed and unsigned 16-bit strings into 32-bit strings.
--
--
-- NOTES:
-- 10/01/2014 created.
-------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;

entity extend16 is
  port(i_Sign  : in  std_logic;
       i_16bit : in  std_logic_vector(15 downto 0);
       o_32bit : out std_logic_vector(31 downto 0));
end extend16;

architecture behavioral_16bit_extend of extend16 is
  
begin
  
  -- Copy the 16-bit string into the output 32-bit string
  cpy: for j in 0 to 15 generate
         o_32bit(j) <= i_16bit(j);
       end generate;
  
  -- Mask sign bit of 8-bit string with the un-/signed control bit
  ext: for i in 16 to 31 generate
         o_32bit(i) <= i_Sign and i_16bit(15);
       end generate;

end architecture behavioral_16bit_extend;
