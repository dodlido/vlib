//|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|//
//|                                                                                    |//
//| ~~ pipe ~~                                                                         |//
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
//| Requirements:                                                                      |//
//|    1. DEPTH >= 1                                                                   |//
//|                                                                                    |//
//|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|//

module pipe #(
   parameter           DEPTH       =    4 , // Pipe depth
   parameter           WID         =    8 , // Data width
   parameter bit [0:0] LOW_PWR_OPT = 1'b1   // Low power mode option 
) (
   // General // 
   input wire [    0:0] clk     , // clock signal
   input wire [    0:0] rst_n   , // Async reset, active low
   // Input data // 
   input wire [WID-1:0] dat_in  , // Input data
   input wire [    0:0] vld_in  , // Input valid indicator
   // Output data // 
   output reg [WID-1:0] dat_out , // Output data
	output reg [    0:0] vld_out   // Output valid indicator
);

// Pipe interconnects declaration // 
typedef struct packed {
   logic [WID-1:0] dat ; 
   logic [    0:0] vld ;
} pipe_cell_s ; 
pipe_cell_s [DEPTH:0] pipe_cncts ; 

// Connecting first stage to input // 
assign pipe_cncts[0].dat = dat_in ; 
assign pipe_cncts[0].vld = vld_in ; 

// Pipe internal stages generation // 
genvar ST ; 
generate
   for (ST = 0; ST<DEPTH; ST++) begin : gen_pipe_loop
      base_reg #(.WID(WID+1)) i_base_reg (
         .clk          ( clk                                        ),
         .rst_n        ( rst_n                                      ),
         .en           ( pipe_cncts[ST].vld |  LOW_PWR_OPT          ),
         .data_in      ({pipe_cncts[ST].dat  , pipe_cncts[ST].vld  }),
         .data_out     ({pipe_cncts[ST+1].dat, pipe_cncts[ST+1].vld})
      ); 
   end
endgenerate

// Connecting last stage to output // 
assign dat_out = pipe_cncts[DEPTH].dat ; 
assign vld_out = pipe_cncts[DEPTH].vld ; 

endmodule
