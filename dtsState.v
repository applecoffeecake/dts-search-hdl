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

/*
	This module defines bidirectional circular shifter registers
	for storing the dts state along a control FSM enabling insertion
	and holdout (a kind of backtracking) operation.
*/
// synthesis VERILOG_INPUT_VERSION VERILOG_2001
`default_nettype none
module dtsState(
				clk,
				reset,
				natRuler,
				ready,
				insert,
				holdout,
				t,
				spectrum_i_minus_1,
				natRulerIn,
				spectrumIn,
				spectrumBackup
				);

	parameter n = 3; // num blocks
	parameter M = 19; // max mark to consider

	input wire clk;
	input wire reset;

	output wire ready;
	input wire insert;
	input wire holdout;
	output reg [$clog2(n+1)-1:0] t; // has reset
	reg [$clog2(n+1)-1:0] next_t;

	output wire [M:0] spectrum_i_minus_1; // need external peek at this

	input wire [M:0] natRulerIn;
	input wire [M:0] spectrumIn;

	output wire [n*(M+1) - 1 : 0] natRuler;

	// bidirectional circular shift registers
	reg [n*(M+1) - 1 : 0] natRulerShiftReg;
	reg [n*(M+1) - 1 : 0] spectrumShiftReg;
	reg [n*(M+1) - 1 : 0] next_natRulerShiftReg;
	reg [n*(M+1) - 1 : 0] next_spectrumShiftReg;

	assign spectrum_i_minus_1 = spectrumShiftReg[1*(M+1) + (M+1)-1 -: M+1];

	assign natRuler = natRulerShiftReg;

	// backup registers, have reset
	reg [M:0] natRulerBackup;
	output reg [M:0] spectrumBackup;
	reg [M:0] next_natRulerBackup;
	reg [M:0] next_spectrumBackup;

	/*
	When a block is completed, we assert "insert."
	When we want to hold out a block, or a different block if
	one is already held out, we assert "holdout."

	When a holdout is requested, we:
		(*). Load the content of the backup register into the active
			position and load content of the about-to-be-active position
			into the backup register.
			If just entering the holdout state, the backup register will
			contain reset state values.
		(**). Shift down circularly and increment t.

	t indicates the number of rulers out of the i populated
	that we have individually held out.
	*/
	// control FSM
	parameter WRITING = 0;
	parameter INSERTING = 1;
	parameter HOLDOUT_BACKUP = 2;
	parameter HOLDOUT_DOWNSHIFT = 3;

	reg [1:0] state;
	reg [1:0] next_state;
	assign ready = state == WRITING;

	integer a;
	parameter [M:0] ZERO = 0;
	parameter [M:0] ONE = 1;
	always @(*) begin
		next_natRulerShiftReg = natRulerShiftReg;
		next_spectrumShiftReg = spectrumShiftReg;
		next_t = t;
		next_natRulerBackup = natRulerBackup;
		next_spectrumBackup = spectrumBackup;
		next_state = state;
		case (state)
			WRITING : begin
				next_natRulerShiftReg[0*(M+1) + (M+1)-1 -: M+1] = natRulerIn;
				next_spectrumShiftReg[0*(M+1) + (M+1)-1 -: M+1] = spectrumIn;
				if (insert) begin
					next_state = INSERTING;
				end else if (holdout) begin
					next_state = HOLDOUT_BACKUP;
				end
			end
			INSERTING : begin
				for (a = 0; a < n; a = a + 1) begin // upshift
					next_natRulerShiftReg[a*(M+1) + (M+1)-1 -: M+1] =
						a == 0 ? natRulerShiftReg[(n-1)*(M+1) + (M+1)-1 -: M+1] : natRulerShiftReg[(a-1)*(M+1) + (M+1)-1 -: M+1];
					next_spectrumShiftReg[a*(M+1) + (M+1)-1 -: M+1] =
						a == 0 ? spectrumShiftReg[(n-1)*(M+1) + (M+1)-1 -: M+1] : spectrumShiftReg[(a-1)*(M+1) + (M+1)-1 -: M+1];
				end
				if (t > 1) begin
					next_state = INSERTING;
					next_t = t - 1;
				end else begin
					next_natRulerBackup = ONE;
					next_spectrumBackup = ZERO;
					next_state = WRITING;
					next_t = 0;
				end
			end
			HOLDOUT_BACKUP : begin
				next_state = HOLDOUT_DOWNSHIFT;
				next_t = t + 1;
				next_natRulerShiftReg[1*(M+1) + (M+1)-1 -: M+1] = ONE;
				next_spectrumShiftReg[1*(M+1) + (M+1)-1 -: M+1] = ZERO;
				next_natRulerBackup = natRulerShiftReg[1*(M+1) + (M+1)-1 -: M+1];
				next_spectrumBackup = spectrumShiftReg[1*(M+1) + (M+1)-1 -: M+1];
				next_natRulerShiftReg[0*(M+1) + (M+1)-1 -: M+1] = natRulerBackup;
				next_spectrumShiftReg[0*(M+1) + (M+1)-1 -: M+1] = spectrumBackup;
			end
			HOLDOUT_DOWNSHIFT : begin
				next_state = WRITING;
				for (a = 0; a < n; a = a + 1) begin // downshift
					next_natRulerShiftReg[a*(M+1) + (M+1)-1 -: M+1] =
						a == n-1 ? natRulerShiftReg[0*(M+1) + (M+1)-1 -: M+1] : natRulerShiftReg[(a+1)*(M+1) + (M+1)-1 -: M+1];
					next_spectrumShiftReg[a*(M+1) + (M+1)-1 -: M+1] =
						a == n-1 ? spectrumShiftReg[0*(M+1) + (M+1)-1 -: M+1] : spectrumShiftReg[(a+1)*(M+1) + (M+1)-1 -: M+1];
				end
			end
		endcase
	end
	always @(posedge clk) begin
		if (reset) begin
			state <= WRITING;
			t <= 0;
			natRulerBackup <= ONE;
			spectrumBackup <= ZERO;
		end else begin
			state <= next_state;
			t <= next_t;
			natRulerBackup <= next_natRulerBackup;
			spectrumBackup <= next_spectrumBackup;
		end
	end
	always @(posedge clk) begin
		natRulerShiftReg <= next_natRulerShiftReg;
		spectrumShiftReg <= next_spectrumShiftReg;
	end
endmodule
