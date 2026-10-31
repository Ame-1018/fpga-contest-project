`timescale 1ns/1ps







  

module DSP_dsp_mul_u9x10#(// config_param
    parameter              INPUTFORMAT  = "SIGNED", 
    parameter              SRMODE       = "ASYNC", 
    parameter              INPUT_WIDTH_A= 64,
    parameter              INPUT_WIDTH_B= 64,
    parameter              OUTPUT_WIDTH = 128
    ) (// input ports
    input CLK,     
    
    
    
    input [(INPUT_WIDTH_A - 1):0] A,
    input [(INPUT_WIDTH_B - 1):0] B,
    //cascade ports
    //output ports
    output [(OUTPUT_WIDTH - 1):0] P) ;

localparam [2:0] NUM_A   = (INPUT_WIDTH_A<=18) ? 1:
                           (INPUT_WIDTH_A<=35) ? 2:
                           (INPUT_WIDTH_A<=52) ? 3:
                                                 4;
localparam [2:0] NUM_B   = (INPUT_WIDTH_B<=18) ? 1:
                           (INPUT_WIDTH_B<=35) ? 2:
                           (INPUT_WIDTH_B<=52) ? 3:
                                                 4;

reg      [INPUT_WIDTH_A-1:0] a_reg ;
reg      [INPUT_WIDTH_B-1:0] b_reg ;
reg      [OUTPUT_WIDTH -1:0] p_reg ;

reg      [INPUT_WIDTH_A-1:0] a_use ;
reg      [INPUT_WIDTH_B-1:0] b_use ;
reg      [OUTPUT_WIDTH -1:0] p_use ;

wire                         p_sign;
reg                          p_sign_d1;
reg                          p_sign_d2;
reg                          p_sign_d3;
reg                          p_sign_d4;
reg                          p_sign_d5;

wire [35:0] p_mul[NUM_A-1:0] [NUM_B-1:0];
wire [17:0] acout[NUM_A-1:0] [NUM_B-1:0];
wire [17:0] bcout[NUM_A-1:0] [NUM_B-1:0];

reg  [OUTPUT_WIDTH-1 : 0] p_mul_add [NUM_A-1 : 0];

reg      [INPUT_WIDTH_A+NUM_A-2:0] a_in  ;
reg      [INPUT_WIDTH_B+NUM_B-2:0] b_in  ;










        
        always @(*)begin
            a_use = A ;
        end
               

        
        always @(*)begin
            b_use = B ;
        end
         

        
        always @(*)begin
            p_use = p_reg ;
        end
         

    assign p_sign= INPUTFORMAT == "SIGNED" ? (a_use[INPUT_WIDTH_A - 1]^b_use[INPUT_WIDTH_B - 1]) : 1'b0;

    
        always @(*)begin
            p_sign_d1    = p_sign;
            p_sign_d2    = p_sign_d1;
            p_sign_d3    = p_sign_d2;               
            p_sign_d4    = p_sign_d3;
            p_sign_d5    = p_sign_d4;                
        end
    

        
            
                    
                        assign P  = p_sign    ? (~p_use+1'b1) : p_use;
                    
                    
        


    always @(*)begin
        if(INPUTFORMAT == "SIGNED")
            if(a_use[INPUT_WIDTH_A - 1])
                a_reg = -(a_use);
            else
                a_reg = a_use;
        else
            a_reg = a_use;                   
    end

    always @(*)begin
        if(INPUTFORMAT == "SIGNED")
            if(b_use[INPUT_WIDTH_B - 1])
                b_reg = -(b_use);
            else
                b_reg = b_use;
       else
            b_reg = b_use;                   
    end

genvar i;
genvar j;
generate for(i=0;i<NUM_A;i=i+1)begin:A_CYCLE
             for(j=0;j<NUM_B;j=j+1)begin:B_CYCLE

    always @(*)
        if (i == NUM_A-1)
            a_in[(INPUT_WIDTH_A-1+i) : (18*i)] = a_reg[(INPUT_WIDTH_A-1) : (17*i)];
        else
            a_in[(18*i+17) : (18*i)]           = {1'd0 , a_reg[(17*i+16) : (17*i)]};

    always @(*)
        if (j == NUM_B-1)
            b_in[(INPUT_WIDTH_B-1+j) : (18*j)] = b_reg[(INPUT_WIDTH_B-1) : (17*j)];
        else
            b_in[(18*j+17) : (18*j)]           = {1'd0 , b_reg[(17*j+16) : (17*j)]};

    if (i == NUM_A-1)
        if (j == NUM_B-1)begin
            if((INPUT_WIDTH_A-17*i)<18)begin
                if((INPUT_WIDTH_B-17*j)<18)begin
                    
                    EG_PHY_MULT18  #(
                     
                        
                            
                            .INPUTREGA("DISABLE"),
                            .INPUTREGB("DISABLE"),
                            
                        
                        
                        .OUTPUTREG("DISABLE"),                        
                        
                        
                            
                                
                            
                        
                        .MODE("MULT18X18C"),
                        .CEAMUX("SIG"),
                        .CEBMUX("SIG"),
                        .CEPDMUX("SIG"),
                        .RSTANMUX("SIG"),
                        .RSTBNMUX("SIG"),
                        .RSTPDNMUX("SIG"),                                                                                                                         
                        .CLKMUX("SIG"),
                        .SIGNEDAMUX("SIG"),
                        .SIGNEDBMUX("SIG"),
                        .SOURCEAMUX("SIG"),
                        .SOURCEBMUX("SIG")
                    )inst3(
                        .acout(acout[i][j]),
                        .bcout(bcout[i][j]),
                        .acin(18'd0),
                        .bcin(18'd0),
                        .signeda(1'b0),
                        .signedb(1'b0),
                        .sourcea(1'b1),
                        .sourceb(1'b1),
                        .a({{(18-INPUT_WIDTH_A+17*i){1'b0}},a_in[(INPUT_WIDTH_A-1+i) : (18*i)]}),
                        .b({{(18-INPUT_WIDTH_B+17*j){1'b0}},b_in[(INPUT_WIDTH_B-1+j) : (18*j)]}),
                        .p(p_mul[i][j]),
                        
                        
                                                
                        .clk(CLK)                        
                    ); 
                end
                else begin
                    
                    EG_PHY_MULT18  #(
                     
                        
                            
                            .INPUTREGA("DISABLE"),
                            .INPUTREGB("DISABLE"),
                            
                        
                        
                        .OUTPUTREG("DISABLE"),                        
                        
                        
                            
                                
                            
                        
                        .MODE("MULT18X18C"),
                        .CEAMUX("SIG"),
                        .CEBMUX("SIG"),
                        .CEPDMUX("SIG"),
                        .RSTANMUX("SIG"),
                        .RSTBNMUX("SIG"),
                        .RSTPDNMUX("SIG"),                                                                                                                         
                        .CLKMUX("SIG"),
                        .SIGNEDAMUX("SIG"),
                        .SIGNEDBMUX("SIG"),
                        .SOURCEAMUX("SIG"),
                        .SOURCEBMUX("SIG")
                    )inst3(
                        .acout(acout[i][j]),
                        .bcout(bcout[i][j]),
                        .acin(18'd0),
                        .bcin(18'd0),
                        .signeda(1'b0),
                        .signedb(1'b0),
                        .sourcea(1'b1),
                        .sourceb(1'b1),
                        .a({{(18-INPUT_WIDTH_A+17*i){1'b0}},a_in[(INPUT_WIDTH_A-1+i) : (18*i)]}),
                        .b(b_in[(18*j+17) : (18*j)]),
                        .p(p_mul[i][j]),
                        
                        
                                                
                        .clk(CLK) 
                    ); 
                end
            end
            else begin
                if((INPUT_WIDTH_B-17*j)<18)begin
                    
                    EG_PHY_MULT18  #(
                     
                        
                            
                            .INPUTREGA("DISABLE"),
                            .INPUTREGB("DISABLE"),
                            
                        
                        
                        .OUTPUTREG("DISABLE"),                        
                        
                        
                            
                                
                            
                        
                        .MODE("MULT18X18C"),
                        .CEAMUX("SIG"),
                        .CEBMUX("SIG"),
                        .CEPDMUX("SIG"),
                        .RSTANMUX("SIG"),
                        .RSTBNMUX("SIG"),
                        .RSTPDNMUX("SIG"),                                                                                                                         
                        .CLKMUX("SIG"),
                        .SIGNEDAMUX("SIG"),
                        .SIGNEDBMUX("SIG"),
                        .SOURCEAMUX("SIG"),
                        .SOURCEBMUX("SIG")
                    )inst3(
                        .acout(acout[i][j]),
                        .bcout(bcout[i][j]),
                        .acin(18'd0),
                        .bcin(18'd0),
                        .signeda(1'b0),
                        .signedb(1'b0),
                        .sourcea(1'b1),
                        .sourceb(1'b1),
                        .a(a_in[(18*i+17) : (18*i)]),
                        .b({{(18-INPUT_WIDTH_B+17*j){1'b0}},b_in[(INPUT_WIDTH_B-1+j) : (18*j)]}),
                        .p(p_mul[i][j]),
                        
                        
                                                
                        .clk(CLK) 
                    );
                end
                else begin
                    
                    EG_PHY_MULT18  #(
                     
                        
                            
                            .INPUTREGA("DISABLE"),
                            .INPUTREGB("DISABLE"),
                            
                        
                        
                        .OUTPUTREG("DISABLE"),                        
                        
                        
                            
                                
                            
                        
                        .MODE("MULT18X18C"),
                        .CEAMUX("SIG"),
                        .CEBMUX("SIG"),
                        .CEPDMUX("SIG"),
                        .RSTANMUX("SIG"),
                        .RSTBNMUX("SIG"),
                        .RSTPDNMUX("SIG"),                                                                                                                         
                        .CLKMUX("SIG"),
                        .SIGNEDAMUX("SIG"),
                        .SIGNEDBMUX("SIG"),
                        .SOURCEAMUX("SIG"),
                        .SOURCEBMUX("SIG")
                    )inst3(
                        .acout(acout[i][j]),
                        .bcout(bcout[i][j]),
                        .acin(18'd0),
                        .bcin(18'd0),
                        .signeda(1'b0),
                        .signedb(1'b0),
                        .sourcea(1'b1),
                        .sourceb(1'b1),
                        .a(a_in[(18*i+17) : (18*i)]),
                        .b(b_in[(18*j+17) : (18*j)]),
                        .p(p_mul[i][j]),
                        
                        
                                                
                        .clk(CLK) 
                    );
                end                  
            end                                
        end
        else begin 
            if((INPUT_WIDTH_A-17*i)<18)begin
                    
                    EG_PHY_MULT18  #(
                    
                        
                            
                            .INPUTREGA("DISABLE"),
                            .INPUTREGB("DISABLE"),
                            
                        
                        
                        .OUTPUTREG("DISABLE"),                        
                        
                        
                            
                                
                            
                        
                        .MODE("MULT18X18C"),
                        .CEAMUX("SIG"),
                        .CEBMUX("SIG"),
                        .CEPDMUX("SIG"),
                        .RSTANMUX("SIG"),
                        .RSTBNMUX("SIG"),
                        .RSTPDNMUX("SIG"),                                                                                                                         
                        .CLKMUX("SIG"),
                        .SIGNEDAMUX("SIG"),
                        .SIGNEDBMUX("SIG"),
                        .SOURCEAMUX("SIG"),
                        .SOURCEBMUX("SIG")
            )inst2(
                        .acout(acout[i][j]),
                        .bcout(bcout[i][j]),
                        .acin(18'd0),
                        .bcin(18'd0),
                        .signeda(1'b0),
                        .signedb(1'b0),
                        .sourcea(1'b1),
                        .sourceb(1'b1),
                        .a({{(18-INPUT_WIDTH_A+17*i){1'b0}},a_in[(INPUT_WIDTH_A-1+i) : (18*i)]}),
                        .b(b_in[(18*j+17) : (18*j)]),
                        .p(p_mul[i][j]),
                        
                        
                                                
                        .clk(CLK) 
                    );
            end
            else begin
                    
                    EG_PHY_MULT18  #(
                    
                        
                            
                            .INPUTREGA("DISABLE"),
                            .INPUTREGB("DISABLE"),
                            
                        
                        
                        .OUTPUTREG("DISABLE"),                        
                        
                        
                            
                                
                            
                        
                        .MODE("MULT18X18C"),
                        .CEAMUX("SIG"),
                        .CEBMUX("SIG"),
                        .CEPDMUX("SIG"),
                        .RSTANMUX("SIG"),
                        .RSTBNMUX("SIG"),
                        .RSTPDNMUX("SIG"),                                                                                                                         
                        .CLKMUX("SIG"),
                        .SIGNEDAMUX("SIG"),
                        .SIGNEDBMUX("SIG"),
                        .SOURCEAMUX("SIG"),
                        .SOURCEBMUX("SIG")
            )inst2(
                        .acout(acout[i][j]),
                        .bcout(bcout[i][j]),
                        .acin(18'd0),
                        .bcin(18'd0),
                        .signeda(1'b0),
                        .signedb(1'b0),
                        .sourcea(1'b1),
                        .sourceb(1'b1),
                        .a(a_in[(18*i+17) : (18*i)]),
                        .b(b_in[(18*j+17) : (18*j)]),
                        .p(p_mul[i][j]),
                        
                        
                                                
                        .clk(CLK) 
                    );
            end                                     
        end      
    else
        if (j == NUM_B-1)begin
            if((INPUT_WIDTH_B-17*j)<18)begin
                    
                    EG_PHY_MULT18  #(
                    
                        
                            
                            .INPUTREGA("DISABLE"),
                            .INPUTREGB("DISABLE"),
                            
                        
                        
                        .OUTPUTREG("DISABLE"),                        
                        
                        
                            
                                
                            
                        
                        .MODE("MULT18X18C"),
                        .CEAMUX("SIG"),
                        .CEBMUX("SIG"),
                        .CEPDMUX("SIG"),
                        .RSTANMUX("SIG"),
                        .RSTBNMUX("SIG"),
                        .RSTPDNMUX("SIG"),                                                                                                                         
                        .CLKMUX("SIG"),
                        .SIGNEDAMUX("SIG"),
                        .SIGNEDBMUX("SIG"),
                        .SOURCEAMUX("SIG"),
                        .SOURCEBMUX("SIG")
            )inst1(
                        .acout(acout[i][j]),
                        .bcout(bcout[i][j]),
                        .acin(18'd0),
                        .bcin(18'd0),
                        .signeda(1'b0),
                        .signedb(1'b0),
                        .sourcea(1'b1),
                        .sourceb(1'b1),
                        .a(a_in[(18*i+17) : (18*i)]),
                        .b({{(18-INPUT_WIDTH_B+17*j){1'b0}},b_in[(INPUT_WIDTH_B-1+j) : (18*j)]}),
                        .p(p_mul[i][j]),
                        
                        
                                                
                        .clk(CLK) 
                    );
            end
            else begin
                    
                    EG_PHY_MULT18  #(
                    
                        
                            
                            .INPUTREGA("DISABLE"),
                            .INPUTREGB("DISABLE"),
                            
                        
                        
                        .OUTPUTREG("DISABLE"),                        
                        
                        
                            
                                
                            
                        
                        .MODE("MULT18X18C"),
                        .CEAMUX("SIG"),
                        .CEBMUX("SIG"),
                        .CEPDMUX("SIG"),
                        .RSTANMUX("SIG"),
                        .RSTBNMUX("SIG"),
                        .RSTPDNMUX("SIG"),                                                                                                                         
                        .CLKMUX("SIG"),
                        .SIGNEDAMUX("SIG"),
                        .SIGNEDBMUX("SIG"),
                        .SOURCEAMUX("SIG"),
                        .SOURCEBMUX("SIG")
            )inst1(
                        .acout(acout[i][j]),
                        .bcout(bcout[i][j]),
                        .acin(18'd0),
                        .bcin(18'd0),
                        .signeda(1'b0),
                        .signedb(1'b0),
                        .sourcea(1'b1),
                        .sourceb(1'b1),
                        .a(a_in[(18*i+17) : (18*i)]),
                        .b(b_in[(18*j+17) : (18*j)]),
                        .p(p_mul[i][j]),
                        
                        
                                                
                        .clk(CLK) 
                    );
            end                
        end
        else begin
                    
                    EG_PHY_MULT18  #(
                    
                        
                            
                            .INPUTREGA("DISABLE"),
                            .INPUTREGB("DISABLE"),
                            
                        
                        
                        .OUTPUTREG("DISABLE"),                        
                        
                        
                            
                                
                            
                        
                        .MODE("MULT18X18C"),
                        .CEAMUX("SIG"),
                        .CEBMUX("SIG"),
                        .CEPDMUX("SIG"),
                        .RSTANMUX("SIG"),
                        .RSTBNMUX("SIG"),
                        .RSTPDNMUX("SIG"),                                                                                                                         
                        .CLKMUX("SIG"),
                        .SIGNEDAMUX("SIG"),
                        .SIGNEDBMUX("SIG"),
                        .SOURCEAMUX("SIG"),
                        .SOURCEBMUX("SIG")
            )inst0(
                        .acout(acout[i][j]),
                        .bcout(bcout[i][j]),
                        .acin(18'd0),
                        .bcin(18'd0),
                        .signeda(1'b0),
                        .signedb(1'b0),
                        .sourcea(1'b1),
                        .sourceb(1'b1),
                        .a(a_in[(18*i+17) : (18*i)]),
                        .b(b_in[(18*j+17) : (18*j)]),
                        .p(p_mul[i][j]),
                        
                        
                                                
                        .clk(CLK) 
                    );
        end
    end   
end
endgenerate


    case({NUM_A,NUM_B})
        6'b001001:begin
            always @(*)begin
                p_mul_add[0] = p_mul[0][0] ;
                p_reg        = p_mul_add[0];
            end
        end
        6'b001010:begin
            always @(*)begin
                p_mul_add[0] = p_mul[0][0]+(p_mul[0][1]<<17);
                p_reg        = p_mul_add[0];               
            end
        end 
        6'b001011:begin
            always @(*)begin
                p_mul_add[0] = p_mul[0][0]+(p_mul[0][1]<<17)+(p_mul[0][2]<<34);
                p_reg        = p_mul_add[0]; 
            end
        end
        6'b001100:begin
            always @(*)begin
                p_mul_add[0] = p_mul[0][0]+(p_mul[0][1]<<17)+(p_mul[0][2]<<34)+(p_mul[0][3]<<51);
                p_reg        = p_mul_add[0];                 
            end
        end
        6'b010001:begin
            always @(*)begin
                p_mul_add[0] = p_mul[0][0];
                p_mul_add[1] = p_mul[1][0];
                p_reg        = p_mul_add[0]+(p_mul_add[1]<<17);                 
            end
        end
        6'b010010:begin
            always @(*)begin
                p_mul_add[0] = p_mul[0][0]+(p_mul[0][1]<<17);
                p_mul_add[1] = p_mul[1][0]+(p_mul[1][1]<<17);
                p_reg        = p_mul_add[0]+(p_mul_add[1]<<17);                               
            end
        end 
        6'b010011:begin
            always @(*)begin
                p_mul_add[0] = p_mul[0][0]+(p_mul[0][1]<<17)+(p_mul[0][2]<<34);
                p_mul_add[1] = p_mul[1][0]+(p_mul[1][1]<<17)+(p_mul[1][2]<<34);
                p_reg        = p_mul_add[0]+(p_mul_add[1]<<17);                                
            end
        end
        6'b010100:begin
            always @(*)begin
                p_mul_add[0] = p_mul[0][0]+(p_mul[0][1]<<17)+(p_mul[0][2]<<34)+(p_mul[0][3]<<51);
                p_mul_add[1] = p_mul[1][0]+(p_mul[1][1]<<17)+(p_mul[1][2]<<34)+(p_mul[1][3]<<51);
                p_reg        = p_mul_add[0]+(p_mul_add[1]<<17);                              
            end
        end
        6'b011001:begin
            always @(*)begin
                p_mul_add[0] = p_mul[0][0];
                p_mul_add[1] = p_mul[1][0];
                p_mul_add[2] = p_mul[2][0];               
                p_reg        = p_mul_add[0]+(p_mul_add[1]<<17)+(p_mul_add[2]<<34);                 
            end
        end
        6'b011010:begin
            always @(*)begin
                p_mul_add[0] = p_mul[0][0]+(p_mul[0][1]<<17);
                p_mul_add[1] = p_mul[1][0]+(p_mul[1][1]<<17);
                p_mul_add[2] = p_mul[2][0]+(p_mul[2][1]<<17);                               
                p_reg        = p_mul_add[0]+(p_mul_add[1]<<17)+(p_mul_add[2]<<34); 
            end
        end 
        6'b011011:begin
            always @(*)begin
                p_mul_add[0] = p_mul[0][0]+(p_mul[0][1]<<17)+(p_mul[0][2]<<34);
                p_mul_add[1] = p_mul[1][0]+(p_mul[1][1]<<17)+(p_mul[1][2]<<34);
                p_mul_add[2] = p_mul[2][0]+(p_mul[2][1]<<17)+(p_mul[2][2]<<34);                
                p_reg        = p_mul_add[0]+(p_mul_add[1]<<17)+(p_mul_add[2]<<34);                                
            end
        end
        6'b011100:begin
            always @(*)begin
                p_mul_add[0] = p_mul[0][0]+(p_mul[0][1]<<17)+(p_mul[0][2]<<34)+(p_mul[0][3]<<51);
                p_mul_add[1] = p_mul[1][0]+(p_mul[1][1]<<17)+(p_mul[1][2]<<34)+(p_mul[1][3]<<51);
                p_mul_add[2] = p_mul[2][0]+(p_mul[2][1]<<17)+(p_mul[2][2]<<34)+(p_mul[2][3]<<51);                              
                p_reg        = p_mul_add[0]+(p_mul_add[1]<<17)+(p_mul_add[2]<<34);                              
            end
        end
        6'b100001:begin
            always @(*)begin
                p_mul_add[0] = p_mul[0][0];
                p_mul_add[1] = p_mul[1][0];
                p_mul_add[2] = p_mul[2][0];
                p_mul_add[3] = p_mul[3][0];                              
                p_reg        = p_mul_add[0]+(p_mul_add[1]<<17)+(p_mul_add[2]<<34)+(p_mul_add[3]<<51);                
            end
        end
        6'b100010:begin
            always @(*)begin
                p_mul_add[0] = p_mul[0][0]+(p_mul[0][1]<<17);
                p_mul_add[1] = p_mul[1][0]+(p_mul[1][1]<<17);
                p_mul_add[2] = p_mul[2][0]+(p_mul[2][1]<<17);                               
                p_mul_add[3] = p_mul[3][0]+(p_mul[3][1]<<17);
                p_reg        = p_mul_add[0]+(p_mul_add[1]<<17)+(p_mul_add[2]<<34)+(p_mul_add[3]<<51);                 
            end
        end 
        6'b100011:begin
            always @(*)begin
                p_mul_add[0] = p_mul[0][0]+(p_mul[0][1]<<17)+(p_mul[0][2]<<34);
                p_mul_add[1] = p_mul[1][0]+(p_mul[1][1]<<17)+(p_mul[1][2]<<34);
                p_mul_add[2] = p_mul[2][0]+(p_mul[2][1]<<17)+(p_mul[2][2]<<34);
                p_mul_add[3] = p_mul[3][0]+(p_mul[3][1]<<17)+(p_mul[3][2]<<34);                                
                p_reg        = p_mul_add[0]+(p_mul_add[1]<<17)+(p_mul_add[2]<<34)+(p_mul_add[3]<<51);                               
            end
        end
        6'b100100:begin
            always @(*)begin
                p_mul_add[0] = p_mul[0][0]+(p_mul[0][1]<<17)+(p_mul[0][2]<<34)+(p_mul[0][3]<<51);
                p_mul_add[1] = p_mul[1][0]+(p_mul[1][1]<<17)+(p_mul[1][2]<<34)+(p_mul[1][3]<<51);
                p_mul_add[2] = p_mul[2][0]+(p_mul[2][1]<<17)+(p_mul[2][2]<<34)+(p_mul[2][3]<<51);
                p_mul_add[3] = p_mul[3][0]+(p_mul[3][1]<<17)+(p_mul[3][2]<<34)+(p_mul[3][3]<<51);                               
                p_reg        = p_mul_add[0]+(p_mul_add[1]<<17)+(p_mul_add[2]<<34)+(p_mul_add[3]<<51);                              
            end
        end
        default:begin
            always @(*)begin
                p_reg = 0;
            end         
        end
    endcase



endmodule


