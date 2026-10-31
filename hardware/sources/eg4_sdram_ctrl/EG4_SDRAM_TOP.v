`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// ███╗   ███╗██╗   ██╗██╗  ██╗ █████╗ ███╗   ██╗
// ████╗ ████║██║   ██║██║  ██║██╔══██╗████╗  ██║
// ██╔████╔██║██║   ██║███████║███████║██╔██╗ ██║
// ██║╚██╔╝██║██║   ██║██╔══██║██╔══██║██║╚██╗██║
// ██║ ╚═╝ ██║╚██████╔╝██║  ██║██║  ██║██║ ╚████║
// ╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝
// Create Date: 2026/10/08 09:21:17
// Design Name: 
// Module Name: SD_WR_CTRL
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`include "../eg4_sdram_enc/global_def.v"

module EG4_SDRAM_TOP(
    input   wire                sdram_clk               ,
    input   wire                sdram_clk_s180          ,
    input   wire                sdram_reset             ,

    output  wire                Sdr_init_done           ,
    output  wire                Sdr_init_ref_vld        ,
    output  wire                Sdr_busy                ,
    output  wire                Sdr_ref_hold            ,

    input   wire                App_wr_en               ,
    input   wire    [20:0]      App_wr_addr             , 	
    input   wire    [3:0]       App_wr_dm               ,
    input   wire    [31:0]      App_wr_din              ,

    input   wire                App_rd_en               ,
    input   wire    [20:0]      App_rd_addr             ,
    output  wire                Sdr_rd_en               ,
    output  wire    [31:0]      Sdr_rd_dout             
);

wire                            App_ref_req             ;

wire                            sdram_busy              ;


wire                            SDRAM_CLK               ;
wire                            SDR_RAS                 ;
wire                            SDR_CAS                 ;
wire                            SDR_WE                  ;
wire  [`BA_WIDTH-1:0]	        SDR_BA                  ; 
wire  [`ROW_WIDTH-1:0]	        SDR_ADDR                ;
wire  [`DM_WIDTH-1:0]	        SDR_DM                  ; 
wire  [`DATA_WIDTH-1:0]	        SDR_DQ                  ;

sdr_as_ram #( 
    .self_refresh_open          (1'b1                   )
)sdr_as_ram( 
    .Sdr_clk                    (sdram_clk              ),
    .Sdr_clk_sft                (sdram_clk_s180         ),
    .Rst                        (sdram_reset            ),

    .Sdr_init_done              (Sdr_init_done          ),
    .Sdr_init_ref_vld           (Sdr_init_ref_vld       ),
    .Sdr_busy                   (Sdr_busy               ),

    .App_ref_req                (App_ref_req            ),		

    .App_wr_en                  (App_wr_en              ),
    .App_wr_addr                (App_wr_addr            ),
    .App_wr_dm                  (App_wr_dm              ),
    .App_wr_din                 (App_wr_din             ),
    .App_rd_en                  (App_rd_en              ),
    .App_rd_addr                (App_rd_addr            ),
    .Sdr_rd_en                  (Sdr_rd_en              ),
    .Sdr_rd_dout                (Sdr_rd_dout            ),

    .SDRAM_CLK                  (SDRAM_CLK              ),
    .SDR_RAS                    (SDR_RAS                ),
    .SDR_CAS                    (SDR_CAS                ),
    .SDR_WE                     (SDR_WE                 ),
    .SDR_BA                     (SDR_BA                 ),
    .SDR_ADDR                   (SDR_ADDR               ),
    .SDR_DM                     (SDR_DM                 ),
    .SDR_DQ                     (SDR_DQ                 )
);

assign Sdr_ref_hold = 1'b0;

// assign sdram_busy = App_wr_en | App_rd_en | Sdr_busy    ;

// EG4_SDRAM_REF EG4_SDRAM_REF(
//     .clk                        (sdram_clk              ),
//     .reset                      (!Sdr_init_done         ),

//     .sdram_busy                 (sdram_busy             ),

//     .sdram_ref_req              (App_ref_req            ),
//     .sdram_ref_ack              (Sdr_init_ref_vld       ),
//     .sdram_ref_hold             (Sdr_ref_hold           )
// );


`ifndef SIM_MODE

EG_PHY_SDRAM_2M_32 EG_PHY_SDRAM_2M_32(
    .clk                        (SDRAM_CLK              ),
    .ras_n                      (SDR_RAS                ),
    .cas_n                      (SDR_CAS                ),
    .we_n                       (SDR_WE                 ),
    .addr                       (SDR_ADDR[10:0]         ),
    .ba                         (SDR_BA                 ),
    .dq                         (SDR_DQ                 ),
    .cs_n                       (1'b0                   ),
    .dm0                        (SDR_DM[0]              ),
    .dm1                        (SDR_DM[1]              ),
    .dm2                        (SDR_DM[2]              ),
    .dm3                        (SDR_DM[3]              ),
    .cke                        (1'b1                   )
);

`else 

sdram_model_plus#(
    .physical                   (1                      ),
    .addr_bits                  (11                     ),
    .data_bits                  (32                     ),
    .col_bits                   (8                      ),
    .mem_sizes                  (524287                 )
)sdram_model_plus(
    .Dq                         (SDR_DQ                 ),
    .Addr                       (SDR_ADDR               ),
    .Ba                         (SDR_BA                 ),
    .Clk                        (SDRAM_CLK              ),
    .Cke                        (1'b1                   ),
    .Cs_n                       (1'b0                   ),
    .Ras_n                      (SDR_RAS                ),
    .Cas_n                      (SDR_CAS                ),
    .We_n                       (SDR_WE                 ),
    .Dqm                        (SDR_DM                 ),         
    .Debug                      (1'b0                   )
);

`endif 


endmodule
