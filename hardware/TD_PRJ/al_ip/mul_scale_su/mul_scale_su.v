/************************************************************\
**	Copyright (c) 2012-2026 Anlogic Inc.
**	All Right Reserved.
\************************************************************/
/************************************************************\
**	Gen time	:	Oct 19 2026 21:29:28
**	IpTool version	:	2026.01(189136 2026/01/26)
**	App version	:	6.2.2(build number:190657)
**	Ip Version	:	2.0
\************************************************************/
`timescale 1ns/1ps
module mul_scale_su
(
  input                         CLK,
  input   [8:0]                 A,
  input   [7:0]                 B,
  output  [16:0]                P
);

  DSP_mul_scale_su
  #(
      .INPUTFORMAT("SIGNED"),
      .SRMODE("SYNC"),
      .INPUT_WIDTH_A(9),
      .INPUT_WIDTH_B(8),
      .OUTPUT_WIDTH(17)
  )DSP_Inst
  (
      .CLK(CLK),
      .A(A),
      .B(B),
      .P(P)
  );
endmodule
