// MIT License
//
// Copyright (c) 2024 Mohannad Shehadeh
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
// synthesis VERILOG_INPUT_VERSION VERILOG_2001
`default_nettype none
/*
	m is randomly chosen from {1,2,...,M}
	according to one of k distinct
	non-uniform distributions chosen via
	sel. The k distributions are specified
	through the BINBOUNDs parameter.
	Uniform pseudo-randomness is needed
	and is obtained as part of the state
	of an LFSR.
*/
module multiDiscNonUnif(clk, reset, sel, m);
	`include "multiDiscNonUnif_paramfile.v"
	input clk;
	input reset;
	input [k_iWIDTH-1:0] sel;
	output reg [M_WIDTH-1:0] m;

	// Galois LFSR; top SKIM bits of state assigned to u
	reg [SIZE-1:0] q;
	wire [SKIM-1:0] u;
	assign u = q[SKIM-1:0];
	always @(posedge clk) begin
		if (reset) begin
			q <= SEED;
		end else begin
			q <= (q >> 1)^{SIZE{q[0]}}&FEEDBACK;
		end
	end
	/*
		bin uniform source u according to collection
		of bin boundaries chosen by sel
		can be reasonably realized from comparators,
		muxes, and priority encoders
	*/
	integer i;
	integer j;
	always @(*) begin
		m = M;
		for (i = 1; i <= M-1; i = i + 1) begin
			for (j = 0; j <= k-1; j = j + 1) begin
				if (u < BINBOUND[SKIM-1 + i*SKIM + (k-1-j)*M*SKIM -: SKIM]) begin
					if (sel == j) begin
						m = M-i;
					end
				end
			end
		end
	end
endmodule




