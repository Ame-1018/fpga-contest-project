`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Create Date: 2026/10/11 09:21:17
// Module Name: SDCARD_AUDIO_READ
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
//   BMP 初始化完成后，按索引结构体循环读取 WAV。
//   结构体最多 8 条，序号从 0 起，与数据同时有效。98bit：24 位起始扇区、32 位字节长度、32 位采样率、4 位声道、6 位位深。
//   扇区号零扩展成 32 位再发 CMD17。采样率、声道和位深随结构体保存，读数仍按 44 字节头、16bit 立体声。
//   样本数由 (字节长度-44)/4 得到。放在单口 RAM。样本 FIFO 为异步 32bit x 256。
//   写时钟是 clk，读时钟是 sd_audio_fifo_clk。跨时钟在本模块内完成。
//   存量少于 128 时读一个 512 字节扇区（128 个立体声样本）。
//   固定跳过 44 字节头。16bit 小端立体声，左在 [15:0]，右在 [31:16]。
//   送给音频口时各扩展到 24bit，高 16bit 为样本，低 8bit 为 0。
//   上一首/下一首为单周期脉冲，先清 FIFO 再从头读。
//   FIFO 空时请求返回静音。循环电平只在一首放完时采样。
//   sd_bmp_init_done 拉低时，控制状态、扇区状态和读请求一起回到空闲。
//   切图占用 SD 总线期间，进行中的扇区结束标志不会再送到本模块。
//   done 重新拉高后从第 0 首重新装入并播放。
//   不处理 sd_audio_r_err。
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module SDCARD_AUDIO_READ #(
    parameter                   CLK_FREQ                    = 50_000_000
)(
    input   wire                clk                         ,
    input   wire                reset                       ,

    input   wire                sd_bmp_init_done            ,

    input   wire                sd_audio_previous           ,
    input   wire                sd_audio_next               ,
    input   wire                sd_audio_loop               ,

    input   wire                sd_audio_Structures_flag    ,
    input   wire    [3:0]       sd_audio_Structures_cnt     ,
    input   wire    [97:0]      sd_audio_Structures_data    ,//24+32+32+4+6

    output  reg                 sd_audio_r_req              ,
    output  reg     [31:0]      sd_audio_r_addr             ,
    input   wire                sd_audio_r_ack              ,

    input   wire                sd_audio_r_start            ,
    input   wire                sd_audio_r_dv               ,
    input   wire    [7:0]       sd_audio_r_data             ,
    input   wire                sd_audio_r_end              ,
    input   wire    [8:0]       sd_audio_r_cnt              ,
    input   wire                sd_audio_r_err              ,

    input   wire                sd_audio_fifo_clk           ,
    input   wire                sd_audio_fifo_req           ,
    output  reg                 sd_audio_fifo_ack           ,
    output  reg     [47:0]      sd_audio_fifo_data
);

localparam                      AUDIO_RAM_DEPTH             = 8;
localparam                      AUDIO_FIFO_DEPTH            = 256;
localparam                      AUDIO_FIFO_LEVEL            = 128;
localparam                      WAV_HEAD_BYTES              = 32'd44;

localparam                      CTRL_WAIT                   = 4'd0,
                                CTRL_ADDR                   = 4'd1,
                                CTRL_READ                   = 4'd2,
                                CTRL_LATCH                  = 4'd3,
                                CTRL_FLUSH                  = 4'd4,
                                CTRL_FLUSH_WAIT             = 4'd5,
                                CTRL_PLAY                   = 4'd6,
                                CTRL_DROP                   = 4'd7;

localparam                      STA_IDLE                    = 3'd0,
                                STA_REQ                     = 3'd1,
                                STA_DATA                    = 3'd2,
                                STA_DONE                    = 3'd3;

reg     [3:0]                   ctrl                        ;
reg     [3:0]                   flush_cnt                   ;
reg                             total_tog                   ;
reg     [2:0]                   track_idx                   ;
reg     [3:0]                   audio_nub                   ;

reg     [2:0]                   ram_addra                   ;
reg                             ram_wea                     ;
reg     [97:0]                  ram_dina                    ;
wire    [97:0]                  ram_douta                   ;

reg     [31:0]                  cap_saddr                   ;
reg     [31:0]                  cap_blen                    ;
reg     [31:0]                  sample_total                ;

reg                             audio_hold                  ;
reg                             fifo_flush                  ;

reg                             audio_start                 ;
reg                             audio_dv                    ;
reg     [7:0]                   audio_data                  ;
reg                             audio_end                   ;

reg     [2:0]                   state                       ;
reg                             audio_req_start             ;

reg     [31:0]                  file_byte_cnt               ;
reg                             file_done                   ;
reg     [1:0]                   pack_cnt                    ;
reg     [31:0]                  pack_word                   ;
reg                             fifo_wr                     ;

wire                            fifo_full                   ;
wire                            fifo_empty                  ;
wire    [31:0]                  fifo_dout                   ;
wire    [7:0]                   fifo_wrusedw                ;
wire                            fifo_wr_rst_done            ;
wire                            fifo_rd_rst_done            ;

reg                             rd_rst_done_s0              ;
reg                             rd_rst_done_s1              ;
reg                             play_done_s0                ;
reg                             play_done_s1                ;
reg                             play_done_s2                ;
wire                            song_finished               ;

reg                             prev_r                      ;
reg                             next_r                      ;
wire                            prev_pulse                  ;
wire                            next_pulse                  ;
wire                            user_pulse                  ;

wire    [3:0]                   track_next                  ;
wire    [3:0]                   track_prev                  ;
wire                            sector_busy                 ;
wire                            payload_byte                ;

assign prev_pulse  = sd_audio_previous & ~prev_r;
assign next_pulse  = sd_audio_next & ~next_r;
assign user_pulse  = prev_pulse | next_pulse;
assign track_next  = ({1'b0, track_idx} + 4'd1 >= audio_nub) ? 4'd0 : {1'b0, track_idx} + 4'd1;
assign track_prev  = (track_idx == 3'd0) ? (audio_nub - 4'd1) : {1'b0, track_idx} - 4'd1;
assign sector_busy   = (state != STA_IDLE) || sd_audio_r_req || audio_req_start;
assign song_finished = play_done_s1 & ~play_done_s2;
assign payload_byte = audio_hold && audio_dv && (ctrl == CTRL_PLAY) && !file_done
                    && (file_byte_cnt >= WAV_HEAD_BYTES) && (file_byte_cnt < cap_blen);

always@(posedge clk) begin
    prev_r <= sd_audio_previous;
    next_r <= sd_audio_next;

    audio_start <= sd_audio_r_start;
    audio_dv    <= sd_audio_r_dv;
    audio_data  <= sd_audio_r_data;
    audio_end   <= sd_audio_r_end;
end

always@(posedge clk) begin
    if(reset) begin
        audio_nub <= 4'd0;
    end
    else if(sd_audio_Structures_flag && sd_audio_Structures_cnt < AUDIO_RAM_DEPTH) begin
        audio_nub <= sd_audio_Structures_cnt + 4'd1;
    end
end

always@(posedge clk) begin
    if(sd_audio_Structures_flag && sd_audio_Structures_cnt < AUDIO_RAM_DEPTH) begin
        ram_wea   <= 1'b1;
        ram_addra <= sd_audio_Structures_cnt[2:0];
        ram_dina  <= sd_audio_Structures_data;
    end
    else begin
        ram_wea   <= 1'b0;
        ram_addra <= track_idx;
        ram_dina  <= ram_dina;
    end
end

single_port_ram #(
    .RAM_WIDTH                  (98                         ),
    .RAM_DEPTH                  (AUDIO_RAM_DEPTH            ),
    .PERFORMENCE                ("LOW"                      )
)u_audio_index_ram(
    .clka                       (clk                        ),
    .wea                        (ram_wea                    ),
    .dina                       (ram_dina                   ),
    .addra                      (ram_addra                  ),
    .douta                      (ram_douta                  )
);

always@(posedge clk) begin
    if(reset || !sd_bmp_init_done) begin
        ctrl        <= CTRL_WAIT;
        track_idx   <= 3'd0;
        fifo_flush  <= 1'b0;
        flush_cnt   <= 4'd0;
        total_tog   <= 1'b0;
    end
    else begin
        case(ctrl)
            CTRL_WAIT : begin
                fifo_flush <= 1'b0;
                if(audio_nub != 4'd0) begin
                    track_idx <= 3'd0;
                    ctrl      <= CTRL_ADDR;
                end
            end
            CTRL_ADDR : begin
                ctrl <= CTRL_READ;
            end
            CTRL_READ : begin
                ctrl <= CTRL_LATCH;
            end
            CTRL_LATCH : begin
                cap_saddr  <= {8'd0, ram_douta[97:74]};
                cap_blen   <= ram_douta[73:42];
                fifo_flush <= 1'b1;
                flush_cnt  <= 4'd0;
                ctrl       <= CTRL_FLUSH;
            end
            CTRL_FLUSH : begin
                fifo_flush   <= 1'b1;
                sample_total <= (cap_blen > WAV_HEAD_BYTES) ? ((cap_blen - WAV_HEAD_BYTES) >> 2) : 32'd0;
                if(flush_cnt != 4'hF) begin
                    flush_cnt <= flush_cnt + 4'd1;
                end
                if(flush_cnt >= 4'd4 && !fifo_wr_rst_done && !rd_rst_done_s1) begin
                    fifo_flush <= 1'b0;
                    ctrl       <= CTRL_FLUSH_WAIT;
                end
            end
            CTRL_FLUSH_WAIT : begin
                fifo_flush <= 1'b0;
                if(fifo_wr_rst_done && rd_rst_done_s1) begin
                    total_tog <= ~total_tog;
                    ctrl      <= CTRL_PLAY;
                end
            end
            CTRL_PLAY : begin
                fifo_flush <= 1'b0;
                if(user_pulse) begin
                    track_idx  <= next_pulse ? track_next[2:0] : track_prev[2:0];
                    fifo_flush <= 1'b1;
                    flush_cnt  <= 4'd0;
                    ctrl       <= sector_busy ? CTRL_DROP : CTRL_ADDR;
                end
                else if(song_finished) begin
                    if(!sd_audio_loop && audio_nub != 4'd0) begin
                        track_idx <= track_next[2:0];
                    end
                    ctrl <= sector_busy ? CTRL_DROP : CTRL_ADDR;
                end
            end
            CTRL_DROP : begin
                if(fifo_flush) begin
                    fifo_flush <= 1'b1;
                    if(flush_cnt != 4'hF) begin
                        flush_cnt <= flush_cnt + 4'd1;
                    end
                end
                if(user_pulse) begin
                    track_idx <= next_pulse ? track_next[2:0] : track_prev[2:0];
                end
                if(!sector_busy) begin
                    ctrl <= CTRL_ADDR;
                end
            end
            default : begin
                ctrl <= CTRL_WAIT;
            end
        endcase
    end
end

always@(posedge clk) begin
    if(reset || !sd_bmp_init_done) begin
        audio_hold <= 1'b0;
    end
    else if(ctrl == CTRL_FLUSH || ctrl == CTRL_FLUSH_WAIT) begin
        audio_hold <= 1'b1;
    end
    else if(ctrl != CTRL_PLAY) begin
        audio_hold <= 1'b0;
    end
end

always@(posedge clk) begin
    if(reset || !sd_bmp_init_done) begin
        state <= STA_IDLE;
    end
    else begin
        case(state)
            STA_IDLE : begin
                if(audio_req_start) begin
                    state <= STA_REQ;
                end
            end
            STA_REQ  : begin
                if(sd_audio_r_ack) begin
                    state <= STA_DATA;
                end
            end
            STA_DATA : begin
                if(audio_end) begin
                    state <= STA_DONE;
                end
            end
            STA_DONE : begin
                state <= STA_IDLE;
            end
            default  : begin
                state <= STA_IDLE;
            end
        endcase
    end
end

always@(posedge clk) begin
    if(sd_bmp_init_done && ctrl == CTRL_PLAY && audio_hold && !file_done && state == STA_IDLE && fifo_wr_rst_done && fifo_wrusedw < AUDIO_FIFO_LEVEL) begin
        audio_req_start <= 1'b1;
    end
    else begin
        audio_req_start <= 1'b0;
    end
end

always@(posedge clk) begin
    if(reset || !sd_bmp_init_done) begin
        sd_audio_r_req <= 1'b0;
    end
    else if(sd_audio_r_ack) begin
        sd_audio_r_req <= 1'b0;
    end
    else if(audio_req_start) begin
        sd_audio_r_req <= 1'b1;
    end
end

always@(posedge clk) begin
    if(reset) begin
        sd_audio_r_addr <= 32'd0;
    end
    else if(ctrl == CTRL_FLUSH) begin
        sd_audio_r_addr <= cap_saddr;
    end
    else if(ctrl == CTRL_PLAY && audio_hold && audio_end) begin
        sd_audio_r_addr <= sd_audio_r_addr + 1'b1;
    end
end

always@(posedge clk) begin
    if(reset || ctrl == CTRL_FLUSH) begin
        file_byte_cnt <= 32'd0;
        file_done     <= 1'b0;
        pack_cnt      <= 2'd0;
        pack_word     <= 32'd0;
        fifo_wr       <= 1'b0;
    end
    else begin
        fifo_wr <= 1'b0;
        if(audio_hold && audio_dv && ctrl == CTRL_PLAY && !file_done) begin
            if(file_byte_cnt + 1'b1 == cap_blen) begin
                file_done <= 1'b1;
            end
            file_byte_cnt <= file_byte_cnt + 1'b1;
            if(payload_byte) begin
                pack_word <= {audio_data, pack_word[31:8]};
                pack_cnt  <= pack_cnt + 2'd1;
                if(pack_cnt == 2'd3) begin
                    fifo_wr <= 1'b1;
                end
            end
        end
    end
end

reg                             fifo_rd                     ;
reg                             fifo_rd_d                   ;
reg                             fifo_pop                    ;
reg                             fifo_silence                ;
reg                             fifo_busy                   ;
reg     [31:0]                  sample_rd                   ;
reg     [31:0]                  sample_total_r              ;
reg                             total_tog_s0                ;
reg                             total_tog_s1                ;
reg                             total_tog_s2                ;
reg                             play_done                   ;
reg                             read_rst_s0                 ;
reg                             read_rst_s1                 ;

asfifo_audio_data u_audio_fifo(
    .rst                        (reset | fifo_flush         ),
    .di                         (pack_word                  ),
    .clkr                       (sd_audio_fifo_clk          ),
    .re                         (fifo_rd                    ),
    .clkw                       (clk                        ),
    .we                         (fifo_wr & ~fifo_flush & fifo_wr_rst_done & ~fifo_full),
    .dout                       (fifo_dout                  ),
    .empty_flag                 (fifo_empty                 ),
    .aempty                     (                           ),
    .full_flag                  (fifo_full                  ),
    .afull                      (                           ),
    .valid                      (                           ),
    .overflow                   (                           ),
    .underflow                  (                           ),
    .wr_success                 (                           ),
    .rdusedw                    (                           ),
    .wrusedw                    (fifo_wrusedw               ),
    .wr_rst_done                (fifo_wr_rst_done           ),
    .rd_rst_done                (fifo_rd_rst_done           )
);

always@(posedge clk) begin
    rd_rst_done_s0 <= fifo_rd_rst_done;
    rd_rst_done_s1 <= rd_rst_done_s0;
    play_done_s0   <= play_done;
    play_done_s1   <= play_done_s0;
    play_done_s2   <= play_done_s1;
end

always@(posedge sd_audio_fifo_clk) begin
    read_rst_s0  <= reset | fifo_flush;
    read_rst_s1  <= read_rst_s0;
    total_tog_s0 <= total_tog;
    total_tog_s1 <= total_tog_s0;
    total_tog_s2 <= total_tog_s1;

    if(read_rst_s1) begin
        fifo_rd      <= 1'b0;
        fifo_rd_d    <= 1'b0;
        fifo_pop     <= 1'b0;
        fifo_silence <= 1'b0;
        if(fifo_busy || sd_audio_fifo_req) begin
            fifo_busy          <= 1'b0;
            sd_audio_fifo_ack  <= 1'b1;
            sd_audio_fifo_data <= 48'd0;
        end
        else begin
            fifo_busy          <= 1'b0;
            sd_audio_fifo_ack  <= 1'b0;
        end
    end
    else if(total_tog_s1 ^ total_tog_s2) begin
        sample_total_r <= sample_total;
        sample_rd      <= 32'd0;
        play_done      <= (sample_total == 32'd0);
        fifo_rd        <= 1'b0;
        fifo_rd_d      <= 1'b0;
        fifo_pop       <= 1'b0;
        fifo_silence   <= 1'b0;
        if(fifo_busy || sd_audio_fifo_req) begin
            fifo_busy          <= 1'b0;
            sd_audio_fifo_ack  <= 1'b1;
            sd_audio_fifo_data <= 48'd0;
        end
        else begin
            fifo_busy          <= 1'b0;
            sd_audio_fifo_ack  <= 1'b0;
        end
    end
    else begin
        fifo_rd   <= 1'b0;
        fifo_rd_d <= fifo_rd;
        sd_audio_fifo_ack <= 1'b0;

        if(!fifo_busy && sd_audio_fifo_req) begin
            fifo_busy <= 1'b1;
            if(fifo_rd_rst_done && !fifo_empty && !play_done && sample_rd < sample_total_r) begin
                fifo_rd      <= 1'b1;
                fifo_pop     <= 1'b1;
                fifo_silence <= 1'b0;
            end
            else begin
                fifo_pop     <= 1'b0;
                fifo_silence <= 1'b1;
            end
        end

        if(fifo_rd_d && fifo_pop) begin
            fifo_busy          <= 1'b0;
            fifo_pop           <= 1'b0;
            sd_audio_fifo_ack  <= 1'b1;
            sd_audio_fifo_data <= {fifo_dout[15:0], 8'h00, fifo_dout[31:16], 8'h00};
            sample_rd          <= sample_rd + 1'b1;
            if(sample_rd + 1'b1 == sample_total_r) begin
                play_done <= 1'b1;
            end
        end
        else if(fifo_silence) begin
            fifo_busy          <= 1'b0;
            fifo_silence       <= 1'b0;
            sd_audio_fifo_ack  <= 1'b1;
            sd_audio_fifo_data <= 48'd0;
        end
    end
end

endmodule
