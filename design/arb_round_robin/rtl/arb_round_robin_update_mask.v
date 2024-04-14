
module arb_round_robin_update_mask #(
    parameter WID = 16 // rqsts and grnts bus width in bits
) (
    // General // 
    input wire [    0:0] clk   , // Clock signal
    input wire [    0:0] rst_n , // Async reset, active high
    // Inputs // 
    input wire [WID-1:0] grnts , // Grant bus
    // Outputs // 
    output reg [WID-1:0] mask    // requests mask
);

// Internal wires // 
wire [WID-1:0] mask_next ; // Next values for mask

// Next mask values logic // 
genvar II;
generate
    for (II = 0; II < WID ; II = II + 1 ) begin
        if (II==0) begin
            assign mask_next[II] = 1'b0 ; // First bit of mask is always 0
        end
        else begin 
            assign mask_next[II] = mask_next[II-1] | grnts[II-1] ; 
        end
    end
endgenerate

// mask FFs // 
always_ff @( posedge clk, negedge rst_n ) begin
    if (!rst_n) begin
        mask <= {WID{1'b0}} ; 
    end
    else begin
        mask <= mask_next ; 
    end
end

endmodule

//|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|//
//|                                               |//
//| 1. Project  :  vlib                           |//
//| 2. Author   :  Etay Sela                      |//
//| 3. Date     :  2024-04-15                     |//
//| 4. Version  :  v0.4.0                         |//
//|                                               |//
//|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|//
