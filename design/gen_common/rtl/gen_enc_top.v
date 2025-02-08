// 
// gen_enc_top.v
// 
// Description - encoder with parameteric width
// 

module gen_enc_top #(
   // parameters //
   // ---------- //
   parameter  DAT_IN_W  =               4 , // input data width [bits]
   localparam DAT_OUT_W = $clog2(DAT_IN_W)  // output data width [bits]
)(
   // Input data //
   input  logic [DAT_IN_W -1:0] dat_in , // one-hot decoded vector
   // Output data // 
   output logic [DAT_OUT_W-1:0] dat_out  // encoded version of the dat_in one-hot vector
);

// dat_out = i if dat_in[i]

always_comb begin
   dat_out = DAT_OUT_W'(0) ; 
   for (int i=0; i<DAT_IN_W; i++) begin
      dat_out = dat_in[i] ? DAT_OUT_W'(i) : dat_out ; 
   end
end

endmodule

//|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|//
//|                                               |//
//| 1. Project  :  vlib                           |//
//| 2. Author   :  Etay Sela                      |//
//| 3. Date     :  2025-02-08                     |//
//| 4. Version  :  v0.10.0                        |//
//|                                               |//
//|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|//
