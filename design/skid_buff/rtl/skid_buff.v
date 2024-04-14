//|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|//
//|                                                                                    |//
//| ~~ skid_buff ~~                                                                    |//
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

module skid_buff #(
    parameter int       DAT_W       =    8 , // Data width in bits
    parameter bit [0:0] OPT_OUT_REG = 1'b0   // Optional output registers
) (
    // General // 
    input wire [      0:0] clk     , // clock signal
    input wire [      0:0] rst_n   , // Async reset, active low
    // Input >--> Buffer // 
    input wire [DAT_W-1:0] dat_in  , // Input data
    input wire [      0:0] vld_in  , // Input valid indicator
    // Output >--> Buffer // 
    input wire [      0:0] rdy_in  , // Output ready indicator
    // Buffer >--> Input // 
    output reg [      0:0] rdy_out , // Input ready indicator
    // Buffer >--> Output // 
    output reg [      0:0] vld_out , // Output valid indicator
    output reg [DAT_W-1:0] dat_out   // Output data
);

// Internal regs // 
reg  [      0:0] full ; // Buffer is full
reg  [DAT_W-1:0] buff ; // Internal buffer

// Internal wires // 
wire [      0:0] full_next    ; // Next full value
wire [DAT_W-1:0] buff_next    ; // Next buff value
wire [      0:0] vld_out_next ; // Next vld_out
wire [DAT_W-1:0] dat_out_next ; // Next dat_out value

// Internal logic //
assign full_next    = (vld_in & ~rdy_in) ? 1'b1   : (full & rdy_in) ? 1'b0 : full          ; // not ready for new input ==> full, ready and full ==> empty
assign buff_next    = (vld_in & ~rdy_in) ? dat_in : buff                                   ; // Valid input and not ready ==> sample buffer 
assign vld_out_next = ((vld_in &  rdy_in) | (full & rdy_in)) ? 1'b1 : 1'b0                 ; // Full and ready or valid input and ready ==> valid output
assign dat_out_next = (vld_in &  rdy_in) ? dat_in : (full & rdy_in) ? buff : {DAT_W{1'b0}} ; // ready for new input ==> connect to input, full and readt ==> connect to buff

// Generate output registers or assigns // 
generate
    if (OPT_OUT_REG) begin : gen_smpl_out_case
        base_reg #(.WID(DAT_W)) i0_base_reg (
            .clk      (clk         ),
            .rst_n    (rst_n       ),
            .en       (1'b1        ),
            .data_in  (dat_out_next),
            .data_out (dat_out     )
        ); // data FFs 
        base_reg #(.WID(1)) i1_base_reg (
            .clk      (clk         ),
            .rst_n    (rst_n       ),
            .en       (1'b1        ),
            .data_in  (vld_out_next),
            .data_out (vld_out     )
        ); // valid FF
    end
    else begin : gen_no_smpl_out_case
        assign dat_out = dat_out_next ; // dat connection
        assign vld_out = vld_out_next ; // vld connection
    end
endgenerate

// Full FF // 
base_reg #(.WID(1)) i2_base_reg (
    .clk      (clk         ),
    .rst_n    (rst_n       ),
    .en       (1'b1        ),
    .data_in  (rdy_in      ),
    .data_out (rdy_out     )
); 

// Buffer FFs // 
base_reg #(.WID(DAT_W)) i3_base_reg (
    .clk      (clk         ),
    .rst_n    (rst_n       ),
    .en       (1'b1        ),
    .data_in  (buff_next   ),
    .data_out (buff        )
); 

// Full FF // 
base_reg #(.WID(1)) i4_base_reg (
    .clk      (clk         ),
    .rst_n    (rst_n       ),
    .en       (1'b1        ),
    .data_in  (full_next   ),
    .data_out (full        )
); 




endmodule

//|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|//
//|                                               |//
//| 1. Project  :  vlib                           |//
//| 2. Author   :  Etay Sela                      |//
//| 3. Date     :  2024-04-15                     |//
//| 4. Version  :  v0.4.0                         |//
//|                                               |//
//|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|//
