
module gen_fifo_0dly_top #(
   // Parameters // 
   // ---------- //
   parameter  DEPTH = 16            , // FIFO depth 
   parameter  DAT_W = 4             , // Data width [bits]
   localparam ADD_W = $clog2(DEPTH) , // Pointers width [bits]
   localparam CNT_W = ADD_W + 1       // Counter width [bits]
)(
   // General // 
   // ------- // 
   input  logic [      0:0] clk        , // Clock signal 
   input  logic [      0:0] rst_n      , // Async reset, active low

   // Configurations //
   // -------------- // 
   input  logic [CNT_W-1:0] cfg_af_th  , // almost-full threshold, anything including and above this value will assert sts_af
   input  logic [CNT_W-1:0] cfg_ae_th  , // almost-empty threshold, anything including and below this value will assert sts_ae

   // Input Controls // 
   // -------------- //
   input  logic [      0:0] push       , // Write enable active high
   input  logic [      0:0] pop        , // Output enable active high

   // Data Path //
   // --------- //
   input  logic [DAT_W-1:0] dat_in     , // Input data
   output logic [DAT_W-1:0] dat_out    , // Output data

   // Output Statuses //
   // --------------- //
   output logic [CNT_W-1:0] sts_count  , // FIFO count
   output logic [      0:0] sts_full   , // FIFO full
   output logic [      0:0] sts_af     , // FIFO almost-full
   output logic [      0:0] sts_ae     , // FIFO almost-empty
   output logic [      0:0] sts_empty  , // FIFO empty
   output logic [      0:0] err_ovfl   , // error - overflow detected
   output logic [      0:0] err_udfl     // error - underflow detected
);

// Internal Wires //
// -------------- //
logic [DAT_W-1:0] int_fifo_dat_in   ; 
logic [DAT_W-1:0] int_fifo_dat_out  ; 
logic             int_fifo_push     ;
logic             int_fifo_pop      ;
logic [CNT_W-1:0] int_fifo_count    ; 
logic             int_fifo_full     ;
logic             int_fifo_empty    ;
logic [DAT_W-1:0] skid_buff_dat_in  ;
logic [DAT_W-1:0] skid_buff_dat_out ;
logic             skid_buff_vld_in  ; 
logic             skid_buff_rdy_in  ; 
logic             skid_buff_rdy_out ; 
logic             skid_buff_vld_out ; 

// Internal FIFO, depth of DEPTH-1 //
// ------------------------------- //
// Input control logic //
assign int_fifo_push   = push & ~byps_fifo_cond ; 
assign int_fifo_pop    = skid_buff_rdy_out & ~int_fifo_empty ; 
assign int_fifo_dat_in = dat_in ; 
// FIFO instance //
gen_reg_fifo_top #(.DEPTH(DEPTH-1), .DAT_W(DAT_W)) i_gen_reg_fifo_top (
      // Parameters // 
      // General // 
   .clk       (clk               ), // i, 0:0   X logic  , Clock signal
   .rst_n     (rst_n             ), // i, 0:0   X logic  , Async reset. active low
      // Configurations //
   .cfg_af_th ({CNT_W{1'b1}}     ), // i, CNT_W X logic  , almost-full threshold. anything including and above this value will assert sts_af
   .cfg_ae_th ({CNT_W{1'b0}}     ), // i, CNT_W X logic  , almost-empty threshold. anything including and below this value will assert sts_ae
      // Input Controls // 
   .clr       (1'b0              ), // i, 0:0   X logic  , Clear FIFO. reset all pointers to 0
   .push      (int_fifo_push     ), // i, 0:0   X logic  , Write enable active high
   .pop       (int_fifo_pop      ), // i, 0:0   X logic  , Output enable active high
      // Data Path //
   .dat_in    (int_fifo_dat_in   ), // i, DAT_W X logic  , Input data
   .dat_out   (int_fifo_dat_out  ), // o, DAT_W X logic  , Output data
      // Output Statuses //
   .sts_count (int_fifo_count    ), // o, CNT_W X logic  , FIFO count
   .sts_full  (int_fifo_full     ), // o, 0:0   X logic  , FIFO full
   .sts_af    (                  ), // o, 0:0   X logic  , FIFO almost-full
   .sts_ae    (                  ), // o, 0:0   X logic  , FIFO almost-empty
   .sts_empty (int_fifo_empty    ), // o, 0:0   X logic  , FIFO empty
   .err_ovfl  (                  ), // o, 0:0   X logic  , error - overflow detected
   .err_udfl  (                  )  // o, 0:0   X logic  , error - underflow detected
);

// 1-level Skid Buffer at the output level //
// --------------------------------------- // 
// Buffer input logic // 
assign byps_fifo_cond   = skid_buff_rdy_out &  int_fifo_empty & push           ; // If the FIFO is empty and the skid buffer is empty we can bypass the internal FIFO 
assign skid_buff_dat_in = byps_fifo_cond ? dat_in : int_fifo_dat_out           ; // In case of bypassing the FIFO, skid buffer input is the main input data 
assign skid_buff_vld_in = byps_fifo_cond | skid_buff_rdy_out & ~int_fifo_empty ; // valid in case bypass of internal FIFO or the internal FIFO is not empty and buffer is
assign skid_buff_rdy_in = pop                                                  ; // simply use the pop
// Buffer instance // 
gen_skid_buff_top #(.DAT_W(DAT_W)) i_gen_skid_buff_top (
       // General // 
   .clk     (clk              ), // i, 0:0   X wire  , clock signal
   .rst_n   (rst_n            ), // i, 0:0   X wire  , Async reset. active low
       // Input >--> Buffer // 
   .dat_in  (skid_buff_dat_in ), // i, DAT_W X wire  , Input data
   .vld_in  (skid_buff_vld_in ), // i, 0:0   X wire  , Input valid indicator
       // Output >--> Buffer //, 
   .rdy_in  (skid_buff_rdy_in ), // i, 0:0   X wire  , Output ready indicator
       // Buffer >--> Input // , 
   .rdy_out (skid_buff_rdy_out), // o, 0:0   X reg   , Input ready indicator
       // Buffer >--> Output // 
   .vld_out (skid_buff_vld_out), // o, 0:0   X reg   , Output valid indicator
   .dat_out (skid_buff_dat_out)  // o, DAT_W X reg   , Output data
);

// Output Level // 
// ------------ //
assign dat_out   = skid_buff_dat_out ; 
// Count // 
assign sts_count = int_fifo_count + {{(CNT_W-1){1'b0}}, skid_buff_rdy_out} ; 
// Statuses // 
assign sts_empty = ~skid_buff_vld_out ; 
assign sts_ae    = sts_count <= cfg_ae_th ; 
assign sts_af    = sts_count >= cfg_af_th ; 
assign sts_full  = int_fifo_full & ~skid_buff_rdy_out ; 
// Errors // 
assign err_ovfl  = push & sts_full  ; 
assign err_udfl  = pop  & sts_empty ;

endmodule

//|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|//
//|                                               |//
//| 1. Project  :  vlib                           |//
//| 2. Author   :  Etay Sela                      |//
//| 3. Date     :  2025-02-08                     |//
//| 4. Version  :  v0.10.0                        |//
//|                                               |//
//|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|//
