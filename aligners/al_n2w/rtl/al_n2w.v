//|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|//
//|                                                                                    |//
//| ~~ al_n2w ~~                                                                       |//
//|                                                                                    |//
//| Top-level description:                                                             |//
//|    1. Narrow-to-wide aligner                                                       |//
//|                                                                                    |//
//| Features:                                                                          |//
//|    1. Parameterized input width (WID_IN)                                           |//
//|    2. Parameterized output width (WID_OUT)                                         |//
//|       * Note that WID_OUT % WID_IN must be 0                                       |//
//|    3. Aligner advances only at input valid indicator high (vld_in)                 |//
//|    4. ter_in terminates the current transaction, outputs a valid out (vld_out)     |//
//|       indicator high and the currently gathered data as output (data_out)          |//
//|    5. ptr output signals the aligner internal pointer, it is a RATIO_WID bits       |//
//|       register that holds the number of valid inputs gathered in the aligner       |//
//|       a. ptr=0 --> aligner is empty                                                |//
//|       b. ptr=RATIO_VAL-1 --> aligner is full, next valid input will triger a       |//
//|          valid output                                                              |//
//|                                                                                    |//
//|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|//

module al_n2w #(
    parameter WID_IN     =                8  , // Input width in bits
    parameter WID_OUT    =               64  , // Output width in bits
    localparam RATIO_VAL = WID_OUT / WID_IN  , // Ratio (input width / output width)
    localparam RATIO_WID = $clog2(RATIO_VAL) , // Ratio width in bits
    localparam INT_WID   = 32                  // Width of integer in bits
) (
    // General // 
    input wire [0:0]           clk      , // Clock signal
    input wire [0:0]           rst_n    , // Async reset, active low
    // Input controls // 
    input wire [0:0]           vld_in   , // Valid input indicator
    input wire [0:0]           ter      , // Terminate transaction, active high
    // Input data // 
    input wire [WID_IN-1:0]    data_in  , // Input data
    // Output controls // 
    output reg [0:0]           vld_out  , // Valid output indicator
    // Output data // 
    output reg [WID_OUT-1:0]   data_out , // Output data
    // Output debug // 
    output reg [RATIO_WID-1:0] ptr      , // Aligner pointer counter
    output reg                 full     , // Aligner is full
    output reg                 empty      // Aligner is empty
);

// Internal wires // 
wire                 clr_ptr_cond ; // condition to clear pointer
wire [RATIO_WID-1:0] ptr_plus1    ; // pointer plus 1
wire [RATIO_WID-1:0] ptr_next     ; // next pointer value
wire                 vld_out_next ; // next valid output indicator

// Aligner internal storage // 
wire [RATIO_VAL-2:0] [WID_IN-1:0] int_strg ; // Internal storage the size of (RATIO_VAL-1) * WID_IN bits

// Aligner pointer assignments // 
assign full         = ({{(INT_WID-RATIO_WID){1'b0}}, ptr} == (RATIO_VAL-1))           ; // ptr reached limit
assign empty        = (ptr == {RATIO_WID{1'b0}})                                      ; // ptr is all 0's
assign ptr_plus1    = ptr + {{(RATIO_WID-1){1'b0}},1'b1}                              ; // ptr + 1 
assign clr_ptr_cond = ((ter) | (vld_in & full))                                       ; // Terminate transaction is active or aligner full and input is valid
assign ptr_next     = (clr_ptr_cond) ? {RATIO_WID{1'b0}} : (vld_in) ? ptr_plus1 : ptr ; // Clear if condition met, o.w inc only if valid input

// pointer register // 
always_ff @( posedge clk, negedge rst_n ) begin : ptr_reg
    if (!rst_n) begin // Reset
        ptr <= {RATIO_WID{1'b0}} ; 
    end
    else begin // Sample next value
        ptr <= ptr_next ; 
    end
end

// Sample aligner internal storage // 
genvar ii;
generate
    for (ii = 0 ; ii < RATIO_VAL-1 ; ii=ii+1) begin : gen_int_strg_reg_loop
        base_reg #(.WID(WID_IN)) i_base_reg (
            .clk       (clk                                                  ),
            .rst_n     (rst_n                                                ),
            .en        ((ii == {{(INT_WID-RATIO_WID){1'b0}}, ptr}) & (vld_in)), // Aligner ptr points to me and input is valid
            .data_in   (data_in                                              ),
            .data_out  (int_strg[ii]                                         )
        );
    end
endgenerate

// valid output register // 
assign vld_out_next = (full & vld_in) ; 

always_ff @( posedge clk, negedge rst_n ) begin : vld_out_reg
    if (!rst_n) begin // reset
        vld_out <= 1'b0 ; 
    end
    else begin // sample
        vld_out <= vld_out_next ; 
    end
end

// Data output assembly // 
assign data_out = {data_in, int_strg} ; // Output data is the concat of input data at the MSword and int_strg after that

endmodule