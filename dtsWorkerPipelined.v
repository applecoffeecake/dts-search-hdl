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
module dtsWorkerPipelined(clk, reset, natRuler, done);
	parameter SEEDCLASS = 123; // choose 1 <= SEEDCLASS <= SEEDCOEFF
	parameter SEEDCOEFF = 123456;

	parameter n = 3; // num blocks
	parameter k = 3; // num marks (excluding zero mark)
	parameter M = 19; // max mark to consider

	/*
		Note that we need BLOCKGEN_THRESH >= k-1.
		Note further that it is NOT beneficial to have PARMARKS
		or PARMARKS*BLOCKGEN_THRESH be too large!
		It is better to backtrack if marks sampled from the specified
		distributions don't fit than it is to force any mark to fit.
		Marks sampled from the specified distributions are more likely
		to allow eventual completion of the entire DTS.
	*/
	// parameter BLOCKGEN_THRESH = 10;
	parameter BLOCKGEN_THRESH = 100;
	parameter PARMARKS = 10;
	parameter STAGES = 5; // need STAGES * 2^STAGE_POW >= M
	parameter STAGE_POW = 2; // each stage shifts by up to 2^STAGE_POW

	parameter LATENCY = STAGES + 1;

	parameter DTSGEN_THRESH = 100*1000;

	input wire clk;
	input wire reset;
	output wire done;

	// registers representing dts state (6)
	output reg [n*(M+1) - 1 : 0] natRuler;
	reg [n*(M+1) - 1 : 0] revRuler;
	reg [n*(M+1) - 1 : 0] spectrum;
	reg [M:0] cumSpectrum;
	reg [$clog2(M+1)-1:0] largestMark; // of block i, not of the dts
	reg [$clog2(n)-1:0] t; // index of next deletion candidate
	// next dts state signals
	reg [n*(M+1) - 1 : 0] next_natRuler;
	reg [n*(M+1) - 1 : 0] next_revRuler;
	reg [n*(M+1) - 1 : 0] next_spectrum;
	reg [M:0] next_cumSpectrum;
	reg [$clog2(M+1)-1:0] next_largestMark;
	reg [$clog2(n)-1:0] next_t;

	// registers representing counters (4)
	reg [$clog2(DTSGEN_THRESH+1)-1:0] dtsGenIters;
	reg [$clog2(BLOCKGEN_THRESH+1)-1:0] blockGenIters;
	reg [$clog2(k)-1:0] j; // marks populated (excluding zero mark)
	reg [$clog2(n)-1:0] i; // blocks populated
	// next counter state signals
	reg [$clog2(DTSGEN_THRESH+1)-1:0] next_dtsGenIters;
	reg [$clog2(BLOCKGEN_THRESH+1)-1:0] next_blockGenIters;
	reg [$clog2(k)-1:0] next_j;
	reg [$clog2(n)-1:0] next_i;

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
	always @(posedge clk) begin
		if (reset) begin
			// dts state registers
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

	reg [PARMARKS*$clog2(M+1)-1:0] mark_options;
	wire [PARMARKS*$clog2(M+1)-1:0] mark_optionsIn;
	integer q;
	always @(posedge clk) begin
		if (reset) begin
			for (q = 0; q < PARMARKS; q = q + 1) begin
				mark_options[$clog2(M+1)-1 + q*$clog2(M+1) -: $clog2(M+1)] <= 0;
			end
		end else begin
			mark_options <= mark_optionsIn;
		end
	end

	genvar u;
	generate
		for (u = 0; u < PARMARKS; u = u + 1) begin:unit
			multiDiscNonUnif #( .SEED( SEEDCOEFF*u + SEEDCLASS ) ) markGen(clk, reset, j, mark_optionsIn[$clog2(M+1)-1 + u*$clog2(M+1) -: $clog2(M+1)]);
		end
	endgenerate


	reg clearPipeline;
	reg [$clog2(LATENCY+1)-1:0] latencyCtr;
	always @(posedge clk) begin
		if (reset | clearPipeline) begin
			latencyCtr <= 0;
		end else if (latencyCtr == LATENCY) begin
			latencyCtr <= latencyCtr;
		end else begin
			latencyCtr <= latencyCtr + 1;
		end
	end


	reg [PARMARKS*$clog2(M+1)-1:0] mark_minus_largestMark_options;
	reg [PARMARKS*$clog2(M+1)-1:0] largestMark_minus_mark_options;
	reg [PARMARKS*$clog2(M+1)-1:0] mark_options_oneDelay;
	integer b;
	always @(posedge clk) begin
		if (reset | clearPipeline) begin
			mark_minus_largestMark_options <= 0;
			largestMark_minus_mark_options <= 0;
			mark_options_oneDelay <= 0;
		end else begin
			mark_options_oneDelay <= mark_options;
			for (b = 0; b < PARMARKS; b = b + 1) begin
				mark_minus_largestMark_options[$clog2(M+1)-1 + b*$clog2(M+1) -: $clog2(M+1)] <=
					mark_options[$clog2(M+1)-1 + b*$clog2(M+1) -: $clog2(M+1)] - largestMark;
				largestMark_minus_mark_options[$clog2(M+1)-1 + b*$clog2(M+1) -: $clog2(M+1)] <=
					largestMark - mark_options[$clog2(M+1)-1 + b*$clog2(M+1) -: $clog2(M+1)];
			end
		end
	end

	wire [PARMARKS*(M+1)-1:0] leftDistances_branch1_ins;
	wire [PARMARKS*(M+1)-1:0] leftDistances_branch2_ins;
	wire [PARMARKS*(M+1)-1:0] rightDistances_branch2_ins;
	genvar z;
	generate
		for (z = 0; z < PARMARKS; z = z + 1) begin:pipeline
			leftShiftPipelined #(.WIDTH(M+1), .STAGES(STAGES), .STAGE_POW(STAGE_POW)) leftShifter (
									.clk(clk),
									.reset(reset|clearPipeline),
									.out(leftDistances_branch1_ins[M + z*(M+1) -: M+1]),
									.in(revRuler[M + i*(M+1) -: M+1]),
									.shift(mark_minus_largestMark_options[$clog2(M+1)-1 + z*$clog2(M+1) -: $clog2(M+1)])
									);
			rightShiftPipelined #(.WIDTH(M+1), .STAGES(STAGES), .STAGE_POW(STAGE_POW)) rightShifter1 (
									.clk(clk),
									.reset(reset|clearPipeline),
									.out(leftDistances_branch2_ins[M + z*(M+1) -: M+1]),
									.in(revRuler[M + i*(M+1) -: M+1]),
									.shift(largestMark_minus_mark_options[$clog2(M+1)-1 + z*$clog2(M+1) -: $clog2(M+1)])
									);
			rightShiftPipelined #(.WIDTH(M+1), .STAGES(STAGES), .STAGE_POW(STAGE_POW)) rightShifter2 (
									.clk(clk),
									.reset(reset|clearPipeline),
									.out(rightDistances_branch2_ins[M + z*(M+1) -: M+1]),
									.in(natRuler[M + i*(M+1) -: M+1]),
									.shift(mark_options_oneDelay[$clog2(M+1)-1 + z*$clog2(M+1) -: $clog2(M+1)])
									);
		end
	endgenerate

	// add STAGES cycles of latency
	wire [PARMARKS*$clog2(M+1)-1:0] mark_options_delayed;
	reg [STAGES*PARMARKS*$clog2(M+1)-1:0] mark_options_ShiftReg;
	integer f;
	always @(posedge clk) begin
		if (reset | clearPipeline) begin
			mark_options_ShiftReg <= 0;
		end else begin
			mark_options_ShiftReg[(STAGES-1)*PARMARKS*$clog2(M+1) + PARMARKS*$clog2(M+1)-1 -: PARMARKS*$clog2(M+1)] <= mark_options;
			for (f = STAGES-1; f >= 1; f = f - 1) begin
				mark_options_ShiftReg[(f-1)*PARMARKS*$clog2(M+1) + PARMARKS*$clog2(M+1)-1 -: PARMARKS*$clog2(M+1)] <= mark_options_ShiftReg[f*PARMARKS*$clog2(M+1) + PARMARKS*$clog2(M+1)-1 -: PARMARKS*$clog2(M+1)];
			end
		end
	end
	assign mark_options_delayed = mark_options_ShiftReg[0*PARMARKS*$clog2(M+1) + PARMARKS*$clog2(M+1)-1 -: PARMARKS*$clog2(M+1)];

	// add one more cycle of latency to account for delayed subtractions before shifters
	reg [PARMARKS*$clog2(M+1)-1:0] mark_options_delayed_oneDelay;
	reg [PARMARKS-1:0] mark_options_delayed_gt_largestMark_oneDelay;
	reg [PARMARKS*$clog2(M+1)-1:0] largestMark_minus_mark_options_delayed_oneDelay;
	integer a;
	always @(posedge clk) begin
		if (reset | clearPipeline) begin
			mark_options_delayed_oneDelay <= 0;
			mark_options_delayed_gt_largestMark_oneDelay <= 0;
			largestMark_minus_mark_options_delayed_oneDelay <= 0;
		end else begin
			mark_options_delayed_oneDelay <= mark_options_delayed;
			for (a = 0; a < PARMARKS; a = a + 1) begin
				mark_options_delayed_gt_largestMark_oneDelay[a] <=
					mark_options_delayed[$clog2(M+1)-1 + a*$clog2(M+1) -: $clog2(M+1)] > largestMark;
				largestMark_minus_mark_options_delayed_oneDelay[$clog2(M+1)-1 + a*$clog2(M+1) -: $clog2(M+1)] <=
					largestMark - mark_options_delayed[$clog2(M+1)-1 + a*$clog2(M+1) -: $clog2(M+1)];
			end
		end
	end


	// (5)
	reg [PARMARKS*(M+1)-1:0] distances_options;
	reg [PARMARKS-1:0] optionValidity;
	reg [PARMARKS*(M+1)-1:0] cand_natRuler_options;
	reg [PARMARKS*(M+1)-1:0] cand_revRuler_options;
	reg [PARMARKS*$clog2(M+1)-1:0] cand_largestMark_options;

	integer v;
	reg [(M+1)-1:0] leftDistances;
	reg [(M+1)-1:0] rightDistances;
	reg [(M+1)-1:0] bisection;
	reg [(M+1)-1:0] intersection;
	always @(*) begin
		for (v = 0; v < PARMARKS; v = v + 1) begin
			cand_natRuler_options[M + v*(M+1) -: M+1] = natRuler[M + i*(M+1) -: M+1] | (ONE << mark_options_delayed_oneDelay[$clog2(M+1)-1 + v*$clog2(M+1) -: $clog2(M+1)]);
			if (mark_options_delayed_gt_largestMark_oneDelay[v]) begin
				leftDistances = leftDistances_branch1_ins[M + v*(M+1) -: M+1];
				rightDistances = ZERO;
				cand_revRuler_options[M + v*(M+1) -: M+1] = leftDistances | ONE;
				cand_largestMark_options[$clog2(M+1)-1 + v*$clog2(M+1) -: $clog2(M+1)] = mark_options_delayed_oneDelay[$clog2(M+1)-1 + v*$clog2(M+1) -: $clog2(M+1)];
			end else begin
				leftDistances = leftDistances_branch2_ins[M + v*(M+1) -: M+1];
				rightDistances = rightDistances_branch2_ins[M + v*(M+1) -: M+1];
				cand_largestMark_options[$clog2(M+1)-1 + v*$clog2(M+1) -: $clog2(M+1)] = largestMark;
				cand_revRuler_options[M + v*(M+1) -: M+1] = revRuler[M + i*(M+1) -: M+1] | (ONE << largestMark_minus_mark_options_delayed_oneDelay[$clog2(M+1)-1 + v*$clog2(M+1) -: $clog2(M+1)]);
			end
			distances_options[M + v*(M+1) -: M+1] = leftDistances | rightDistances;
			bisection = leftDistances & rightDistances;
			intersection = cumSpectrum & distances_options[M + v*(M+1) -: M+1];
			optionValidity[v] = !( bisection || intersection ) && (latencyCtr == LATENCY);
		end
	end

	// (5)
	reg [M:0] distances;
	reg markIsValid;
	reg [(M+1)-1:0] cand_natRuler;
	reg [(M+1)-1:0] cand_revRuler;
	reg [$clog2(M+1)-1:0] cand_largestMark;

	integer w;
	always @(*) begin
		distances = distances_options[M + 0*(M+1) -: M+1];
		markIsValid = optionValidity[0];
		cand_natRuler = cand_natRuler_options[M + 0*(M+1) -: M+1];
		cand_revRuler = cand_revRuler_options[M + 0*(M+1) -: M+1];
		cand_largestMark = cand_largestMark_options[$clog2(M+1)-1 + 0*$clog2(M+1) -: $clog2(M+1)];
		for (w = 0; w < PARMARKS; w = w + 1) begin
			if (optionValidity[w]) begin
				distances = distances_options[M + w*(M+1) -: M+1];
				markIsValid = optionValidity[w];
				cand_natRuler = cand_natRuler_options[M + w*(M+1) -: M+1];
				cand_revRuler = cand_revRuler_options[M + w*(M+1) -: M+1];
				cand_largestMark = cand_largestMark_options[$clog2(M+1)-1 + w*$clog2(M+1) -: $clog2(M+1)];
			end
		end
	end


	// state transition logic
	always @(*) begin
		clearPipeline = 1;
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
					next_natRuler[M + i*(M+1) -: M+1] = cand_natRuler;
					next_revRuler[M + i*(M+1) -: M+1] = cand_revRuler;
					next_largestMark = cand_largestMark;
					next_spectrum[M + i*(M+1) -: M+1] = spectrum[M + i*(M+1) -: M+1] | distances;
					next_cumSpectrum = cumSpectrum | distances;
					if (j == k-1) begin // finished block i
						if (i == n-1) begin // done
							next_ctrlState = ctrlC; // don't care about other updates
						end else if (dtsGenIters == DTSGEN_THRESH) begin
							// reset all 11 registers
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
							if (i == 0) begin
								// reset all 11 registers
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
							end else begin
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
							end
						end else begin // mark inserted, block not completed, not out of iters
							next_blockGenIters = blockGenIters + 1;
							next_j = j + 1;
						end
					end
				end else begin // invalid mark
					if (blockGenIters == BLOCKGEN_THRESH) begin // invalid mark and out of iters
						if (i == 0) begin
							// reset all 11 registers
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
						end else begin
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
						end
					end else begin // invalid mark and not out of iters
						next_blockGenIters = blockGenIters + 1;
						clearPipeline = 0;
					end
				end
			end // case ctrlA
			ctrlB : begin
				if (markIsValid) begin
					next_natRuler[M + i*(M+1) -: M+1] = cand_natRuler;
					next_revRuler[M + i*(M+1) -: M+1] = cand_revRuler;
					next_largestMark = cand_largestMark;
					next_spectrum[M + i*(M+1) -: M+1] = spectrum[M + i*(M+1) -: M+1] | distances;
					next_cumSpectrum = cumSpectrum | distances;
					if (j == k-1) begin // finished block i with block t held out
						// go back to ctrlA
						if (dtsGenIters == DTSGEN_THRESH) begin // out of iters
							// reset all 11 registers
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
								next_cumSpectrum = cumSpectrum ^ spectrum[M + i*(M+1) -: M+1] ^ spectrum[M + t*(M+1) -: M+1] ^ spectrum[M + (t-1)*(M+1) -: M+1];
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
							next_cumSpectrum = cumSpectrum ^ spectrum[M + i*(M+1) -: M+1] ^ spectrum[M + t*(M+1) -: M+1] ^ spectrum[M + (t-1)*(M+1) -: M+1];
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
						clearPipeline = 0;
					end
				end
			end //case ctrl B
			ctrlC : ;// stay;
			default : ;
		endcase
	end
endmodule
