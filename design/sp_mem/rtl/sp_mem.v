//|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|//
//|                                                                                    |//
//| ~~ sp_mem ~~                                                                       |//
//|                                                                                    |//
//| Top-level description:                                                             |//
//|    1. Single port register based memory                                            |//
//|                                                                                    |//
//| Features:                                                                          |//
//|    1. Parameterized write and read delays                                          |//
//|    2. Parameterized address and data widths                                        |//
//|    3. Parameterized memory depth                                                   |//
//|                                                                                    |//
//| Requirements:                                                                      |//
//|    1. R_DLY, W_DLY >= 1                                                            |//
//|    2. DEPTH <= 2^32 - 1                                                            |//
//|                                                                                    |//
//|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|//

module sp_mem #(
    parameter R_DLY =             1 , // Read delay in cycles
    parameter W_DLY =             1 , // Write delay in cycles
    parameter DAT_W =             8 , // data width in bits 
    parameter DEPTH =            32 , // Memory depth (number of words)
    parameter ADD_W = $clog2(DEPTH)   // Address width in bits
) (
    // General // 
    input wire [      0:0] clk     , // clock signal
    input wire [      0:0] rst_n   , // Async reset, active low
    // Input control // 
    input wire [      0:0] enable  , // Write enable
    input wire [      0:0] wen     , // Write enable
    input wire [      0:0] oen     , // Output enable
    input wire [ADD_W-1:0] add     , // Address  
    // Input data // 
    input wire [DAT_W-1:0] dat_in  , // Input data
    // Output data // 
    output reg [DAT_W-1:0] dat_out   // Output data
);

// Internal wires declaration // 
wire             [      0:0] masked_wr   ; 
wire             [      0:0] masked_rd   ;
wire             [DAT_W-1:0] wr_pipe_dat ;
wire             [ADD_W-1:0] wr_pipe_add ;
wire             [      0:0] wr_pipe_vld ;
wire             [DAT_W-1:0] rd_pipe_dat ;
wire [DEPTH-1:0] [DAT_W-1:0] int_strg    ; 
reg  [DEPTH-1:0]             wen_single  ;

// Mask write and read with master enable // 
assign masked_wr = wen & enable ; 
assign masked_rd = oen & enable ; 

// Generate write pipe // 
pipe #(.DEPTH(W_DLY-1), .WID(DAT_W + ADD_W + 1)) wr_pipe (
    .clk      (clk                                      ),
    .rst_n    (rst_n                                    ),
    .data_in  ({dat_in      , add         , masked_wr  }),
    .data_out ({wr_pipe_dat , wr_pipe_add , wr_pipe_vld})
) ; 

// Individual write enables logic (per word) // 
always_comb begin : wen_single_logic
    for (int i = 0; i<DEPTH; i=i+1) begin
        wen_single[i] = ( i == {{(32-ADD_W){1'b0}} , wr_pipe_add} ) & wr_pipe_vld ; 
    end
end

// Generate internal storage // 
genvar j ; 
generate
    for (j = 0; j<DEPTH; j=j+1) begin : gen_mem_loop
        base_reg #(.WID(DAT_W)) i_base_reg (
            .clk          (clk          ),
            .rst_n        (rst_n        ),
            .en           (wen_single[j]),
            .data_in      (wr_pipe_dat  ),
            .data_out     (int_strg[j]  )
        ); 
    end
endgenerate

// Generate read pipe // 
assign rd_pipe_dat = (masked_rd) ? int_strg[add] : {DAT_W{1'b0}} ; 
pipe #(.DEPTH(R_DLY), .WID(DAT_W)) rd_pipe (
    .clk      (clk           ),
    .rst_n    (rst_n         ),
    .data_in  (rd_pipe_dat   ),
    .data_out (dat_out       )
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
