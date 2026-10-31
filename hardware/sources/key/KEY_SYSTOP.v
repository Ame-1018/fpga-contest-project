`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Create Date: 2026/10/08 09:21:17
// Module Name: KEY_SYSTOP
//////////////////////////////////////////////////////////////////////////////////


module KEY_SYSTOP #(
    parameter                   CLK_FREQ                    = 50_000_000,
    parameter                   DEBOUNCE_MS                 = 20        ,
    parameter                   ROW_DWELL_US                = 1000
)(
    input   wire                clk                         ,
    input   wire                reset                       ,
    output  wire    [3:0]       key_matrix_row              ,
    input   wire    [3:0]       key_matrix_col              ,
    output  wire    [3:0]       key_matrix_flag0            ,
    output  wire    [3:0]       key_matrix_flag1            ,
    output  wire    [3:0]       key_matrix_flag2            ,
    output  wire    [3:0]       key_matrix_flag3            
);

key_matrix #(
    .CLK_FREQ                   (CLK_FREQ                   ),
    .DEBOUNCE_MS                (DEBOUNCE_MS                ),
    .ROW_DWELL_US               (ROW_DWELL_US               )
) u_key_matrix (
    .sys_clk                    (clk                        ),
    .sys_rst                    (reset                      ),
    .key_row                    (key_row                    ),
    .key_col                    (key_col                    ),
    .key_flag0                  (key_flag0                  ),
    .key_flag1                  (key_flag1                  ),
    .key_flag2                  (key_flag2                  ),
    .key_flag3                  (key_flag3                  )
);

endmodule
