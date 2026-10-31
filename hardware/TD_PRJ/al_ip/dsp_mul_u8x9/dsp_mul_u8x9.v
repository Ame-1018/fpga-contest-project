/************************************************************\
**	Copyright (c) 2012-2026 Anlogic Inc.
**	All Right Reserved.
\************************************************************/
/************************************************************\
**	Gen time	:	Oct 20 2026 09:36:41
**	IpTool version	:	2026.01(189136 2026/01/26)
**	App version	:	6.2.2(build number:190657)
**	Ip Version	:	2.0
\************************************************************/
`timescale 1ns/1ps
module dsp_mul_u8x9
(
  input                         CLK,
  input   [7:0]                 A,
  input   [8:0]                 B,
  output  [16:0]                P
);

  DSP_dsp_mul_u8x9
  #(
      .INPUTFORMAT("UNSIGNED"),
      .SRMODE("SYNC"),
      .INPUT_WIDTH_A(8),
      .INPUT_WIDTH_B(9),
      .OUTPUT_WIDTH(17)
  )DSP_Inst
  (
      .CLK(CLK),
      .A(A),
      .B(B),
      .P(P)
  );
endmodule
