-------------------------------------------------------------------------
-- Zhao Zhang, Tom Atterbury
-- Department of Electrical and Computer Engineering
-- Iowa State University
-------------------------------------------------------------------------


-- tb_cpu.vhd
-------------------------------------------------------------------------
-- DESCRIPTION: This file contains a testbench for testing a 32-bit 
-- single cycle MIPS processor.
--
--
-- NOTES:
-- 10/21/2013 created.
-- 11/17/2014 Modified to increase total number of clock cycles to run
-------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use work.mips32.all;

entity tb_cpu is
end tb_cpu;

architecture behavior of tb_cpu is
  -- The cpu component
  component cpu is
    port (imem_addr   : out m32_word;     -- Instruction memory address
          inst        : in  m32_word;     -- Instruction
          dmem_addr   : out m32_word;     -- Data memory address
          dmem_read   : out m32_1bit;     -- Data memory read?
          dmem_write  : out m32_1bit;     -- Data memory write?
          dmem_wmask  : out m32_4bits;    -- Data memory write mask
          dmem_rdata  : in  m32_word;     -- Data memory read data
          dmem_wdata  : out m32_word;     -- Data memory write data
          reset       : in  m32_1bit;     -- Reset signal
          clock       : in  m32_1bit);    -- System clock
  end component;
  
  -- The memory component
  component mem is
    generic (
      depth_exp_of_2  : integer := 8;
      mif_filename    : string);
        port (address : in  m32_vector(7 downto 0);
              byteena : in  m32_vector(3 DOWNTO 0);
              clock	  : in  m32_1bit;
           	  data    : in  m32_word;
           	  wren	   : in  m32_1bit;
           	  q	      : out m32_word);      
  end component;
  
  -- The signals connected to CPU and memories
  signal imem_addr   : m32_word;     -- Instruction memory address
  signal inst        : m32_word;     -- Instruction
  signal dmem_addr   : m32_word;     -- Data memory address
  signal dmem_read   : m32_1bit;     -- Data memory read?
  signal dmem_write  : m32_1bit;     -- Data memory write?
  signal dmem_wmask  : m32_4bits;    -- Data memory write mask
  signal dmem_rdata  : m32_word;     -- Data memory read data
  signal dmem_wdata  : m32_word;     -- Data memory write data
  signal reset       : m32_1bit;     -- Reset signal
  signal clock       : m32_1bit;     -- System clock

begin
  -- The CPU
  CPU1 : cpu
    port map (imem_addr, inst, dmem_addr, dmem_read, dmem_write, dmem_wmask, dmem_rdata, dmem_wdata, reset, clock);
      
  -- The instruction memory. Note that write mask is hard-wired to 0000,
  -- write-enable is '0', and write data is 0.
  INST_MEM : mem
    generic map (mif_filename => "imem.txt")
    port map (imem_addr(9 downto 2), "0000", clock, x"00000000", '0', inst);
      
  -- The data memory. Note that the write mask is hard wired to 1111, and
  -- both data and q are connected to dmem_data
  DATA_MEM : mem
    generic map (mif_filename => "dmem.txt")
    port map (dmem_addr(9 downto 2), dmem_wmask, clock, dmem_wdata, dmem_write, dmem_rdata);
      
  -- Produce a clock signal whose rising edge happens at 
  -- the beginging of CCT. Report signals right before
  -- the end of a clock cycle
  CLOCK_SIGNAL : process 
    variable cycle : integer := 0;
  begin
    -- High for half cycle
    clock <= '1';
    wait for HCT;

    -- Low for half cycle
    clock <= '0';
    wait for HCT*4/5;    

    -- Debug: Print all signal values right before the rising edge
    report integer'image(cycle) & " " & hex(imem_addr) & 
      " " & hex(inst) & " " & hex (dmem_addr) & " " & 
      hex(dmem_rdata) & " " & hex(dmem_wdata);
    cycle := cycle + 1;
    wait for HCT*1/5;
  end process;
  
  TEST : process
  begin
    -- Wait for a small delay so that signal changes happen right before 
    -- the clock rising edge
    wait for 0.1*CCT;
    
    -- Reset the processor
    reset <= '1';
    wait for CCT;
    reset <= '0';
    
    -- Run for five clock cycles
    wait for 470*CCT;
    
    -- Force the simulation to stop
    assert false report "Simulation ends" severity failure;
  end process;

end behavior;

