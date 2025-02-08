//|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|//
//|                                                                                    |//
//| ~~ gen_fifo_ctrl_mult_ch_top.v ~~                                                  |//
//|                                                                                    |//
//| Top-level description:                                                             |//
//|    1. This provides a wrapper to a SP-SRAM that is managed as a multi-channel FIFO |//
//|                                                                                    |//
//| Interfaces and naming conventions:                                                 |//
//|    1. Writes are signaled to the module over the 'usr_in_' interface               |//
//|    2. Reads are signaled to the user over the 'usr_out_' interface                 |//
//|    3. Read requests are signaled over the 'rd_' interface                          |//
//|    4. Clearing channels can be requested over the 'clr_' interface                 |//
//|    5. Configurations are signaled to this module over the 'cfg_' signals           |//
//|    6. The block signals statuses, functional and error interrupts over the 'sts_', |//
//|       'func_' and 'err_' signals respectivly                                       |//
//|    7. The 'mem_' interface should be connected to a single port S-RAM              |// 
//|                                                                                    |//
//| Theory-of-operation:                                                               |//
//|    1. Writes are always given a priority, no skid-FIFO is implemented to           |//
//|       buffer input data                                                            |//
//|    2. Read requests enter a credit bank per channel and are granted using an       |//
//|       arbitration process. Use RR_ARB_OPT to select which arbitration method       |//
//|    3. Configurable thresholds - the user can choose where exactly he would like to |//
//|       almost-full and almost-empty indications for both the credit counters and    |//
//|       data entries counts within the SRAM per-channel                              |//
//|    3. Clearing channels - the user can signal a clear request for a channel. doing |//
//|       so will trigger the following process:                                       |//
//|       a. The block throws away all input data and read requests of the cleared     |//
//|          channel unitl the process is done                                         |//
//|       b. The block grants all pre-existing read credits, prioritizing the cleared  |//
//|          channel for all upcoming read requests                                    |//
//|       c. The block resets the read and write pointers of the channel's FIFO        |//
//|       d. The block notifies the user that the clearing process is done             |//
//|                                                                                    |//
//|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|//

module gen_fifo_ctrl_mult_ch_top #(
   // User Parameters //
   // --------------- //
   parameter           CH_N         =    4 , // Number of channels  
   parameter           ADD_W        =    4 , // Pointers width [bits]
   parameter           DAT_W        =    4 , // Data width [bits] 
   parameter           RQST_CRDT_N  =    4 , // Number of pending requests the block can hold per channel
   parameter bit [0:0] RR_ARB_OPT   = 1'b0 , // Set to 1'b1 to use round-robin arbitration of read requests, default is strict-prio
   parameter           DLY_USER2MEM =    0 , // Delay between the user IF to the memory [cycles]
   parameter           DLY_MEM2USER =    1 , // Delay between the memory instance to the user [cycles]

   // Inferred Parameter // 
   // ------------------ //
   localparam RQST_CRDT_W = $clog2(RQST_CRDT_N) + 1 , // Request credit counters width [bits]
   localparam CH_W        = $clog2(CH_N)            , // Channel index width [bits]
   localparam CNT_W       = ADD_W + 1                 // Counter width [bits]
)(
   // --------------------------------------------------------------- //
   // ------------------------ User Interface ----------------------- // 
   // --------------------------------------------------------------- //
   // General // 
   // ------- // 
   input  logic                              clk               , // Clock signal 
   input  logic                              rst_n             , // Async reset, active low

   // Configurations //
   // -------------- // 
   input  logic [CH_N-1:0][ADD_W       -1:0] cfg_vec_dat_base  , // Per-Channel data base address configuration 
   input  logic [CH_N-1:0][CNT_W       -1:0] cfg_vec_dat_size  , // Per-Channel data size configuration 
   input  logic [CH_N-1:0][CNT_W       -1:0] cfg_vec_dat_af_th , // Per-Channel data almost-full threshold
   input  logic [CH_N-1:0][CNT_W       -1:0] cfg_vec_dat_ae_th , // Per-Channel data almost-empty threshold
   input  logic [CH_N-1:0][RQST_CRDT_W -1:0] cfg_vec_crd_af_th , // Per-Channel  credits almost-full threshold per channel
   input  logic [CH_N-1:0][RQST_CRDT_W -1:0] cfg_vec_crd_ae_th , // Per-Channel  credits almost-empty threshold per channel

   // Input Controls // 
   // -------------- //
   input  logic                              clr_rqst          , // Clear FIFO, request reset all pointers to 0
   input  logic           [CH_W        -1:0] clr_ch_num        , // Clear FIFO, channel number, reset all pointers to 0
   input  logic                              rd_rqst           , // Read data from channel, request
   input  logic           [CH_W        -1:0] rd_ch_num         , // Read data from channel, channel number

   // Data Path //
   // --------- //
   input  logic                              usr_in_vld        , // User Input IF, valid indicator
   input  logic           [CH_W        -1:0] usr_in_ch_num     , // User Input IF, channel number
   input  logic           [DAT_W       -1:0] usr_in_dat        , // User Input IF, data
   output logic                              usr_out_vld       , // User Output IF, valid indicator
   output logic           [CH_W        -1:0] usr_out_ch_num    , // User Output IF, channel number
   output logic           [DAT_W       -1:0] usr_out_dat       , // User Output IF, data

   // Output Statuses //
   // --------------- //
   output logic [CH_N-1:0][CNT_W       -1:0] sts_vec_dat_count , // Per-Channel Data FIFO count
   output logic [CH_N-1:0]                   sts_vec_dat_full  , // Per-Channel Data FIFO full
   output logic [CH_N-1:0]                   sts_vec_dat_af    , // Per-Channel Data FIFO almost-full
   output logic [CH_N-1:0]                   sts_vec_dat_ae    , // Per-Channel Data FIFO almost-empty
   output logic [CH_N-1:0]                   sts_vec_dat_empty , // Per-Channel Data FIFO empty
   output logic [CH_N-1:0][RQST_CRDT_W -1:0] sts_vec_crd_count , // Per-Channel Credits count
   output logic [CH_N-1:0]                   sts_vec_crd_full  , // Per-Channel Credits full
   output logic [CH_N-1:0]                   sts_vec_crd_af    , // Per-Channel Credits almost-full
   output logic [CH_N-1:0]                   sts_vec_crd_ae    , // Per-Channel Credits almost-empty
   output logic [CH_N-1:0]                   sts_vec_crd_empty , // Per-Channel Credits empty

   // Output Interrupts //
   // ----------------- //
   output logic [CH_N-1:0]                   err_vec_dat_ovfl  , // Per-Channel error - data overflow detected
   output logic [CH_N-1:0]                   err_vec_dat_udfl  , // Per-Channel error - data underflow detected
   output logic [CH_N-1:0]                   err_vec_rqst_ovfl , // Per-Channel error - request overflow detected
   output logic [CH_N-1:0]                   err_vec_rqst_udfl , // Per-Channel error - request underflow detected
   output logic                              err_clr_rqst_ovfl , // Clear request initiated in the middle of the previous clearing process
   output logic                              func_ch_clrd      , // Functional interrupt - last clear request done

   // ----------------------------------------------------------------- //
   // ------------------------ Memory Interface ----------------------- // 
   // ----------------------------------------------------------------- //
   // Input control // 
   // ------------- //
   output logic                              mem_cs            , // Chip-select 
   output logic                              mem_wen           , // Write enable
   output logic           [ADD_W       -1:0] mem_add           , // Address  

   // Input data // 
   // ---------- //
   output logic           [DAT_W       -1:0] mem_dat_in        , // Input data (from memory POV)

   // Output data // 
   // ----------- //
   input  logic           [DAT_W       -1:0] mem_dat_out         // Output data (from memory POV)
);

// Type defs and Local Parameters // 
// ------------------------------ //
typedef enum bit [1:0] {CLR_IDLE=2'b00, CLR_IN_PROG=2'b01, CLR_DONE=2'b10, CLR_RESERVED=2'b11} clr_sts_e ; 

// Internal Wires //
// -------------- // 
logic                       usr_in_vld_masked     ; 
logic [CH_N-1:0]            clr_ch_oh             ; 
logic [CH_W-1:0]            push_rqst_ch_num      ;                                
logic                       push_rqst_vld         ;                                
logic [CH_N-1:0]            push_ch_oh            ; 
logic [CH_N-1:0][ADD_W-1:0] rd_ptr_vec            ; 
logic [CH_N-1:0][ADD_W-1:0] wr_ptr_vec            ; 
logic [CH_N-1:0][ADD_W-1:0] addr_vec              ; 
logic [CH_N-1:0]            rd_rqst_ch_oh         ; // This increments credits 
logic [CH_N-1:0]            crd_exists_ch         ; // This signals that credits exist
logic [CH_N-1:0]            pop_ch_oh             ; // This pops , one-hot vector
logic [CH_W-1:0]            pop_ch_num            ; // encoded version of pop_ch_oh
logic [CH_W-1:0]            addr_mux_sel          ; // address MUX select signal
clr_sts_e                   clr_sts_next          ; 
logic                       clr_ch_crd_exist      ;
logic [CH_W-1:0]            int_clr_ch_num_next   ;                             
logic [CH_N-1:0]            int_clr_ch_oh_next    ;                             
logic [CH_N-1:0]            arb_rd_rqsts_vec      ; 
logic [CH_N-1:0]            arb_rd_rqsts_clr_mask ; 
// Internal Registers // 
// ------------------ //
clr_sts_e                   clr_sts_curr          ; 
logic [CH_W-1:0]            int_clr_ch_num        ;                             

// Decoders // 
// -------- //
// Decode Read Requests //
gen_dec_top #(
   .DAT_IN_W(CH_W         )  // type: int, default: 2, description: input data width [bits]
) i0_gen_dec_top (
   // Input data //
   .dat_in  (rd_ch_num    ), // i, DAT_IN_W X logic  , input encoded data
   .en      (rd_rqst      ), // i, [1]      X logic  , enable bit. output is 0's if this is asserted low
   // Output data // 
   .dat_out (rd_rqst_ch_oh)  // o, DAT_OUT_W X logic  , decoded version of dat_in. one-hot vector
);
// Decode Write Requests //
gen_dec_top #(
   .DAT_IN_W(CH_W             )  // type: int, default: 2, description: input data width [bits]
) i1_gen_dec_top (
   // Input data // 
   .dat_in  (push_rqst_ch_num ), // i, DAT_IN_W X logic  , input encoded data
   .en      (push_rqst_vld    ), // i, [1]      X logic  , enable bit. output is 0's if this is asserted low
   // Output data // 
   .dat_out (push_ch_oh       )  // o, DAT_OUT_W X logic  , decoded version of dat_in. one-hot vector
);

// Generate FIFO controls and Credit Managers // 
// ------------------------------------------ // 
genvar CH_IDX ; 
generate
   for (CH_IDX=0; CH_IDX<CH_N; CH_IDX++) begin: gen_controls_loop
      // Credit Managers // 
      gen_crd_mng_top #(
         .CRD_INIT_AMOUNT  (RQST_CRDT_N), // type: int, default: 8, description: Initial credit amount, target FIFO depth for example
         .MAX_CRD_GRNT_VAL (1          ), // type: int, default: 1, description: Maximum amount of credits to grant in a single grant request
         .MAX_CRD_USED_VAL (1          )  // type: int, default: 1, description: Maximum amount of credits to use in a single use request
      ) i_gen_crd_mng_top (
         // General Signals //
         .clk          (clk                       ), // i, [1]        X logic  , clock signal
         .rst_n        (rst_n                     ), // i, [1]        X logic  , active low reset
         // Input Controls // 
         .crd_grnt_val (1'b1                      ), // i, CRD_GRNT_W X logic  , credit grant value
         .crd_grnt_en  (rd_rqst_ch_oh    [CH_IDX] ), // i, [1]        X logic  , credit grant enable
         .crd_used_val (1'b1                      ), // i, CRD_USED_W X logic  , credit used value
         .crd_used_en  (pop_ch_oh        [CH_IDX] ), // i, [1]        X logic  , credit used enable
         // Output Controls // 
         .crd_cnt      (sts_vec_crd_count[CH_IDX] ), // o, CRD_CNT_W  X logic  , credit count
         .crd_exist    (crd_exists_ch    [CH_IDX] )  // o, [1]        X logic  , credits exist condition. active high
      );
      // Credit statueses //
      assign sts_vec_crd_full [CH_IDX] = sts_vec_crd_count[CH_IDX]==RQST_CRDT_W'(RQST_CRDT_N) ; // full 
      assign sts_vec_crd_af   [CH_IDX] = sts_vec_crd_count[CH_IDX]>=cfg_vec_crd_af_th[CH_IDX] ; // almost-full
      assign sts_vec_crd_ae   [CH_IDX] = sts_vec_crd_count[CH_IDX]<=cfg_vec_crd_ae_th[CH_IDX] ; // almost-empty
      assign sts_vec_crd_empty[CH_IDX] = sts_vec_crd_count[CH_IDX]==RQST_CRDT_W'(0)           ; // empty
      assign err_vec_rqst_ovfl[CH_IDX] = sts_vec_crd_full [CH_IDX]& rd_rqst_ch_oh[CH_IDX]     ; // overflow
      assign err_vec_rqst_udfl[CH_IDX] = sts_vec_crd_empty[CH_IDX]& pop_ch_oh    [CH_IDX]     ; // underflow
      
      // FIFO Controls // 
      gen_fifo_ctrl_cfg_size_top #(
         .PTR_W(ADD_W)  // type: int, default: 4, description: Pointers width [bits]
      ) i_gen_fifo_ctrl_cfg_size_top (
         // General // 
         .clk       (clk                       ), // i, 0:0   X logic  , Clock signal
         .rst_n     (rst_n                     ), // i, 0:0   X logic  , Async reset. active low
         // Configurations //
         .cfg_size  (cfg_vec_dat_size [CH_IDX] ), // i, CNT_W X logic  , Configurable FIFO size. specifies the FIFO depth
         .cfg_af_th (cfg_vec_dat_af_th[CH_IDX] ), // i, CNT_W X logic  , almost-full threshold. anything including and above this value will assert sts_af
         .cfg_ae_th (cfg_vec_dat_ae_th[CH_IDX] ), // i, CNT_W X logic  , almost-empty threshold. anything including and below this value will assert sts_ae
         // Input Controls // 
         .clr       (clr_ch_oh        [CH_IDX] ), // i, 0:0   X logic  , Clear FIFO. reset all pointers to 0 
         .push      (push_ch_oh       [CH_IDX] ), // i, 0:0   X logic  , Write enable active high
         .pop       (pop_ch_oh        [CH_IDX] ), // i, 0:0   X logic  , Output enable active high
         // Output Controls // 
         .rd_ptr    (rd_ptr_vec       [CH_IDX] ), // o, PTR_W X logic  , Read pointer
         .wr_ptr    (wr_ptr_vec       [CH_IDX] ), // o, PTR_W X logic  , Write pointer
         // Output Statuses //
         .sts_count (sts_vec_dat_count[CH_IDX] ), // o, CNT_W X logic  , FIFO count
         .sts_full  (sts_vec_dat_full [CH_IDX] ), // o, 0:0   X logic  , FIFO full
         .sts_af    (sts_vec_dat_af   [CH_IDX] ), // o, 0:0   X logic  , FIFO almost-full
         .sts_ae    (sts_vec_dat_ae   [CH_IDX] ), // o, 0:0   X logic  , FIFO almost-empty
         .sts_empty (sts_vec_dat_empty[CH_IDX] ), // o, 0:0   X logic  , FIFO empty
         .err_ovfl  (err_vec_dat_ovfl [CH_IDX] ), // o, 0:0   X logic  , error - overflow detected
         .err_udfl  (err_vec_dat_udfl [CH_IDX] )  // o, 0:0   X logic  , error - underflow detected
      );
      assign addr_vec[CH_IDX] = push_ch_oh[CH_IDX] ? wr_ptr_vec[CH_IDX] : rd_ptr_vec[CH_IDX] ; // MUX between read and write pointers
   end
endgenerate 

// Arbitrate read requests //
// ----------------------- // 
assign arb_rd_rqsts_vec = arb_rd_rqsts_clr_mask & crd_exists_ch & {CH_N{~usr_in_vld_masked}} ; // any of the channels requested a read and no channels requested a write
generate 
   if (RR_ARB_OPT) begin: gen_rr_arb_cond
      gen_arb_rr_top #(
         .WID(CH_N)  // type: int, default: 1, description: 
      ) i_gen_arb_rr_top (
         // General // 
         .clk   (clk             ), // i, 0:0 X wire  , Clock signal
         .rst_n (rst_n           ), // i, 0:0 X wire  , Async reset. active high
         // Inputs //            )
         .rqsts (arb_rd_rqsts_vec), // i, WID X wire  , Requests bus
         // Outputs //           )
         .grnts (pop_ch_oh       ) // o, WID  X reg   , Grants bus
      );
   end
   else begin: gen_strict_arb_cond
      gen_arb_strict_top #(
         .WID(CH_N)  // type: int, default: 1, description: 
      ) i_gen_arb_strict_top (
         // Inputs // 
         .rqsts (arb_rd_rqsts_vec), // i, WID X wire  , Request bus
         // Outputs // 
         .grnts (pop_ch_oh       )  // o, WID X reg   , grnts bus
      );
   end
endgenerate

// Drive memory interface //
// ---------------------- //
// Encoder to choose the correct address //
gen_enc_top #(
   .DAT_IN_W(CH_N)  // type: int, default: 4, description: input data width [bits]
) i_gen_enc_top (
   // Input data //
   .dat_in  (pop_ch_oh ), // i, DAT_IN_W  X logic  , one-hot decoded vector
   // Output data // 
   .dat_out (pop_ch_num)  // o, DAT_OUT_W X logic  , encoded version of the dat_in one-hot vector
);
// MUX address to memory // 
assign addr_mux_sel = usr_in_vld_masked ? usr_in_ch_num : pop_ch_num ; 
assign mem_add = addr_vec[addr_mux_sel] + cfg_vec_dat_base[addr_mux_sel] ; // adding base as offset to memory address
// Delay pipe //
// 1. |pop_ch_oh    -- DLY_USER2MEM + DLY_MEM2USER cycles later --> usr_out_vld
// 2. usr_in_vld    -- DLY_USER2MEM + DLY_MEM2USER cycles later --> push_rqst_vld 
// 2. usr_in_ch_num -- DLY_USER2MEM + DLY_MEM2USER cycles later --> push_rqst_ch_num
gen_pipe_top #(
   .DEPTH      (DLY_USER2MEM + DLY_MEM2USER), // type: int, default: 4, description: Pipe depth
   .DAT_W      (1 + CH_W + 1 + CH_W        ), // type: int, default: 8, description: Data width
   .LOW_PWR_OPT(1'b0                       )  // type: bit, default: 1, description: 
) i_gen_pipe_top (
   // General // 
   .clk     (clk                                                                     ), // i, 0:0   X logic  , clock signal
   .rst_n   (rst_n                                                                   ), // i, 0:0   X logic  , Async reset. active low
   // Input data // 
   .dat_in  ({(|(pop_ch_oh)), pop_ch_num    ,  usr_in_vld_masked  , usr_in_ch_num   }), // i, DAT_W X logic  , Input data
   .vld_in  (1'b1                                                                    ), // i, 0:0   X logic  , Input valid indicator
   // Output data // 
   .dat_out ({usr_out_vld   , usr_out_ch_num, push_rqst_vld       , push_rqst_ch_num}), // o, DAT_W X logic  , Output data
   .vld_out (                                                                        )  // o, 0:0   X logic  , Output valid indicator
);
// Memory IF // 
assign mem_cs      = 1'b1              ; 
assign mem_dat_in  = usr_in_dat        ; 
assign mem_wen     = usr_in_vld_masked ; 
assign usr_out_dat = mem_dat_in        ;

// Clear Channel FSM //
// ----------------- //
// MUX credits exist signal for the cleared channel // 
assign int_clr_ch_num_next = clr_rqst & clr_sts_curr==CLR_IDLE ? clr_ch_num : int_clr_ch_num ; 
assign clr_ch_crd_exist = crd_exists_ch[int_clr_ch_num_next] ; 
// Next state logic // 
always_comb begin   
   case (clr_sts_curr)
      CLR_IDLE   : begin
         if (clr_rqst & ~clr_ch_crd_exist)
            clr_sts_next = CLR_DONE ; 
         else if (clr_rqst) 
            clr_sts_next = CLR_IN_PROG ; 
         else 
            clr_sts_next = CLR_IDLE ; 
      end
      CLR_IN_PROG: begin 
         if (~clr_ch_crd_exist)
            clr_sts_next = CLR_DONE ; 
         else
            clr_sts_next = CLR_IN_PROG ; 
      end
      CLR_DONE   : clr_sts_next = CLR_IDLE ; 
      default    : clr_sts_next = CLR_IDLE ; // SNGH
   endcase
end
// Decode Clear Requests //
gen_dec_top #(
   .DAT_IN_W(CH_W       )  // type: int, default: 2, description: input data width [bits]
) i2_gen_dec_top (
   // Input data //
   .dat_in  (int_clr_ch_num_next ), // i, DAT_IN_W X logic  , input encoded data
   .en      (1'b1                ), // i, [1]      X logic  , enable bit. output is 0's if this is asserted low
   // Output data // 
   .dat_out (int_clr_ch_oh_next  )  // o, DAT_OUT_W X logic  , decoded version of dat_in. one-hot vector
);
// FSM outputs //
assign arb_rd_rqsts_clr_mask = clr_sts_curr==CLR_IN_PROG ? int_clr_ch_oh_next : {CH_N{1'b1}} ; 
assign err_clr_rqst_ovfl = clr_rqst & clr_sts_curr!=CLR_IDLE ; 
assign func_ch_clrd = clr_sts_curr==CLR_DONE ; 
assign clr_ch_oh = int_clr_ch_oh_next & {CH_N{clr_sts_curr==CLR_DONE}} ; 
assign usr_in_vld_masked = usr_in_vld & (int_clr_ch_num_next!=usr_in_ch_num | clr_sts_curr==CLR_IDLE) ; 

endmodule


//|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|//
//|                                               |//
//| 1. Project  :  vlib                           |//
//| 2. Author   :  Etay Sela                      |//
//| 3. Date     :  2025-02-08                     |//
//| 4. Version  :  v0.10.0                        |//
//|                                               |//
//|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|//
