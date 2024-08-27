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

`default_nettype none
module rightShiftPipelined(clk, reset, out, in, shift);
	parameter WIDTH = 140; // width of input to be shifted
	parameter STAGES = 10; // pipelining stages or latency
	parameter STAGE_POW = 4;
	parameter STAGE_MAX = 1 << STAGE_POW;
	initial begin
		if (STAGES*STAGE_MAX < WIDTH - 1 || STAGE_POW > $clog2(WIDTH) || STAGES < 1) begin
			$error();
		end
	end
	input wire clk;
	input wire reset;
	output wire [WIDTH-1:0] out;
	input wire [WIDTH-1:0] in;
	input wire [$clog2(WIDTH)-1:0] shift;
	reg [STAGES*WIDTH-1:0] stages;
	reg [STAGES*$clog2(WIDTH)-1:0] residual_shifts;
	integer i;
	always @(posedge clk) begin
		if (reset) begin
			stages <= 0;
			residual_shifts <= 0;
		end else begin
			if (|(shift >> STAGE_POW)) begin
				residual_shifts[(STAGES-1)*$clog2(WIDTH) + $clog2(WIDTH)-1 -: $clog2(WIDTH)] <= shift - STAGE_MAX;
				stages[(STAGES-1)*WIDTH + WIDTH-1 -: WIDTH] <= in >> STAGE_MAX;
			end else begin
				residual_shifts[(STAGES-1)*$clog2(WIDTH) + $clog2(WIDTH)-1 -: $clog2(WIDTH)] <= 0;
				stages[(STAGES-1)*WIDTH + WIDTH-1 -: WIDTH] <= in >> shift[STAGE_POW-1:0];
			end
			for (i = STAGES-1; i >= 1; i = i - 1) begin
				if (|(residual_shifts[i*$clog2(WIDTH) + $clog2(WIDTH)-1 -: $clog2(WIDTH)] >> STAGE_POW)) begin
					residual_shifts[(i-1)*$clog2(WIDTH) + $clog2(WIDTH)-1 -: $clog2(WIDTH)] <= residual_shifts[i*$clog2(WIDTH) + $clog2(WIDTH)-1 -: $clog2(WIDTH)] - STAGE_MAX;
					stages[(i-1)*WIDTH + WIDTH-1 -: WIDTH] <= stages[i*WIDTH + WIDTH-1 -: WIDTH] >> STAGE_MAX;
				end else begin
					residual_shifts[(i-1)*$clog2(WIDTH) + $clog2(WIDTH)-1 -: $clog2(WIDTH)] <= 0;
					stages[(i-1)*WIDTH + WIDTH-1 -: WIDTH] <= stages[i*WIDTH + WIDTH-1 -: WIDTH] >> residual_shifts[i*$clog2(WIDTH) + STAGE_POW-1 -: STAGE_POW];
				end
			end
		end
	end
	assign out = stages[0*WIDTH + WIDTH-1 -: WIDTH];
endmodule
