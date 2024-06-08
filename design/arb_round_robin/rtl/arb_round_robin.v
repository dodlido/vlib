//|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|//
//|                                                                                    |//
//| ~~ arb_round_robin ~~                                                              |//
//|                                                                                    |//
//| Top-level description:                                                             |//
//|    1. Round-robin arbiter, lsb highest prio                                        |//
//|                                                                                    |//
//| Features:                                                                          |//
//|    1. Parameterized request and grnts bus width in bits (WID)                      |//
//|                                                                                    |//
//|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|//

module arb_round_robin #(
    parameter WID = 16 // rqsts and grnts bus width in bits
) (
    // General // 
    input wire [    0:0] clk   , // Clock signal
    input wire [    0:0] rst_n , // Async reset, active high
    // Inputs // 
    input wire [WID-1:0] rqsts , // Requests bus
    // Outputs // 
    output reg [WID-1:0] grnts   // Grants bus
);

// Internal wires // 
wire [WID-1:0] base_grnts   ; // Unmasked grnts
wire [WID-1:0] mask         ; // Mask for request bus
wire [WID-1:0] masked_rqsts ; // Masked rqsts bus
wire [WID-1:0] masked_grnts ; // Masked grnts bus
wire [    0:0] mask_grntd   ; // Mask granted indicator

// Internal Logic // 
assign masked_rqsts = mask & rqsts                           ; // mask input rqsts with current mask
assign mask_grntd   = |(masked_grnts)                        ; // bit-wise or of all masked grants
assign grants       = mask_grntd ? masked_grnts : base_grnts ; // Prioritize masked grants

// Basic arbiter instance // 
arb_strict #(.WID(WID)) i_arb_strict (
    .rqsts (rqsts       ), 
    .grnts (base_grnts  )
);

// Masked arbiter instance // 
arb_strict #(.WID(WID)) i_arb_strict (
    .rqsts (masked_rqsts), 
    .grnts (masked_grnts)
);

// Update mask instance // 
arb_round_robin_update_mask #(.WID(WID)) i_arb_round_robin_update_mask (
    .clk   (clk  ),
    .rst_n (rst_n),
    .grnts (grnts),
    .mask  (mask )
); 

endmodule

//|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|//
//|                                               |//
//| 1. Project  :  vlib                           |//
//| 2. Author   :  Etay Sela                      |//
//| 3. Date     :  2024-06-08                     |//
//| 4. Version  :  v0.6.0                         |//
//|                                               |//
//|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|//
