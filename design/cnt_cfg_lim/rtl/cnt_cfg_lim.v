//|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|//
//|                                                                                    |//
//| ~~ cnt_cfg_lim ~~                                                                  |//
//|                                                                                    |//
//| Top-level description:                                                             |//
//|    1. Count with a configurable limit                                              |//
//|                                                                                    |//
//| Features:                                                                          |//
//|    1. Configurable limit (lim)                                                     |//
//|    2. increment signal active high (inc)                                           |//
//|    3. soft reset, clear count value (clr)                                          |//
//|    4. Done pulse, active high (done)                                               |//
//|                                                                                    |//
//| Requirements:                                                                      |//
//|    1. CNT_W <= 32                                                                  |//
//|    1. lim width in bits = CNT_W                                                    |//
//|                                                                                    |//
//|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|//

module cnt_fix_lim #(
    parameter                  CNT_W =                          4 , // Counter width in bits
    localparam bit [CNT_W-1:0] ZERO  =              {CNT_W{1'b0}} , // Counter 0 val
    localparam bit [CNT_W-1:0] ONE   = {{(CNT_W-1){1'b0}},{1'b1}}   // Counter 1 val
) (
    // General // 
    input wire [      0:0] clk   , // Clock signal
    input wire [      0:0] rst_n , // Async reset, active low
    // input Control // 
    input wire [CNT_W-1:0] lim   , // Counter limit
    input wire [      0:0] inc   , // Increment counter
    input wire [      0:0] clr   , // Clear counter
    // Outputs // 
    output reg [CNT_W-1:0] count , // Counter value
    output reg [      0:0] done    // Counter reached LIM, pulse
);

// Internal wires & logic // 
// ---------------------- // 

// Wires // 
wire [      0:0] wrap_cond   ; // Count reached limit
wire [CNT_W-1:0] count_next  ; // Next value of count
wire [      0:0] done_next   ; // Next value of done 

// Logic // 
assign wrap_cond  = (count == (lim - ONE))                               ; // Count == lim-1
assign done_next  = inc & wrap_cond                                      ; // Next done value
assign count_next = (clr | done_next) ? ZERO : inc ? count + ONE : count ; // Next count value

// Output sampling // 
// --------------- // 

// count FFs // 
always_ff @( posedge clk, negedge rst_n ) begin 
    if (!rst_n) begin
        count <= ZERO ; // Reset count 
    end
    else begin
        count <= count_next ; // Sample next
    end
end

// done FF // 
always_ff @( posedge clk, negedge rst_n ) begin 
    if (!rst_n) begin
        done <= 1'b0 ; // Reset done
    end
    else begin
        done <= done_next ; // Sample next
    end
end

endmodule