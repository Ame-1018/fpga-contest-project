`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Create Date: 2026/10/20
// Module Name: UART_PHY
// Description: 8N1 字节收发。RX 两级同步，起始位下降沿后在位中点采样。
//              BAUD_DIV 是一个比特占用的时钟数。
//////////////////////////////////////////////////////////////////////////////////

module UART_PHY #(
    parameter integer           BAUD_DIV                    = 293
)(
    input   wire                clk                             ,
    input   wire                reset                           ,

    input   wire                rx_pin                          ,
    output  wire                tx_pin                          ,

    input   wire                tx_valid                        ,
    input   wire    [7:0]       tx_data                         ,
    output  wire                tx_ready                        ,

    output  reg                 rx_valid                        ,
    output  reg     [7:0]       rx_data
);

localparam                      TX_IDLE                     = 2'd0;
localparam                      TX_START                    = 2'd1;
localparam                      TX_DATA                     = 2'd2;
localparam                      TX_STOP                     = 2'd3;
localparam                      RX_IDLE                     = 2'd0;
localparam                      RX_START                    = 2'd1;
localparam                      RX_DATA                     = 2'd2;
localparam                      RX_STOP                     = 2'd3;
localparam integer              HALF_DIV                    = BAUD_DIV / 2;

reg             [1:0]           tx_st                           ;
reg             [15:0]          tx_cnt                          ;
reg             [2:0]           tx_bit                          ;
reg             [7:0]           tx_shift                        ;
reg                             tx_r                            ;

reg                             rx_ff1                          ;
reg                             rx_ff2                          ;
reg                             rx_ff3                          ;
reg             [1:0]           rx_st                           ;
reg             [15:0]          rx_cnt                          ;
reg             [2:0]           rx_bit                          ;
reg             [7:0]           rx_shift                        ;

wire                            rx_fall                         ;

assign tx_pin   = tx_r;
assign tx_ready = (tx_st == TX_IDLE);
assign rx_fall  = rx_ff3 & ~rx_ff2;

always @(posedge clk) begin
    if(reset) begin
        tx_st    <= TX_IDLE;
        tx_cnt   <= 16'd0;
        tx_bit   <= 3'd0;
        tx_shift <= 8'd0;
        tx_r     <= 1'b1;
    end
    else begin
        case(tx_st)
            TX_IDLE: begin
                tx_r <= 1'b1;
                if(tx_valid) begin
                    tx_shift <= tx_data;
                    tx_bit   <= 3'd0;
                    tx_cnt   <= BAUD_DIV[15:0] - 16'd1;
                    tx_r     <= 1'b0;
                    tx_st    <= TX_START;
                end
            end
            TX_START: begin
                tx_r <= 1'b0;
                if(tx_cnt == 16'd0) begin
                    tx_cnt <= BAUD_DIV[15:0] - 16'd1;
                    tx_r   <= tx_shift[0];
                    tx_st  <= TX_DATA;
                end
                else begin
                    tx_cnt <= tx_cnt - 16'd1;
                end
            end
            TX_DATA: begin
                tx_r <= tx_shift[0];
                if(tx_cnt == 16'd0) begin
                    tx_shift <= {1'b0, tx_shift[7:1]};
                    tx_cnt   <= BAUD_DIV[15:0] - 16'd1;
                    if(tx_bit == 3'd7) begin
                        tx_r  <= 1'b1;
                        tx_st <= TX_STOP;
                    end
                    else begin
                        tx_bit <= tx_bit + 3'd1;
                        tx_r   <= tx_shift[1];
                    end
                end
                else begin
                    tx_cnt <= tx_cnt - 16'd1;
                end
            end
            default: begin
                tx_r <= 1'b1;
                if(tx_cnt == 16'd0) begin
                    tx_st <= TX_IDLE;
                end
                else begin
                    tx_cnt <= tx_cnt - 16'd1;
                end
            end
        endcase
    end
end

always @(posedge clk) begin
    if(reset) begin
        rx_ff1   <= 1'b1;
        rx_ff2   <= 1'b1;
        rx_ff3   <= 1'b1;
        rx_st    <= RX_IDLE;
        rx_cnt   <= 16'd0;
        rx_bit   <= 3'd0;
        rx_shift <= 8'd0;
        rx_valid <= 1'b0;
        rx_data  <= 8'd0;
    end
    else begin
        rx_ff1   <= rx_pin;
        rx_ff2   <= rx_ff1;
        rx_ff3   <= rx_ff2;
        rx_valid <= 1'b0;

        case(rx_st)
            RX_IDLE: begin
                if(rx_fall) begin
                    rx_cnt <= HALF_DIV[15:0] - 16'd1;
                    rx_st  <= RX_START;
                end
            end
            RX_START: begin
                if(rx_cnt == 16'd0) begin
                    if(rx_ff2 == 1'b0) begin
                        rx_cnt  <= BAUD_DIV[15:0] - 16'd1;
                        rx_bit  <= 3'd0;
                        rx_st   <= RX_DATA;
                    end
                    else begin
                        rx_st <= RX_IDLE;
                    end
                end
                else begin
                    rx_cnt <= rx_cnt - 16'd1;
                end
            end
            RX_DATA: begin
                if(rx_cnt == 16'd0) begin
                    rx_shift <= {rx_ff2, rx_shift[7:1]};
                    rx_cnt   <= BAUD_DIV[15:0] - 16'd1;
                    if(rx_bit == 3'd7) begin
                        rx_st <= RX_STOP;
                    end
                    else begin
                        rx_bit <= rx_bit + 3'd1;
                    end
                end
                else begin
                    rx_cnt <= rx_cnt - 16'd1;
                end
            end
            default: begin
                if(rx_cnt == 16'd0) begin
                    if(rx_ff2 == 1'b1) begin
                        rx_data  <= rx_shift;
                        rx_valid <= 1'b1;
                    end
                    rx_st <= RX_IDLE;
                end
                else begin
                    rx_cnt <= rx_cnt - 16'd1;
                end
            end
        endcase
    end
end

endmodule
