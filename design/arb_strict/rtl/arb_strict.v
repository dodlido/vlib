//|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|//
//|                                                                                    |//
//| ~~ arb_strict ~~                                                                   |//
//|                                                                                    |//
//| Top-level description:                                                             |//
//|    1. Strict priority, combinational arbiter, lsb highest prio                     |//
//|                                                                                    |//
//| Features:                                                                          |//
//|    1. Parameterized request and grnts bus width in bits (WID)                      |//
//|                                                                                    |//
//|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|//

module arb_strict #(
    parameter WID = 16 // rqsts and grnts bus width in bits
) (
    input wire [WID-1:0] rqsts , // Request bus
    output reg [WID-1:0] grnts   // grnts bus
);
    // Internal wires // 
    wire [WID-1:0] prev_g ; // Previous grnts, prev_g[i] is high if a request was granted in index j<i

    // Generate internal grant logic // 
    genvar i;
    generate
        for (i = 0; i < WID; i = i + 1) begin
            if (i==0) begin
                assign prev_g[i] = 1'b0     ; // prev_g initial conditions
                assign grnts[i]  = rqsts[i] ; // grnts initial conditions
            end
            else begin
                assign prev_g[i] = prev_g[i-1] & rqsts[i-1] ; // previous grant check previous grnts and nearest request
                assign grnts[i]  = ~prev_g[i]  & rqsts[i]   ; // grant only if not previously granted and request is high
            end
        end
    endgenerate

endmodule


//|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|//
//|                                               |//
//| 1. Project  :  vlib                           |//
//| 2. Author   :  Etay Sela                      |//
//| 3. Date     :  2024-04-15                     |//
//| 4. Version  :  v0.4.0                         |//
//|                                               |//
//|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|//
