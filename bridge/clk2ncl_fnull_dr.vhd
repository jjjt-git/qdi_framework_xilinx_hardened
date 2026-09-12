library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.math_real.all;

library UNISIM;
use UNISIM.VComponents.all;

entity clk2ncl_fnull_dr is
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
end clk2ncl_fnull_dr;

architecture Behavioural of clk2ncl_fnull_dr is
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

	signal d_r, do_0m, do_1m : std_logic_vector(dr_width - 1 downto 0);
	
	signal written, read : std_logic;
	signal sync_meta, sync_stable : std_logic;
	
	signal stall_int, ki_clk : std_logic;
	
	attribute ASYNC_REG of sync_meta   : signal is true;
	attribute ASYNC_REG of sync_stable : signal is true;
	
	attribute NCL_WIRE_TYPE of ki_buf : label is "COMP_CLK_CLK2NCL";
	
	attribute NCL_IN_ENC_REG of written : signal is "clk_valid";
begin

	dro_0 <= do_0m;
	dro_1 <= do_1m;
	
	stall <= stall_int;
	
	stall_int <= written xor sync_stable;
	
	ki_buf: LUT1
		generic map (
			INIT => "10"
		) port map (
			I0 => ki,
			O  => ki_clk
		);
	
	handshake_ncl: process(ki_clk, rst) begin
		if rst = '1' then
			read <= '0';
		elsif falling_edge(ki_clk) then
			read <= not read;
		end if;
	end process handshake_ncl;
	
	handshake_clk: process(clk) begin
		if rising_edge(clk) then
			if rst = '1' then
				written <= '0';
			elsif valid = '1' and stall_int = '0' then
				written <= not written;
			end if;
		end if;
	end process handshake_clk;
	
	di: process(clk) begin
		if falling_edge(clk) then
			if valid = '1' and stall_int = '0' then
				d_r <= dri;
			end if;
		end if;
	end process di;
	
	encode: for ii in 0 to dr_width - 1 generate
		constant WRITTEN_BITS : bit_vector(15 downto 0) := "1010101010101010";
		constant DATA_BITS    : bit_vector(15 downto 0) := "1100110011001100";
		constant READ_BITS    : bit_vector(15 downto 0) := "1111000011110000";
		constant KI_BITS      : bit_vector(15 downto 0) := "1111111100000000";
		
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
		d0: LUT4
			generic map (
				INIT => KI_BITS and (READ_BITS xor WRITTEN_BITS) and not DATA_BITS
			) port map (
				I0 => written,
				I1 => d_r(ii),
				I2 => read,
				I3 => ki,
				
				O => do_0m(ii)
			);
		
		d1: LUT4
			generic map (
				INIT => KI_BITS and (READ_BITS xor WRITTEN_BITS) and DATA_BITS
			) port map (
				I0 => written,
				I1 => d_r(ii),
				I2 => read,
				I3 => ki,
				
				O => do_1m(ii)
			);
	end generate encode;
	
	sync: process(clk) begin
		if rising_edge(clk) then
			if rst = '1' then
				sync_meta   <= '0';
				sync_stable <= '0';
			else
				sync_meta   <= read;
				sync_stable <= sync_meta;
			end if;
		end if;
	end process sync;
	
end Behavioural;