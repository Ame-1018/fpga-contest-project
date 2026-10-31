`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// 
// Create Date: 2024/11/09 17:15:47
// Design Name: 
// Module Name: synchronous_fifo
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
`define RAM_DISTRIBUTED
//  `define RAM_BLOCK
// `define RAM_REGISTERS
// `define RAM_ULTRA
// `define RAM_MIXED
// `define RAM_AUTO
/*
    ram_style   = "distributed"  
                = "block"        
                = "registers"    
                = "ultra"        
                = "mixed"        
                = "auto"         
*/

module synchronous_fifo#(  
    parameter FIFO_WIDTH = 16, 
    parameter FIFO_DEPTH = 16,
    parameter FIFO_OREG  = 0
)(
    input   wire                                clk,    
    input   wire                                rst, 

    input   wire    [FIFO_WIDTH-1:0]            din,
    input   wire                                wr_en,
 
    input   wire                                rd_en,
    output  reg     [FIFO_WIDTH-1:0]            dout, 

    output  wire                                full,
    output  wire                                empty,  
    output  reg     [$clog2(FIFO_DEPTH)-1:0]    data_count   
); 
 
`ifdef RAM_DISTRIBUTED
    (* ram_style = "distributed" *) reg [FIFO_WIDTH-1:0]	mem	[FIFO_DEPTH-1:0];
`elsif RAM_BLOCK
    (* ram_style = "block" *)       reg [FIFO_WIDTH-1:0]	mem	[FIFO_DEPTH-1:0];
`elsif RAM_REGISTERS
    (* ram_style = "registers" *)   reg [FIFO_WIDTH-1:0]	mem	[FIFO_DEPTH-1:0];
`elsif RAM_ULTRA
    (* ram_style = "ultra" *)       reg [FIFO_WIDTH-1:0]	mem	[FIFO_DEPTH-1:0];
`elsif RAM_MIXED
    (* ram_style = "mixed" *)       reg [FIFO_WIDTH-1:0]	mem	[FIFO_DEPTH-1:0];
`elsif RAM_AUTO
    (* ram_style = "auto" *)        reg [FIFO_WIDTH-1:0]	mem	[FIFO_DEPTH-1:0];
`else
    reg [FIFO_WIDTH-1:0]	mem	[FIFO_DEPTH-1:0];
`endif

reg     [$clog2(FIFO_DEPTH):0]      wr_addr;
reg     [$clog2(FIFO_DEPTH):0]      rd_addr;
 
    
wire    [$clog2(FIFO_DEPTH)-1:0]    wr_addr_true;
wire    [$clog2(FIFO_DEPTH)-1:0]    rd_addr_true;
wire    						    wr_addr_msb;
wire    						    rd_addr_msb;

reg     [FIFO_WIDTH-1:0]            out_temp    ;

assign {wr_addr_msb,wr_addr_true} = wr_addr;	
assign {rd_addr_msb,rd_addr_true} = rd_addr;	 

integer i;
initial begin
	for(i = 0;i < FIFO_DEPTH;i = i + 1) begin
		mem[i] = 0;
	end
end

//read
always@(posedge clk)begin 
	if(rst) begin
		rd_addr <= 0;
		dout <= 0;
        out_temp <= 0;
    end
    else if(FIFO_OREG == 0) begin
        if(rd_en && !empty)begin   
	    	rd_addr	<=	rd_addr + 1'd1; 
	    	dout	<=	mem[rd_addr_true];  
	    end
    end
    else if(FIFO_OREG == 1) begin
        if(rd_en && !empty)begin   
	    	rd_addr	<=	rd_addr + 1'd1; 
            out_temp <= mem[rd_addr_true];
            dout	<=	out_temp;  
	    end
        else begin
            dout	<=	out_temp;  
        end
    end
end

//write
always@(posedge clk)begin 
	if(rst) begin
		wr_addr <= 0;
    end
	else if(wr_en && !full)begin    
		wr_addr	<=	wr_addr + 1'd1; 
		mem[wr_addr_true] <= din;   
	end
end

//count
always@(posedge clk)begin 
	if(rst) begin
		data_count <= 'd0;
    end
	else if(wr_en && !full && !rd_en) begin
		data_count <= data_count + 1'b1;
	end
	else if(rd_en && !empty && !wr_en) begin
		data_count <= data_count - 1'b1;
	end
end

//-----------------------------<>-----------------------------------
assign	empty = ( wr_addr == rd_addr ) ? 1'b1 : 1'b0;                                              
assign	full  = ((wr_addr_msb != rd_addr_msb ) && ( wr_addr_true == rd_addr_true )) ? 1'b1 : 1'b0; 
 

endmodule
