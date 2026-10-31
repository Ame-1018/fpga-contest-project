`timescale 1ns / 1ps

module tb_key_matrix;

localparam                      CLK_FREQ                    = 50_000_000;
localparam                      DEBOUNCE_MS                 = 2;
localparam                      ROW_DWELL_US                = 100;
localparam                      CLK_HALF_NS                 = 10;

reg                             sys_clk                     ;
reg                             sys_rst                     ;
reg     [15:0]                  finger                      ;
wire    [3:0]                   key_row                     ;
wire    [3:0]                   key_col                     ;
wire    [3:0]                   key_flag0                   ;
wire    [3:0]                   key_flag1                   ;
wire    [3:0]                   key_flag2                   ;
wire    [3:0]                   key_flag3                   ;
wire    [15:0]                  flags                       ;

integer                         err                         ;

assign flags = {key_flag3, key_flag2, key_flag1, key_flag0};

key_matrix #(
    .CLK_FREQ                   (CLK_FREQ                   ),
    .DEBOUNCE_MS                (DEBOUNCE_MS                ),
    .ROW_DWELL_US               (ROW_DWELL_US               )
) u_key_matrix (
    .sys_clk                    (sys_clk                    ),
    .sys_rst                    (sys_rst                    ),
    .key_row                    (key_row                    ),
    .key_col                    (key_col                    ),
    .key_flag0                  (key_flag0                  ),
    .key_flag1                  (key_flag1                  ),
    .key_flag2                  (key_flag2                  ),
    .key_flag3                  (key_flag3                  )
);

// 列上拉。只有被拉低的那一行上有手指时，对应列才为 0。
// 键 0 在行 3 列 3，键 15 在行 0 列 0。
wire                            row3_low                    ;
wire                            row2_low                    ;
wire                            row1_low                    ;
wire                            row0_low                    ;

assign row3_low = (key_row[3] === 1'b0);
assign row2_low = (key_row[2] === 1'b0);
assign row1_low = (key_row[1] === 1'b0);
assign row0_low = (key_row[0] === 1'b0);

assign key_col[3] = ((row3_low && finger[ 0]) || (row2_low && finger[ 4]) ||
                     (row1_low && finger[ 8]) || (row0_low && finger[12])) ? 1'b0 : 1'b1;
assign key_col[2] = ((row3_low && finger[ 1]) || (row2_low && finger[ 5]) ||
                     (row1_low && finger[ 9]) || (row0_low && finger[13])) ? 1'b0 : 1'b1;
assign key_col[1] = ((row3_low && finger[ 2]) || (row2_low && finger[ 6]) ||
                     (row1_low && finger[10]) || (row0_low && finger[14])) ? 1'b0 : 1'b1;
assign key_col[0] = ((row3_low && finger[ 3]) || (row2_low && finger[ 7]) ||
                     (row1_low && finger[11]) || (row0_low && finger[15])) ? 1'b0 : 1'b1;

initial begin
    sys_clk = 1'b0;
    forever #CLK_HALF_NS sys_clk = ~sys_clk;
end

initial begin
    err      = 0;
    finger   = 16'h0000;
    sys_rst  = 1'b1;
    repeat(10) @(posedge sys_clk);
    sys_rst  = 1'b0;

    check_idle(3000);
    check_press(0, 16'h0001);
    check_press(15, 16'h8000);
    check_press(5, 16'h0020);
    check_short(7);
    check_rows();

    if(err == 0) begin
        $display("PASS key_matrix");
    end
    else begin
        $display("FAIL key_matrix err=%0d", err);
    end
    $finish;
end

task check_idle;
    input integer us;
    integer k;
    integer cycles;
    begin
        cycles = us * (1000 / (CLK_HALF_NS * 2));
        for(k = 0; k < cycles; k = k + 1) begin
            @(posedge sys_clk);
            #1;
            if(flags !== 16'h0000) begin
                $display("FAIL idle flags=%h", flags);
                err = err + 1;
                k = cycles;
            end
        end
    end
endtask

task check_press;
    input integer key_id;
    input [15:0] expect_bit;
    integer seen;
    integer guard;
    reg [15:0] got;
    begin
        finger = 16'h0000;
        finger[key_id] = 1'b1;
        seen  = 0;
        guard = 0;
        got   = 16'h0000;
        // 2 ms 消抖，再加一轮 0.4 ms 扫描
        while((seen == 0) && (guard < 200000)) begin
            @(posedge sys_clk);
            #1;
            if(flags !== 16'h0000) begin
                got  = flags;
                seen = seen + 1;
            end
            guard = guard + 1;
        end
        if(got !== expect_bit) begin
            $display("FAIL key %0d got=%h exp=%h", key_id, got, expect_bit);
            err = err + 1;
        end
        @(posedge sys_clk);
        #1;
        if(flags !== 16'h0000) begin
            $display("FAIL key %0d flag wider than 1 cycle %h", key_id, flags);
            err = err + 1;
        end
        // 按住不放，不应再出脉冲
        repeat(150000) begin
            @(posedge sys_clk);
            #1;
            if(flags !== 16'h0000) begin
                $display("FAIL key %0d repeat flag %h", key_id, flags);
                err = err + 1;
            end
        end
        finger = 16'h0000;
        repeat(20000) @(posedge sys_clk);
    end
endtask

task check_short;
    input integer key_id;
    integer k;
    begin
        finger = 16'h0000;
        finger[key_id] = 1'b1;
        #(500_000);
        finger = 16'h0000;
        for(k = 0; k < 150000; k = k + 1) begin
            @(posedge sys_clk);
            #1;
            if(flags !== 16'h0000) begin
                $display("FAIL short press flags=%h", flags);
                err = err + 1;
                k = 150000;
            end
        end
    end
endtask

task check_rows;
    integer ones;
    integer zcnt;
    integer b;
    begin
        repeat(4) begin
            ones = 0;
            zcnt = 0;
            for(b = 0; b < 4; b = b + 1) begin
                if(key_row[b] === 1'b0) ones = ones + 1;
                if(key_row[b] === 1'bz) zcnt = zcnt + 1;
            end
            if((ones != 1) || (zcnt != 3)) begin
                $display("FAIL row drive %b", key_row);
                err = err + 1;
            end
            #(ROW_DWELL_US * 1000);
        end
    end
endtask

endmodule
