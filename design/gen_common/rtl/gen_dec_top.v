// 
// gen_dec_top.v
// 
// Description - decoder with parameteric width and an enable bit
// 

module gen_dec_top #(
   // parameters //
   // ---------- //
   parameter  DAT_IN_W  =             2 , // input data width [bits]
   localparam DAT_OUT_W = 2 ** DAT_IN_W   // output data width [bits]
)(
   // Input data //
   input  logic [DAT_IN_W -1:0] dat_in , // input encoded data
   input  logic                 en     , // enable bit, output is 0's if this is asserted low
   // Output data // 
   output logic [DAT_OUT_W-1:0] dat_out  // decoded version of dat_in, one-hot vector
);

// dat_out[i] = dat_in==i
genvar BIT ; 
generate
   for (BIT=0; BIT<DAT_OUT_W; BIT++) begin: gen_dec_loop
      assign dat_out[BIT] = (dat_in==DAT_IN_W'(BIT)) & en ; 
   end
endgenerate

endmodule

//|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|//
//|                                               |//
//| 1. Project  :  vlib                           |//
//| 2. Author   :  Etay Sela                      |//
//| 3. Date     :  2025-01-09                     |//
//| 4. Version  :  v0.8.0                         |//
//|                                               |//
//|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|//
