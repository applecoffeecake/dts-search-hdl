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
module uartTx(clk, reset, start, data, ready, out);
	parameter BITDUR = 1736; // (200M cycles/sec) / (115200 bits/sec) = 1736 cycles/bit
	input wire clk;
	input wire reset;
	input wire start;
	input wire [7:0] data;
	output wire ready;
	output reg out;
	/*
		states:
			A : idle, sending idle bit 1
			B : sending start bit 0
			C : sending data bit i
			D : sending stop bit 1
	*/
	parameter A = 0, B = 1, C = 2, D = 3;
	// registers
	reg [1:0] state;
	reg [$clog2(BITDUR)-1:0] bitDurCtr;
	reg [7:0] dataReg;
	reg [2:0] i;
	assign ready = state == A;
	always @(*) begin
		case (state)
			A : out = 1; // idle bit
			B : out = 0; // start bit
			C : out = dataReg[i]; // data bits
			D : out = 1; // stop bit
		endcase
	end
	always @(posedge clk) begin
		if (reset) begin
			state <= 0;
			bitDurCtr <= 0;
			dataReg <= 0;
			i <= 0;
		end else begin
			case (state)
				A : begin
					if (start) begin
						state <= B;
						dataReg <= data;
					end
				end
				B : begin
					if (bitDurCtr == BITDUR-1) begin
						state <= C;
						bitDurCtr <= 0;
					end else begin
						bitDurCtr <= bitDurCtr + 1;
					end
				end
				C : begin
					if (bitDurCtr == BITDUR-1) begin
						if (i == 7) begin
							state <= D;
							bitDurCtr <= 0;
							i <= 0;
						end else begin
							i <= i + 1;
							bitDurCtr <= 0;
						end
					end else begin
						bitDurCtr <= bitDurCtr + 1;
					end
				end
				D : begin
					if (bitDurCtr == BITDUR-1) begin
						state <= A;
						bitDurCtr <= 0;
					end else begin
						bitDurCtr <= bitDurCtr + 1;
					end
				end
			endcase
		end
	end
endmodule
