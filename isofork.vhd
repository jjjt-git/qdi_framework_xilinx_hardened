library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VComponents.all;

entity isofork is
	port (
		I : in std_logic;
		O : out std_logic
	);
end isofork;

architecture Structural of isofork is
	attribute DONT_TOUCH                : boolean;
	attribute DONT_TOUCH of QDI_ISOFORK : label is true;
begin

	QDI_ISOFORK: LUT1
		generic map (
			INIT => "10"
		) port map (
			I0 => I,
			O  => O
		);

end Structural;
