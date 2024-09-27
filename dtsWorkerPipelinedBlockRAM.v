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
module dtsWorkerPipelinedBlockRAM(clk, reset, rowStream, done, anotherOne);
	parameter workerIndex = 0;

	parameter n = 3; // num blocks
	parameter k = 3; // num marks (excluding zero mark)
	parameter M = 19; // max mark to consider
	parameter MARKGEN_STAGES = 4;
	parameter BLOCKGEN_THRESH = 50;
	parameter PARMARKS = 2;
	parameter DTSGEN_THRESH = 1000;

	parameter [M:0] ZERO = 0;
	parameter [M:0] ONE = 1;

	input wire clk;
	input wire reset;
	output wire [M:0] rowStream;

	output reg done;
	input wire anotherOne;

	// active ruler buffer
	reg [M:0] natRulerActiveIn;
	reg [M:0] revRulerActiveIn;
	reg [M:0] spectrumActiveIn;
	reg [M:0] natRulerActive;
	reg [M:0] revRulerActive;
	reg [M:0] spectrumActive;
	always @(posedge clk) begin
		natRulerActive <= natRulerActiveIn;
		revRulerActive <= revRulerActiveIn;
		spectrumActive <= spectrumActiveIn;
	end

	// dts state storage
	reg natRulerRAM_we;
	reg [$clog2(n)-1:0] natRulerRAM_addr;
	wire [M:0] natRulerRAM_out;
	ram #(.n(n), .M(M)) natRulerRAM (
									.clk(clk),
									.we(natRulerRAM_we),
									.en(1'b1),
									.addr(natRulerRAM_addr),
									.di(natRulerActive),
									.dout(natRulerRAM_out)
									);
	reg spectrumRAM_we;
	reg [$clog2(n)-1:0] spectrumRAM_addr;
	wire [M:0] spectrumRAM_out;
	ram #(.n(n), .M(M)) spectrumRAM (
									.clk(clk),
									.we(spectrumRAM_we),
									.en(1'b1),
									.addr(spectrumRAM_addr),
									.di(spectrumActive),
									.dout(spectrumRAM_out)
									);

	assign rowStream = natRulerRAM_out;

	reg [M:0] cumSpectrum;
	reg [$clog2(M+1)-1:0] largestMark; // of block i, not of the dts
	reg [M:0] next_cumSpectrum;
	reg [$clog2(M+1)-1:0] next_largestMark;

	// registers representing counters
	reg [$clog2(DTSGEN_THRESH+5)-1:0] dtsGenIters;
	reg [$clog2(BLOCKGEN_THRESH+5)-1:0] blockGenIters;
	reg [$clog2(DTSGEN_THRESH+5)-1:0] next_dtsGenIters;
	reg [$clog2(BLOCKGEN_THRESH+5)-1:0] next_blockGenIters;

	reg [$clog2(k)-1:0] j; // marks populated (excluding zero mark)
	reg [$clog2(n)-1:0] i; // blocks populated
	reg [$clog2(n)-1:0] t;
	reg [$clog2(k)-1:0] next_j;
	reg [$clog2(n)-1:0] next_i;
	reg [$clog2(n)-1:0] next_t;

	// register for control FSM state
	reg [3:0] ctrlState;
	reg [3:0] next_ctrlState;

	parameter ctrlA = 0;
	parameter ctrlB = 1;
	parameter ctrlC = 2;
	parameter wait_ctrlA = 3;
	parameter ctrlResetDtsState = 4;
	parameter firstEntry_ctrlB = 5;
	parameter exhaustion_ctrlB = 6;
	parameter wait_ctrlC = 7;
	parameter ctrlInsertion = 8;
	parameter ctrlInsertionDuringHoldout = 9;

	// main register update and reset
	always @(posedge clk) begin
		if (reset) begin
			ctrlState <= ctrlResetDtsState;
		end else begin
			ctrlState <= next_ctrlState;
		end
	end
	always @(posedge clk) begin
		cumSpectrum <= next_cumSpectrum;
		largestMark <= next_largestMark;
		dtsGenIters <= next_dtsGenIters;
		blockGenIters <= next_blockGenIters;
		j <= next_j;
		i <= next_i;
		t <= next_t;
	end

	// markGen pipeline never needs to be cleared
	wire [PARMARKS-1:0] markGenValid_options;
	wire markGenValid;
	wire [PARMARKS*$clog2(M+1)-1:0] mark_options;
	assign markGenValid = markGenValid_options[0]; // all should be equal
	genvar u;
	generate
		for (u = 0; u < PARMARKS; u = u + 1) begin:unit
			multiDiscNonUnifHQ #(
								.seedIndex(workerIndex*PARMARKS + u),
								.STAGES(MARKGEN_STAGES)
								) markGen (
											clk,
											reset,
											j,
											mark_options[$clog2(M+1)-1 + u*$clog2(M+1) -: $clog2(M+1)],
											markGenValid_options[u]
											);
		end
	endgenerate

	// the pipeline which follows needs clearing on every mark insertion
	reg clearPipeline;

	// one cycle of latency
	reg [PARMARKS*$clog2(M+1)-1:0] mark_options_oneDelay;
	reg [PARMARKS*$clog2(M+1)-1:0] mark_minus_largestMark_options_oneDelay;
	reg [PARMARKS*$clog2(M+1)-1:0] largestMark_minus_mark_options_oneDelay;
	reg valid_oneDelay;
	integer b;
	always @(posedge clk) begin
		if (clearPipeline) begin
			valid_oneDelay <= 0;
		end else begin
			valid_oneDelay <= markGenValid;
		end
	end
	always @(posedge clk) begin
		mark_options_oneDelay <= mark_options;
		for (b = 0; b < PARMARKS; b = b + 1) begin
			mark_minus_largestMark_options_oneDelay[$clog2(M+1)-1 + b*$clog2(M+1) -: $clog2(M+1)] <=
				mark_options[$clog2(M+1)-1 + b*$clog2(M+1) -: $clog2(M+1)] - largestMark;
			largestMark_minus_mark_options_oneDelay[$clog2(M+1)-1 + b*$clog2(M+1) -: $clog2(M+1)] <=
				largestMark - mark_options[$clog2(M+1)-1 + b*$clog2(M+1) -: $clog2(M+1)];
		end
	end

	wire [PARMARKS*(M+1)-1:0] leftDistances_branch1_ins;
	wire [PARMARKS*(M+1)-1:0] leftDistances_branch2_ins;
	wire [PARMARKS*(M+1)-1:0] rightDistances_branch2_ins;
	wire [PARMARKS-1:0] shifterValid_options;
	wire shifterValid;
	assign shifterValid = shifterValid_options[0]; // all should be equal
	genvar z;
	generate
		for (z = 0; z < PARMARKS; z = z + 1) begin:pipeline
			leftShiftPipelinedRecursive #(.WIDTH(M+1)) leftShifter (
									.clk(clk),
									.reset(clearPipeline),
									.out(leftDistances_branch1_ins[M + z*(M+1) -: M+1]),
									.in(revRulerActive),
									.shift(mark_minus_largestMark_options_oneDelay[$clog2(M+1)-1 + z*$clog2(M+1) -: $clog2(M+1)]),
									.validIn(valid_oneDelay),
									.validOut(shifterValid_options[z])
									);
			rightShiftPipelinedRecursive #(.WIDTH(M+1)) rightShifter1 (
									.clk(clk),
									.reset(clearPipeline),
									.out(leftDistances_branch2_ins[M + z*(M+1) -: M+1]),
									.in(revRulerActive),
									.shift(largestMark_minus_mark_options_oneDelay[$clog2(M+1)-1 + z*$clog2(M+1) -: $clog2(M+1)]),
									.validIn(1'b1),
									.validOut()
									);
			rightShiftPipelinedRecursive #(.WIDTH(M+1)) rightShifter2 (
									.clk(clk),
									.reset(clearPipeline),
									.out(rightDistances_branch2_ins[M + z*(M+1) -: M+1]),
									.in(natRulerActive),
									.shift(mark_options_oneDelay[$clog2(M+1)-1 + z*$clog2(M+1) -: $clog2(M+1)]),
									.validIn(1'b1),
									.validOut()
									);
		end
	endgenerate

	// add SHIFTER_LATENCY cycles of latency to synchronize with shifter outputs
	parameter SHIFTER_LATENCY = ($clog2(M+1)+1)/2;
	wire [PARMARKS*$clog2(M+1)-1:0] mark_options_delayed;
	wire [PARMARKS*$clog2(M+1)-1:0] largestMark_minus_mark_options_delayed;
	wire [PARMARKS-1:0] mark_options_gt_largestMark_delayed;
	reg [SHIFTER_LATENCY*PARMARKS*$clog2(M+1)-1:0] mark_options_ShiftReg;
	reg [SHIFTER_LATENCY*PARMARKS*$clog2(M+1)-1:0] largestMark_minus_mark_options_ShiftReg;
	reg [SHIFTER_LATENCY*PARMARKS-1:0] mark_options_gt_largestMark_ShiftReg;
	assign mark_options_delayed = mark_options_ShiftReg[PARMARKS*$clog2(M+1)-1 -: PARMARKS*$clog2(M+1)];
	assign largestMark_minus_mark_options_delayed = largestMark_minus_mark_options_ShiftReg[PARMARKS*$clog2(M+1)-1 -: PARMARKS*$clog2(M+1)];
	assign mark_options_gt_largestMark_delayed = mark_options_gt_largestMark_ShiftReg[PARMARKS-1 -: PARMARKS];
	integer a;
	always @(posedge clk) begin
		// shift register inputs:
		mark_options_ShiftReg[(SHIFTER_LATENCY-1)*PARMARKS*$clog2(M+1) + PARMARKS*$clog2(M+1)-1 -: PARMARKS*$clog2(M+1)] <= mark_options_oneDelay;
		for (a = 0; a < PARMARKS; a = a + 1) begin
			largestMark_minus_mark_options_ShiftReg[(SHIFTER_LATENCY-1)*PARMARKS*$clog2(M+1) + a*$clog2(M+1) + $clog2(M+1)-1 -: $clog2(M+1)] <=
																largestMark_minus_mark_options_oneDelay[$clog2(M+1)-1 + a*$clog2(M+1) -: $clog2(M+1)];
			mark_options_gt_largestMark_ShiftReg[(SHIFTER_LATENCY-1)*PARMARKS + a] <=
																mark_options_oneDelay[$clog2(M+1)-1 + a*$clog2(M+1) -: $clog2(M+1)] > largestMark;
		end
		// shift register
		for (a = SHIFTER_LATENCY-1; a >= 1; a = a - 1) begin
			mark_options_ShiftReg[(a-1)*PARMARKS*$clog2(M+1) + PARMARKS*$clog2(M+1)-1 -: PARMARKS*$clog2(M+1)] <=
										mark_options_ShiftReg[a*PARMARKS*$clog2(M+1) + PARMARKS*$clog2(M+1)-1 -: PARMARKS*$clog2(M+1)];
			largestMark_minus_mark_options_ShiftReg[(a-1)*PARMARKS*$clog2(M+1) + PARMARKS*$clog2(M+1)-1 -: PARMARKS*$clog2(M+1)] <=
										largestMark_minus_mark_options_ShiftReg[a*PARMARKS*$clog2(M+1) + PARMARKS*$clog2(M+1)-1 -: PARMARKS*$clog2(M+1)];
			mark_options_gt_largestMark_ShiftReg[(a-1)*PARMARKS + PARMARKS-1 -: PARMARKS] <=
										mark_options_gt_largestMark_ShiftReg[a*PARMARKS + PARMARKS-1 -: PARMARKS];
		end
	end

	// plus three cycles of latency
	reg [PARMARKS*$clog2(M+1)-1:0] largestMark_minus_mark_options_delayed_oneDelay;
	reg [PARMARKS-1:0] mark_options_gt_largestMark_delayed_oneDelay;
	reg [PARMARKS-1:0] mark_options_gt_largestMark_delayed_twoDelay;
	reg shifterValid_oneDelay;
	reg shifterValid_twoDelay;
	always @(posedge clk) begin
		if (clearPipeline) begin
			shifterValid_oneDelay <= 0;
			shifterValid_twoDelay <= 0;
		end else begin
			shifterValid_oneDelay <= shifterValid;
			shifterValid_twoDelay <= shifterValid_oneDelay;
		end
	end
	always @(posedge clk) begin
		largestMark_minus_mark_options_delayed_oneDelay <= largestMark_minus_mark_options_delayed;
		mark_options_gt_largestMark_delayed_oneDelay <= mark_options_gt_largestMark_delayed;
		mark_options_gt_largestMark_delayed_twoDelay <= mark_options_gt_largestMark_delayed_oneDelay;
	end

	reg [PARMARKS*(M+1)-1:0] cand_natRuler_options_partial_1;
	reg [PARMARKS*(M+1)-1:0] cand_natRuler_options_partial_2;
	reg [PARMARKS*(M+1)-1:0] cand_natRuler_options;

	reg [PARMARKS*(M+1)-1:0] cand_revRuler_options_partial_1;
	reg [PARMARKS*(M+1)-1:0] cand_revRuler_options_partial_2;
	reg [PARMARKS*(M+1)-1:0] cand_revRuler_options;

	reg [PARMARKS*(M+1)-1:0] distances_oneDelay;
	reg [PARMARKS*(M+1)-1:0] distances_twoDelay;
	reg [PARMARKS*(M+1)-1:0] cand_spectrum_options;
	reg [PARMARKS*(M+1)-1:0] cand_cumSpectrum_options;

	reg [PARMARKS*$clog2(M+1)-1:0] cand_largestMark_options_partial_1;
	reg [PARMARKS*$clog2(M+1)-1:0] cand_largestMark_options_partial_2;
	reg [PARMARKS*$clog2(M+1)-1:0] cand_largestMark_options;

	reg [PARMARKS*(M+1)-1:0] intersection_options_oneDelay;
	reg [PARMARKS*(M+1)-1:0] bisection_options_oneDelay;

	reg [PARMARKS-1:0] optionValidity;

	integer v;
	parameter HALF_WIDTH = (M+1+2-1)/2;
	reg [PARMARKS*HALF_WIDTH*2-1:0] intersection_options_oneDelay_evenPad;
	reg [PARMARKS*HALF_WIDTH*2-1:0] bisection_options_oneDelay_evenPad;
	always @(*) begin
		for (v = 0; v < PARMARKS; v = v + 1) begin
			intersection_options_oneDelay_evenPad[v*HALF_WIDTH*2 + HALF_WIDTH*2-1 -: HALF_WIDTH*2] =
									intersection_options_oneDelay[v*(M+1) + (M+1)-1 -: M+1];
			bisection_options_oneDelay_evenPad[v*HALF_WIDTH*2 + HALF_WIDTH*2-1 -: HALF_WIDTH*2] =
									bisection_options_oneDelay[v*(M+1) + (M+1)-1 -: M+1];
		end
	end
	reg [PARMARKS-1:0] intersection_options_firstHalfReduction;
	reg [PARMARKS-1:0] intersection_options_secondHalfReduction;
	reg [PARMARKS-1:0] bisection_options_firstHalfReduction;
	reg [PARMARKS-1:0] bisection_options_secondHalfReduction;

	always @(posedge clk) begin
		if (clearPipeline) begin
			optionValidity <= 0;
		end else begin
			for (v = 0; v < PARMARKS; v = v + 1) begin
				optionValidity[v] <= &{ ~intersection_options_firstHalfReduction[v],
										~intersection_options_secondHalfReduction[v],
										~bisection_options_firstHalfReduction[v],
										~bisection_options_secondHalfReduction[v],
										shifterValid_twoDelay};
			end
		end
	end
	always @(posedge clk) begin
		for (v = 0; v < PARMARKS; v = v + 1) begin
			cand_natRuler_options_partial_1[M + v*(M+1) -: M+1] <= (ONE << mark_options_delayed[$clog2(M+1)-1 + v*$clog2(M+1) -: $clog2(M+1)]);
			cand_natRuler_options_partial_2[M + v*(M+1) -: M+1] <= natRulerActive | cand_natRuler_options_partial_1[M + v*(M+1) -: M+1];
			cand_natRuler_options[M + v*(M+1) -: M+1] <= cand_natRuler_options_partial_2[M + v*(M+1) -: M+1];

			cand_revRuler_options_partial_1[M + v*(M+1) -: M+1] <= leftDistances_branch1_ins[M + v*(M+1) -: M+1] | ONE;
			cand_revRuler_options_partial_2[M + v*(M+1) -: M+1] <= mark_options_gt_largestMark_delayed_oneDelay[v] ?
							cand_revRuler_options_partial_1[M + v*(M+1) -: M+1] :
							(ONE << largestMark_minus_mark_options_delayed_oneDelay[$clog2(M+1)-1 + v*$clog2(M+1) -: $clog2(M+1)]);
			cand_revRuler_options[M + v*(M+1) -: M+1] <= mark_options_gt_largestMark_delayed_twoDelay[v] ?
								cand_revRuler_options_partial_2[M + v*(M+1) -: M+1] :
								(cand_revRuler_options_partial_2[M + v*(M+1) -: M+1]|revRulerActive);

			cand_largestMark_options_partial_1[$clog2(M+1)-1 + v*$clog2(M+1) -: $clog2(M+1)] <=
						mark_options_gt_largestMark_delayed[v] ? mark_options_delayed[$clog2(M+1)-1 + v*$clog2(M+1) -: $clog2(M+1)] : largestMark;
			cand_largestMark_options_partial_2[$clog2(M+1)-1 + v*$clog2(M+1) -: $clog2(M+1)] <=
							cand_largestMark_options_partial_1[$clog2(M+1)-1 + v*$clog2(M+1) -: $clog2(M+1)];
			cand_largestMark_options[$clog2(M+1)-1 + v*$clog2(M+1) -: $clog2(M+1)] <=
							cand_largestMark_options_partial_2[$clog2(M+1)-1 + v*$clog2(M+1) -: $clog2(M+1)];

			distances_oneDelay[M + v*(M+1) -: M+1] <=
						mark_options_gt_largestMark_delayed[v] ?
								leftDistances_branch1_ins[M + v*(M+1) -: M+1] :
								(leftDistances_branch2_ins[M + v*(M+1) -: M+1]|rightDistances_branch2_ins[M + v*(M+1) -: M+1]);
			distances_twoDelay[M + v*(M+1) -: M+1] <= distances_oneDelay[M + v*(M+1) -: M+1];
			cand_spectrum_options[M + v*(M+1) -: M+1] <= spectrumActive|distances_twoDelay[M + v*(M+1) -: M+1];
			cand_cumSpectrum_options[M + v*(M+1) -: M+1] <= cumSpectrum|distances_twoDelay[M + v*(M+1) -: M+1];

			intersection_options_oneDelay[M + v*(M+1) -: M+1] <= mark_options_gt_largestMark_delayed[v] ?
								(cumSpectrum&leftDistances_branch1_ins[M + v*(M+1) -: M+1]) :
								(cumSpectrum&leftDistances_branch2_ins[M + v*(M+1) -: M+1]|cumSpectrum&rightDistances_branch2_ins[M + v*(M+1) -: M+1]);

			bisection_options_oneDelay[M + v*(M+1) -: M+1] <= mark_options_gt_largestMark_delayed[v] ?
						ZERO : (leftDistances_branch2_ins[M + v*(M+1) -: M+1]&rightDistances_branch2_ins[M + v*(M+1) -: M+1]);

			intersection_options_firstHalfReduction[v] <= |intersection_options_oneDelay_evenPad[v*HALF_WIDTH*2 + HALF_WIDTH*2-1 -: HALF_WIDTH];
			intersection_options_secondHalfReduction[v] <= |intersection_options_oneDelay_evenPad[v*HALF_WIDTH*2 + HALF_WIDTH-1 -: HALF_WIDTH];

			bisection_options_firstHalfReduction[v] <= |bisection_options_oneDelay_evenPad[v*HALF_WIDTH*2 + HALF_WIDTH*2-1 -: HALF_WIDTH];
			bisection_options_secondHalfReduction[v] <= |bisection_options_oneDelay_evenPad[v*HALF_WIDTH*2 + HALF_WIDTH-1 -: HALF_WIDTH];
		end
	end

	// plus one cycle of latency
	reg markIsValidIn;
	reg [(M+1)-1:0] cand_natRulerIn;
	reg [(M+1)-1:0] cand_revRulerIn;
	reg [$clog2(M+1)-1:0] cand_largestMarkIn;
	reg [(M+1)-1:0] cand_spectrumIn;
	reg [(M+1)-1:0] cand_cumSpectrumIn;
	integer w;
	always @(*) begin
		markIsValidIn = optionValidity[0];
		cand_natRulerIn = cand_natRuler_options[M + 0*(M+1) -: M+1];
		cand_revRulerIn = cand_revRuler_options[M + 0*(M+1) -: M+1];
		cand_largestMarkIn = cand_largestMark_options[$clog2(M+1)-1 + 0*$clog2(M+1) -: $clog2(M+1)];
		cand_spectrumIn = cand_spectrum_options[M + 0*(M+1) -: M+1];
		cand_cumSpectrumIn = cand_cumSpectrum_options[M + 0*(M+1) -: M+1];
		for (w = 0; w < PARMARKS; w = w + 1) begin
			if (optionValidity[w]) begin
				markIsValidIn = optionValidity[w];
				cand_natRulerIn = cand_natRuler_options[M + w*(M+1) -: M+1];
				cand_revRulerIn = cand_revRuler_options[M + w*(M+1) -: M+1];
				cand_largestMarkIn = cand_largestMark_options[$clog2(M+1)-1 + w*$clog2(M+1) -: $clog2(M+1)];
				cand_spectrumIn = cand_spectrum_options[M + w*(M+1) -: M+1];
				cand_cumSpectrumIn = cand_cumSpectrum_options[M + w*(M+1) -: M+1];
			end
		end
	end
	reg markIsValid;
	reg [(M+1)-1:0] cand_natRuler;
	reg [(M+1)-1:0] cand_revRuler;
	reg [$clog2(M+1)-1:0] cand_largestMark;
	reg [M:0] cand_spectrum;
	reg [M:0] cand_cumSpectrum;
	always @(posedge clk) begin
		if (clearPipeline) begin
			markIsValid <= 0;
		end else begin
			markIsValid <= markIsValidIn;
		end
	end
	always @(posedge clk) begin
		cand_natRuler <= cand_natRulerIn;
		cand_revRuler <= cand_revRulerIn;
		cand_largestMark <= cand_largestMarkIn;
		cand_spectrum <= cand_spectrumIn;
		cand_cumSpectrum <= cand_cumSpectrumIn;
	end

	// there should usually be enough latency for these to settle to the right values
	reg [$clog2(n)-1:0] t_t_minus_1_toggler;
	always @(posedge clk) begin
		if (t_t_minus_1_toggler == t) begin
			t_t_minus_1_toggler <= t - 1;
		end else begin
			t_t_minus_1_toggler <= t;
		end
	end
	reg [M:0] spectrum_t;
	reg [M:0] spectrum_t_minus_1;
	always @(posedge clk) begin
		if (t_t_minus_1_toggler == t) begin
			spectrum_t_minus_1 <= spectrumRAM_out;
		end else begin
			spectrum_t <= spectrumRAM_out;
		end
	end
	// independent, no additional latency since these are constant between pipeline clears
	reg [M:0] cand_cumSpectrum_case1;
	reg [M:0] cand_cumSpectrum_case2;
	reg [M:0] cand_cumSpectrum_case3;
	always @(posedge clk) begin
		cand_cumSpectrum_case1 <= cumSpectrum ^ spectrumActive ^ spectrum_t;
		cand_cumSpectrum_case2 <= cumSpectrum ^ spectrumActive ^ spectrum_t_minus_1;
		cand_cumSpectrum_case3 <= cumSpectrum ^ spectrumActive ^ spectrum_t ^ spectrum_t_minus_1;
	end

	reg [$clog2(n)-1:0] i_ctr;
	always @(posedge clk) begin
		if (reset) begin
			i_ctr <= 0;
		end else if (i_ctr == n-1) begin
			i_ctr <= 0;
		end else begin
			i_ctr <= i_ctr + 1;
		end
	end
	always @(posedge clk) begin
		if (reset|anotherOne) begin
			done <= 0;
		end else begin
			done <= ctrlState == ctrlC;
		end
	end

	// state transition logic
	always @(*) begin
		// defaults:
		clearPipeline = 1;
		natRulerActiveIn = natRulerActive;
		revRulerActiveIn = revRulerActive;
		spectrumActiveIn = spectrumActive;
		natRulerRAM_addr = t_t_minus_1_toggler;
		spectrumRAM_addr = t_t_minus_1_toggler;
		natRulerRAM_we = 0;
		spectrumRAM_we = 0;
		next_cumSpectrum = cumSpectrum;
		next_largestMark = largestMark;
		next_dtsGenIters = dtsGenIters;
		next_blockGenIters = blockGenIters;
		next_j = j;
		next_i = i;
		next_t = t;
		next_ctrlState = ctrlState;
		case (ctrlState)
			ctrlA : begin
				if (markIsValid) begin
					natRulerActiveIn = cand_natRuler;
					revRulerActiveIn = cand_revRuler;
					next_largestMark = cand_largestMark;
					spectrumActiveIn = cand_spectrum;
					next_cumSpectrum = cand_cumSpectrum;
					if (j == k-1) begin // finished block i
						if (i == n-1) begin // done
							next_ctrlState = wait_ctrlC; // don't care about other updates
						end else begin // block i completed, not last block
							next_ctrlState = ctrlInsertion;
						end
					end else begin // mark inserted but block not completed
						next_j = j + 1;
					end
				end else begin // invalid mark
					clearPipeline = 0;
				end
				if (blockGenIters == BLOCKGEN_THRESH && next_ctrlState == ctrlA) begin // out of iters
					if (i == 0) begin
						next_ctrlState = ctrlResetDtsState;
					end else begin
						next_ctrlState = firstEntry_ctrlB;
					end
				end else begin
					next_blockGenIters = blockGenIters + 1;
				end
			end // case ctrlA
			ctrlB : begin
				if (markIsValid) begin
					natRulerActiveIn = cand_natRuler;
					revRulerActiveIn = cand_revRuler;
					next_largestMark = cand_largestMark;
					spectrumActiveIn = cand_spectrum;
					next_cumSpectrum = cand_cumSpectrum;
					if (j == k-1) begin
						next_ctrlState = ctrlInsertionDuringHoldout;
					end else begin // mark inserted but block not completed
						next_j = j + 1;
					end
				end else begin // invalid mark
					clearPipeline = 0;
				end
				if (blockGenIters == BLOCKGEN_THRESH && next_ctrlState == ctrlB) begin // out of iters
					next_ctrlState = exhaustion_ctrlB;
				end else begin
					next_blockGenIters = blockGenIters + 1;
				end
			end //case ctrl B
			wait_ctrlC : begin
				natRulerRAM_we = 1;
				natRulerRAM_addr = i;
				next_ctrlState = ctrlC;
			end
			ctrlC : begin
				if (anotherOne) begin
					next_ctrlState = ctrlResetDtsState;
				end
				natRulerRAM_addr = i_ctr;
			end
			ctrlResetDtsState : begin
				natRulerActiveIn = ONE;
				revRulerActiveIn = ONE;
				spectrumActiveIn = ZERO;
				next_cumSpectrum = ZERO;
				next_largestMark = 0;
				next_dtsGenIters = 0;
				next_blockGenIters = 0;
				next_j = 0;
				next_i = 0;
				next_t = 0;
				next_ctrlState = wait_ctrlA;
			end
			firstEntry_ctrlB : begin
				natRulerActiveIn = ONE;
				revRulerActiveIn = ONE;
				spectrumActiveIn = ZERO;
				next_cumSpectrum = cand_cumSpectrum_case1;
				next_largestMark = 0;
				next_blockGenIters = 0;
				next_j = 0;
				next_t = t + 1;
				next_ctrlState = ctrlB;
			end
			wait_ctrlA : begin
				if (dtsGenIters == DTSGEN_THRESH) begin
					next_ctrlState = ctrlResetDtsState;
				end else begin
					next_ctrlState = ctrlA;
				end
			end
			exhaustion_ctrlB : begin
				if (t == i) begin // out of deletion candidates and out of iters, return to ctrlA
					natRulerActiveIn = ONE;
					revRulerActiveIn = ONE;
					spectrumActiveIn = ZERO;
					next_cumSpectrum = cand_cumSpectrum_case2;
					next_largestMark = 0;
					next_dtsGenIters = dtsGenIters + 1;
					next_blockGenIters = 0;
					next_j = 0;
					next_t = 0;
					next_ctrlState = wait_ctrlA;
				end else begin // out of iters but not out of deletion candidates, go to next deletion candidate
					natRulerActiveIn = ONE;
					revRulerActiveIn = ONE;
					spectrumActiveIn = ZERO;
					next_cumSpectrum = cand_cumSpectrum_case3;
					next_largestMark = 0;
					next_blockGenIters = 0;
					next_j = 0;
					next_t = t + 1;
					next_ctrlState = ctrlB;
				end
			end
			ctrlInsertion : begin
				natRulerActiveIn = ONE;
				revRulerActiveIn = ONE;
				spectrumActiveIn = ZERO;
				next_largestMark = 0;
				next_dtsGenIters = dtsGenIters + 1;
				next_blockGenIters = 0;
				next_j = 0;
				next_i = i + 1;
				natRulerRAM_we = 1;
				spectrumRAM_we = 1;
				natRulerRAM_addr = i;
				spectrumRAM_addr = i;
				next_ctrlState = wait_ctrlA;
			end
			ctrlInsertionDuringHoldout : begin
				natRulerActiveIn = ONE;
				revRulerActiveIn = ONE;
				spectrumActiveIn = ZERO;
				natRulerRAM_we = 1;
				spectrumRAM_we = 1;
				natRulerRAM_addr = t - 1;
				spectrumRAM_addr = t - 1;
				next_largestMark = 0;
				next_dtsGenIters = dtsGenIters + 1;
				next_blockGenIters = 0;
				next_j = 0;
				next_t = 0;
				next_ctrlState = wait_ctrlA;
			end
			default : ;
		endcase
	end
endmodule
