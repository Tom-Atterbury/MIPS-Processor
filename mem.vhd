-------------------------------------------------------------------------
-- Justin Rilling
-- Department of Electrical and Computer Engineering
-- Iowa State University
-------------------------------------------------------------------------


-- mem.vhd
-------------------------------------------------------------------------
-- DESCRIPTION: This file contains a behavioral model of a generic memory 
-- 
--
--
-- NOTES:
-- 10/10/10 by JRR::Design created.
-------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;
use std.textio.all;

entity mem is
	generic(depth_exp_of_2 	: integer := 10;
      mif_filename 	: string := "mem.mif");
	port   (address			: IN STD_LOGIC_VECTOR (depth_exp_of_2-1 DOWNTO 0) := (OTHERS => '0');
      byteena			: IN STD_LOGIC_VECTOR (3 DOWNTO 0) := (OTHERS => '1');
			clock			: IN STD_LOGIC := '1';
			data			: IN STD_LOGIC_VECTOR (31 DOWNTO 0) := (OTHERS => '0');
			wren			: IN STD_LOGIC := '0';
			q				: OUT STD_LOGIC_VECTOR (31 DOWNTO 0));         
end entity mem;

architecture behavioral of mem is

	constant MAX_STRING_LENGTH : integer := 200;
	constant MAX_STRINGS_PER_LIST : integer := 100;
	constant MEM_DEPTH : integer := 2**depth_exp_of_2;

	type int_array is array (natural range <>) of integer;
	type slv_1Darray is array (natural range <>) of std_logic_vector(31 downto 0);
	type slv_2Darray is array (natural range <>) of slv_1Darray(MEM_DEPTH-1 downto 0);
	type read_mif_state is (SET_ATTRIBUTES, CHECK_FOR_BEGIN, MEM_INIT, CHECK_FOR_SEMICOLON, END_OF_MEM_INIT);
	type set_attr_state is (INDENTIFY_ATTRIBUTE, CHECK_FOR_EQUALS, SET_ATTRIBUTE, CHECK_FOR_SEMICOLON);
	type init_mem_state is (DET_INIT_METHOD, M1_SET_START_ADDR, M1_CHECK_FOR_DOUBLE_PERIOD, M1_SET_STOP_ADDR, M1_CHECK_FOR_RIGHT_BRACKET, M1_CHECK_FOR_COLON, M1_SET_INIT_VAL, M1_CHECK_FOR_SEMICOLON, M2_CHECK_FOR_COLON, M2_SET_INIT_VAL, M2_SET_NEXT_INIT_VAL);
	type keyword_tag is (DEPTH, WIDTH, ADDRESS_RADIX, DATA_RADIX, BIN, DEC, HEX, OCT, UNS, CONTENT, BEGIN_INIT, END_INIT, UNKNOWN_KEYWORD);

	type int is 
		record
			val : integer;
			valid : boolean;
	end record;
	
	type str is 
		record
			val : string(1 to MAX_STRING_LENGTH);
			alt_val : string(1 to MAX_STRING_LENGTH);
			length : integer;
			tag : keyword_tag;
	end record;
	
	type str_array is array (natural range <>) of str;
	
	type str_list is 
		record 
			element : str_array(MAX_STRINGS_PER_LIST downto 0);
			size : integer;
	end record;
	
	type attributes is 
		record 
			depth : integer;
			width : integer;
			addr_radix : str;
			data_radix : str;
	end record;
	
	function identify_keyword (input_str: str) return keyword_tag is 

		variable known_keywords: str_list;
		variable i,j : integer := 0;
		variable keyword_identified : boolean := false;
		
		begin

			-- define "DEPTH" keyword
			known_keywords.element(0).val(1 to 5) := "DEPTH";
			known_keywords.element(0).alt_val(1 to 5) := "depth";
			known_keywords.element(0).length := 5;
			known_keywords.element(0).tag := DEPTH;
			
			-- define "WIDTH" keyword
			known_keywords.element(1).val(1 to 5) := "WIDTH";
			known_keywords.element(1).alt_val(1 to 5) := "width";
			known_keywords.element(1).length := 5;
			known_keywords.element(1).tag := WIDTH;
						
			-- define "ADDRESS_RADIX" keyword
			known_keywords.element(2).val(1 to 13) := "ADDRESS_RADIX";
			known_keywords.element(2).alt_val(1 to 13) := "address_radix";
			known_keywords.element(2).length := 13;
			known_keywords.element(2).tag := ADDRESS_RADIX;
			
			-- define "DATA_RADIX" keyword
			known_keywords.element(3).val(1 to 10) := "DATA_RADIX";
			known_keywords.element(3).alt_val(1 to 10) := "data_radix";
			known_keywords.element(3).length := 10;
			known_keywords.element(3).tag := DATA_RADIX;

			-- define "BIN" keyword
			known_keywords.element(4).val(1 to 3) := "BIN";
			known_keywords.element(4).alt_val(1 to 3) := "bin";
			known_keywords.element(4).length := 3;
			known_keywords.element(4).tag := BIN;
			
			-- define "DEC" keyword
			known_keywords.element(5).val(1 to 3) := "DEC";
			known_keywords.element(5).alt_val(1 to 3) := "dec";
			known_keywords.element(5).length := 3;
			known_keywords.element(5).tag := DEC;
			
			-- define "HEX" keyword
			known_keywords.element(6).val(1 to 3) := "HEX";
			known_keywords.element(6).alt_val(1 to 3) := "hex";
			known_keywords.element(6).length := 3;
			known_keywords.element(6).tag := HEX;
			
			-- define "OCT" keyword
			known_keywords.element(7).val(1 to 3) := "OCT";
			known_keywords.element(7).alt_val(1 to 3) := "oct";
			known_keywords.element(7).length := 3;
			known_keywords.element(7).tag := OCT;
			
			-- define "UNS" keyword
			known_keywords.element(8).val(1 to 3) := "UNS";
			known_keywords.element(8).alt_val(1 to 3) := "uns";
			known_keywords.element(8).length := 3;
			known_keywords.element(8).tag := UNS;
			
			-- define "CONTENT" keyword
			known_keywords.element(9).val(1 to 7) := "CONTENT";
			known_keywords.element(9).alt_val(1 to 7) := "content";
			known_keywords.element(9).length := 7;
			known_keywords.element(9).tag := CONTENT;
			
			-- define "BEGIN_INIT" keyword
			known_keywords.element(10).val(1 to 5) := "BEGIN";
			known_keywords.element(10).alt_val(1 to 5) := "begin";
			known_keywords.element(10).length := 5;
			known_keywords.element(10).tag := BEGIN_INIT;
			
			-- define "END_INIT" keyword
			known_keywords.element(11).val(1 to 3) := "END";
			known_keywords.element(11).alt_val(1 to 3) := "end";
			known_keywords.element(11).length := 3;
			known_keywords.element(11).tag := END_INIT;

			known_keywords.size := 12;
			
			while((i < known_keywords.size) and (keyword_identified = false)) loop 
            
				if(input_str.length = known_keywords.element(i).length) then

					keyword_identified := true;	
					
					for j in 1 to input_str.length loop
						if((known_keywords.element(i).val(j) /= input_str.val(j)) and (known_keywords.element(i).alt_val(j) /= input_str.val(j))) then 
							keyword_identified := false;
						end if; 
					end loop;
				end if;

				i := i + 1;

			end loop;
			
			if(keyword_identified = true) then 
				return known_keywords.element(i-1).tag;
			else
				return UNKNOWN_KEYWORD;
			end if; 

	end function;

	function identify_number (input_str : str; number_format : keyword_tag; signed_number : boolean) return int is 

		variable i,j : integer := 0;
		variable number_str : str;
		variable multiplier : integer;
		variable result : integer := 0;
		variable digit_found : boolean;
		variable negate_number : boolean := false;
		variable ret_val : int;
		
		begin

			ret_val.val := 0;
			ret_val.valid := false;
		
			if(number_format = HEX) then
				number_str.val(1 to 16) := "0123456789ABCDEF";
				number_str.alt_val(1 to 16) := "0123456789abcdef";
				number_str.length := 16;
				--if(input_str.length) > 8 then
				--	return ret_val;
				--end if;
			elsif(number_format = OCT) then
				number_str.val(1 to 8) := "01234567";
				number_str.length := 8;
				--if(input_str.length) > 11 then 
				--	return ret_val;
				--end if;
			elsif(number_format = BIN) then
				number_str.val(1 to 2) := "01";
				number_str.length := 2;
				--if(input_str.length) > 32 then 
				--	return ret_val;
				--end if;
			else
				number_str.val(1 to 10) := "0123456789";
				number_str.length := 10;
				--if(input_str.length) > 10 then 
				--	return ret_val;
				--end if;
			end if;
			
			multiplier := number_str.length;
			
			for i in 1 to input_str.length loop
			  
				digit_found := false;
			  
				if((i = 1) and (number_format = DEC) and (signed_number = true) and (input_str.val(i) = '-')) then
					negate_number := true;
				else
					for j in 1 to number_str.length loop
						if((input_str.val(i) = number_str.val(j)) or (input_str.val(i) = number_str.alt_val(j))) then 
							result := result*multiplier + j-1;
							digit_found := true;
						end if; 
					end loop;
				
					if((i = 1) and (signed_number = true)) then
						if((number_format = HEX) and (input_str.length = 8) and (result >= 8)) then 
							result := result - 16;
						elsif((number_format = OCT) and (input_str.length = 11) and (result >= 4)) then
							result := result - 8;
						elsif((number_format = BIN) and (input_str.length = 32)) then 		
							result := -result;
						end if;
					end if;
				
					if(digit_found = false) then
						return ret_val;
					end if;
				end if;
			end loop;
			
			ret_val.valid := true;
			
			if(negate_number = true) then
				ret_val.val := -result;
				return ret_val;
			else
				ret_val.val := result;
				return ret_val;
			end if;

	end function;

	function init_str_list return str_list is 

		variable i, j : integer;
		variable ret_val : str_list;
		
		begin

			ret_val.size := 0;
		
			for i in 0 to MAX_STRINGS_PER_LIST loop
				for j in 1 to MAX_STRING_LENGTH loop
					ret_val.element(i).val(j) := ' ';
					ret_val.element(i).alt_val(j) := ' ';
				end loop;
				ret_val.element(i).length := 0;
				ret_val.element(i).tag := UNKNOWN_KEYWORD;
			end loop;
		  	
			return ret_val;	
		  	
	end function;
	
	function init_attr return attributes is 

		variable ret_val : attributes;
		
		begin

			ret_val.depth := 1024;
			ret_val.width := 32;
			ret_val.addr_radix.val(1 to 3) := "HEX";
			ret_val.addr_radix.length := 3;
			ret_val.addr_radix.tag := HEX;
			ret_val.data_radix.val(1 to 3) := "HEX";
			ret_val.data_radix.length := 3;	
			ret_val.data_radix.tag := HEX;
		  	
			return ret_val;	
		  	
	end function;

	function init_mem return slv_1Darray is 

		variable ret_val : slv_1Darray(MEM_DEPTH-1 downto 0);
		variable i : integer;
		
		begin

			for i in ret_val'range loop
				ret_val(i) := x"00000000";
			end loop;
		  	
			return ret_val;	
		  	
	end function;
	
	function goto_next_element (input_str_list : str_list) return integer is 
		
		begin

			if(input_str_list.element(input_str_list.size).length /= 0) then
				return input_str_list.size + 1;
			else 
				return input_str_list.size;
			end if;
		  	
	end function;
	
	function is_char_valid (input_char : character) return boolean is 
		
		variable valid_char_list : string(1 to 93) := "!#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~";
		variable i : integer;
		
		begin
		
			for i in 1 to valid_char_list'high loop
				if(input_char = valid_char_list(i)) then 
					return true;
				end if;
			end loop;
			
			return false;
		  	
	end function;
	
	function parse_line (input_str: str) return str_list is 

		variable input_str_index : integer := 1; 
		variable tokens : str_list;

		begin

			tokens := init_str_list;
			
			while(input_str_index <= input_str.length) loop
			
				if(is_char_valid(input_str.val(input_str_index))) then  
			 
					if(input_str.val(input_str_index) = '%') then 
						return tokens;
				  
					elsif((input_str.val(input_str_index) = '-') and (input_str_index < input_str.length)) then
						if(input_str.val(input_str_index+1) = '-') then
							return tokens;
						else
							tokens.size := goto_next_element(tokens);
							tokens.element(tokens.size).val(1) := '-';
							tokens.element(tokens.size).length := 1;
						end if;
				  
					elsif((input_str.val(input_str_index) = '.') and (input_str_index < input_str.length)) then
						if(input_str.val(input_str_index+1) = '.') then
							tokens.size := goto_next_element(tokens);
							tokens.element(tokens.size).val(1 to 2) := "..";
							tokens.element(tokens.size).length := 2;
							tokens.size := goto_next_element(tokens);
							input_str_index := input_str_index + 1;
						else
							tokens.size := goto_next_element(tokens);
							tokens.element(tokens.size).val(1) := '.';
							tokens.element(tokens.size).length := 1;
						end if;
				  
					elsif((input_str.val(input_str_index) = '=') or (input_str.val(input_str_index) = ';') or (input_str.val(input_str_index) = ':') or (input_str.val(input_str_index) = '[') or (input_str.val(input_str_index) = ']')) then 
						tokens.size := goto_next_element(tokens);
						tokens.element(tokens.size).val(1) := input_str.val(input_str_index);
						tokens.element(tokens.size).length := 1;
						tokens.size := goto_next_element(tokens);
						
					else
						tokens.element(tokens.size).length := tokens.element(tokens.size).length + 1;
						tokens.element(tokens.size).val(tokens.element(tokens.size).length) := input_str.val(input_str_index);
					end if;
					
			    else
					tokens.size := goto_next_element(tokens);
				end if;
		
				input_str_index := input_str_index + 1;
		
			end loop;
		  	
			tokens.size := goto_next_element(tokens);
			
		return tokens;	
		  	
	end function;
	
	function str_cmp (input_str1 : str; input_str2 : str) return integer is 
		
		variable i : integer;
		
		begin 
		
			if(input_str1.length /= input_str2.length) then
				return -1;
			end if;
		
			for i in 1 to input_str1.length loop
				if(input_str1.val(i) /= input_str2.val(i)) then
					return -1;
				end if;
			end loop; 
			
			return 1; 
			
	end str_cmp;
	
	function is_signal_valid (input_slv : std_logic_vector) return boolean is 
		
		variable i : integer;
		
		begin 
			for i in 0 to input_slv'high loop
				if ((input_slv(i) /= '0') and (input_slv(i) /= '1')) then
					return false;
				end if;
			end loop;
			
			return true;
					
	end is_signal_valid;
	
	function resolution_function (constant input_slv2D: slv_2Darray) return slv_1Darray is 
		
		variable resolved_value: slv_1Darray(MEM_DEPTH-1 downto 0); 
		variable i, j : integer;
		
		begin 
			for i in resolved_value'range loop
				for j in input_slv2D'high downto 0 loop 
					if(is_signal_valid(input_slv2D(j)(i)) = true) then 
						resolved_value(i) := input_slv2D(j)(i);
						exit;
					end if;
				end loop;
			end loop; 
			
			return resolved_value; 
			
	end resolution_function; 

	signal mem : resolution_function slv_1Darray(MEM_DEPTH-1 downto 0);
	signal data_mask, write_data : std_logic_vector(31 downto 0);
	
begin
  
  q <= mem(conv_integer(address));
	
	G1 : for i in 0 to 7 generate
		write_data(i) <= data(i) and byteena(0);
		write_data(8+i) <= data(8+i) and byteena(1);
		write_data(16+i) <= data(16+i) and byteena(2);
		write_data(24+i) <= data(24+i) and byteena(3);
		data_mask(i) <= not byteena(0);
		data_mask(8+i) <= not byteena(1);
		data_mask(16+i) <= not byteena(2);
		data_mask(24+i) <= not byteena(3);
	end generate;
	
	memory: process(clock)
		begin
			if(clock'event and clock = '0') then
				if(wren = '1') then 
					mem(conv_integer(address)) <= (mem(conv_integer(address)) and data_mask) or write_data;
				end if;
			end if;
	end process memory;
	
	read_mif_file: process   
	  
		file mif_file: text;
		variable file_line: line;
		variable in_str : boolean;
		variable read_mif_mode : read_mif_state := SET_ATTRIBUTES;	
		variable set_attr_mode : set_attr_state := INDENTIFY_ATTRIBUTE; 
		variable mem_init_mode : init_mem_state := DET_INIT_METHOD;
		variable target_attribute : keyword_tag;
		variable temp_char : character;
		variable temp_line : str; 
		variable temp_keyword : keyword_tag;
		variable temp_num : int;
		variable line_tokens : str_list;
		variable line_tokens_index: integer;
		variable line_number : integer := 0;
		variable mem_addr, start_addr, stop_addr, init_value : integer;
		variable i : integer;  
		variable mem_attributes : attributes;	
		variable SEMICOLON : str;
		variable LEFT_BRACKET : str;
		variable DOUBLE_PERIOD : str;
		variable RIGHT_BRACKET : str;
		variable COLON : str;
		variable EQUALS : str;
		variable SIGNED_NUM : boolean;
		variable UNSIGNED_NUM : boolean;

		begin
		
			SEMICOLON.val(1) := ';';
			SEMICOLON.length := 1;
			LEFT_BRACKET.val(1) := '[';
			LEFT_BRACKET.length := 1;
			DOUBLE_PERIOD.val(1 to 2) := "..";
			DOUBLE_PERIOD.length := 2;
			RIGHT_BRACKET.val(1) := ']';
			RIGHT_BRACKET.length := 1;
			COLON.val(1) := ':';
			COLON.length := 1;
			EQUALS.val(1) := '=';
			EQUALS.length := 1;
			SIGNED_NUM := true;
			UNSIGNED_NUM := false;
		
			mem_attributes := init_attr;
			mem <= init_mem;	
	
			file_open(mif_file,mif_filename,READ_MODE);

			while (not endfile(mif_file)) loop

				readline (mif_file,file_line);
				line_number := line_number + 1;
				
				read (file_line,temp_char,in_str);
				temp_line.length := 0;
        
				while(in_str = true)loop
					temp_line.length := temp_line.length + 1;
					temp_line.val(temp_line.length) := temp_char; 
					read (file_line,temp_char,in_str); 
				end loop;
			
				line_tokens := parse_line(temp_line);
				line_tokens_index := 0;
		
				while(line_tokens_index < line_tokens.size) loop
		
					case(read_mif_mode) is 
					
						when SET_ATTRIBUTES =>     

							case(set_attr_mode) is

								when INDENTIFY_ATTRIBUTE => 
									
									temp_keyword := identify_keyword(line_tokens.element(line_tokens_index));
						
									if(temp_keyword = CONTENT) then
										read_mif_mode := CHECK_FOR_BEGIN;
									else
										if((temp_keyword /= DEPTH) and (temp_keyword /= WIDTH) and (temp_keyword /= ADDRESS_RADIX) and (temp_keyword /= DATA_RADIX)) then 
											report mif_filename & "(" & integer'image(line_number) & "): Unknown Attribute - '" & line_tokens.element(line_tokens_index).val(1 to line_tokens.element(line_tokens_index).length) & "'.  Valid attributes include: DEPTH, WIDTH, ADDRESS_RADIX and DATA_RADIX."		
											severity error;
											wait;
										end if;
										
										target_attribute := temp_keyword;
										set_attr_mode := CHECK_FOR_EQUALS;
									end if;

								when CHECK_FOR_EQUALS =>

									if(str_cmp(line_tokens.element(line_tokens_index),EQUALS) /= 1) then 
										report mif_filename & "(" & integer'image(line_number) & "): near '" & line_tokens.element(line_tokens_index).val(1 to line_tokens.element(line_tokens_index).length) & "': expecting '='."		
										severity error;
										wait;
									end if;
									
									set_attr_mode := SET_ATTRIBUTE;
								
								when SET_ATTRIBUTE =>
								
									if(target_attribute = DEPTH) then 
										
										temp_num := identify_number(line_tokens.element(line_tokens_index),DEC,UNSIGNED_NUM);
										
										if(temp_num.valid = false) then  
											report mif_filename & "(" & integer'image(line_number) & "): Invalid value - '" & line_tokens.element(line_tokens_index).val(1 to line_tokens.element(line_tokens_index).length) & "' for attribute 'DEPTH'.  Valid memory depths include any positive integer expressed in decimal notation." 
											severity error;
											wait;
										end if;
										
										mem_attributes.depth := temp_num.val;
										
									elsif(target_attribute = WIDTH) then 
									
										temp_num := identify_number(line_tokens.element(line_tokens_index),DEC,UNSIGNED_NUM);
										
										if(temp_num.valid = false) then 
											report mif_filename & "(" & integer'image(line_number) & "): Invalid value - '" & line_tokens.element(line_tokens_index).val(1 to line_tokens.element(line_tokens_index).length) & "' for attribute 'WIDTH'.  Valid memory widths include any positive integer expressed in decimal notation." 
											severity error;
											wait;
										end if;
										
										mem_attributes.width := temp_num.val;
										
									elsif(target_attribute = ADDRESS_RADIX) then
									
										temp_keyword := identify_keyword(line_tokens.element(line_tokens_index));
										
										if((temp_keyword /= BIN) and (temp_keyword /= DEC) and (temp_keyword /= HEX) and (temp_keyword /= OCT) and (temp_keyword /= UNS)) then  
											report mif_filename & "(" & integer'image(line_number) & "): Invalid value - '" & line_tokens.element(line_tokens_index).val(1 to line_tokens.element(line_tokens_index).length) & "' for attribute 'ADDRESS_RADIX'.  Valid address radices include: BIN, DEC, HEX, OCT and UNS." 
											severity error;
											wait;
										end if;
										
										mem_attributes.addr_radix.tag := temp_keyword;
										mem_attributes.addr_radix.val := line_tokens.element(line_tokens_index).val;
										mem_attributes.addr_radix.length := line_tokens.element(line_tokens_index).length;
										
									elsif(target_attribute = DATA_RADIX) then 
										
										temp_keyword := identify_keyword(line_tokens.element(line_tokens_index));
										
										if((temp_keyword /= BIN) and (temp_keyword /= DEC) and (temp_keyword /= HEX) and (temp_keyword /= OCT) and (temp_keyword /= UNS)) then 
											report mif_filename & "(" & integer'image(line_number) & "): Invalid value - '" & line_tokens.element(line_tokens_index).val(1 to line_tokens.element(line_tokens_index).length) & "' for attribute 'DATA_RADIX'.  Valid data radices include: BIN, DEC, HEX, OCT and UNS." 
											severity error;
											wait;
										end if;
										
										mem_attributes.data_radix.tag := temp_keyword;
										mem_attributes.data_radix.val := line_tokens.element(line_tokens_index).val;
										mem_attributes.data_radix.length := line_tokens.element(line_tokens_index).length;
										
									end if;
								
									set_attr_mode := CHECK_FOR_SEMICOLON;
								
								when CHECK_FOR_SEMICOLON =>

									if(str_cmp(line_tokens.element(line_tokens_index),SEMICOLON) /= 1) then
										report mif_filename & "(" & integer'image(line_number) & "): near '" & line_tokens.element(line_tokens_index).val(1 to line_tokens.element(line_tokens_index).length) & "': expecting ';'."		
										severity error;
										wait;
									end if;
									
									set_attr_mode := INDENTIFY_ATTRIBUTE;		
									
								when others =>

									set_attr_mode := INDENTIFY_ATTRIBUTE;

							end case;

						when CHECK_FOR_BEGIN =>

							if(identify_keyword(line_tokens.element(line_tokens_index)) /= BEGIN_INIT) then 
								report mif_filename & "(" & integer'image(line_number) & "): near '" & line_tokens.element(line_tokens_index).val(1 to line_tokens.element(line_tokens_index).length) & "': expecting 'BEGIN'."
								severity error;
								wait;
							end if;

							read_mif_mode := MEM_INIT;	

						when MEM_INIT =>

							case(mem_init_mode) is 

								when DET_INIT_METHOD => 
								
									temp_keyword := identify_keyword(line_tokens.element(line_tokens_index));
									temp_num := identify_number(line_tokens.element(line_tokens_index),mem_attributes.addr_radix.tag,UNSIGNED_NUM);
									
									if(temp_keyword = END_INIT) then 
										read_mif_mode := CHECK_FOR_SEMICOLON;
									else
										if(temp_num.valid = true) then
										  if((temp_num.val < 0) or (temp_num.val >= MEM_DEPTH)) then 
										    report mif_filename & "(" & integer'image(line_number) & "): Invalid value - '" & line_tokens.element(line_tokens_index).val(1 to line_tokens.element(line_tokens_index).length) & "' for first address of memory range.  Valid values include any non-negative integer (expressed in '" & mem_attributes.addr_radix.val(1 to 3) & "' notation) less than " & integer'image(MEM_DEPTH) & "."
										    severity error;
										    wait;
									    end if;
									    
											mem_addr := temp_num.val;
											mem_init_mode := M2_CHECK_FOR_COLON;
											
										elsif(str_cmp(line_tokens.element(line_tokens_index),LEFT_BRACKET) = 1) then
											mem_init_mode := M1_SET_START_ADDR;
										else
											report mif_filename & "(" & integer'image(line_number) & "): near '" & line_tokens.element(line_tokens_index).val(1 to line_tokens.element(line_tokens_index).length) & "': expecting valid memory address or '['.  Valid memory addresses include any non-negative integer (expressed in '" & mem_attributes.addr_radix.val(1 to 3) & "' notation) less than " & integer'image(MEM_DEPTH) & "."
											severity error;
											wait;
										end if;
									end if;
								
								when M1_SET_START_ADDR => 
									
									temp_num := identify_number(line_tokens.element(line_tokens_index),mem_attributes.addr_radix.tag,UNSIGNED_NUM);
									
									if((temp_num.valid = false) or (temp_num.val < 0) or (temp_num.val >= MEM_DEPTH)) then 
										report mif_filename & "(" & integer'image(line_number) & "): Invalid value - '" & line_tokens.element(line_tokens_index).val(1 to line_tokens.element(line_tokens_index).length) & "' for first address of memory range.  Valid values include any non-negative integer (expressed in '" & mem_attributes.addr_radix.val(1 to 3) & "' notation) less than " & integer'image(MEM_DEPTH) & "."
										severity error;
										wait;
									end if;
									
									start_addr := temp_num.val;
									mem_init_mode := M1_CHECK_FOR_DOUBLE_PERIOD;
									
								when M1_CHECK_FOR_DOUBLE_PERIOD => 
								
									if(str_cmp(line_tokens.element(line_tokens_index),DOUBLE_PERIOD) /= 1) then 
										report mif_filename & "(" & integer'image(line_number) & "): near '" & line_tokens.element(line_tokens_index).val(1 to line_tokens.element(line_tokens_index).length) & "': expecting '..'"
										severity error;
										wait;
									end if;
									
									mem_init_mode := M1_SET_STOP_ADDR;
									
								when M1_SET_STOP_ADDR => 
								
									temp_num := identify_number(line_tokens.element(line_tokens_index),mem_attributes.addr_radix.tag,UNSIGNED_NUM);
									
									if((temp_num.valid = false) or (temp_num.val < start_addr) or (temp_num.val >= MEM_DEPTH)) then 
										report mif_filename & "(" & integer'image(line_number) & "): Invalid value - '" & line_tokens.element(line_tokens_index).val(1 to line_tokens.element(line_tokens_index).length) & "' for last address of memory range.  Valid values include any integer (expressed in '" & mem_attributes.addr_radix.val(1 to 3) & "' notation) greater than or equal to " & integer'image(start_addr) & " and less than " & integer'image(MEM_DEPTH) & "."
										severity error;
										wait;
									end if;
									
									stop_addr := temp_num.val;
									mem_init_mode := M1_CHECK_FOR_RIGHT_BRACKET;					
								
								when M1_CHECK_FOR_RIGHT_BRACKET => 
								
									if(str_cmp(line_tokens.element(line_tokens_index),RIGHT_BRACKET) /= 1) then 
										report mif_filename & "(" & integer'image(line_number) & "): near '" & line_tokens.element(line_tokens_index).val(1 to line_tokens.element(line_tokens_index).length) & "': expecting ']'."
										severity error;
										wait;
									end if;
									
									mem_init_mode := M1_CHECK_FOR_COLON;
								
								when M1_CHECK_FOR_COLON => 
								
									if(str_cmp(line_tokens.element(line_tokens_index),COLON) /= 1) then  
										report mif_filename & "(" & integer'image(line_number) & "): near '" & line_tokens.element(line_tokens_index).val(1 to line_tokens.element(line_tokens_index).length) & "': expecting ':'."
										severity error;
										wait;
									end if;
									
									mem_init_mode := M1_SET_INIT_VAL;
								
								when M1_SET_INIT_VAL => 
								
									temp_num := identify_number(line_tokens.element(line_tokens_index),mem_attributes.data_radix.tag,SIGNED_NUM);
									
									if(temp_num.valid = false) then
										report mif_filename & "(" & integer'image(line_number) & "): Invalid value - '" & line_tokens.element(line_tokens_index).val(1 to line_tokens.element(line_tokens_index).length) & "' for memory data.  Valid values include any 32 bit integer expressed in '" & mem_attributes.data_radix.val(1 to 3) & "' notation."
										severity error;
										wait;
									end if;
									
									init_value := temp_num.val;
									mem_init_mode := M1_CHECK_FOR_SEMICOLON;
								
								when M1_CHECK_FOR_SEMICOLON => 
								
									if(str_cmp(line_tokens.element(line_tokens_index),SEMICOLON) /= 1) then  
										report mif_filename & "(" & integer'image(line_number) & "): near '" & line_tokens.element(line_tokens_index).val(1 to line_tokens.element(line_tokens_index).length) & "': expecting ';'."
										severity error;
										wait;
									end if;
									
									for i in start_addr to stop_addr loop
										mem(i) <= conv_std_logic_vector(init_value,32);
									end loop;
									
									mem_init_mode := DET_INIT_METHOD;
								
								when M2_CHECK_FOR_COLON => 
								
									if(str_cmp(line_tokens.element(line_tokens_index),COLON) /= 1) then  
										report mif_filename & "(" & integer'image(line_number) & "): near '" & line_tokens.element(line_tokens_index).val(1 to line_tokens.element(line_tokens_index).length) & "': expecting ':'."
										severity error;
										wait;
									end if;
									
									mem_init_mode := M2_SET_INIT_VAL;
									
								when M2_SET_INIT_VAL => 
								
									temp_num := identify_number(line_tokens.element(line_tokens_index),mem_attributes.data_radix.tag,SIGNED_NUM);
									
									if(temp_num.valid = false) then
										report mif_filename & "(" & integer'image(line_number) & "): Invalid value - '" & line_tokens.element(line_tokens_index).val(1 to line_tokens.element(line_tokens_index).length) & "' for memory data.  Valid values include any 32 bit integer expressed in '" & mem_attributes.data_radix.val(1 to 3) & "' notation."
										severity error;
										wait;
									end if;
									
									mem(mem_addr) <= conv_std_logic_vector(temp_num.val,32);
									mem_init_mode := M2_SET_NEXT_INIT_VAL;
									
								when M2_SET_NEXT_INIT_VAL => 
								
									temp_num := identify_number(line_tokens.element(line_tokens_index),mem_attributes.data_radix.tag,SIGNED_NUM);
									
									if(str_cmp(line_tokens.element(line_tokens_index),SEMICOLON) = 1) then 
										mem_init_mode := DET_INIT_METHOD;
									elsif(temp_num.valid = true) then
										mem_addr := mem_addr + 1;
										mem(mem_addr) <= conv_std_logic_vector(temp_num.val,32);
									else
										report mif_filename & "(" & integer'image(line_number) & "): near '" & line_tokens.element(line_tokens_index).val(1 to line_tokens.element(line_tokens_index).length) & "': expecting ';' or valid memory data.  Valid values include any 32 bit integer expressed in '" & mem_attributes.data_radix.val(1 to 3) & "' notation."
										severity error;
										wait;
									end if;

								when others => 
									mem_init_mode := DET_INIT_METHOD;
									
							end case;
						
						when CHECK_FOR_SEMICOLON =>	
						
							if(str_cmp(line_tokens.element(line_tokens_index),SEMICOLON) /= 1) then
								report mif_filename & "(" & integer'image(line_number) & "): near '" & line_tokens.element(line_tokens_index).val(1 to line_tokens.element(line_tokens_index).length) & "': expecting ';'."		
								severity error;
								wait;
							end if;
								
							read_mif_mode := END_OF_MEM_INIT;
						
						when END_OF_MEM_INIT =>
						
							if(line_tokens.size > 0) then 
								report mif_filename & "(" & integer'image(line_number) & "): near '" & line_tokens.element(line_tokens_index).val(1 to line_tokens.element(line_tokens_index).length) & "': All statements other than comments should appear before the 'END' keyword."
								severity error;
								wait;
							end if;
						
						when others =>
					
							read_mif_mode := SET_ATTRIBUTES;
					
					end case;
					
					line_tokens_index := line_tokens_index + 1;
					
				end loop;
      
			end loop;

			file_close(mif_file);

			wait;
			
	end process read_mif_file;

end architecture behavioral;
