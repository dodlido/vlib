//|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|//
//|                                                                                    |//
//| ~~ gen_skid_buff_top ~~                                                            |//
//|                                                                                    |//
//| Top-level description:                                                             |//
//|    1. Data-vld-rdy skid buffer, rdy signal registered                              |//
//|                                                                                    |//
//| Features:                                                                          |//
//|    1. Parameterized data width (DAT_W)                                             |//
//|    2. Parameterized control over output registered / assigned (OPT_OUT_REG)        |//
//|                                                                                    |//
//| Scheme:                                                                            |//
//|                            __________________                                      |//
//|                           |                  |                                     |//
//|          >>-- dat_in -->> |                  |>>-- dat_out ->>                     |//
//|          >>-- vld_in -->> |     skid_buff    |>>-- vld_out ->>                     |//
//|          <<-- rdy_out -<< |                  |<<-- rdy_in --<<                     |//
//|                           |__________________|                                     |//
//|                                                                                    |//
//|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|//

module gen_skid_buff_top #(
    parameter int       DAT_W       =    4 , // Data width in bits
    parameter bit [0:0] OPT_OUT_REG = 1'b0   // Optional output registers
) (
    // General // 
    input  logic [      0:0] clk     , // clock signal
    input  logic [      0:0] rst_n   , // Async reset, active low
    // Input >--> Buffer // 
    input  logic [DAT_W-1:0] dat_in  , // Input data
    input  logic [      0:0] vld_in  , // Input valid indicator
    // Output >--> Buffer // 
    input  logic [      0:0] rdy_in  , // Output ready indicator
    // Buffer >--> Input // 
    output logic [      0:0] rdy_out , // Input ready indicator
    // Buffer >--> Output // 
    output logic [      0:0] vld_out , // Output valid indicator
    output logic [DAT_W-1:0] dat_out   // Output data
);

// Internal regs // 
logic [      0:0] full ; // Buffer is full
logic [DAT_W-1:0] buff ; // Internal buffer

// Internal wires // 
logic [      0:0] full_next    ; // Next full value
logic [DAT_W-1:0] buff_next    ; // Next buff value
logic [      0:0] vld_out_next ; // Next vld_out
logic [DAT_W-1:0] dat_out_next ; // Next dat_out value

// Internal logic //
assign full_next    = (vld_in & ~rdy_in) ? 1'b1   : (full & rdy_in) ? 1'b0 : full          ; // not ready for new input ==> full, ready and full ==> empty
assign buff_next    = (vld_in & ~rdy_in) ? dat_in : buff                                   ; // Valid input and not ready ==> sample buffer 
assign vld_out_next = ((vld_in &  rdy_in) | (full & rdy_in)) ? 1'b1 : 1'b0                 ; // Full and ready or valid input and ready ==> valid output
assign dat_out_next = (vld_in &  rdy_in) ? dat_in : (full & rdy_in) ? buff : {DAT_W{1'b0}} ; // ready for new input ==> connect to input, full and readt ==> connect to buff

// Generate output registers or assigns // 
generate
   if (OPT_OUT_REG) begin : gen_smpl_out_case
      always_ff @(posedge clk) if (!rst_n) dat_out <= DAT_W'(0) ; else dat_out <= dat_out_next ; 
      always_ff @(posedge clk) if (!rst_n) vld_out <= 1'b0      ; else vld_out <= vld_out_next ; 
   end
   else begin : gen_no_smpl_out_case
      assign dat_out = dat_out_next ; 
      assign vld_out = vld_out_next ; 
   end
endgenerate

// FFs //
// --- //
always_ff @(posedge clk) if (!rst_n) rdy_out <= 1'b0      ; else rdy_out   <= rdy_in    ; 
always_ff @(posedge clk) if (!rst_n) buff    <= DAT_W'(0) ; else buff      <= buff_next ; 
always_ff @(posedge clk) if (!rst_n) full    <= 1'b0      ; else full      <= full_next ; 

endmodule

//|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|//
//|                                               |//
//| 1. Project  :  vlib                           |//
//| 2. Author   :  Etay Sela                      |//
//| 3. Date     :  2025-01-09                     |//
//| 4. Version  :  v0.8.0                         |//
//|                                               |//
//|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|//
