//input pad
module pc3d01(CIN, PAD);
input PAD;
output CIN;
wire  constant_one, constant_zero;
assign constant_one = 1'b1;
assign constant_zero = 1'b0;
PDDW0204CDG I1( .PAD(PAD), .DS(constant_zero), .OEN(constant_one), .PE(constant_one), .I(constant_zero), .IE(constant_one), .C(CIN) );
endmodule

//output pad 
module pt3o01(PAD, I);
output PAD;
input I;
wire  constant_one, constant_zero;
assign constant_one = 1'b1;
assign constant_zero = 1'b0;
PDDW0204CDG I1( .PAD(PAD), .DS(constant_zero), .OEN(constant_zero), .PE(constant_one), .I(I), .IE(constant_zero), .C() );
endmodule

module pvdc( VDD );
output VDD;
PVDD1CDG I1 ( .VDD(VDD) );
endmodule

module pv0c( VSS );
output VSS;
PVSS1CDG I1 ( .VSS(VSS) );
endmodule

module pvda( );
PVDD2CDG I1 ( );
endmodule

module pv0a( );
PVSS2CDG I1 ( );
endmodule

module ppoc;
PVDD2POC I1 ();
endmodule

module pfrelr;
PCORNER I1 ();
endmodule

