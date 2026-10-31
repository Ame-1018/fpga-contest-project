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
// Create Date: 2026/10/19 10:20:00
// Design Name: 
// Module Name: VPU_MUL_US_PIPE
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 移位加法乘法器，不使用星号。流水或串行由模块名区分。
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module VPU_MUL_US_PIPE #(
    parameter integer A_W         = 13,
    parameter integer B_W         = 16,
    parameter integer ITERATE_SEL = 0
)(
    input  wire                         clk,
    input  wire                         reset,

    input  wire                         valid_in,
    input  wire        [A_W-1:0]        a,
    input  wire signed [B_W-1:0]        b,

    output reg                          valid_out,
    output reg signed [A_W+B_W-1:0]     prod
);

    localparam integer P_W = A_W + B_W;
    localparam integer ITERATE_A =
        (ITERATE_SEL == 1) ? 1 :
        (ITERATE_SEL == 2) ? 0 : (A_W <= B_W);
    localparam integer ITER_W = ITERATE_A ? A_W : B_W;

    reg        [A_W-1:0] a_r;
    reg signed [B_W-1:0] b_r;
    reg                  vin_r;

    wire [B_W-1:0] b_bits = b_r;
    wire [B_W-1:0] b_mag  = b_r[B_W-1]
                            ? (~b_bits + 1'b1) : b_bits;

    reg [P_W-1:0]    acc_st   [0:ITER_W-1];
    reg [P_W-1:0]    mcand_st [0:ITER_W-1];
    reg [ITER_W-1:0] mp_st    [0:ITER_W-1];
    reg              neg_st   [0:ITER_W-1];
    reg              vld_st   [0:ITER_W-1];

    wire [P_W-1:0] magnitude_out = acc_st[ITER_W-1];
    wire [P_W-1:0] result_bits = neg_st[ITER_W-1]
                                 ? (~magnitude_out + 1'b1) : magnitude_out;

    integer j;

    initial begin
        if (A_W < 1)
            $error("VPU_MUL_US_PIPE: A_W must be >= 1");
        if (B_W < 1)
            $error("VPU_MUL_US_PIPE: B_W must be >= 1");
        if (ITERATE_SEL < 0 || ITERATE_SEL > 2)
            $error("VPU_MUL_US_PIPE: ITERATE_SEL must be 0, 1 or 2");
    end

    always@(posedge clk) begin
        if (reset) begin
            a_r   <= {A_W{1'b0}};
            b_r   <= {B_W{1'b0}};
            vin_r <= 1'b0;
        end else begin
            a_r   <= a;
            b_r   <= b;
            vin_r <= valid_in;
        end
    end

    always@(posedge clk) begin
        if (reset) begin
            for (j = 0; j < ITER_W; j = j + 1) begin
                acc_st[j]   <= {P_W{1'b0}};
                mcand_st[j] <= {P_W{1'b0}};
                mp_st[j]    <= {ITER_W{1'b0}};
                neg_st[j]   <= 1'b0;
                vld_st[j]   <= 1'b0;
            end
        end else begin
            vld_st[0] <= vin_r;
            neg_st[0] <= b_r[B_W-1];
            if (ITERATE_A) begin
                mp_st[0]    <= a_r >> 1;
                mcand_st[0] <= {{A_W{1'b0}}, b_mag} << 1;
                acc_st[0]   <= vin_r && a_r[0]
                             ? {{A_W{1'b0}}, b_mag} : {P_W{1'b0}};
            end else begin
                mp_st[0]    <= b_mag >> 1;
                mcand_st[0] <= {{B_W{1'b0}}, a_r} << 1;
                acc_st[0]   <= vin_r && b_mag[0]
                             ? {{B_W{1'b0}}, a_r} : {P_W{1'b0}};
            end

            for (j = 1; j < ITER_W; j = j + 1) begin
                vld_st[j]   <= vld_st[j-1];
                neg_st[j]   <= neg_st[j-1];
                mp_st[j]    <= mp_st[j-1] >> 1;
                mcand_st[j] <= mcand_st[j-1] << 1;
                acc_st[j]   <= vld_st[j-1]
                             ? acc_st[j-1]
                               + (mp_st[j-1][0] ? mcand_st[j-1] : {P_W{1'b0}})
                             : {P_W{1'b0}};
            end
        end
    end

    always@(posedge clk) begin
        if (reset) begin
            valid_out <= 1'b0;
            prod      <= {P_W{1'b0}};
        end else begin
            valid_out <= vld_st[ITER_W-1];
            prod      <= result_bits;
        end
    end

endmodule
