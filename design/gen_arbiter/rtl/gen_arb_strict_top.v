//|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|//
//|                                                                                    |//
//| ~~ gen_arb_strict_top ~~                                                           |//
//|                                                                                    |//
//| Top-level description:                                                             |//
//|    1. Strict priority, combinational arbiter, lsb highest prio                     |//
//|                                                                                    |//
//| Features:                                                                          |//
//|    1. Parameterized request and grnts bus width in bits (WID)                      |//
//|                                                                                    |//
//|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|//

module gen_arb_strict_top #(
    parameter WID = 4 // rqsts and grnts bus width in bits
) (
    // Inputs // 
    input  logic [WID-1:0] rqsts , // Request bus
    // Outputs // 
    output logic [WID-1:0] grnts   // grnts bus
);

    // Internal wires // 
    logic [WID-1:0] prev_g ; // Previous grnts, prev_g[i] is high if a request was granted in index j<i

    // Generate internal grant logic // 
    genvar i;
    generate
        for (i = 0; i < WID; i = i + 1) begin: gen_arb_loop
            if (i==0) begin: gen_1st_stage_cond
                assign prev_g[i] = 1'b0     ; // prev_g initial conditions
                assign grnts[i]  = rqsts[i] ; // grnts initial conditions
            end
            else begin: gen_rest_cond
                assign prev_g[i] = prev_g[i-1] | rqsts[i-1] ; // previous grant check previous grnts and nearest request
                assign grnts[i]  = ~prev_g[i]  & rqsts[i]   ; // grant only if not previously granted and request is high
            end
        end
    endgenerate

endmodule


//|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|//
//|                                               |//
//| 1. Project  :  vlib                           |//
//| 2. Author   :  Etay Sela                      |//
//| 3. Date     :  2025-01-07                     |//
//| 4. Version  :  v0.7.0                         |//
//|                                               |//
//|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|//
