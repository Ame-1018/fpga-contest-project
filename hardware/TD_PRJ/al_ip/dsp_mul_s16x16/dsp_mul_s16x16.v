/************************************************************\
**	Copyright (c) 2012-2026 Anlogic Inc.
**	All Right Reserved.
\************************************************************/
/************************************************************\
**	Gen time	:	Oct 20 2026 09:37:50
**	IpTool version	:	2026.01(189136 2026/01/26)
**	App version	:	6.2.2(build number:190657)
**	Ip Version	:	2.0
\************************************************************/
`timescale 1ns/1ps
module dsp_mul_s16x16
(
  input                         CLK,
  input   [15:0]                A,
  input   [15:0]                B,
  output  [31:0]                P
);

  DSP_dsp_mul_s16x16
  #(
      .INPUTFORMAT("SIGNED"),
      .SRMODE("SYNC"),
      .INPUT_WIDTH_A(16),
      .INPUT_WIDTH_B(16),
      .OUTPUT_WIDTH(32)
  )DSP_Inst
  (
      .CLK(CLK),
      .A(A),
      .B(B),
      .P(P)
  );
endmodule
