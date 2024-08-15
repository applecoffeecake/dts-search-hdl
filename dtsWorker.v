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
module dtsWorker(clk, reset, natRuler, done);
	parameter n = 3; // num blocks
	parameter k = 3; // num marks (excluding zero mark)
	parameter M = 19; // max mark to consider
	parameter n_iWIDTH = 2; // num bits to represent n indices
	parameter k_iWIDTH = 2; // num bits to represent k indices
	parameter M_WIDTH = 5; // num bits to represent the value M

	parameter BLOCKGEN_THRESH = 100;
	parameter BLOCKGEN_CTRWIDTH = 7;
	parameter DTSGEN_THRESH = 100*1000;
	parameter DTSGEN_CTRWIDTH = 17;

	input clk;
	input reset;
	output done;

	// registers representing dts state (6)
	output reg [n*(M+1) - 1 : 0] natRuler;
	reg [n*(M+1) - 1 : 0] revRuler;
	reg [n*(M+1) - 1 : 0] spectrum;
	reg [M:0] cumSpectrum;
	reg [M_WIDTH-1:0] largestMark; // of block i, not of the dts
	reg [n_iWIDTH-1:0] t; // index of next deletion candidate
	// next dts state signals
	reg [n*(M+1) - 1 : 0] next_natRuler;
	reg [n*(M+1) - 1 : 0] next_revRuler;
	reg [n*(M+1) - 1 : 0] next_spectrum;
	reg [M:0] next_cumSpectrum;
	reg [M_WIDTH-1:0] next_largestMark;
	reg [n_iWIDTH-1:0] next_t;

	// registers representing counters (4)
	reg [DTSGEN_CTRWIDTH-1:0] dtsGenIters;
	reg [BLOCKGEN_CTRWIDTH-1:0] blockGenIters;
	reg [k_iWIDTH-1:0] j; // marks populated (excluding zero mark)
	reg [n_iWIDTH-1:0] i; // blocks populated
	// next counter state signals
	reg [DTSGEN_CTRWIDTH-1:0] next_dtsGenIters;
	reg [BLOCKGEN_CTRWIDTH-1:0] next_blockGenIters;
	reg [k_iWIDTH-1:0] next_j;
	reg [n_iWIDTH-1:0] next_i;

	// registers for control FSM state (1)
	reg [1:0] ctrlState;
	// next control state signal
	reg [1:0] next_ctrlState;
	parameter ctrlA = 0, ctrlB = 1, ctrlC = 2;
	/*
		control FSM states:
		ctrlA : populating block i:
					if blockGenIters is maxed out, remove block t from the
					cumulative spectrum and go to ctrlB
		ctrlB : block t-1 is being held out of the cumulative spectrum:

		ctrlC : done
	*/
	assign done = ctrlState == ctrlC;

	// register update and reset
	parameter [M:0] ZERO = 0;
	parameter [M:0] ONE = 1;
//	integer q;
	always @(posedge clk) begin
		if (reset) begin
			// dts state registers
//			for (q = 0; q <= n-1; q = q + 1) begin
//				natRuler[M + q*(M+1) -: M+1] <= ONE;
//				revRuler[M + q*(M+1) -: M+1] <= ONE;
//				spectrum[M + q*(M+1) -: M+1] <= ZERO;
//			end
			natRuler <= {n{ONE}};
			revRuler <= {n{ONE}};
			spectrum <= {n{ZERO}};
			cumSpectrum <= ZERO;
			largestMark <= 0;
			t <= 0;
			// counter registers
			dtsGenIters <= 0;
			blockGenIters <= 0;
			j <= 0;
			i <= 0;
			// control registers
			ctrlState <= ctrlA;
		end else begin
			// dts state registers
			natRuler <= next_natRuler;
			revRuler <= next_revRuler;
			spectrum <= next_spectrum;
			cumSpectrum <= next_cumSpectrum;
			largestMark <= next_largestMark;
			t <= next_t;
			// counter registers
			dtsGenIters <= next_dtsGenIters;
			blockGenIters <= next_blockGenIters;
			j <= next_j;
			i <= next_i;
			// control registers
			ctrlState <= next_ctrlState;
		end
	end

	// mark and markIsValid are determined by current state
	reg [M_WIDTH-1:0] mark;
	
	// optional pipelining of markGen output:
	wire [M_WIDTH-1:0] markRegIn;
	always @(posedge clk) begin
		if (reset) begin
			mark <= M;
		end else begin
			mark <= markRegIn;
		end
	end

	multiDiscNonUnif markGen(clk, reset, j, markRegIn);
	
	
	
	reg [M:0] leftDistances, rightDistances;
	wire [M:0] distances, bisection, intersection;
	assign distances = leftDistances | rightDistances;
	assign bisection = leftDistances & rightDistances;
	assign intersection = cumSpectrum & distances;
	always @(*) begin
		if (mark > largestMark) begin
			leftDistances = revRuler[M + i*(M+1) -: M+1] << (mark - largestMark);
			rightDistances = ZERO;
		end else begin
			leftDistances = revRuler[M + i*(M+1) -: M+1] >> (largestMark - mark);
			rightDistances = natRuler[M + i*(M+1) -: M+1] >> mark;
		end
	end
	wire markIsValid;
	assign markIsValid = !(bisection || intersection);
	
//	integer qq;
	// state transition logic
	always @(*) begin
//		qq=0;
		// defaults:
		// dts state
		next_natRuler = natRuler;
		next_revRuler = revRuler;
		next_spectrum = spectrum;
		next_cumSpectrum = cumSpectrum;
		next_largestMark = largestMark;
		next_t = t;
		// counters state
		next_dtsGenIters = dtsGenIters;
		next_blockGenIters = blockGenIters;
		next_j = j;
		next_i = i;
		// control state
		next_ctrlState = ctrlState;
		case (ctrlState)
			ctrlA : begin
				if (markIsValid) begin
					next_natRuler[M + i*(M+1) -: M+1] = natRuler[M + i*(M+1) -: M+1] | (ONE << mark);
					if (mark > largestMark) begin
						next_revRuler[M + i*(M+1) -: M+1] = leftDistances | ONE;
						next_largestMark = mark;
					end else begin
						next_revRuler[M + i*(M+1) -: M+1] = revRuler[M + i*(M+1) -: M+1] | (ONE << (largestMark - mark));
					end
					next_spectrum[M + i*(M+1) -: M+1] = spectrum[M + i*(M+1) -: M+1] | distances;
					next_cumSpectrum = cumSpectrum | distances;
					if (j == k-1) begin // finished block i
						if (i == n-1) begin // done
							next_ctrlState = ctrlC; // don't care about other updates
						end else if (dtsGenIters == DTSGEN_THRESH) begin
							// reset all 11 registers
//							for (qq = 0; qq <= n-1; qq = qq + 1) begin
//								next_natRuler[M + qq*(M+1) -: M+1] = ONE;
//								next_revRuler[M + qq*(M+1) -: M+1] = ONE;
//								next_spectrum[M + qq*(M+1) -: M+1] = ZERO;
//							end
							next_natRuler = {n{ONE}};
							next_revRuler = {n{ONE}};
							next_spectrum = {n{ZERO}};
							next_cumSpectrum = ZERO;
							next_largestMark = 0;
							next_t = 0;
							next_dtsGenIters = 0;
							next_blockGenIters = 0;
							next_j = 0;
							next_i = 0;
							next_ctrlState = ctrlA;
						end else begin // block i completed, not last block, not out of iters
							next_largestMark = 0;
							next_dtsGenIters = dtsGenIters + 1;
							next_blockGenIters = 0;
							next_j = 0;
							next_i = i + 1;
						end
					end else begin // mark inserted but block not completed
						if (blockGenIters == BLOCKGEN_THRESH) begin // transition to ctrlB
							// Entry of ctrlB:
							// dts state
							next_natRuler[M + i*(M+1) -: M+1] = ONE;
							next_revRuler[M + i*(M+1) -: M+1] = ONE;
							next_spectrum[M + i*(M+1) -: M+1] = ZERO;
							next_cumSpectrum = cumSpectrum ^ spectrum[M + i*(M+1) -: M+1] ^ spectrum[M + t*(M+1) -: M+1];
							next_largestMark = 0;
							next_t = t + 1;
							// counters state
							next_blockGenIters = 0;
							next_j = 0;
							// control state
							next_ctrlState = ctrlB;
						end else begin // mark inserted, block not completed, not out of iters
							next_blockGenIters = blockGenIters + 1;
							next_j = j + 1;
						end
					end
				end else begin // invalid mark
					if (blockGenIters == BLOCKGEN_THRESH) begin // invalid mark and out of iters
							// Entry of ctrlB:
							// dts state
							next_natRuler[M + i*(M+1) -: M+1] = ONE;
							next_revRuler[M + i*(M+1) -: M+1] = ONE;
							next_spectrum[M + i*(M+1) -: M+1] = ZERO;
							next_cumSpectrum = cumSpectrum ^ spectrum[M + i*(M+1) -: M+1] ^ spectrum[M + t*(M+1) -: M+1];
							next_largestMark = 0;
							next_t = t + 1;
							// counters state
							next_blockGenIters = 0;
							next_j = 0;
							// control state
							next_ctrlState = ctrlB;
					end else begin // invalid mark and not out of iters
						next_blockGenIters = blockGenIters + 1;
					end
				end
			end // case ctrlA
			ctrlB : begin
				if (markIsValid) begin
					next_natRuler[M + i*(M+1) -: M+1] = natRuler[M + i*(M+1) -: M+1] | (ONE << mark);
					if (mark > largestMark) begin
						next_revRuler[M + i*(M+1) -: M+1] = leftDistances | ONE;
						next_largestMark = mark;
					end else begin
						next_revRuler[M + i*(M+1) -: M+1] = revRuler[M + i*(M+1) -: M+1] | (ONE << (largestMark - mark));
					end
					next_spectrum[M + i*(M+1) -: M+1] = spectrum[M + i*(M+1) -: M+1] | distances;
					next_cumSpectrum = cumSpectrum | distances;
					if (j == k-1) begin // finished block i with block t held out
						// go back to ctrlA
						if (dtsGenIters == DTSGEN_THRESH) begin // out of iters
							// reset all 11 registers
//							for (qq = 0; qq <= n-1; qq = qq + 1) begin
//								next_natRuler[M + qq*(M+1) -: M+1] = ONE;
//								next_revRuler[M + qq*(M+1) -: M+1] = ONE;
//								next_spectrum[M + qq*(M+1) -: M+1] = ZERO;
//							end
							next_natRuler = {n{ONE}};
							next_revRuler = {n{ONE}};
							next_spectrum = {n{ZERO}};
							next_cumSpectrum = ZERO;
							next_largestMark = 0;
							next_t = 0;
							next_dtsGenIters = 0;
							next_blockGenIters = 0;
							next_j = 0;
							next_i = 0;
							next_ctrlState = ctrlA;
						end else begin // block i completed with block t-1 held out, not out of iters
							// dts state
							next_natRuler[M + (t-1)*(M+1) -: M+1] = next_natRuler[M + i*(M+1) -: M+1];
							next_revRuler[M + (t-1)*(M+1) -: M+1]  = next_revRuler[M + i*(M+1) -: M+1];
							next_spectrum[M + (t-1)*(M+1) -: M+1]  = next_spectrum[M + i*(M+1) -: M+1];
							next_natRuler[M + i*(M+1) -: M+1] = ONE;
							next_revRuler[M + i*(M+1) -: M+1]  = ONE;
							next_spectrum[M + i*(M+1) -: M+1]  = ZERO;
							next_largestMark = 0;
							next_t = 0;
							// counters state
							next_dtsGenIters = dtsGenIters + 1;
							next_blockGenIters = 0;
							next_j = 0;
							next_i = i;
							// control state
							next_ctrlState = ctrlA;
						end
					end else begin // mark inserted but block not completed
						if (blockGenIters == BLOCKGEN_THRESH) begin // out of iters
							if (t == i) begin // out of deletion candidates and out of iters, return to ctrlA
								// dts state
								next_natRuler[M + i*(M+1) -: M+1] = ONE;
								next_revRuler[M + i*(M+1) -: M+1] = ONE;
								next_spectrum[M + i*(M+1) -: M+1] = ZERO;
								next_cumSpectrum = cumSpectrum ^ spectrum[M + i*(M+1) -: M+1] ^ spectrum[M + (t-1)*(M+1) -: M+1];
								next_largestMark = 0;
								next_t = 0;
								// counters state
								next_dtsGenIters = dtsGenIters + 1;
								next_blockGenIters = 0;
								next_j = 0;
								next_i = i;
								// control state
								next_ctrlState = ctrlA;
							end else begin // out of iters but not out of deletion candidates, go to next deletion candidate
								// Re-entry of ctrlB:
								// dts state
								next_natRuler[M + i*(M+1) -: M+1] = ONE;
								next_revRuler[M + i*(M+1) -: M+1] = ONE;
								next_spectrum[M + i*(M+1) -: M+1] = ZERO;
								next_cumSpectrum = cumSpectrum ^ spectrum[M + i*(M+1) -: M+1] ^
													spectrum[M + t*(M+1) -: M+1] ^ spectrum[M + (t-1)*(M+1) -: M+1];
								next_largestMark = 0;
								next_t = t + 1;
								// counters state
								next_blockGenIters = 0;
								next_j = 0;
								// control state
								next_ctrlState = ctrlB;
							end
						end else begin // mark inserted, block not completed, not out of iters
							next_blockGenIters = blockGenIters + 1;
							next_j = j + 1;
						end
					end
				end else begin // invalid mark
					if (blockGenIters == BLOCKGEN_THRESH) begin // out of iters
						if (t == i) begin // out of deletion candidates and out of iters, return to ctrlA
							// dts state
							next_natRuler[M + i*(M+1) -: M+1] = ONE;
							next_revRuler[M + i*(M+1) -: M+1] = ONE;
							next_spectrum[M + i*(M+1) -: M+1] = ZERO;
							next_cumSpectrum = cumSpectrum ^ spectrum[M + i*(M+1) -: M+1] ^ spectrum[M + (t-1)*(M+1) -: M+1];
							next_largestMark = 0;
							next_t = 0;
							// counters state
							next_dtsGenIters = dtsGenIters + 1;
							next_blockGenIters = 0;
							next_j = 0;
							next_i = i;
							// control state
							next_ctrlState = ctrlA;
						end else begin // out of iters but not out of deletion candidates, go to next deletion candidate
							// Re-entry of ctrlB:
							// dts state
							next_natRuler[M + i*(M+1) -: M+1] = ONE;
							next_revRuler[M + i*(M+1) -: M+1] = ONE;
							next_spectrum[M + i*(M+1) -: M+1] = ZERO;
							next_cumSpectrum = cumSpectrum ^ spectrum[M + i*(M+1) -: M+1] ^
												spectrum[M + t*(M+1) -: M+1] ^ spectrum[M + (t-1)*(M+1) -: M+1];
							next_largestMark = 0;
							next_t = t + 1;
							// counters state
							next_blockGenIters = 0;
							next_j = 0;
							// control state
							next_ctrlState = ctrlB;
						end
					end else begin // mark invalid, block not completed, not out of iters
						next_blockGenIters = blockGenIters + 1;
					end
				end
			end //case ctrl B
			ctrlC : ;// stay;
		endcase
	end
endmodule
