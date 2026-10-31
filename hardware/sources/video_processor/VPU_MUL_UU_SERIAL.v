`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Create Date: 2026/10/19 10:20:00
// Design Name: 
// Module Name: VPU_MUL_UU_SERIAL
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

module VPU_MUL_UU_SERIAL #(
    parameter integer A_W         = 13,
    parameter integer B_W         = 16,
    parameter integer ITERATE_SEL = 0
)(
    input  wire                     clk,
    input  wire                     reset,

    input  wire                     valid_in,
    input  wire [A_W-1:0]           a,
    input  wire [B_W-1:0]           b,

    output reg                      valid_out,
    output reg  [A_W+B_W-1:0]       prod,
    output reg                      busy
);

    localparam integer P_W = A_W + B_W;
    localparam integer ITERATE_A =
        (ITERATE_SEL == 1) ? 1 :
        (ITERATE_SEL == 2) ? 0 : (A_W <= B_W);
    localparam integer ITER_W = ITERATE_A ? A_W : B_W;
    localparam integer STEP_W = (ITER_W <= 1) ? 1 : $clog2(ITER_W);

    reg [STEP_W-1:0] step;
    reg [P_W-1:0]    acc;
    reg [P_W-1:0]    mcand;
    reg [ITER_W-1:0] mp;

    wire [P_W-1:0] addend   = mp[0] ? mcand : {P_W{1'b0}};
    wire [P_W-1:0] acc_next = acc + addend;

    initial begin
        if (A_W < 1)
            $error("VPU_MUL_UU_SERIAL: A_W must be >= 1");
        if (B_W < 1)
            $error("VPU_MUL_UU_SERIAL: B_W must be >= 1");
        if (ITERATE_SEL < 0 || ITERATE_SEL > 2)
            $error("VPU_MUL_UU_SERIAL: ITERATE_SEL must be 0, 1 or 2");
    end

    always@(posedge clk) begin
        if (reset) begin
            valid_out <= 1'b0;
            prod      <= {P_W{1'b0}};
            busy      <= 1'b0;
            step      <= {STEP_W{1'b0}};
            acc       <= {P_W{1'b0}};
            mcand     <= {P_W{1'b0}};
            mp        <= {ITER_W{1'b0}};
        end else begin
            valid_out <= 1'b0;

            if (!busy) begin
                if (valid_in) begin
                    busy <= 1'b1;
                    step <= {STEP_W{1'b0}};
                    acc  <= {P_W{1'b0}};

                    if (ITERATE_A) begin
                        mp    <= a;
                        mcand <= {{A_W{1'b0}}, b};
                    end else begin
                        mp    <= b;
                        mcand <= {{B_W{1'b0}}, a};
                    end
                end
            end else begin
                if (step == ITER_W-1) begin
                    prod      <= acc_next;
                    valid_out <= 1'b1;
                    busy      <= 1'b0;
                end else begin
                    acc   <= acc_next;
                    mcand <= mcand << 1;
                    mp    <= mp >> 1;
                    step  <= step + 1'b1;
                end
            end
        end
    end

endmodule
