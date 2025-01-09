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
//|    5. ptr output signals the aligner internal pointer, it is a RATIO_WID bits      |//
//|       register that holds the number of valid inputs gathered in the aligner       |//
//|       a. ptr=0 --> aligner is empty                                                |//
//|       b. ptr=RATIO_VAL-1 --> aligner is full, next valid input will triger a       |//
//|          valid output                                                              |//
//|                                                                                    |//
//|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|//

module gen_al_n2w_top #(
    parameter WID_IN     =                4  , // Input width in bits
    parameter WID_OUT    =                16 , // Output width in bits
    localparam RATIO_VAL = WID_OUT / WID_IN  , // Ratio (input width / output width)
    localparam RATIO_WID = $clog2(RATIO_VAL) , // Ratio width in bits
    localparam INT_WID   = 32                  // Width of integer in bits
) (
    // General // 
    input  logic                 clk      , // Clock signal
    input  logic                 rst_n    , // Async reset, active low
    // Input controls // 
    input  logic                 vld_in   , // Valid input indicator
    input  logic                 ter      , // Terminate transaction, active high
    // Input data // 
    input  logic [WID_IN-1:0]    data_in  , // Input data
    // Output controls // 
    output logic                 vld_out  , // Valid output indicator
    // Output data // 
    output logic [WID_OUT-1:0]   data_out , // Output data
    // Output debug // 
    output logic [RATIO_WID-1:0] ptr      , // Aligner pointer counter
    output logic                 full     , // Aligner is full
    output logic                 empty      // Aligner is empty
);

// Internal wires // 
logic                 clr_ptr_cond ; // condition to clear pointer
logic                 vld_out_next ; // next valid output indicator

// Aligner internal storage // 
logic [RATIO_VAL-2:0] [WID_IN-1:0] int_strg ; // Internal storage the size of (RATIO_VAL-1) * WID_IN bits

// --------------------------------------------------------- //
// the below instance was generated automatically by enst.py //

gen_cnt_top #(.CNT_W(RATIO_WID)) i_gen_cnt_top (
       // General // 
   .clk   (clk                      ), // i, 0:0   X logic  , Clock signal
   .rst_n (rst_n                    ), // i, 0:0   X logic  , sync reset. active low
       // Input Controls // 
   .lim   (RATIO_WID'(RATIO_VAL-1)  ), // i, CNT_W X logic  , Counter limit
   .inc   (vld_in                   ), // i, 0:0   X logic  , Increment counter
   .dec   (1'b0                     ), // i, 0:0   X logic  , Decrement counter
   .clr   (ter                      ), // i, 0:0   X logic  , Clear counter
       // Output Count // 
   .count (ptr                      )  // o, CNT_W X logic  , Counter value
);

// the above instance was generated automatically by enst.py //
// --------------------------------------------------------- //

// Aligner pointer assignments // 
assign full  = ptr == RATIO_WID'(RATIO_VAL-1) ; // ptr reached limit
assign empty = ptr == RATIO_WID'(0)           ; // ptr is all 0's

// Sample aligner internal storage // 
genvar II;
generate
   logic [RATIO_VAL-1-1:0] int_strg_we ; 
   for (II = 0 ; II < RATIO_VAL-1 ; II=II+1) begin : gen_int_strg_reg_loop
      assign int_strg_we[II] = (ptr == RATIO_WID'(II)) & (vld_in); 
      always_ff @(posedge clk) if (!rst_n) int_strg[II] <= WID_IN'(0) ; else if (int_strg_we[II]) int_strg[II] <= data_in ; 
   end
endgenerate

// valid out logic // 
assign vld_out = (full & vld_in) ; 

// Data output assembly // 
assign data_out = {data_in, int_strg} ; // Output data is the concat of input data at the MSword and int_strg after that

endmodule

//|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|//
//|                                               |//
//| 1. Project  :  vlib                           |//
//| 2. Author   :  Etay Sela                      |//
//| 3. Date     :  2025-01-10                     |//
//| 4. Version  :  v0.9.0                         |//
//|                                               |//
//|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|//
