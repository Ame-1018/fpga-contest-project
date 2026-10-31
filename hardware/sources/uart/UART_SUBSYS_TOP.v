`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Create Date: 2026/10/20
// Module Name: UART_SUBSYS_TOP
// Description: 256000 8N1。解析 VPU 参数帧，复位后给出可出图的默认值。
//              0x21 在 CRC 通过后每个时钟写 1 个 32bit 字。
//              字幕点阵高 32、宽 2048，地址是字地址 0～2047。
//////////////////////////////////////////////////////////////////////////////////

module UART_SUBSYS_TOP #(
    parameter                   CLK_FREQ                    = 75_000_000
)(
    input   wire                clk                             ,
    input   wire                reset                           ,

    input   wire                key_we                          ,
    input   wire    [5:0]       key_id                          ,
    input   wire    [12:0]      key_data                        ,

    input   wire                vpu_uart_rx                     ,
    output  wire                vpu_uart_tx                     ,

    output  reg                 uart_cut_to_disable             ,
    output  reg     [2:0]       uart_cut_to_mode                ,
    output  reg     [1:0]       uart_cut_to_speed               ,

    output  reg                 uart_dis_eff_disable            ,
    output  reg     [7:0]       uart_lumi_set_data              ,
    output  reg     [7:0]       uart_contrast_set_data          ,
    output  reg     [7:0]       uart_temp_set_data              ,
    output  reg     [7:0]       uart_tint_set_data              ,

    output  reg                 uart_osd_disable                ,
    output  reg     [12:0]      uart_osd_logo_sx                ,
    output  reg     [12:0]      uart_osd_logo_sy                ,

    output  reg     [12:0]      uart_osd_txt_sx                 ,
    output  reg     [12:0]      uart_osd_txt_sy                 ,
    output  reg     [12:0]      uart_osd_txt_x_area             ,
    output  reg     [1:0]       uart_osd_txt_speed              ,
    output  reg     [1:0]       uart_osd_color_mode             ,
    output  reg     [23:0]      uart_osd_color_set              ,

    output  reg                 uart_osd_txtram_disable         ,
    output  reg                 uart_osd_txtram_dv              ,
    output  reg     [31:0]      uart_osd_txtram_data            ,
    output  reg     [10:0]      uart_osd_txtram_addr            ,

    output  reg                 uart_vpu_audio_disable          ,
    output  reg     [1:0]       uart_vpu_audio_mode             ,
    output  reg     [1:0]       uart_vpu_audio_color_mode       ,
    output  reg     [23:0]      uart_vpu_audio_color_data       ,
    output  reg     [12:0]      uart_vpu_audio_sx               ,
    output  reg     [12:0]      uart_vpu_audio_sy               ,

    output  reg                 uart_scaler_disable             ,
    output  reg     [12:0]      uart_scaler_target_width        ,
    output  reg     [12:0]      uart_scaler_target_height       ,

    output  reg                 uart_style_disable              ,
    output  reg     [2:0]       uart_style_mode                 ,
    output  reg     [7:0]       uart_style_bin_th               ,
    output  reg     [7:0]       uart_style_gamma
);

localparam integer              BAUD_RATE                   = 256000;
localparam integer              BAUD_DIV                    = (CLK_FREQ + (BAUD_RATE / 2)) / BAUD_RATE;
localparam integer              GAP_MAX                     = BAUD_DIV * 80;

localparam                      S_SYNC0                     = 3'd0;
localparam                      S_SYNC1                     = 3'd1;
localparam                      S_HDR                       = 3'd2;
localparam                      S_PAY                       = 3'd3;
localparam                      S_CRC                       = 3'd4;
localparam                      S_APPLY                     = 3'd5;
localparam                      S_FONT                      = 3'd6;
localparam                      S_REPLY                     = 3'd7;

reg             [2:0]           st                              ;
reg             [7:0]           wr_data                         ;
reg             [5:0]           wr_addr                         ;
reg                             wr_en                           ;
reg                             reply_go                        ;
reg             [23:0]          gap_cnt                         ;
reg             [2:0]           hdr_i                           ;
reg             [7:0]           rx_ver                          ;
reg             [7:0]           rx_seq                          ;
reg             [7:0]           rx_cmd                          ;
reg             [15:0]          rx_len                          ;
reg             [6:0]           pay_i                           ;
reg                             crc_i                           ;
reg             [7:0]           pay             [0:65]          ;
reg             [15:0]          calc_crc                        ;
reg             [7:0]           crc_lo                          ;
reg                             crc_match                       ;

reg                             txt_saved                       ;
reg             [10:0]          font_base                       ;
reg             [6:0]           font_n                          ;
reg             [6:0]           font_i                          ;

reg             [7:0]           rcode                           ;
reg             [6:0]           rlen                            ;
reg             [7:0]           rseq                            ;
reg             [7:0]           rcmd                            ;
reg             [5:0]           rp                              ;
reg             [15:0]          reply_crc                       ;
reg             [5:0]           tx_hold_len                     ;

reg             [5:0]           tx_len                          ;
reg             [5:0]           tx_idx                          ;

wire                            rx_valid                        ;
wire            [7:0]           rx_data                         ;
wire                            tx_ready                        ;
wire                            tx_busy                         ;
wire                            receiving                       ;

assign tx_busy    = (tx_idx != tx_len);
assign receiving  = (st == S_SYNC1) || (st == S_HDR) || (st == S_PAY) || (st == S_CRC);

function [15:0] crc16_byte;
    input [15:0] crc;
    input [7:0]  data;
    integer      i;
    reg   [15:0] c;
    begin
        c = crc ^ {data, 8'h00};
        for(i = 0; i < 8; i = i + 1) begin
            if(c[15])
                c = {c[14:0], 1'b0} ^ 16'h1021;
            else
                c = {c[14:0], 1'b0};
        end
        crc16_byte = c;
    end
endfunction

function [7:0] reply_pay;
    input [5:0] idx;
    begin
        if(idx == 6'd0)
            reply_pay = rcode;
        else if((rcmd == 8'h01) && (idx == 6'd1))
            reply_pay = 8'h01;
        else if(rcmd == 8'h02) begin
            case(idx)
                6'd1:  reply_pay = {7'd0, uart_cut_to_disable};
                6'd2:  reply_pay = {5'd0, uart_cut_to_mode};
                6'd3:  reply_pay = {6'd0, uart_cut_to_speed};
                6'd4:  reply_pay = {7'd0, uart_dis_eff_disable};
                6'd5:  reply_pay = uart_lumi_set_data;
                6'd6:  reply_pay = uart_contrast_set_data;
                6'd7:  reply_pay = uart_temp_set_data;
                6'd8:  reply_pay = uart_tint_set_data;
                6'd9:  reply_pay = {7'd0, uart_osd_disable};
                6'd10: reply_pay = uart_osd_logo_sx[7:0];
                6'd11: reply_pay = {3'd0, uart_osd_logo_sx[12:8]};
                6'd12: reply_pay = uart_osd_logo_sy[7:0];
                6'd13: reply_pay = {3'd0, uart_osd_logo_sy[12:8]};
                6'd14: reply_pay = uart_osd_txt_sx[7:0];
                6'd15: reply_pay = {3'd0, uart_osd_txt_sx[12:8]};
                6'd16: reply_pay = uart_osd_txt_sy[7:0];
                6'd17: reply_pay = {3'd0, uart_osd_txt_sy[12:8]};
                6'd18: reply_pay = uart_osd_txt_x_area[7:0];
                6'd19: reply_pay = {3'd0, uart_osd_txt_x_area[12:8]};
                6'd20: reply_pay = {6'd0, uart_osd_txt_speed};
                6'd21: reply_pay = {6'd0, uart_osd_color_mode};
                6'd22: reply_pay = uart_osd_color_set[23:16];
                6'd23: reply_pay = uart_osd_color_set[15:8];
                6'd24: reply_pay = uart_osd_color_set[7:0];
                6'd25: reply_pay = {7'd0, uart_osd_txtram_disable};
                6'd26: reply_pay = {7'd0, uart_vpu_audio_disable};
                6'd27: reply_pay = {6'd0, uart_vpu_audio_mode};
                6'd28: reply_pay = {7'd0, uart_scaler_disable};
                6'd29: reply_pay = uart_scaler_target_width[7:0];
                6'd30: reply_pay = {3'd0, uart_scaler_target_width[12:8]};
                6'd31: reply_pay = uart_scaler_target_height[7:0];
                6'd32: reply_pay = {3'd0, uart_scaler_target_height[12:8]};
                6'd33: reply_pay = {6'd0, uart_vpu_audio_color_mode};
                6'd34: reply_pay = uart_vpu_audio_color_data[23:16];
                6'd35: reply_pay = uart_vpu_audio_color_data[15:8];
                6'd36: reply_pay = uart_vpu_audio_color_data[7:0];
                6'd37: reply_pay = uart_vpu_audio_sx[7:0];
                6'd38: reply_pay = {3'd0, uart_vpu_audio_sx[12:8]};
                6'd39: reply_pay = uart_vpu_audio_sy[7:0];
                6'd40: reply_pay = {3'd0, uart_vpu_audio_sy[12:8]};
                6'd41: reply_pay = {7'd0, uart_style_disable};
                6'd42: reply_pay = {5'd0, uart_style_mode};
                6'd43: reply_pay = uart_style_bin_th;
                6'd44: reply_pay = uart_style_gamma;
                default: reply_pay = 8'h00;
            endcase
        end
        else
            reply_pay = 8'h00;
    end
endfunction

wire [5:0] tx_rd = reply_go ? 6'd0 : tx_idx;
wire [7:0] tx_q;

simple_dual_ram #(
    .RAM_WIDTH                  (8                          ),
    .RAM_DEPTH                  (64                         ),
    .PERFORMENCE                ("LOW"                      )
)U_TX(
    .clka                       (clk                        ),
    .wea                        (wr_en                      ),
    .dina                       (wr_data                    ),
    .addra                      (wr_addr                    ),
    .addrb                      (tx_rd                      ),
    .doutb                      (tx_q                       )
);

UART_PHY #(
    .BAUD_DIV                   (BAUD_DIV                   )
)UART_PHY(
    .clk                        (clk                        ),
    .reset                      (reset                      ),
    .rx_pin                     (vpu_uart_rx                ),
    .tx_pin                     (vpu_uart_tx                ),
    .tx_valid                   (tx_busy                    ),
    .tx_data                    (tx_q                       ),
    .tx_ready                   (tx_ready                   ),
    .rx_valid                   (rx_valid                   ),
    .rx_data                    (rx_data                    )
);

always @(posedge clk) begin
    if(reset) begin
        st                          <= S_SYNC0;
        gap_cnt                     <= 24'd0;
        hdr_i                       <= 3'd0;
        rx_ver                      <= 8'd0;
        rx_seq                      <= 8'd0;
        rx_cmd                      <= 8'd0;
        rx_len                      <= 16'd0;
        pay_i                       <= 7'd0;
        crc_i                       <= 1'b0;
        calc_crc                    <= 16'hFFFF;
        crc_lo                      <= 8'd0;
        crc_match                   <= 1'b0;
        txt_saved                   <= 1'b0;
        font_base                   <= 11'd0;
        font_n                      <= 7'd0;
        font_i                      <= 7'd0;
        rlen                        <= 7'd0;
        rseq                        <= 8'd0;
        rcmd                        <= 8'd0;
        rcode                       <= 8'd0;
        rp                          <= 6'd0;
        reply_crc                   <= 16'hFFFF;
        tx_hold_len                 <= 6'd0;
        tx_len                      <= 6'd0;
        tx_idx                      <= 6'd0;
        wr_en                       <= 1'b0;
        reply_go                    <= 1'b0;

        uart_cut_to_disable         <= 1'b0;
        uart_cut_to_mode            <= 3'd1;
        uart_cut_to_speed           <= 2'd0;
        uart_dis_eff_disable        <= 1'b0;
        uart_lumi_set_data          <= 8'd128;
        uart_contrast_set_data      <= 8'd128;
        uart_temp_set_data          <= 8'd128;
        uart_tint_set_data          <= 8'd128;
        uart_osd_disable            <= 1'b0;
        uart_osd_logo_sx            <= 13'd12;
        uart_osd_logo_sy            <= 13'd12;
        uart_osd_txt_sx             <= 13'd80;
        uart_osd_txt_sy             <= 13'd400;
        uart_osd_txt_x_area         <= 13'd480;
        uart_osd_txt_speed          <= 2'd1;
        uart_osd_color_mode         <= 2'd0;
        uart_osd_color_set          <= 24'hFFFFFF;
        uart_osd_txtram_disable     <= 1'b0;
        uart_osd_txtram_dv          <= 1'b0;
        uart_osd_txtram_data        <= 32'd0;
        uart_osd_txtram_addr        <= 11'd0;
        uart_vpu_audio_disable      <= 1'b0;
        uart_vpu_audio_mode         <= 2'd0;
        uart_vpu_audio_color_mode   <= 2'd0;
        uart_vpu_audio_color_data   <= 24'h00E5FF;
        uart_vpu_audio_sx           <= 13'd0;
        uart_vpu_audio_sy           <= 13'd353;
        uart_scaler_disable         <= 1'b0;
        uart_scaler_target_width    <= 13'd640;
        uart_scaler_target_height   <= 13'd480;
        uart_style_disable          <= 1'b0;
        uart_style_mode             <= 3'd0;
        uart_style_bin_th           <= 8'd128;
        uart_style_gamma            <= 8'd128;
    end
    else begin
        if(tx_ready && tx_busy)
            tx_idx <= tx_idx + 6'd1;

        wr_en  <= 1'b0;

        uart_osd_txtram_dv <= 1'b0;

        if(rx_valid && (receiving || (st == S_SYNC0))) begin
            gap_cnt <= 24'd0;
            case(st)
                S_SYNC0: begin
                    if(rx_data == 8'hA5)
                        st <= S_SYNC1;
                end
                S_SYNC1: begin
                    if(rx_data == 8'h5A) begin
                        st    <= S_HDR;
                        hdr_i <= 3'd0;
                    end
                    else if(rx_data != 8'hA5) begin
                        st <= S_SYNC0;
                    end
                end
                S_HDR: begin
                    case(hdr_i)
                        3'd0: begin
                            rx_ver   <= rx_data;
                            calc_crc <= crc16_byte(16'hFFFF, rx_data);
                        end
                        3'd1: begin
                            rx_seq   <= rx_data;
                            calc_crc <= crc16_byte(calc_crc, rx_data);
                        end
                        3'd2: begin
                            rx_cmd   <= rx_data;
                            calc_crc <= crc16_byte(calc_crc, rx_data);
                        end
                        3'd3: begin
                            calc_crc <= crc16_byte(calc_crc, rx_data);
                        end
                        3'd4: begin
                            rx_len[7:0] <= rx_data;
                            calc_crc    <= crc16_byte(calc_crc, rx_data);
                        end
                        default: begin
                            calc_crc <= crc16_byte(calc_crc, rx_data);
                            rx_len   <= {rx_data, rx_len[7:0]};
                            pay_i    <= 7'd0;
                            if({rx_data, rx_len[7:0]} > 16'd66 ||
                               ((rx_cmd != 8'h21) && ({rx_data, rx_len[7:0]} > 16'd64))) begin
                                st <= S_SYNC0;
                            end
                            else if({rx_data, rx_len[7:0]} == 16'd0) begin
                                crc_i <= 1'b0;
                                st    <= S_CRC;
                            end
                            else begin
                                st <= S_PAY;
                            end
                        end
                    endcase
                    if(hdr_i != 3'd5)
                        hdr_i <= hdr_i + 3'd1;
                end
                S_PAY: begin
                    pay[pay_i] <= rx_data;
                    calc_crc   <= crc16_byte(calc_crc, rx_data);
                    if(pay_i + 7'd1 == rx_len[6:0]) begin
                        crc_i <= 1'b0;
                        st    <= S_CRC;
                    end
                    else begin
                        pay_i <= pay_i + 7'd1;
                    end
                end
                S_CRC: begin
                    if(crc_i == 1'b0) begin
                        crc_lo <= rx_data;
                        crc_i  <= 1'b1;
                    end
                    else begin
                        crc_match <= ({rx_data, crc_lo} == calc_crc);
                        crc_i     <= 1'b0;
                        st        <= S_APPLY;
                    end
                end
                default: begin
                end
            endcase
        end
        else if(receiving && (gap_cnt >= GAP_MAX)) begin
            st      <= S_SYNC0;
            gap_cnt <= 24'd0;
        end
        else if(receiving) begin
            gap_cnt <= gap_cnt + 24'd1;
        end
        else if(st == S_APPLY) begin
            if(tx_busy) begin
                st <= S_APPLY;
            end
            else begin
                rseq <= rx_seq;
                rcmd <= rx_cmd;
                begin : apply_frame
                    reg [7:0]  code;
                    reg [15:0] a0;
                    reg [15:0] a1;
                    reg [15:0] a2;
                    reg [16:0] span;
                    code = 8'd0;
                    a0   = 16'd0;
                    a1   = 16'd0;
                    a2   = 16'd0;
                    span = 17'd0;
                    if(!crc_match)
                        code = 8'd1;
                    else if(rx_ver != 8'h01)
                        code = 8'd3;
                    else begin
                        case(rx_cmd)
                            8'h01, 8'h02, 8'h20, 8'h22: begin
                                if(rx_len != 16'd0)
                                    code = 8'd2;
                            end
                            8'h10: begin
                                if(rx_len != 16'd3)
                                    code = 8'd2;
                                else if((pay[1] > 8'd7) || (pay[2] > 8'd3))
                                    code = 8'd4;
                            end
                            8'h11: begin
                                if(rx_len != 16'd5)
                                    code = 8'd2;
                            end
                            8'h12: begin
                                a0 = {pay[2], pay[1]};
                                a1 = {pay[4], pay[3]};
                                if(rx_len != 16'd5)
                                    code = 8'd2;
                                else if((a0 > 16'd8191) || (a1 > 16'd8191))
                                    code = 8'd4;
                            end
                            8'h13: begin
                                a0 = {pay[1], pay[0]};
                                a1 = {pay[3], pay[2]};
                                a2 = {pay[5], pay[4]};
                                if(rx_len != 16'd11)
                                    code = 8'd2;
                                else if((a0 > 16'd8191) || (a1 > 16'd8191) || (a2 > 16'd8191) ||
                                        (pay[6] > 8'd3) || (pay[7] > 8'd3))
                                    code = 8'd4;
                            end
                            8'h14: begin
                                a0 = {pay[7], pay[6]};
                                a1 = {pay[9], pay[8]};
                                if(rx_len != 16'd10)
                                    code = 8'd2;
                                else if((pay[1] > 8'd1) || (pay[2] > 8'd2) ||
                                        (a0 > 16'd8191) || (a1 > 16'd8191))
                                    code = 8'd4;
                            end
                            8'h15: begin
                                a0 = {pay[2], pay[1]};
                                a1 = {pay[4], pay[3]};
                                if(rx_len != 16'd5)
                                    code = 8'd2;
                                else if((a0 == 16'd0) || (a0 > 16'd1280) ||
                                        (a1 == 16'd0) || (a1 > 16'd720))
                                    code = 8'd4;
                            end
                            8'h16: begin
                                if(rx_len != 16'd4)
                                    code = 8'd2;
                                else if(pay[1] > 8'd4)
                                    code = 8'd4;
                            end
                            8'h21: begin
                                a0   = {pay[1], pay[0]};
                                span = {1'b0, a0} + {10'd0, rx_len[8:2]};
                                if((rx_len < 16'd6) || (rx_len > 16'd66) || (rx_len[1:0] != 2'b10))
                                    code = 8'd2;
                                else if(span > 17'd2048)
                                    code = 8'd4;
                            end
                            default: code = 8'd3;
                        endcase
                    end

                    rcode <= code;
                    if((code == 8'd0) && (rx_cmd == 8'h01))
                        rlen <= 7'd2;
                    else if((code == 8'd0) && (rx_cmd == 8'h02))
                        rlen <= 7'd45;
                    else
                        rlen <= 7'd1;

                    if(code == 8'd0) begin
                        case(rx_cmd)
                            8'h10: begin
                                uart_cut_to_disable <= pay[0][0];
                                uart_cut_to_mode    <= pay[1][2:0];
                                uart_cut_to_speed   <= pay[2][1:0];
                            end
                            8'h11: begin
                                uart_dis_eff_disable   <= pay[0][0];
                                uart_lumi_set_data     <= pay[1];
                                uart_contrast_set_data <= pay[2];
                                uart_temp_set_data     <= pay[3];
                                uart_tint_set_data     <= pay[4];
                            end
                            8'h12: begin
                                uart_osd_disable <= pay[0][0];
                                uart_osd_logo_sx <= {pay[2][4:0], pay[1]};
                                uart_osd_logo_sy <= {pay[4][4:0], pay[3]};
                            end
                            8'h13: begin
                                uart_osd_txt_sx       <= {pay[1][4:0], pay[0]};
                                uart_osd_txt_sy       <= {pay[3][4:0], pay[2]};
                                uart_osd_txt_x_area   <= {pay[5][4:0], pay[4]};
                                uart_osd_txt_speed    <= pay[6][1:0];
                                uart_osd_color_mode   <= pay[7][1:0];
                                uart_osd_color_set    <= {pay[8], pay[9], pay[10]};
                            end
                            8'h14: begin
                                uart_vpu_audio_disable    <= pay[0][0];
                                uart_vpu_audio_mode       <= pay[1][1:0];
                                uart_vpu_audio_color_mode <= pay[2][1:0];
                                uart_vpu_audio_color_data <= {pay[3], pay[4], pay[5]};
                                uart_vpu_audio_sx         <= {pay[7][4:0], pay[6]};
                                uart_vpu_audio_sy         <= {pay[9][4:0], pay[8]};
                            end
                            8'h15: begin
                                uart_scaler_disable       <= pay[0][0];
                                uart_scaler_target_width  <= {pay[2][4:0], pay[1]};
                                uart_scaler_target_height <= {pay[4][4:0], pay[3]};
                            end
                            8'h16: begin
                                uart_style_disable <= pay[0][0];
                                uart_style_mode    <= pay[1][2:0];
                                uart_style_bin_th  <= pay[2];
                                uart_style_gamma   <= pay[3];
                            end
                            8'h20: begin
                                txt_saved               <= uart_osd_txtram_disable;
                                uart_osd_txtram_disable <= 1'b1;
                            end
                            8'h22: begin
                                uart_osd_txtram_disable <= txt_saved;
                            end
                            8'h21: begin
                                font_base <= {pay[1][2:0], pay[0]};
                                font_n    <= {2'b0, rx_len[6:2]};
                                font_i    <= 7'd0;
                            end
                            default: begin
                            end
                        endcase
                    end

                    if((code == 8'd0) && (rx_cmd == 8'h21))
                        st <= S_FONT;
                    else begin
                        st <= S_REPLY;
                        rp <= 6'd0;
                    end
                end
            end
        end
        else if(st == S_FONT) begin
            begin : pack_word
                reg [6:0] bi;
                bi = {font_i[4:0], 2'b00} + 7'd2;
                uart_osd_txtram_dv   <= 1'b1;
                uart_osd_txtram_addr <= font_base + {4'd0, font_i};
                uart_osd_txtram_data <= {pay[bi], pay[bi + 7'd1], pay[bi + 7'd2], pay[bi + 7'd3]};
            end
            if(font_i + 7'd1 == font_n) begin
                st <= S_REPLY;
                rp <= 6'd0;
            end
            else begin
                font_i <= font_i + 7'd1;
            end
        end
        else if(st == S_REPLY) begin
            if(reply_go) begin
                tx_len    <= tx_hold_len;
                tx_idx    <= 6'd0;
                reply_go  <= 1'b0;
                st        <= S_SYNC0;
            end
            else if(rp == 6'd0) begin
                reply_crc   <= 16'hFFFF;
                wr_data     <= 8'hA5;
                wr_addr     <= 6'd0;
                wr_en       <= 1'b1;
                rp          <= 6'd1;
            end
            else if(rp <= (6'd6 + {1'b0, rlen[5:0]})) begin
                begin : reply_byte
                    reg [7:0] b;
                    if(rp == 6'd1)       b = 8'h01;
                    else if(rp == 6'd2)  b = rseq;
                    else if(rp == 6'd3)  b = rcmd | 8'h80;
                    else if(rp == 6'd4)  b = 8'h00;
                    else if(rp == 6'd5)  b = rlen;
                    else if(rp == 6'd6)  b = 8'h00;
                    else                 b = reply_pay(rp - 6'd7);
                    wr_data   <= b;
                    wr_addr   <= rp + 6'd1;
                    wr_en     <= 1'b1;
                    reply_crc <= crc16_byte(reply_crc, b);
                end
                rp <= rp + 6'd1;
            end
            else if(rp == (6'd7 + {1'b0, rlen[5:0]})) begin
                wr_data <= reply_crc[7:0];
                wr_addr <= rp + 6'd1;
                wr_en   <= 1'b1;
                rp      <= rp + 6'd1;
            end
            else if(rp == (6'd8 + {1'b0, rlen[5:0]})) begin
                wr_data     <= reply_crc[15:8];
                wr_addr     <= rp + 6'd1;
                wr_en       <= 1'b1;
                tx_hold_len <= rp + 6'd2;
                rp          <= rp + 6'd1;
            end
            else begin
                wr_data  <= 8'h5A;
                wr_addr  <= 6'd1;
                wr_en    <= 1'b1;
                reply_go <= 1'b1;
            end
        end

        if(key_we) begin
            case(key_id)
                6'd0:  uart_cut_to_disable <= key_data[0];
                6'd1:  uart_cut_to_mode <= key_data[2:0];
                6'd2:  uart_cut_to_speed <= key_data[1:0];
                6'd3:  uart_dis_eff_disable <= key_data[0];
                6'd4:  uart_lumi_set_data <= key_data[7:0];
                6'd5:  uart_contrast_set_data <= key_data[7:0];
                6'd6:  uart_temp_set_data <= key_data[7:0];
                6'd7:  uart_tint_set_data <= key_data[7:0];
                6'd8:  uart_style_disable <= key_data[0];
                6'd9:  uart_style_mode <= key_data[2:0];
                6'd10: uart_style_bin_th <= key_data[7:0];
                6'd11: uart_style_gamma <= key_data[7:0];
                6'd12: uart_osd_disable <= key_data[0];
                6'd13: uart_osd_logo_sx <= key_data;
                6'd14: uart_osd_logo_sy <= key_data;
                6'd15: uart_osd_txtram_disable <= key_data[0];
                6'd16: uart_osd_txt_sx <= key_data;
                6'd17: uart_osd_txt_sy <= key_data;
                6'd18: uart_osd_txt_x_area <= key_data;
                6'd19: uart_osd_txt_speed <= key_data[1:0];
                6'd20: uart_osd_color_mode <= key_data[1:0];
                6'd21: uart_osd_color_set[23:16] <= key_data[7:0];
                6'd22: uart_osd_color_set[15:8] <= key_data[7:0];
                6'd23: uart_osd_color_set[7:0] <= key_data[7:0];
                6'd24: uart_vpu_audio_disable <= key_data[0];
                6'd25: uart_vpu_audio_mode <= key_data[1:0];
                6'd26: uart_vpu_audio_color_mode <= key_data[1:0];
                6'd27: uart_vpu_audio_color_data[23:16] <= key_data[7:0];
                6'd28: uart_vpu_audio_color_data[15:8] <= key_data[7:0];
                6'd29: uart_vpu_audio_color_data[7:0] <= key_data[7:0];
                6'd30: uart_vpu_audio_sx <= key_data;
                6'd31: uart_vpu_audio_sy <= key_data;
                6'd32: uart_scaler_disable <= key_data[0];
                6'd33: uart_scaler_target_width <= key_data;
                6'd34: uart_scaler_target_height <= key_data;
                default: begin
                end
            endcase
        end
    end
end

endmodule
