module base_reg #(
    parameter WID = 8 
) (
    // General // 
    input wire [    0:0] clk     , // clock signal
    input wire [    0:0] rst_n   , // Async reset, active low
    // Input control // 
    input wire [    0:0] en      , // Sample input enable
    // Input data // 
    input wire [WID-1:0] data_in , // Input data
    // Output data // 
    output reg [WID-1:0] data_out  // Output data
);

// Internal wires // 
wire [WID-1:0] data_out_next ;  // Next data out value

// data_out register //
assign data_out_next = (en) ? data_in : data_out ; // If enable, sample data in

always @( posedge clk, negedge rst_n ) begin 
    if (!rst_n) begin // Reset
        data_out <= {WID{1'b0}} ; 
    end
    else begin // Sample
        data_out <= data_out_next ; 
    end
end

endmodule

//|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|//
//|                                               |//
//| 1. Project  :  vlib                           |//
//| 2. Author   :  Etay Sela                      |//
//| 3. Date     :  2024-04-15                     |//
//| 4. Version  :  v0.4.0                         |//
//|                                               |//
//|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|//
