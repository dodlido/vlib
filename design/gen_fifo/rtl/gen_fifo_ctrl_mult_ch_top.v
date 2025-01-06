//|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|//
//|                                                                                    |//
//| ~~ gen_fifo_ctrl_mult_ch_top.v ~~                                                  |//
//|                                                                                    |//
//| Top-level description:                                                             |//
//|    1. This provides a wrapper to a SP-SRAM that is managed as a multi-channel FIFO |//
//|                                                                                    |//
//| Interfaces and naming conventions:                                                 |//
//|    1. Writes are signaled to the module over the 'in_' interface                   |//
//|    2. Reads are signaled to the user over the 'out_' interface                     |//
//|    3. Read requests are signaled over the 'rd_' interface                          |//
//|    4. Clearing channels can be requested over the 'clr_' interface                 |//
//|    5. Configurations are signaled to this module over the 'cfg_' signals           |//
//|    6. The block signals a flow-control bit per channel to the user over 'fc_'      |//
//|    7. The block signals statuses, functional and error interrupts over the 'sts_', |//
//|       'func_' and 'err_' signals respectivly                                       |//
//|    8. The 'mem_' interface should be connected to a single port S-RAM              |// 
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
   parameter           CH_N        =    4 , // Number of channels  
   parameter           ADD_W       =    4 , // Pointers width [bits]
   parameter           DAT_W       =    4 , // Data width [bits] 
   parameter           RQST_CRDT_N =    4 , // Number of pending requests the block can hold per channel
   parameter bit [0:0] RR_ARB_OPT  = 1'b0 , // Set to 1'b1 to use round-robin arbitration of read requests, default is strict-prio

   // Inferred Parameter // 
   // ------------------ //
   localparam RQST_CRDT_W = $clog2(RQST_CRDT_N) , // Request credit counters width [bits]
   localparam CH_W        = $clog2(CH_N)        , // Channel index width [bits]
   localparam CNT_W       = ADD_W + 1             // Counter width [bits]
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
   input  logic [CH_N-1:0][ADD_W       -1:0] cfg_vec_dat_size  , // Per-Channel data size configuration 
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
   input  logic                              in_vld            , // Input IF, valid indicator
   input  logic           [CH_W        -1:0] in_ch_num         , // Input IF, channel number
   input  logic           [DAT_W       -1:0] in_dat            , // Input IF, data
   output logic                              out_vld           , // Input IF, valid indicator
   output logic           [CH_W        -1:0] out_ch_num        , // Input IF, channel number
   output logic           [DAT_W       -1:0] out_dat           , // Input IF, data

   // Flow Control // 
   // ------------ //
   output logic [CH_N-1:0]                   fc_vec_rqst_rdy_n , // Flow control vector - not ready for new requests, bit per channel

   // Output Statuses //
   // --------------- //
   output logic [CH_N-1:0][CNT_W       -1:0] sts_vec_dat_count , // Per-Channel Data FIFO count
   output logic [CH_N-1:0]                   sts_vec_dat_full  , // Per-Channel Data FIFO full
   output logic [CH_N-1:0]                   sts_vec_dat_af    , // Per-Channel Data FIFO almost-full
   output logic [CH_N-1:0]                   sts_vec_dat_ae    , // Per-Channel Data FIFO almost-empty
   output logic [CH_N-1:0]                   sts_vec_dat_empty , // Per-Channel Data FIFO empty
   output logic [CH_N-1:0][CNT_W       -1:0] sts_vec_crd_count , // Per-Channel Credits count
   output logic [CH_N-1:0]                   sts_vec_crd_full  , // Per-Channel Credits full
   output logic [CH_N-1:0]                   sts_vec_crd_af    , // Per-Channel Credits almost-full
   output logic [CH_N-1:0]                   sts_vec_crd_ae    , // Per-Channel Credits almost-empty
   output logic [CH_N-1:0]                   sts_vec_crd_empty , // Per-Channel Credits empty

   // Output Interrupts //
   // ----------------- //
   output logic [CH_N-1:0]                   func_vec_ch_clrd  , // Per-Channel functional interrupt - channel cleared done
   output logic [CH_N-1:0]                   err_vec_dat_ovfl  , // Per-Channel error - data overflow detected
   output logic [CH_N-1:0]                   err_vec_dat_udfl  , // Per-Channel error - data underflow detected
   output logic [CH_N-1:0]                   err_vec_rqst_ovfl , // Per-Channel error - request overflow detected
   output logic [CH_N-1:0]                   err_vec_rqst_udfl , // Per-Channel error - request underflow detected

   // ----------------------------------------------------------------- //
   // ------------------------ Memory Interface ----------------------- // 
   // ----------------------------------------------------------------- //
   // Input control // 
   // ------------- //
   input  logic                              mem_cs            , // Chip-select 
   input  logic                              mem_wen           , // Write enable
   input  logic           [ADD_W       -1:0] mem_add           , // Address  

   // Input data // 
   // ---------- //
   output logic           [DAT_W       -1:0] mem_dat_in        , // Input data (from memory POV)

   // Output data // 
   // ----------- //
   input  logic           [DAT_W       -1:0] mem_dat_out         // Output data (from memory POV)
);

//|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|//
//|                                               |//
//| 1. Project  :  vlib                           |//
//| 2. Author   :  Etay Sela                      |//
//| 3. Date     :  2025-01-07                     |//
//| 4. Version  :  v0.7.0                         |//
//|                                               |//
//|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|//
