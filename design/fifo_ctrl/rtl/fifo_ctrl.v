//|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|//
//|                                                                                    |//
//| ~~ fifo_ctrl ~~                                                                    |//
//|                                                                                    |//
//| Top-level description:                                                             |//
//|    1. Basic FIFO control                                                           |//
//|                                                                                    |//
//| Features:                                                                          |//
//|    1. Parameterized fifo depth (DEPTH)                                             |//
//|    2. Read and write pointers as address management                                |//
//|    3. full, empty and count as status output                                       |//
//|                                                                                    |//
//| Requirements:                                                                      |//
//|    1. DEPTH <= 2^32 - 1                                                            |//
//|                                                                                    |//
//|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|//

module fifo_ctrl #(
    parameter                    DEPTH   = 16                         , // FIFO depth 
    localparam                   PTR_WID = $clog2(DEPTH)              , // Pointers width
    localparam bit [PTR_WID-1:0] PTR_ZER = {(PTR_WID){1'b0}}          , // Pointer-wid 1 value
    localparam bit [PTR_WID-1:0] PTR_ONE = {{(PTR_WID-1){1'b0}},1'b1} , // Pointer-wid 0 value
    localparam                   CNT_WID = PTR_WID + 1                , // Counter width
    localparam bit [CNT_WID-1:0] CNT_ZER = {(CNT_WID){1'b0}}          , // Pointer-wid 0 value
    localparam bit [CNT_WID-1:0] CNT_ONE = {{(CNT_WID-1){1'b0}},1'b1}   // Pointer-wid 1 value
) (
    // General // 
    input wire [        0:0] clk    , // Clock signal 
    input wire [        0:0] rst_n  , // Async reset, active low
    // Inputs // 
    input wire [        0:0] wen    , // Write enable active high
    input wire [        0:0] oen    , // Output enable active high
    // Outputs // 
    output reg [PTR_WID-1:0] rd_ptr , // Read pointer
    output reg [PTR_WID-1:0] wr_ptr , // Write pointer
    output reg [CNT_WID-1:0] count  , // FIFO count
    output reg [        0:0] full   , // FIFO full
    output reg [        0:0] empty    // FIFO empty
);

// Internal wires declaration // 
// -------------------------- // 

// Internal count wires // 
wire               inc_count_cond ; // Increase count value condition
wire               dec_count_cond ; // Decrease count value condition
wire [CNT_WID-1:0] count_next     ; // Next count value
// Internal read wires // 
wire               inc_rd_cond    ; // Increase read pointer condition
wire               rd_wrap_cond   ; // Read wrap around condition
wire [PTR_WID-1:0] rd_ptr_next    ; // Next read pointer value
// Internal write wires // 
wire               inc_wr_cond    ; // Increase write pointer condition
wire               wr_wrap_cond   ; // Write wrap around conidtion
wire [PTR_WID-1:0] wr_ptr_next    ; // Next write pointer value

// Assignaments // 
// ------------ // 

// Empty and Full // 
assign empty          = (count == CNT_ZER)                                         ; // Empty logic
assign full           = ({{(32-CNT_WID){1'b0}} , count} == DEPTH)                  ; // Full logic, count padded to integer width (32 bit fixed) and compared to DEPTH
// Count // 
assign inc_count_cond = ((wen) & (~(oen)) & (~(full)))                             ; // Increase count logic, write and not read and space available
assign dec_count_cond = ((~wen) & ((oen)) & (~(empty)))                            ; // Decrese count logic, read and not write and not completely empty
assign count_next     = inc_count_cond ? (count + CNT_ONE)                         : 
                        dec_count_cond ? (count - CNT_ONE)                         : 
                                         (count          )                         ; // Next count value logic
// Read pointer // 
assign inc_rd_cond    = (oen) & (~(empty))                                         ; // Increase read pointer if readout valid data
assign rd_wrap_cond   = ({{(32-PTR_WID){1'b0}},rd_ptr}==(DEPTH-1)) & (inc_rd_cond) ; // Condition to wrap around rd pointer to base
assign rd_ptr_next    = rd_wrap_cond ? PTR_ZER                                     : 
                        inc_rd_cond  ? (rd_ptr + PTR_ONE)                          : 
                                        rd_ptr                                     ; // Next read pointer value logic
// Write pointer // 
assign inc_wr_cond    = (wen) & (~(full))                                          ; // Increase write pointer if there is place available
assign wr_wrap_cond   = ({{(32-PTR_WID){1'b0}},wr_ptr}==(DEPTH-1)) & (inc_wr_cond) ; // Condition to wrap around wr pointer to base
assign wr_ptr_next    = wr_wrap_cond ? PTR_ZER                                     : 
                        inc_wr_cond  ? (wr_ptr + PTR_ONE)                          : 
                                        wr_ptr                                     ; // Next read pointer value logic

// Registers // 
// --------- // 

// Count register // 
always_ff @( posedge clk, negedge rst_n ) begin : count_reg
    if (!rst_n) begin // reset
        count <= CNT_ZER ; 
    end
    else begin // sample next
        count <= count_next ; 
    end
end

// Read pointer register // 
always_ff @( posedge clk, negedge rst_n ) begin : rd_ptr_reg
    if (!rst_n) begin // reset 
        rd_ptr <= PTR_ZER ; 
    end
    else begin // sample next
        rd_ptr <= rd_ptr_next ; 
    end
end

// Write pointer register // 
always_ff @( posedge clk, negedge rst_n ) begin : wr_ptr_reg
    if (!rst_n) begin // reset 
        wr_ptr <= PTR_ZER ; 
    end
    else begin // sample next
        wr_ptr <= wr_ptr_next ; 
    end
end

endmodule