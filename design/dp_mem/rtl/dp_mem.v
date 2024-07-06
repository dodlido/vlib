//|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|//
//|                                                                                    |//
//| ~~ dp_mem ~~                                                                       |//
//|                                                                                    |//
//| Top-level description:                                                             |//
//|    1. Dual-port register based memory                                              |//
//|                                                                                    |//
//| Features:                                                                          |//
//|    1. Parameterized delays:                                                        |//
//|       a. DLY_USER2MEM - number of cycles delay from user controls to mem instance  |//
//|       b. DLY_USER2MEM - number of cycles delay from mem instance to user data out  |//
//|    2. Parameterized dimensions:                                                    |//
//|       a. DAT_W - number of bits per memory word                                    |//
//|       b. DEPTH - number of memory words                                            |//
//|       c. ADD_W - address width in bits, defaults to log2(DEPTH)                    |//
//|    3. Options:                                                                     |//
//|       a. LOW_PWR_OPT - low power option, if active data is valid-dependent.        |//
//|                        o.w, data is free-flowing                                   |//
//|       b. BIT_EN      - bit-enable option, if active memory write data is the result|//
//|                        of bit-wise and operation between dat_in and bit_sel        |//
//|                        o.w, bit-sel is ignored                                     |//
//|       c. WR2RD_OPT   - option to specify how to handle write-to-read events:       |//
//|                        i.  '0' - read data presents the previous cell state        |//
//|                        ii. '1' - write data is forwarded to read data              |//
//|                                                                                    |//
//|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|//

module sp_mem #(
    // Memory dimensions // 
    parameter int       DAT_W        =             8 , // data width in bits 
    parameter int       DEPTH        =            32 , // Memory depth (number of words)
    parameter int       ADD_W        = $clog2(DEPTH) , // Address width in bits
    // Delay parameters // 
    parameter int       DLY_USER2MEM = 0             , // User to memory delay in cycles
    parameter int       DLY_MEM2USER = 0             , // Memory to user delay in cycles
    // Option parameters // 
    parameter bit [0:0] LOW_PWR_OPT  = 1'b1          , // Low power mode option
    parameter bit [0:0] BIT_EN_OPT   = 1'b0          , // Bit-enable mechanism option
    parameter bit [0:0] WR2RD_OPT    = 1'b0            // Write-to-read option
)(
    // General // 
    input wire [      0:0] clk     , // clock signal
    input wire [      0:0] rst_n   , // Async reset, active low
    // Input control // 
    input wire [      0:0] cs      , // Chip-select 
    input wire [      0:0] wen     , // Write enable
    input wire [ADD_W-1:0] add_rd  , // Read Address  
    input wire [ADD_W-1:0] add_wr  , // Write Address  
    // Input data // 
    input wire [DAT_W-1:0] dat_in  , // Input data
    input wire [DAT_W-1:0] bit_sel , // bit-select
    // Output data // 
    output reg [DAT_W-1:0] dat_out   // Output data
);

// Internal wires declaration // 
wire            [DAT_W-1:0] mem_dat_in               ;
wire            [DAT_W-1:0] mem_dat_in_post_bit_sel  ;
wire            [ADD_W-1:0] mem_add_rd               ;
wire            [ADD_W-1:0] mem_add_wr               ;
wire            [      0:0] mem_wen                  ;
wire            [DAT_W-1:0] mem_dat_out              ;
wire [DEPTH-1:0][DAT_W-1:0] mem_array                ; 
reg  [DEPTH-1:0]            mem_wen_vec              ;

// Generate data input from user side // 
generate
   if (BIT_EN_OPT) begin: gen_bit_en_cond // BIT_EN_OPT is on, propagate bit_sel
      wire [DAT_W-1:0] mem_bit_sel ; 
      pipe #(.DEPTH(DLY_USER2MEM), .WID(2*DAT_W+ADD_W). LOW_PWR_OPT(LOW_PWR_OPT)) i0_wr_ctrl_pipe (
         .clk      (clk                                  ),
         .rst_n    (rst_n                                ),
         .data_in  ({bit_sel    , dat_in    , add_wr    }),
         .vld_in   (wen & cs                             ),
         .data_out ({mem_bit_sel, mem_dat_in, mem_add_wr}),
         .vld_out  (mem_wen                              )
      ); 
      pipe #(.DEPTH(DLY_USER2MEM), .WID(ADD_W). LOW_PWR_OPT(LOW_PWR_OPT)) i0_rd_ctrl_pipe (
         .clk      (clk       ),
         .rst_n    (rst_n     ),
         .data_in  (add_rd    ),
         .vld_in   (cs        ),
         .data_out (mem_add_rd),
         .vld_out  (          )  // NC
      ); 
   end
   else begin: gen_bit_dis_cond // BIT_EN_OPT is off, don't propagate bit_sel
      pipe #(.DEPTH(DLY_USER2MEM), .WID(DAT_W+ADD_W). LOW_PWR_OPT(LOW_PWR_OPT)) i1_wr_ctrl_pipe (
         .clk      (clk                     ),
         .rst_n    (rst_n                   ),
         .data_in  ({dat_in    , add_wr    }),
         .vld_in   (wen & cs                ),
         .data_out ({mem_dat_in, mem_add_wr}),
         .vld_out  (mem_wen                 )
      ); 
      pipe #(.DEPTH(DLY_USER2MEM), .WID(ADD_W). LOW_PWR_OPT(LOW_PWR_OPT)) i1_rd_ctrl_pipe (
         .clk      (clk       ),
         .rst_n    (rst_n     ),
         .data_in  (add_rd    ),
         .vld_in   (cs        ),
         .data_out (mem_add_rd),
         .vld_out  (          )  // NC
      ); 
   end
endgenerate

// Generate internal storage // 
genvar ADD_IDX, BIT_IDX ; 
generate
   for (ADD_IDX = 0; ADD_IDX<DEPTH; ADD_IDX++) begin : gen_mem_loop

      // Generate post-bit-select data // 
      if (BIT_EN_OPT) begin: gen_bit_sel_dat_en_cond
         for (BIT_IDX=0; BIT_IDX<DAT_W; BIT_IDX++) begin: gen_bit_sel_dat_en_loop
            assign mem_dat_in_post_bit_sel[BIT_IDX] = mem_bit_sel[BIT_IDX] ? mem_dat_in[BIT_IDX] : mem_array[ADD_IDX][BIT_IDX] ; 
         end
      end
      else begin: gen_bit_sel_dat_dis_cond
         assign mem_dat_in_post_bit_sel = mem_dat_in ; 
      end

      // Write enable for each individual memory cell // 
      mem_wen_vec[ADD_IDX] = (ADD_IDX[ADD_W-1:0]==mem_add_wr) & mem_wen ; 
 
      // Generate DAT_W FFs instance per cell //
      base_reg #(.DAT_W(DAT_W)) i_base_reg (
         .clk          (clk                    ),
         .rst_n        (rst_n                  ),
         .en           (mem_wen_vec[ADD_IDX]   ),
         .data_in      (mem_dat_in_post_bit_sel),
         .data_out     (mem_array[ADD_IDX]     )
      ); 

   end
endgenerate

// MUX output data from RAM 
generate
   if (WR2RD_OPT) begin: gen_wr2rd_cond
      wire fwd_dat_cond ; 
      assign fwd_dat_cond = mem_wen & (mem_add_wr==mem_add_rd) ; 
      assign mem_dat_out = fwd_dat_cond ? mem_dat_in : mem_array[mem_add_rd] ; 
   end
   else begin: gen_rdprev_cond
      assign mem_dat_out = mem_array[mem_add_rd] ;  
   end
endgenerate

// Generate output data-path pipe // 
pipe #(.DEPTH(DLY_MEM2USER), .WID(DAT_W), .LOW_PWR_OPT(LOW_PWR_OPT)) out_pipe (
    .clk      (clk        ),
    .rst_n    (rst_n      ),
    .data_in  (mem_dat_out),
    .vld_in   (mem_cs     ),
    .data_out (dat_out    ),
    .vld_out  (           )  // NC
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
