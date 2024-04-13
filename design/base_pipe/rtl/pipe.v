//|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|//
//|                                                                                    |//
//| ~~ pipe ~~                                                                         |//
//|                                                                                    |//
//| Top-level description:                                                             |//
//|    1. Configurable delay                                                           |//
//|                                                                                    |//
//| Features:                                                                          |//
//|    1. Parameterized pipe depth (DEPTH)                                             |//
//|    2. Pipe advances every cycle                                                    |//
//|                                                                                    |//
//| Requirements:                                                                      |//
//|    1. DEPTH >= 1                                                                   |//
//|                                                                                    |//
//|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|//

module pipe #(
    parameter DEPTH = 4 , // Pipe depth
    parameter WID   = 8   // Data width
) (
    // General // 
    input wire [    0:0] clk     , // clock signal
    input wire [    0:0] rst_n   , // Async reset, active low
    // Input data // 
    input wire [WID-1:0] data_in , // Input data
    // Output data // 
    output reg [WID-1:0] data_out  // Output data
);

// Pipe interconnects declaration // 
wire [DEPTH-1:0][WID-1:0] pipe_cncts ; 

// Pipe first stage // 
base_reg #(.WID(WID)) i_base_reg (
    .clk          (clk             ),
    .rst_n        (rst_n           ),
    .en           (1'b1            ),
    .data_in      (data_in         ),
    .data_out     (pipe_cncts[0]   )
); 

// Pipe internal stages generation // 
genvar st ; 
generate
    for (st = 1; st<DEPTH; st=st+1) begin : gen_pipe_loop
        base_reg #(.WID(WID)) i_base_reg (
            .clk          (clk             ),
            .rst_n        (rst_n           ),
            .en           (1'b1            ),
            .data_in      (pipe_cncts[st-1]),
            .data_out     (pipe_cncts[st]  )
        ); 
    end
endgenerate

// Connect between pipe final stage and output
assign data_out = pipe_cncts[DEPTH-1] ; 

endmodule

//|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|//
//|                                               |//
//| 1. Project  :  vlib                           |//
//| 2. Author   :  Etay Sela                      |//
//| 3. Date     :  2024-04-14                     |//
//| 4. Version  :  v0.3.0                         |//
//|                                               |//
//|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|//
