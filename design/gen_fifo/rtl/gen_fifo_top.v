//
// gen_fifo_top.v
//
// Description: generic register based FIFO
//
// Features:
// 1. Parameterizable depth and data width
// 2. Configurable almost-full and almost empty thresholds
// 3. Overflow and Underflow are protected by design and the user is notified
//    of the event
//

module gen_fifo_top #(
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
   input  logic [      0:0] clr        , // Clear FIFO, reset all pointers to 0
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
logic [ADD_W-1:0] address ; 
logic [ADD_W-1:0] wr_ptr  ; 
logic [ADD_W-1:0] rd_ptr  ; 

// Internal Logic //
// -------------- //
assign address = push ? wr_ptr : rd_ptr ; 

// FIFO Registers // 
// -------------- //
gen_reg_mem_top #(.ADD_W(ADD_W), .DAT_W(DAT_W), .DEPTH(DEPTH)) i_gen_reg_mem_top (
   // Memory dimensions // 
   // General // 
   .clk     (clk          ), // i, 0:0   X logic  , clock signal
   .rst_n   (rst_n        ), // i, 0:0   X logic  , Async reset. active low
   // Input control // 
   .cs      (1'b1         ), // i, 0:0   X logic  , Chip-select
   .wen     (push         ), // i, 0:0   X logic  , Write enable
   .add     (address      ), // i, ADD_W X logic  , Address
   // Input data // 
   .dat_in  (dat_in       ), // i, DAT_W X logic  , Input data
   .bit_sel ({DAT_W{1'b1}}), // i, DAT_W X logic  , bit-select
   // Output data // 
   .dat_out (dat_out      )  // o, DAT_W X logic  , Output data
);

// FIFO Control //
// ------------ //
gen_fifo_ctrl_top #(.DEPTH(DEPTH)) i_gen_fifo_ctrl_top (
   // General // 
   .clk       (clk      ), // i, 0:0   X logic  , Clock signal
   .rst_n     (rst_n    ), // i, 0:0   X logic  , Async reset. active low
   // Configurations //
   .cfg_af_th (cfg_af_th), // i, CNT_W X logic  , almost-full threshold. anything including and above this value will assert sts_af
   .cfg_ae_th (cfg_ae_th), // i, CNT_W X logic  , almost-empty threshold. anything including and below this value will assert sts_ae
   // Input Controls // 
   .clr       (clr      ), // i, 0:0   X logic  , Clear FIFO. reset all pointers to 0
   .push      (push     ), // i, 0:0   X logic  , Write enable active high
   .pop       (pop      ), // i, 0:0   X logic  , Output enable active high
   // Output Controls // , 
   .rd_ptr    (rd_ptr   ), // o, PTR_W X logic  , Read pointer
   .wr_ptr    (wr_ptr   ), // o, PTR_W X logic  , Write pointer
   // Output Statuses //
   .sts_count (sts_count), // o, CNT_W X logic  , FIFO count
   .sts_full  (sts_full ), // o, 0:0   X logic  , FIFO full
   .sts_af    (sts_af   ), // o, 0:0   X logic  , FIFO almost-full
   .sts_ae    (sts_ae   ), // o, 0:0   X logic  , FIFO almost-empty
   .sts_empty (sts_empty), // o, 0:0   X logic  , FIFO empty
   .err_ovfl  (err_ovfl ), // o, 0:0   X logic  , error - overflow detected
   .err_udfl  (err_udfl )  // o, 0:0   X logic  , error - underflow detected
);

endmodule
