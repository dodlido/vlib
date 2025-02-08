//|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|//
//|                                                                                    |//
//| ~~ gen_pipe_top.v ~~                                                               |//
//|                                                                                    |//
//| Top-level description:                                                             |//
//|    1. Parameterizable delay                                                        |//
//|                                                                                    |//
//| Features:                                                                          |//
//|    1. Parameterized pipe depth (DEPTH)                                             |//
//|    2. Parameterized low power mode (LOW_PWR_OPT) - if active, FFs in pipe sample   |//
//|       only if previous stage valid indicator is active (high)                      |//
//|    3. Pipe advances every cycle                                                    |//
//|                                                                                    |//
//|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|//

module gen_pipe_top #(
   parameter           DEPTH       =    2 , // Pipe depth
   parameter           DAT_W       =    4 , // Data width
   parameter bit [0:0] LOW_PWR_OPT = 1'b1   // Low power mode option 
) (
   // General // 
   input  logic [      0:0] clk     , // clock signal
   input  logic [      0:0] rst_n   , // Async reset, active low
   // Input data // 
   input  logic [DAT_W-1:0] dat_in  , // Input data
   input  logic [      0:0] vld_in  , // Input valid indicator
   // Output data // 
   output logic [DAT_W-1:0] dat_out , // Output data
	output logic [      0:0] vld_out   // Output valid indicator
);

// Pipe interconnects declaration // 
logic [DEPTH:0][DAT_W-1:0] pipe_dat ; 
logic [DEPTH:0]            pipe_vld ; 

// Pipe internal stages generation // 
genvar ST ; 
generate
   for (ST = 0; ST<DEPTH; ST++) begin : gen_pipe_loop
      if (ST==0) begin : gen_1st_stage_cond 
         always_ff @(posedge clk) begin
            if (!rst_n) begin
               pipe_dat[1] <= DAT_W'(0) ; 
               pipe_vld[1] <= 1'b0      ;
            end
            else if (pipe_vld[ST] | ~LOW_PWR_OPT) begin
               pipe_dat[1] <= dat_in ; 
               pipe_vld[1] <= vld_in ;
            end
         end
      end
      else begin : gen_2nd_stage_cond
         always_ff @(posedge clk) begin
            if (!rst_n) begin
               pipe_dat[ST+1] <= DAT_W'(0) ; 
               pipe_vld[ST+1] <= 1'b0      ;
            end
            else if (pipe_vld[ST] | ~LOW_PWR_OPT) begin
               pipe_dat[ST+1] <= pipe_dat[ST] ; 
               pipe_vld[ST+1] <= pipe_vld[ST] ;
            end
         end
      end
   end
endgenerate

// Connecting last stage to output // 
assign dat_out = DEPTH==0 ? dat_in : pipe_dat[DEPTH] ; 
assign vld_out = DEPTH==0 ? vld_in : pipe_vld[DEPTH] ; 

endmodule

//|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|//
//|                                               |//
//| 1. Project  :  vlib                           |//
//| 2. Author   :  Etay Sela                      |//
//| 3. Date     :  2025-02-08                     |//
//| 4. Version  :  v0.10.0                        |//
//|                                               |//
//|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|//
