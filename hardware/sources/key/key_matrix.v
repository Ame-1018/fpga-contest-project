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
// Create Date: 2026/10/16
// Module Name: key_matrix
// Description: 4x4 矩阵键盘扫描。列上拉，按下为低。
//              左上到右下为键 0~15，消抖后各输出一拍 flag。
//              原理图网络：Key_Row3 在上，Key_Col3 在左。
//              键号与原理图丝印 KEY15~KEY0 相反，按物理位置从 0 编号。
//
//              key_flag0[0] 键0  左上  行3 列3    key_flag0[3] 键3
//              key_flag1[0] 键4             key_flag1[3] 键7
//              key_flag2[0] 键8             key_flag2[3] 键11
//              key_flag3[0] 键12            key_flag3[3] 键15 右下
//
//              行线只拉低正在扫描的一行，其余高阻，避免无二极管时行与行短接。
//              无二极管，三键按成矩形时第四个位置会鬼键。
//////////////////////////////////////////////////////////////////////////////////


module key_matrix #(
    parameter                   CLK_FREQ                    = 50_000_000,
    parameter                   DEBOUNCE_MS                 = 20        ,
    parameter                   ROW_DWELL_US                = 1000
)(
    input   wire                sys_clk                     ,
    input   wire                sys_rst                     ,
    output  wire [3:0]          key_row                     ,
    input   wire [3:0]          key_col                     ,
    output  wire [3:0]          key_flag0                   ,
    output  wire [3:0]          key_flag1                   ,
    output  wire [3:0]          key_flag2                   ,
    output  wire [3:0]          key_flag3
);

// 与 key_filter 相同：低电平连续保持 DEBOUNCE_MS 后给一拍。
// 50 MHz、20 ms 时 CNT_MAX = 999_999，和 key_filter 的 CLK_FREQ/50-1 一致。
localparam                      CNT_MAX                     = (CLK_FREQ / 1000) * DEBOUNCE_MS - 1;
localparam                      CNT_W                       = $clog2(CNT_MAX + 1);
localparam                      US_CYC                      = (CLK_FREQ < 1000000) ? 1 : (CLK_FREQ / 1000000);
localparam                      US_W                        = (US_CYC <= 1) ? 1 : $clog2(US_CYC);
localparam                      DWELL_W                     = (ROW_DWELL_US <= 1) ? 1 : $clog2(ROW_DWELL_US);

reg     [CNT_W-1:0]             cnt [0:15]                  ;
reg     [15:0]                  key_flag_all                ;
reg     [15:0]                  key_level                   ;
reg     [US_W-1:0]              us_cnt                      ;
reg     [DWELL_W-1:0]           dwell_cnt                   ;
reg     [1:0]                   scan_idx                    ;
reg     [3:0]                   col_ff1                     ;
reg     [3:0]                   col_ff2                     ;

wire                            us_tick                     ;
wire                            dwell_done                  ;
wire    [3:0]                   col_sync                    ;
integer                         i                           ;

assign us_tick   = (US_CYC <= 1) ? 1'b1 : (us_cnt == US_CYC - 1);
assign dwell_done = us_tick && (dwell_cnt == ROW_DWELL_US - 1);
assign col_sync  = col_ff2;

// [3] 是最上面的 Key_Row3。正在扫描的行输出 0，其它行高阻。
assign key_row[3] = ((sys_rst == 1'b0) && (scan_idx == 2'd0)) ? 1'b0 : 1'bz;
assign key_row[2] = ((sys_rst == 1'b0) && (scan_idx == 2'd1)) ? 1'b0 : 1'bz;
assign key_row[1] = ((sys_rst == 1'b0) && (scan_idx == 2'd2)) ? 1'b0 : 1'bz;
assign key_row[0] = ((sys_rst == 1'b0) && (scan_idx == 2'd3)) ? 1'b0 : 1'bz;

assign key_flag0 = key_flag_all[ 3: 0];
assign key_flag1 = key_flag_all[ 7: 4];
assign key_flag2 = key_flag_all[11: 8];
assign key_flag3 = key_flag_all[15:12];

always@(posedge sys_clk or posedge sys_rst) begin
    if(sys_rst) begin
        us_cnt    <= {US_W{1'b0}};
        dwell_cnt <= {DWELL_W{1'b0}};
        scan_idx  <= 2'd0;
        col_ff1   <= 4'b1111;
        col_ff2   <= 4'b1111;
        key_level <= 16'hFFFF;
    end
    else begin
        col_ff1 <= key_col;
        col_ff2 <= col_ff1;

        if(US_CYC <= 1) begin
            us_cnt <= {US_W{1'b0}};
        end
        else if(us_cnt == US_CYC - 1) begin
            us_cnt <= {US_W{1'b0}};
        end
        else begin
            us_cnt <= us_cnt + 1'b1;
        end

        if(us_tick) begin
            if(dwell_cnt == ROW_DWELL_US - 1) begin
                dwell_cnt <= {DWELL_W{1'b0}};
                scan_idx  <= scan_idx + 2'd1;
                // 列 [3] 在左，对应本组 flag 的 bit0。1 为松开。
                case(scan_idx)
                    2'd0: key_level[ 3: 0] <= {col_sync[0], col_sync[1], col_sync[2], col_sync[3]};
                    2'd1: key_level[ 7: 4] <= {col_sync[0], col_sync[1], col_sync[2], col_sync[3]};
                    2'd2: key_level[11: 8] <= {col_sync[0], col_sync[1], col_sync[2], col_sync[3]};
                    default: key_level[15:12] <= {col_sync[0], col_sync[1], col_sync[2], col_sync[3]};
                endcase
            end
            else begin
                dwell_cnt <= dwell_cnt + 1'b1;
            end
        end
    end
end

// 采样结果在两次扫描之间保持，因此这里的 20 ms 是墙上时间，不是行选通时间。
always@(posedge sys_clk or posedge sys_rst) begin
    if(sys_rst) begin
        key_flag_all <= 16'h0000;
        for(i = 0; i < 16; i = i + 1) begin
            cnt[i] <= {CNT_W{1'b0}};
        end
    end
    else begin
        for(i = 0; i < 16; i = i + 1) begin
            if(key_level[i] == 1'b1) begin
                cnt[i]          <= {CNT_W{1'b0}};
                key_flag_all[i] <= 1'b0;
            end
            else if(cnt[i] == CNT_MAX) begin
                cnt[i]          <= cnt[i];
                key_flag_all[i] <= 1'b0;
            end
            else begin
                cnt[i]          <= cnt[i] + 1'b1;
                key_flag_all[i] <= (cnt[i] == CNT_MAX - 1);
            end
        end
    end
end

endmodule
