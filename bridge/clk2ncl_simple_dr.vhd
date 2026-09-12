library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.math_real.all;

library UNISIM;
use UNISIM.VComponents.all;

entity clk2ncl_simple_dr is
	generic (
		dr_width: integer := 2
	);
	port (
		clk, rst: in std_logic;
		dro_0, dro_1: out std_logic_vector(dr_width - 1 downto 0);
		ki: in std_logic;
		valid: in std_logic;
		stall: out std_logic;
		dri: in std_logic_vector(dr_width - 1 downto 0)
	);
end clk2ncl_simple_dr;

architecture Behavioural of clk2ncl_simple_dr is
	attribute NCL_WIRE_TYPE               : string;
	attribute NCL_IN_ENC_DATA2VALID_EDGES : string;
	attribute NCL_IN_ENC_VALID_PIN        : string;
	attribute NCL_IN_ENC_DATA_PIN         : string;
	attribute NCL_IN_ENC_KI_PIN           : string;
	attribute NCL_IN_ENC_REG              : string;
	
	attribute DONT_TOUCH : boolean;
	attribute ASYNC_REG  : boolean;
	attribute KEEP       : boolean;
	attribute HLUTNM     : string;
	
	attribute KEEP_HIERARCHY : string;
	attribute KEEP_HIERARCHY of Behavioural : architecture is "TRUE";
	
	signal do_1m, do_0m, d_r : std_logic_vector(dr_width - 1 downto 0);
	signal v_r : std_logic;
	
	signal ki_m, ki_s, ki_sn : std_logic;
	
	signal ki_edge : std_logic;
	
	attribute ASYNC_REG of ki_m : signal is true;
	attribute ASYNC_REG of ki_s : signal is true;
	
	attribute NCL_IN_ENC_REG of v_r : signal is "clk_valid";
begin
	stall <= v_r;
	
	dro_0 <= do_0m;
	dro_1 <= do_1m;
	
	ki_edge <= not ki_s and ki_sn;
	
	encode: for ii in 0 to dr_width - 1 generate
		constant VALID_BITS : bit_vector(7 downto 0) := "10101010";
		constant DATA_BITS  : bit_vector(7 downto 0) := "11001100";
		constant KI_BITS    : bit_vector(7 downto 0) := "11110000";
		
		attribute DONT_TOUCH of d0 : label is true;
		attribute DONT_TOUCH of d1 : label is true;
		
		attribute NCL_WIRE_TYPE of d0 : label is "IN_ENC";
		attribute NCL_WIRE_TYPE of d1 : label is "IN_ENC";
		
		attribute NCL_IN_ENC_DATA2VALID_EDGES of d0 : label is "fr";
		attribute NCL_IN_ENC_DATA2VALID_EDGES of d1 : label is "fr";
		
		attribute NCL_IN_ENC_VALID_PIN of d0 : label is "I0";
		attribute NCL_IN_ENC_VALID_PIN of d1 : label is "I0";
		
		attribute NCL_IN_ENC_DATA_PIN of d0 : label is "I1";
		attribute NCL_IN_ENC_DATA_PIN of d1 : label is "I1";

		attribute NCL_IN_ENC_KI_PIN of d0 : label is "none";
		attribute NCL_IN_ENC_KI_PIN of d1 : label is "none";
		
		attribute HLUTNM of d0 : label is "enc" & integer'image(ii);
		attribute HLUTNM of d1 : label is "enc" & integer'image(ii);
	begin
		d0: LUT3
			generic map (
				INIT => VALID_BITS and KI_BITS and not DATA_BITS
			) port map (
				I0 => v_r,
				I1 => d_r(ii),
				I2 => ki_s,
				
				O => do_0m(ii)
			);
		
		d1: LUT3
			generic map (
				INIT => VALID_BITS and KI_BITS and DATA_BITS
			) port map (
				I0 => v_r,
				I1 => d_r(ii),
				I2 => ki_s,
				
				O => do_1m(ii)
			);
	end generate encode;
	
	in_regs: process(clk) begin
		if falling_edge(clk) then
			if rst = '1' then
				d_r <= (others => '0');
			elsif v_r = '0' and valid = '1' then
				d_r <= dri;
			end if;
		end if;
		
		if rising_edge(clk) then
			if rst = '1' then
				v_r <= '0';
			elsif v_r = '0' then
				v_r <= valid;
			elsif ki_edge = '1' then
				v_r <= '0';
			end if;
		end if;
	end process in_regs;
	
	ki_in: process(clk, rst) begin
		if rst = '1' then
			ki_m <= '0';
			ki_s <= '0';
			ki_sn <= '0';
		else
			if falling_edge(clk) then
				ki_m <= ki;
				ki_s <= ki_m;
			end if;
			
			if rising_edge(clk) then
				ki_sn <= ki_s;
			end if;
		end if;
	end process ki_in;
	
end Behavioural;