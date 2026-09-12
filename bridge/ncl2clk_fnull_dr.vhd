library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VComponents.all;

library qdi_framework;

entity ncl2clk_fnull_dr is
	generic (
		dr_width: integer := 2
	);
	port (
		clk, rst: in std_logic;
		dri_0, dri_1: in std_logic_vector(dr_width - 1 downto 0);
		ko: out std_logic;
		valid: out std_logic;
		stall: in  std_logic;
		dro: out std_logic_vector(dr_width - 1 downto 0)
	);
end ncl2clk_fnull_dr;

architecture Behavioural of ncl2clk_fnull_dr is
	attribute NCL_WIRE_TYPE : string;
	attribute DONT_TOUCH    : boolean;
	attribute ASYNC_REG     : boolean;
	
	attribute KEEP_HIERARCHY : string;
	attribute KEEP_HIERARCHY of Behavioural : architecture is "TRUE";
	attribute KEEP_HIERARCHY of comp        : label is "SOFT";
	
	signal ki_vec : std_logic_vector(dr_width - 1 downto 0);
	
	signal ki, ki_clk, ko_int : std_logic;
	
	signal written, read : std_logic;
	signal sync_meta, sync_stable : std_logic;
	
	signal valid_int : std_logic;
	
	attribute NCL_WIRE_TYPE of ko_mark : label is "NCL_CLK";
	attribute DONT_TOUCH    of ko_mark : label is true;
	
	attribute NCL_WIRE_TYPE of ki_buf  : label is "COMP_CLK_NCL2CLK";
	
	attribute NCL_WIRE_TYPE of dro     : signal is "COMP_DI_REG";
	
	attribute ASYNC_REG of sync_meta   : signal is true;
	attribute ASYNC_REG of sync_stable : signal is true;
begin

	ki_vec <= dri_0 or dri_1;
	
	valid_int <= sync_stable xor read;
	valid <= valid_int;
	
	ko_int <= not (written xor read) and not ki; -- ki is internally inverted
	
	ko_mark: LUT1
		generic map (
			INIT => "10"
		) port map (
			I0 => ko_int,
			O  => ko
		);
	
	ki_buf: BUFH
		port map (
			I => ki,
			O => ki_clk
		);
	
	mark_ki_vec: for ii in ki_vec'range generate
		attribute NCL_WIRE_TYPE of kivec_mark : label is "COMP_KI_VEC";
		attribute DONT_TOUCH    of kivec_mark : label is true;
	begin
		kivec_mark: LUT1
			generic map (
				INIT => "10"
			) port map (
				I0 => ki_vec(ii)
			);
	end generate mark_ki_vec;	
		
	comp: entity qdi_framework.completion_loop
		generic map (
			width       => dr_width,
			negated_out => false,
			mark_ko     => false
		) port map (
			ko_vector => ki_vec,
			ko => ki
		);
		
	di: process(ki_clk) begin
		if rising_edge(ki_clk) then
			dro <= dri_1;
		end if;
	end process di;
	
	handshake_ncl: process(ki_clk, rst) begin
		if rst = '1' then
			written <= '0';
		elsif rising_edge(ki_clk) then
			written <= not written;
		end if;
	end process handshake_ncl;
	
	handshake_clk: process(clk) begin
		if rising_edge(clk) then
			if rst = '1' then
				read <= '0';
			elsif valid_int = '1' and stall = '0' then
				read <= not read;
			end if;
		end if;
	end process handshake_clk;
	
	sync: process(clk) begin
		if rising_edge(clk) then
			if rst = '1' then
				sync_meta   <= '0';
				sync_stable <= '0';
			else
				sync_meta   <= written;
				sync_stable <= sync_meta;
			end if;
		end if;
	end process sync;
end Behavioural;
