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
	through the BINBOUNDs parameter. ok
*/
// (* use_dsp = "yes" *) module multiDiscNonUnifHQ(clk, reset, sel, m, valid);
module multiDiscNonUnifHQ(clk, reset, sel, m, valid);
	`include "multiDiscNonUnifHQ_paramfile.v"

	parameter seedIndex = 0;

	parameter STAGES = 12;
	parameter STAGE_SIZE = (M-1+STAGES-1)/STAGES;

	input wire clk;
	input wire reset;
	input wire [$clog2(k)-1:0] sel;
	output reg [$clog2(M+1)-1:0] m;
	output wire valid;

	// SKIM number of Galois LFSRs
	reg [SKIM*SIZE-1:0] q;
	integer s;
	always @(posedge clk) begin
		if (reset) begin
			for (s = 0; s < SKIM; s = s + 1) begin
				q[s*SIZE + SIZE-1 -: SIZE] <= SEEDS[seedIndex*SKIM*SIZE + s*SIZE + SIZE-1 -: SIZE];
			end
		end else begin
			for (s = 0; s < SKIM; s = s + 1) begin
				q[s*SIZE + SIZE-1 -: SIZE] <= (q[s*SIZE + SIZE-1 -: SIZE] >> 1)^{SIZE{q[s*SIZE]}}&PRIMPOLYS[s*SIZE + SIZE-1 -: SIZE];
			end
		end
	end

	reg uValid;
	always @(posedge clk) begin
		if (reset) begin
			uValid <= 0;
		end else begin
			uValid <= 1;
		end
	end
	reg [SKIM-1:0] uIn;
	always @(*) begin
		for (s = 0; s < SKIM; s = s + 1) begin
			uIn[SKIM-1-s] = q[s*SIZE];
		end
	end
	reg [SKIM-1:0] u;
	always @(posedge clk) begin
		u <= uIn;
	end

	reg [STAGES-1:0] validPipe;
	reg [STAGES*k*$clog2(M+1)-1:0] mPipe;
	reg [STAGES*k*$clog2(M+1)-1:0] mPipeIns; // combinational
	reg [STAGES*k*SKIM-1:0] uPipe;
	integer i;
	integer j;
	integer a;
	always @(*) begin
		for (a = 0; a < STAGES; a = a + 1) begin
			if (a == STAGES-1) begin
				for (j = 0; j <= k-1; j = j + 1) begin
					mPipeIns[a*k*$clog2(M+1) + j*$clog2(M+1) + $clog2(M+1)-1 -: $clog2(M+1)] = M;
					for (i = 1 + (STAGES-1-a)*STAGE_SIZE; (i <= M-1) && (i <= 1 + ((STAGES-1-a)+1)*STAGE_SIZE - 1); i = i + 1) begin
						if (u < BINBOUND[SKIM-1 + i*SKIM + (k-1-j)*M*SKIM -: SKIM]) begin
							mPipeIns[a*k*$clog2(M+1) + j*$clog2(M+1) + $clog2(M+1)-1 -: $clog2(M+1)] = M-i;
						end
					end
				end
			end else begin
				for (j = 0; j <= k-1; j = j + 1) begin
					mPipeIns[a*k*$clog2(M+1) + j*$clog2(M+1) + $clog2(M+1)-1 -: $clog2(M+1)] =
								mPipe[(a+1)*k*$clog2(M+1) + j*$clog2(M+1) + $clog2(M+1)-1 -: $clog2(M+1)];
					for (i = 1 + (STAGES-1-a)*STAGE_SIZE; (i <= M-1) && (i <= 1 + ((STAGES-1-a)+1)*STAGE_SIZE - 1); i = i + 1) begin
						if (uPipe[(a+1)*k*SKIM + j*SKIM + SKIM-1 -: SKIM] < BINBOUND[SKIM-1 + i*SKIM + (k-1-j)*M*SKIM -: SKIM]) begin
							mPipeIns[a*k*$clog2(M+1) + j*$clog2(M+1) + $clog2(M+1)-1 -: $clog2(M+1)] = M-i;
						end
					end
				end
			end
		end
	end
	always @(posedge clk) begin
		mPipe <= mPipeIns;
	end
	always @(posedge clk) begin
		for (a = 0; a < STAGES; a = a + 1) begin
			if (a == STAGES-1) begin
				for (j = 0; j <= k-1; j = j + 1) begin
					uPipe[a*k*SKIM + j*SKIM + SKIM-1 -: SKIM] <= u;
				end
			end else begin
				for (j = 0; j <= k-1; j = j + 1) begin
					uPipe[a*k*SKIM + j*SKIM + SKIM-1 -: SKIM] <= uPipe[(a+1)*k*SKIM + j*SKIM + SKIM-1 -: SKIM];
				end
			end
		end
	end
	always @(posedge clk) begin
		if (reset) begin
			validPipe <= 0;
		end else begin
			for (a = 0; a < STAGES; a = a + 1) begin
				if (a == STAGES-1) begin
					validPipe[a] <= uValid;
				end else begin
					validPipe[a] <= validPipe[a+1];
				end
			end
		end
	end
	assign valid = validPipe[0];
	always @(*) begin
		m = 0;
		for (j = 0; j <= k-1; j = j + 1) begin
			if (sel == j) begin
				m = mPipe[j*$clog2(M+1) + $clog2(M+1)-1 -: $clog2(M+1)];
			end
		end
	end
endmodule
