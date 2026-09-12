library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use ieee.math_real.all;

library UNISIM;
use UNISIM.VComponents.all;

entity clk2ncl_fifo_dr is
	generic (
		dr_width   : integer := 2;
		addr_width : integer := 2
	);
	port (
		clk, rst     : in std_logic;
		dro_0, dro_1 : out std_logic_vector(dr_width - 1 downto 0);
		ki           : in std_logic;
		valid        : in std_logic;
		stall        : out std_logic;
		dri          : in std_logic_vector(dr_width - 1 downto 0)
	);
end clk2ncl_fifo_dr;

architecture Behavioural of clk2ncl_fifo_dr is
	constant mem_depth : integer := 2 ** addr_width;

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

	signal empty, full : std_logic;

	type buf_t is array (0 to mem_depth - 1) of std_logic_vector(dr_width - 1 downto 0);
	signal buf : buf_t;

	signal d_r, do_0m, do_1m : std_logic_vector(dr_width - 1 downto 0);

	signal w_ptr, w_ptr_gray, w_ptr_next, w_ptr_gray_next : unsigned(addr_width - 1 downto 0);
	signal r_ptr, r_ptr_gray, r_ptr_next : unsigned(addr_width - 1 downto 0);
	signal sync_meta, sync_stable        : unsigned(addr_width - 1 downto 0);

	signal stall_int, ki_clk : std_logic;

	attribute ASYNC_REG of sync_meta   : signal is true;
	attribute ASYNC_REG of sync_stable : signal is true;

	attribute NCL_WIRE_TYPE of ki_buf : label is "COMP_CLK_CLK2NCL";

	attribute NCL_IN_ENC_REG of w_ptr : signal is "clk_valid";
begin

	dro_0 <= do_0m;
	dro_1 <= do_1m;

	stall <= stall_int;

	empty <=
		'1' when w_ptr_gray = r_ptr_gray else
		'0';

	full <=
		'1' when w_ptr_gray_next = sync_stable else
		'0';

	stall_int <= full;

	d_r <= buf(to_integer(r_ptr));

	di: process(clk) begin
		if falling_edge(clk) then
			if valid = '1' and stall_int = '0' then
				buf(to_integer(w_ptr)) <= dri;
			end if;
		end if;
	end process di;

	ki_buf: LUT1
		generic map (
			INIT => "10"
		) port map (
			I0 => ki,
			O  => ki_clk
		);
		
	w_ptr_next <= w_ptr + 1;
	r_ptr_next <= r_ptr + 1;
	
	w_ptr_gray <= w_ptr xor shift_right(w_ptr, 1);
	r_ptr_gray <= r_ptr xor shift_right(r_ptr, 1);
	
	w_ptr_gray_next <= w_ptr_next xor shift_right(w_ptr_next, 1);

	handshake_clk: process(clk) begin
		if rising_edge(clk) then
			if rst = '1' then
				w_ptr <= (others => '0');
			elsif valid = '1' and stall_int = '0' then
				w_ptr <= w_ptr_next;
			end if;
		end if;
	end process handshake_clk;

	handshake_ncl: process(ki_clk, rst) begin
		if rst = '1' then
			r_ptr <= (others => '0');
		elsif falling_edge(ki_clk) then
			r_ptr <= r_ptr_next;
		end if;
	end process handshake_ncl;

	sync: process(clk) begin
		if rising_edge(clk) then
			if rst = '1' then
				sync_meta   <= (others => '0');
				sync_stable <= (others => '0');
			else
				sync_meta   <= r_ptr_gray;
				sync_stable <= sync_meta;
			end if;
		end if;
	end process sync;

	encode: for ii in 0 to dr_width - 1 generate
		constant EMPTY_BITS : bit_vector(7 downto 0) := "10101010";
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

		attribute NCL_IN_ENC_KI_PIN of d0 : label is "I2";
		attribute NCL_IN_ENC_KI_PIN of d1 : label is "I2";

		attribute HLUTNM of d0 : label is "enc" & integer'image(ii);
		attribute HLUTNM of d1 : label is "enc" & integer'image(ii);
	begin
		d0: LUT3
			generic map (
				INIT => not EMPTY_BITS and KI_BITS and not DATA_BITS
			) port map (
				I0 => empty,
				I1 => d_r(ii),
				I2 => ki,

				O => do_0m(ii)
			);

		d1: LUT3
			generic map (
				INIT => not EMPTY_BITS and KI_BITS and DATA_BITS
			) port map (
				I0 => empty,
				I1 => d_r(ii),
				I2 => ki,

				O => do_1m(ii)
			);
	end generate encode;

end Behavioural;
