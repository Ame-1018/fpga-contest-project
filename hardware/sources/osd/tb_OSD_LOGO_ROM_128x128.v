`timescale 1ns / 1ps
// Clocked read of OSD_LOGO_ROM_128x128. One row per address, 1-cycle latency.
// Pixel x=0 is line_data[255:254]. Writes osd_logo_readback_128x128.bin in the sim directory.

module tb_OSD_LOGO_ROM_128x128;

    reg                         clk;
    reg             [6:0]      addr;
    wire            [255:0]      line_data;

    localparam      [31:0]      EXPECT_FOLD        = 32'h47C7EAC3;

    integer                     fd;
    integer                     row;
    integer                     col;
    integer                     err_n;
    reg             [31:0]      fold;

    OSD_LOGO_ROM_128x128 uut (
        .clk                    (clk),
        .addr                   (addr),
        .line_data              (line_data)
    );

    initial clk = 1'b0;
    always #10 clk = ~clk;

    initial begin
        addr = 7'd0;
        err_n = 0;
        fold = 32'd0;
        fd = $fopen("osd_logo_readback_128x128.bin", "wb");
        if (fd == 0) begin
            $display("FAIL open readback 128x128");
            $finish;
        end
        repeat (2) @(posedge clk);
        for (row = 0; row < 128; row = row + 1) begin
            addr = row[6:0];
            @(posedge clk);
            #1;
            fold = fold ^ line_data[31:0] ^ line_data[63:32] ^ line_data[95:64] ^ line_data[127:96] ^ line_data[159:128] ^ line_data[191:160] ^ line_data[223:192] ^ line_data[255:224];
            for (col = 0; col < 128; col = col + 1) begin
                $fwrite(fd, "%c", line_data[255 - col * 2 -: 2]);
            end
        end
        $fclose(fd);
        if (fold !== EXPECT_FOLD)
            err_n = err_n + 1;
        if (err_n == 0)
            $display("PASS osd logo read 128x128");
        else
            $display("FAIL osd logo read 128x128 err_n=%0d", err_n);
        $finish;
    end

endmodule
