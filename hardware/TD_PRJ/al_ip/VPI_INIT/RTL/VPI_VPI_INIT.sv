    
// synthesis syn_black_box
module VPI_VPI_INIT (  
    output [0:0] outprobe0, 
    input	clk
);
    localparam string IP_TYPE = "VPI";
    
    localparam VPI_OUTPUT_BUS_NUM = 1;
	localparam VPI_BUS_DOUT_NUM = 1;
	localparam integer VPI_BUS_DOUT_WIDTH[0:0] = {1};

    parameter VPI_OUTPUT_INIT_VAL = 1'b0;
endmodule

