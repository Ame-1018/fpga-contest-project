`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: EG4_SDRAM_SCALE_RD
// Description: 按源行号读取一行。picture 是当前图，picture2 是下一张。
//              line_pic 为 0 读当前图，为 1 读下一张。两个图片号在场同步锁存。
//              字地址 = 行号 × (3×宽/4)，三个 32 位字还原 4 个像素。
//              刷新保持期间不开始新的突发。像素经异步 FIFO 交到 75 MHz。
//////////////////////////////////////////////////////////////////////////////////

module EG4_SDRAM_SCALE_RD(
    input   wire                clk                         ,
    input   wire                clk_pix                     ,
    input   wire                reset                       ,
    input   wire                flush                       ,

    input   wire                enable                      ,
    input   wire                vsync                       ,
    input   wire    [2:0]       picture                     ,
    input   wire    [2:0]       picture2                    ,
    input   wire                line_pic                    ,
    input   wire    [12:0]      src_w                       ,
    input   wire                init_done                   ,
    input   wire                ref_vld                     ,
    input   wire                ref_hold                    ,

    input   wire                line_req                    ,
    input   wire    [12:0]      line_y                      ,
    input   wire    [1:0]       line_bank                   ,
    output  reg                 line_ack                    ,

    output  reg                 arbit_req                   ,
    output  reg                 arbit_end                   ,
    input   wire                arbit_allow                 ,

    output  reg                 App_rd_en                   ,
    output  reg     [20:0]      App_rd_addr                 ,
    input   wire                Sdr_rd_en                   ,
    input   wire    [31:0]      Sdr_rd_dout                 ,

    input   wire                pix_re                      ,
    output  wire    [23:0]      pix_data                    ,
    output  wire                pix_empty                   ,
    output  wire                pix_valid
);

reg             [2:0]           req_s                       ;
reg             [3:0]           vs_s                        ;
reg             [2:0]           pic_hold                    ;
reg             [2:0]           pic2_hold                   ;
reg             [2:0]           pic_sel_s                   ;
reg             [12:0]          width_hold                  ;
reg                             en_s                        ;
reg                             flush_s                     ;
reg                             busy                        ;
reg             [12:0]          y_q                         ;
reg             [1:0]           bank_q                      ;
reg             [2:0]           pic_q                       ;
reg             [12:0]          width_q                     ;
reg             [12:0]          col_words                   ;
reg             [17:0]          line_base                   ;
reg             [12:0]          word_left                   ;
reg             [12:0]          burst_left                  ;
reg             [12:0]          burst_sent                  ;
reg             [12:0]          burst_got                   ;
reg             [17:0]          word_addr                   ;
reg                             burst_on                    ;
reg             [2:0]           allow_s                     ;

reg             [31:0]          wmem [0:511]                ;
reg             [9:0]           wwr                         ;
reg             [9:0]           wrd                         ;
reg                             sdr_dv_r                    ;
reg             [31:0]          sdr_data_r                  ;
wire            [9:0]           wcount                      ;
wire                            wempty                      ;

reg             [1:0]           grab                        ;
reg             [31:0]          word_r                      ;
reg             [31:0]          word_g                      ;
reg             [31:0]          word_b                      ;
reg             [1:0]           emit_i                      ;
reg                             emit_on                     ;
reg             [12:0]          pix_i                       ;
reg                             pix_we                      ;
reg             [23:0]          pix_di                      ;
wire                            pix_full                    ;
wire            [9:0]           pix_wrused                  ;

assign wcount = wwr - wrd;
assign wempty = (wwr == wrd);

always@(posedge clk) begin
    if(reset) begin
        req_s      <= 3'd0;
        vs_s       <= 4'd0;
        pic_hold   <= 3'd0;
        pic2_hold  <= 3'd1;
        pic_sel_s  <= 3'd0;
        width_hold <= 13'd640;
        en_s       <= 1'b0;
        flush_s    <= 1'b0;
        allow_s    <= 3'd0;
    end
    else begin
        req_s   <= {req_s[1:0], line_req};
        vs_s    <= {vs_s[2:0], vsync};
        en_s    <= enable;
        flush_s <= flush;
        allow_s <= {allow_s[1:0], arbit_allow};
        pic_sel_s <= {pic_sel_s[1:0], line_pic};
        // 图片号在场同步后还要再打一拍才送到这路。锁存再晚一拍，
        // 否则转场结束的下一场会读到旧的当前图，画面往回闪一帧。
        if(vs_s[2] && !vs_s[3]) begin
            pic_hold   <= picture;
            pic2_hold  <= picture2;
            width_hold <= src_w;
        end
    end
end

wire allow_pos = allow_s[0] && !allow_s[1];

always@(posedge clk) begin
    if(reset || flush_s) begin
        busy        <= 1'b0;
        line_ack    <= 1'b0;
        y_q         <= 13'd0;
        bank_q      <= 2'd0;
        pic_q       <= 3'd0;
        width_q     <= 13'd0;
        col_words   <= 13'd0;
        line_base   <= 18'd0;
        word_left   <= 13'd0;
        burst_left  <= 13'd0;
        burst_sent  <= 13'd0;
        burst_got   <= 13'd0;
        word_addr   <= 18'd0;
        burst_on    <= 1'b0;
        arbit_req   <= 1'b0;
        App_rd_en   <= 1'b0;
        App_rd_addr <= 21'd0;
        arbit_end   <= busy | arbit_req | burst_on;
        wwr         <= 10'd0;
        wrd         <= 10'd0;
        sdr_dv_r    <= 1'b0;
        sdr_data_r  <= 32'd0;
        grab        <= 2'd0;
        emit_i      <= 2'd0;
        emit_on     <= 1'b0;
        pix_i       <= 13'd0;
        pix_we      <= 1'b0;
        pix_di      <= 24'd0;
        word_r      <= 32'd0;
        word_g      <= 32'd0;
        word_b      <= 32'd0;
    end
    else begin
        sdr_dv_r   <= Sdr_rd_en;
        sdr_data_r <= Sdr_rd_dout;
        arbit_end  <= 1'b0;
        pix_we     <= 1'b0;

        if(sdr_dv_r && (wcount < 10'd511)) begin
            wmem[wwr[8:0]] <= sdr_data_r;
            wwr <= wwr + 10'd1;
            burst_got <= burst_got + 13'd1;
        end

        if(!req_s[1])
            line_ack <= 1'b0;

        if(!busy && req_s[2] && !line_ack && en_s && init_done && !ref_hold && !ref_vld) begin
            busy       <= 1'b1;
            line_ack   <= 1'b1;
            y_q        <= line_y;
            bank_q     <= line_bank;
            pic_q      <= pic_sel_s[2] ? pic2_hold : pic_hold;
            width_q    <= width_hold;
            col_words  <= {1'b0, width_hold[12:2]} + {width_hold[12:2], 1'b0};
            line_base  <= line_y * ({1'b0, width_hold[12:2]} + {width_hold[12:2], 1'b0});
            word_left  <= {1'b0, width_hold[12:2]} + {width_hold[12:2], 1'b0};
            word_addr  <= line_y * ({1'b0, width_hold[12:2]} + {width_hold[12:2], 1'b0});
            burst_on   <= 1'b0;
            burst_left <= 13'd0;
            burst_sent <= 13'd0;
            burst_got  <= 13'd0;
            pix_i      <= 13'd0;
            grab       <= 2'd0;
            emit_on    <= 1'b0;
            wwr        <= 10'd0;
            wrd        <= 10'd0;
        end
        else if(busy) begin
            if(!burst_on && !arbit_req && (burst_sent == 13'd0) && (word_left != 13'd0) &&
               !ref_hold && !ref_vld && (wcount < 10'd320)) begin
                arbit_req  <= 1'b1;
                burst_left <= (word_left > 13'd128) ? 13'd128 : word_left;
            end
            if(arbit_req && allow_pos) begin
                arbit_req <= 1'b0;
                burst_on  <= 1'b1;
            end
            if(burst_on) begin
                if(burst_sent == burst_left) begin
                    burst_on  <= 1'b0;
                    App_rd_en <= 1'b0;
                end
                else begin
                    App_rd_en   <= 1'b1;
                    App_rd_addr <= {pic_q, word_addr};
                    word_addr   <= word_addr + 18'd1;
                    burst_sent  <= burst_sent + 13'd1;
                    word_left   <= word_left - 13'd1;
                end
            end
            else
                App_rd_en <= 1'b0;

            if(!burst_on && (burst_sent != 13'd0) && (burst_got == burst_sent)) begin
                arbit_end  <= 1'b1;
                burst_sent <= 13'd0;
                burst_got  <= 13'd0;
            end

            if(!emit_on && (grab < 2'd3) && !wempty && (pix_wrused < 10'd900)) begin
                case(grab)
                    2'd0: word_r <= wmem[wrd[8:0]];
                    2'd1: word_g <= wmem[wrd[8:0]];
                    default: word_b <= wmem[wrd[8:0]];
                endcase
                wrd  <= wrd + 10'd1;
                grab <= grab + 2'd1;
                if(grab == 2'd2)
                    emit_on <= 1'b1;
            end
            if(emit_on && (pix_wrused < 10'd900)) begin
                pix_we <= 1'b1;
                case(emit_i)
                    2'd0: pix_di <= {word_r[31:24], word_g[31:24], word_b[31:24]};
                    2'd1: pix_di <= {word_r[23:16], word_g[23:16], word_b[23:16]};
                    2'd2: pix_di <= {word_r[15:8],  word_g[15:8],  word_b[15:8]};
                    default: pix_di <= {word_r[7:0], word_g[7:0], word_b[7:0]};
                endcase
                if(emit_i == 2'd3) begin
                    emit_i  <= 2'd0;
                    emit_on <= 1'b0;
                    grab    <= 2'd0;
                end
                else
                    emit_i <= emit_i + 2'd1;
                pix_i <= pix_i + 13'd1;
            end

            if((pix_i == width_q) && (word_left == 13'd0) && !burst_on &&
               (burst_got == burst_sent) && wempty && !emit_on && (grab == 2'd0))
                busy <= 1'b0;
        end
    end
end

asfifo_hdmi_driver u_pix_fifo(
    .rst        (reset | flush_s    ),
    .di         (pix_di             ),
    .clkr       (clk_pix            ),
    .re         (pix_re             ),
    .clkw       (clk                ),
    .we         (pix_we && !pix_full),
    .dout       (pix_data           ),
    .empty_flag (pix_empty          ),
    .aempty     (),
    .full_flag  (pix_full           ),
    .afull      (),
    .valid      (pix_valid          ),
    .overflow   (),
    .underflow  (),
    .wr_success (),
    .rdusedw    (),
    .wrusedw    (pix_wrused         ),
    .wr_rst_done(),
    .rd_rst_done()
);

endmodule
