`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: xuchangjun
// 
// Create Date: 2024/11/09 17:10:17
// Design Name: 
// Module Name: single_port_ram
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
//`define RAM_DISTRIBUTED
//  `define RAM_BLOCK
// `define RAM_REGISTERS
// `define RAM_ULTRA
// `define RAM_MIXED
// `define RAM_AUTO
/*
    ram_style   = "distributed"     使用LUT来实现
                = "block"           使用块状RAM来实现
                = "registers"       使用寄存器来是实现
                = "ultra"           只针对ultrascale系列的器件才有效，即使用ultrascale器件中的URAM实现
                = "mixed"           根据使用最小的面积原则灵活确定RAM的实现方式
                = "auto"            综合工具来决定实现方式
*/
module single_port_ram #(
    parameter   RAM_WIDTH   = 16,
    parameter   RAM_DEPTH   = 256,
    parameter   PERFORMENCE = "HIGH",//or LOW
    parameter   INIT_FILE   = ""
)(
    input   wire                                clka,
    input   wire                                wea,
    input   wire    [RAM_WIDTH-1:0]             dina,  
    input   wire    [$clog2(RAM_DEPTH)-1:0]     addra,
    
    output  reg     [RAM_WIDTH-1:0]             douta

);

`ifdef RAM_DISTRIBUTED
    (* ram_style = "distributed" *) reg [RAM_WIDTH-1:0]	mem	[RAM_DEPTH-1:0];
`elsif RAM_BLOCK
    (* ram_style = "block" *)       reg [RAM_WIDTH-1:0]	mem	[RAM_DEPTH-1:0];
`elsif RAM_REGISTERS
    (* ram_style = "registers" *)   reg [RAM_WIDTH-1:0]	mem	[RAM_DEPTH-1:0];
`elsif RAM_ULTRA
    (* ram_style = "ultra" *)       reg [RAM_WIDTH-1:0]	mem	[RAM_DEPTH-1:0];
`elsif RAM_MIXED
    (* ram_style = "mixed" *)       reg [RAM_WIDTH-1:0]	mem	[RAM_DEPTH-1:0];
`elsif RAM_AUTO
    (* ram_style = "auto" *)        reg [RAM_WIDTH-1:0]	mem	[RAM_DEPTH-1:0];
`else
    reg [RAM_WIDTH-1:0]	mem	[RAM_DEPTH-1:0];
`endif


reg     [RAM_WIDTH-1:0] douta_reg = {RAM_WIDTH{1'b0}};

generate
    if(INIT_FILE != "") begin: use_init_file
    	initial begin
            $readmemh(INIT_FILE, mem, 0, RAM_DEPTH-1);
        end
    end
    else begin:init_bram_zero
        integer ram_index;
        initial begin
            for(ram_index = 0;ram_index < RAM_DEPTH;ram_index = ram_index + 1) begin
                mem[ram_index] = {RAM_WIDTH{1'b0}};
            end
        end
    end
endgenerate

always@(posedge clka) begin
    if(wea) begin
        mem[addra] <= dina;
    end
end

generate
    if(PERFORMENCE == "HIGH") begin: HIGH_RAM

        always@(posedge clka) begin
            douta_reg <= mem[addra];
        end

        always@(posedge clka) begin
            douta <= douta_reg;
        end

    end
    else begin:LOW_RAM

        always@(posedge clka) begin
            douta_reg <= mem[addra];
        end

        always@(*) begin
            douta <= douta_reg;
        end

    end
endgenerate


// function integer clogb2 (input integer bit_depth);              
// 	begin                                                           
// 		for(clogb2=0; bit_depth>0; clogb2=clogb2+1)                   
// 			bit_depth = bit_depth >> 1;                                 
// 	end                                                           
// endfunction                                                     
 
endmodule
