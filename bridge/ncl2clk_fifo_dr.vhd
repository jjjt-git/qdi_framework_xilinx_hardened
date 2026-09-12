library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

library UNISIM;
use UNISIM.VComponents.all;

library qdi_framework;

entity ncl2clk_fifo_dr is
	generic (
		dr_width   : integer := 2;
		addr_width : integer := 2
	);
	port (
		clk, rst     : in std_logic;
		dri_0, dri_1 : in std_logic_vector(dr_width - 1 downto 0);
		ko           : out std_logic;
		valid        : out std_logic;
		stall        : in  std_logic;
		dro          : out std_logic_vector(dr_width - 1 downto 0)
	);
end ncl2clk_fifo_dr;

architecture Behavioural of ncl2clk_fifo_dr is
	constant mem_depth : integer := 2 ** addr_width;

	attribute NCL_WIRE_TYPE : string;
	attribute DONT_TOUCH    : boolean;
	attribute KEEP          : boolean;
	attribute ASYNC_REG     : boolean;
	
	attribute KEEP_HIERARCHY : string;
	attribute KEEP_HIERARCHY of Behavioural : architecture is "TRUE";
	attribute KEEP_HIERARCHY of comp        : label is "SOFT";
	
	signal ki_vec, do : std_logic_vector(dr_width - 1 downto 0);
	
	signal ki, ki_clk, ko_int : std_logic;
	
	signal empty, full : std_logic;
	
	type buf_t is array (0 to mem_depth - 1) of std_logic_vector(dr_width - 1 downto 0);
	signal buf : buf_t;
	
	signal w_ptr, w_ptr_gray, w_ptr_next, w_ptr_gray_next : unsigned(addr_width - 1 downto 0);
	signal r_ptr, r_ptr_gray, r_ptr_next : unsigned(addr_width - 1 downto 0);
	signal sync_meta, sync_stable        : unsigned(addr_width - 1 downto 0);
	
	signal valid_int : std_logic;
	
	attribute NCL_WIRE_TYPE of ko_mark : label is "NCL_CLK";
	attribute DONT_TOUCH    of ko_mark : label is true;
	
	attribute NCL_WIRE_TYPE of ki_buf  : label is "COMP_CLK_NCL2CLK";
	
	attribute ASYNC_REG of sync_meta   : signal is true;
	attribute ASYNC_REG of sync_stable : signal is true;
begin

	ki_vec <= dri_0 or dri_1;
	
	valid_int <= not empty;
	valid <= valid_int;
	
	empty <=
		'1' when sync_stable = r_ptr_gray else
		'0';
		
	full <=
		'1' when w_ptr_gray_next = r_ptr_gray else
		'0';
	
	ko_int <= not full and not ki; -- ki is internally inverted
	
	do  <= buf(to_integer(r_ptr));
	dro <= do;
	
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
		attribute NCL_WIRE_TYPE of do_mark    : label is "COMP_DI_REG";
		attribute DONT_TOUCH    of do_mark    : label is true;
		attribute NCL_WIRE_TYPE of kivec_mark : label is "COMP_KI_VEC";
		attribute DONT_TOUCH    of kivec_mark : label is true;
	begin
		kivec_mark: LUT1
			generic map (
				INIT => "10"
			) port map (
				I0 => ki_vec(ii)
			);
			
		do_mark: LUT1
			generic map (
				INIT => "10"
			) port map (
				I0 => do(ii)
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

	sync: process(clk) begin
		if rising_edge(clk) then
			if rst = '1' then
				sync_meta   <= (others => '0');
				sync_stable <= (others => '0');
			else
				sync_meta   <= w_ptr_gray;
				sync_stable <= sync_meta;
			end if;
		end if;
	end process sync;
	
	di: process(ki_clk) begin
		if rising_edge(ki_clk) then
			buf(to_integer(w_ptr)) <= dri_1;
		end if;
	end process di;
		
	w_ptr_next <= w_ptr + 1;
	r_ptr_next <= r_ptr + 1;
	
	w_ptr_gray <= w_ptr xor shift_right(w_ptr, 1);
	r_ptr_gray <= r_ptr xor shift_right(r_ptr, 1);
	
	w_ptr_gray_next <= w_ptr_next xor shift_right(w_ptr_next, 1);
	
	handshake_ncl: process(ki_clk, rst) begin
		if rst = '1' then
			w_ptr <= (others => '0');
		elsif rising_edge(ki_clk) then
			w_ptr <= w_ptr_next;
		end if;
	end process handshake_ncl;
	
	handshake_clk: process(clk) begin
		if rising_edge(clk) then
			if rst = '1' then
				r_ptr <= (others => '0');
			elsif valid_int = '1' and stall = '0' then
				r_ptr <= r_ptr_next;
			end if;
		end if;
	end process handshake_clk;
		
end Behavioural;
