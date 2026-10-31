`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/11/13 16:38:44
// Design Name: 
// Module Name: fw_synchronous_fifo
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
`define RAM_BLOCK
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

module fw_synchronous_fifo#(  
    parameter FIFO_WIDTH = 16, 
    parameter FIFO_DEPTH = 16  
)(
    input   wire                                clk,    
    input   wire                                rst, 

    input   wire                                wr_en,
    input   wire    [FIFO_WIDTH-1:0]            din,
      
    input   wire                                rd_en,
    output  reg     [FIFO_WIDTH-1:0]            dout = 0, 

    output  wire                                empty,  
    output  wire                                full,
    output  reg     [$clog2(FIFO_DEPTH)-1:0]    data_count = 0  
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


reg     [$clog2(FIFO_DEPTH):0]      wr_addr;//写地址（写指针），位宽要多出一位
reg     [$clog2(FIFO_DEPTH):0]      rd_addr;//读地址（读指针），位宽要多出一位
 
    
wire    [$clog2(FIFO_DEPTH)-1:0]    wr_addr_true;	//真实写地址指针
wire    [$clog2(FIFO_DEPTH)-1:0]    rd_addr_true;   //真实读地址指针
wire    						    wr_addr_msb;	//写地址指针地址最高位
wire    						    rd_addr_msb;	//读地址指针地址最高位

assign {wr_addr_msb,wr_addr_true} = wr_addr;		//将最高位与其他位拼接
assign {rd_addr_msb,rd_addr_true} = rd_addr;		//将最高位与其他位拼接  

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
    end
	else if(rd_en && !empty)begin   //读使能有效且FIFO非空
		rd_addr	<=	rd_addr + 1'd1; //读指针递增
	end
end

always@(*) begin
    if(rd_en && !empty)begin   //读使能有效且FIFO非空
		dout	<=	mem[rd_addr_true];  
	end
end

//write
always@(posedge clk)begin 
	if(rst) begin
		wr_addr <= 0;
    end
	else if(wr_en && !full)begin    //写使能有效且FIFO非满
		wr_addr	<=	wr_addr + 1'd1; //读指针递增
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

//-----------------------------<通过地址扩展位更新空/满信号>-----------------------------------
assign	empty = ( wr_addr == rd_addr ) ? 1'b1 : 1'b0;                                              //当所有位相等时，读指针追到了写指针，FIFO被读空
assign	full  = ((wr_addr_msb != rd_addr_msb ) && ( wr_addr_true == rd_addr_true )) ? 1'b1 : 1'b0; //当最高位不同但是其他位相等时，写指针超过读指针一圈，FIFO被写满
 

endmodule
