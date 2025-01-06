// 
// gen_crd_mng_top.v 
// 
// Description:
// 1. credit manager 
// 2. credits initial allocation is parameterizable (CRD_INIT_AMOUNT)
// 3. allows for multiple credit grants and decrements per cycle
// 4. outputs the current credit count and a credit-exists bit 
//

module gen_crd_mng_top #(
   // User Parameters // 
   // --------------- //
   parameter int CRD_INIT_AMOUNT  = 8 , // Initial credit amount, target FIFO depth for example
   parameter int MAX_CRD_GRNT_VAL = 1 , // Maximum amount of credits to grant in a single grant request
   parameter int MAX_CRD_USED_VAL = 1 , // Maximum amount of credits to use in a single use request

   // Inferred Parameters //
   // ------------------- //
   localparam int CRD_CNT_W  = $clog2(CRD_INIT_AMOUNT)  + 1 , // Credit count width [bits] 
   localparam int CRD_GRNT_W = $clog2(MAX_CRD_GRNT_VAL) + 1 , // Credit grant amount width [bits]
   localparam int CRD_USED_W = $clog2(MAX_CRD_USED_VAL) + 1   // Credit used amount width [bits]
)(
   // General Signals //
   // --------------- //
   input  logic                  clk          , // clock signal
   input  logic                  rst_n        , // active low reset

   // Input Controls // 
   // -------------- //
   input  logic [CRD_GRNT_W-1:0] crd_grnt_val , // credit grant value
   input  logic                  crd_grnt_en  , // credit grant enable
   input  logic [CRD_USED_W-1:0] crd_used_val , // credit used value
   input  logic                  crd_used_en  , // credit used enable

   // Output Controls // 
   // --------------- // 
   output logic [CRD_CNT_W -1:0] crd_cnt      , // credit count 
   output logic                  crd_exist      // credits exist condition, active high  

);

// Internal Wires //
// -------------- //
logic [CRD_CNT_W-1:0] crd_cnt_next     ; 
logic                 inc_y_dec_y_cond ; 
logic                 inc_y_dec_n_cond ; 
logic                 inc_n_dec_y_cond ; 
logic                 inc_n_dec_n_cond ; 
logic [CRD_CNT_W-1:0] inc_y_dec_y_val  ; 
logic [CRD_CNT_W-1:0] inc_y_dec_n_val  ; 
logic [CRD_CNT_W-1:0] inc_n_dec_y_val  ; 
logic [CRD_CNT_W-1:0] inc_n_dec_n_val  ; 

// Control logic //
// ------------- //
assign inc_y_dec_y_cond =  crd_grnt_en &  crd_used_en ; 
assign inc_y_dec_n_cond =  crd_grnt_en & ~crd_used_en ; 
assign inc_n_dec_y_cond = ~crd_grnt_en &  crd_used_en ; 
assign inc_n_dec_n_cond = ~crd_grnt_en & ~crd_used_en ; 

// Adders // 
// ------ //
assign inc_y_dec_y_val = crd_cnt + CRD_CNT_W'(crd_grnt_val) - CRD_CNT_W'(crd_used_val) ; 
assign inc_y_dec_n_val = crd_cnt + CRD_CNT_W'(crd_grnt_val)                            ; 
assign inc_n_dec_y_val = crd_cnt +                          - CRD_CNT_W'(crd_used_val) ; 
assign inc_n_dec_n_val = crd_cnt                                                       ; 

// Next credit count logic //
// ----------------------- //
assign crd_cnt_next = {CRD_CNT_W{inc_y_dec_y_cond}} & inc_y_dec_y_val | 
                      {CRD_CNT_W{inc_y_dec_n_cond}} & inc_y_dec_n_val | 
                      {CRD_CNT_W{inc_n_dec_y_cond}} & inc_n_dec_y_val | 
                      {CRD_CNT_W{inc_n_dec_n_cond}} & inc_n_dec_n_val ; 

// Output logic // 
// ------------ // 
assign crd_exist = crd_cnt >= MAX_CRD_USED_VAL ; 

// FFs //
// --- //
always_ff @(posedge clk) // credit count
   if (!rst_n) // reset
      crd_cnt <= CRD_CNT_W'(CRD_INIT_AMOUNT);
   else // sample next
      crd_cnt <= crd_cnt_next ; 

endmodule


//|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|//
//|                                               |//
//| 1. Project  :  vlib                           |//
//| 2. Author   :  Etay Sela                      |//
//| 3. Date     :  2025-01-07                     |//
//| 4. Version  :  v0.7.0                         |//
//|                                               |//
//|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|//
