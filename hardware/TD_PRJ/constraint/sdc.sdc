

create_clock -name {sys_clk} -period 20.000 -waveform {0.000 10.000} [get_ports {sys_clk}]

derive_clocks
# create_generated_clock -name SYSCLK_50M -source  [get_ports {sys_clk}] -master_clock {sys_clk } -multiply_by 1      [get_pins   {SYS_PLL/pll_inst.clkc[0]}]
# create_generated_clock -name SYSCLK_100M -source [get_ports {sys_clk}] -master_clock {sys_clk } -multiply_by 2      [get_pins   {SYS_PLL/pll_inst.clkc[1]}]
# create_generated_clock -name SYSCLK_125M -source [get_ports {sys_clk}] -master_clock {sys_clk } -multiply_by 2.5    [get_pins   {SYS_PLL/pll_inst.clkc[2]}]

# create_generated_clock -name SYSCLK_50M         -source [get_ports {sys_clk}] -master_clock {sys_clk} -multiply_by 1        [get_pins  {SYS_PLL/pll_inst.clkc[0]}]
# create_generated_clock -name SYSCLK_150M        -source [get_ports {sys_clk}] -master_clock {sys_clk} -multiply_by 3        [get_pins  {SYS_PLL/pll_inst.clkc[1]}]
# create_generated_clock -name SYSCLK_150M_S180   -source [get_ports {sys_clk}] -master_clock {sys_clk} -multiply_by 3        [get_pins  {SYS_PLL/pll_inst.clkc[2]}]
# create_generated_clock -name SYSCLK_75M         -source [get_ports {sys_clk}] -master_clock {sys_clk} -multiply_by 1.5      [get_pins  {SYS_PLL/pll_inst.clkc[3]}]
# create_generated_clock -name SYSCLK_375M        -source [get_ports {sys_clk}] -master_clock {sys_clk} -multiply_by 7.5      [get_pins  {SYS_PLL/pll_inst.clkc[4]}]

rename_clock -name {SYSCLK_50M}         [get_clocks {SYS_PLL/pll_inst.clkc[0]}]
rename_clock -name {SYSCLK_150M}        [get_clocks {SYS_PLL/pll_inst.clkc[1]}]
rename_clock -name {SYSCLK_150M_S180}   [get_clocks {SYS_PLL/pll_inst.clkc[2]}]
rename_clock -name {SYSCLK_75M}         [get_clocks {SYS_PLL/pll_inst.clkc[3]}]
rename_clock -name {SYSCLK_375M}        [get_clocks {SYS_PLL/pll_inst.clkc[4]}]

set_clock_groups -exclusive -group [get_clocks {SYSCLK_150M}] -group [get_clocks {SYSCLK_150M_S180}]
set_clock_groups -exclusive -group [get_clocks {SYSCLK_150M_S180}] -group [get_clocks {SYSCLK_150M}]

set_clock_groups -exclusive -group [get_clocks {SYSCLK_75M}] -group [get_clocks {SYSCLK_150M}]
set_clock_groups -exclusive -group [get_clocks {SYSCLK_150M}] -group [get_clocks {SYSCLK_75M}]

set_clock_groups -exclusive -group [get_clocks {SYSCLK_50M}] -group [get_clocks {SYSCLK_150M}]
set_clock_groups -exclusive -group [get_clocks {SYSCLK_150M}] -group [get_clocks {SYSCLK_50M}]

set_clock_groups -exclusive -group [get_clocks {SYSCLK_50M}] -group [get_clocks {SYSCLK_75M}]
set_clock_groups -exclusive -group [get_clocks {SYSCLK_75M}] -group [get_clocks {SYSCLK_50M}]


set_clock_groups -exclusive -group [get_clocks {SYSCLK_75M}] -group [get_clocks {SYSCLK_375M}]
set_clock_groups -exclusive -group [get_clocks {SYSCLK_375M}] -group [get_clocks {SYSCLK_75M}]

