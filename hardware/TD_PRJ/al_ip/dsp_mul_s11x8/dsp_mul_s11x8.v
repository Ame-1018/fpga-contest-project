/************************************************************\
**	Copyright (c) 2012-2026 Anlogic Inc.
**	All Right Reserved.
\************************************************************/
/************************************************************\
**	Gen time	:	Oct 20 2026 09:37:32
**	IpTool version	:	2026.01(189136 2026/01/26)
**	App version	:	6.2.2(build number:190657)
**	Ip Version	:	2.0
\************************************************************/
`timescale 1ns/1ps
module dsp_mul_s11x8
(
  input                         CLK,
  input   [10:0]                A,
  input   [7:0]                 B,
  output  [18:0]                P
);

  DSP_dsp_mul_s11x8
  #(
      .INPUTFORMAT("SIGNED"),
      .SRMODE("SYNC"),
      .INPUT_WIDTH_A(11),
      .INPUT_WIDTH_B(8),
      .OUTPUT_WIDTH(19)
  )DSP_Inst
  (
      .CLK(CLK),
      .A(A),
      .B(B),
      .P(P)
  );
endmodule
