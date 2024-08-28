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
module leftShiftPipelinedRecursive(clk, reset, out, in, shift);

	parameter WIDTH = 13; // width of input to be shifted
	parameter STAGES = ($clog2(WIDTH)+1)/2; // stages/latency

	input wire clk;
	input wire reset;

	output wire [WIDTH-1:0] out;
	input wire [WIDTH-1:0] in;
	input wire [$clog2(WIDTH)-1:0] shift;


	wire [(2*STAGES)-1:0] shiftPadded;
	assign shiftPadded = shift;

	reg [STAGES*WIDTH-1:0] stages;
	reg [STAGES*(2*STAGES)-1:0] shifts;

	integer i, j, k, l;
	always @(posedge clk) begin
		if (reset) begin
			stages <= 0;
			shifts <= 0;
		end else begin
			shifts[(STAGES-1)*(2*STAGES) + (2*STAGES)-1 -: (2*STAGES)] <= shiftPadded;
			for (i = STAGES-1; i >= 1; i = i - 1) begin
				shifts[(i-1)*(2*STAGES) + (2*STAGES)-1 -: (2*STAGES)] <= shifts[i*(2*STAGES) + (2*STAGES)-1 -: (2*STAGES)];
			end
			for (i = STAGES; i >= 1; i = i - 1) begin // pipeline stage to assign
				for (j = 1; j <= (1<<(2*(STAGES-(i-1)))); j = j + 1) begin // contiguous segment to be shifted
					for (k = 0; k < (1<<(2*(i-1))); k = k + 1) begin // bit of contiguous segment to be shifted
						if (j*(1<<(2*(i-1))) - 1 - k < WIDTH) begin
							for (l = 0; l < 4; l = l + 1) begin // multiplex four choices of shift
								if (i == STAGES) begin // exception for input stage
									if (shiftPadded[(2*STAGES)-1 - 2*(STAGES-i) -: 2] == l) begin
										if (j > l) begin
											stages[(i-1)*WIDTH + j*(1<<(2*(i-1))) - 1 - k] <= in[(j-l)*(1<<(2*(i-1))) - 1 - k];
										end else begin
											stages[(i-1)*WIDTH + j*(1<<(2*(i-1))) - 1 - k] <= 0;
										end
									end
								end else begin
									if (shifts[i*(2*STAGES) + (2*STAGES)-1 - 2*(STAGES-i) -: 2] == l) begin
										if (j > l) begin
											stages[(i-1)*WIDTH + j*(1<<(2*(i-1))) - 1 - k] <= stages[i*WIDTH + (j-l)*(1<<(2*(i-1))) - 1 - k];
										end else begin
											stages[(i-1)*WIDTH + j*(1<<(2*(i-1))) - 1 - k] <= 0;
										end
									end
								end
							end
						end
					end
				end
			end
		end
	end
	assign out = stages[WIDTH-1 -: WIDTH];
endmodule








