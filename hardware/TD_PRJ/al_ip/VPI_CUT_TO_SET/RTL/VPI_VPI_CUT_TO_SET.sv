    
// synthesis syn_black_box
module VPI_VPI_CUT_TO_SET (  
    output [2:0] outprobe0, 
    output [1:0] outprobe1, 
    output [7:0] outprobe2, 
    output [7:0] outprobe3, 
    output [7:0] outprobe4, 
    output [7:0] outprobe5, 
    output [0:0] outprobe6, 
    output [0:0] outprobe7, 
    output [0:0] outprobe8, 
    output [12:0] outprobe9, 
    output [12:0] outprobe10, 
    output [12:0] outprobe11, 
    output [12:0] outprobe12, 
    output [12:0] outprobe13, 
    output [1:0] outprobe14, 
    output [1:0] outprobe15, 
    output [23:0] outprobe16, 
    output [0:0] outprobe17, 
    output [0:0] outprobe18, 
    output [1:0] outprobe19, 
    output [0:0] outprobe20, 
    output [12:0] outprobe21, 
    output [12:0] outprobe22, 
    input	clk
);
    localparam string IP_TYPE = "VPI";
    
    localparam VPI_OUTPUT_BUS_NUM = 23;
	localparam VPI_BUS_DOUT_NUM = 164;
	localparam integer VPI_BUS_DOUT_WIDTH[0:22] = {3,2,8,8,8,8,1,1,1,13,13,13,13,13,2,2,24,1,1,2,1,13,13};

    parameter VPI_OUTPUT_INIT_VAL = 164'b00000100000001000000010000000100000000000000000010000000000001000000000000100000000011001000000011110000001000000000000000000000000000000000010100000000000111100000;
endmodule

