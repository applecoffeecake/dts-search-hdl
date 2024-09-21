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
module rightShiftPipelinedRecursive(clk, reset, in, shift, validIn, out, validOut);
	parameter WIDTH = 13; // width of input to be shifted
	parameter STAGES = ($clog2(WIDTH)+1)/2; // stages/latency

	input wire clk;
	input wire reset;

	input wire [WIDTH-1:0] in;
	input wire [$clog2(WIDTH)-1:0] shift;
	input wire validIn;

	output wire [WIDTH-1:0] out;
	output wire validOut;

	reg [STAGES*WIDTH-1:0] stages;
	reg [(STAGES-1)*$clog2(WIDTH)-1:0] shifts;
	reg [STAGES-1:0] valid;

	assign out = stages[WIDTH-1 -: WIDTH];
	assign validOut = valid[0];

	integer i, j, k, l;
	always @(posedge clk) begin
		if (reset) begin
			valid <= 0;
		end else begin
			valid <= {validIn, valid[STAGES-1:1]};
		end
	end
	always @(posedge clk) begin
		for (i = STAGES-2; i >= 0; i = i - 1) begin
			if (i == STAGES-2) begin
				shifts[i*$clog2(WIDTH) + $clog2(WIDTH)-1 -: $clog2(WIDTH)] <= shift;
			end else begin
				shifts[i*$clog2(WIDTH) + $clog2(WIDTH)-1 -: $clog2(WIDTH)] <= shifts[(i+1)*$clog2(WIDTH) + $clog2(WIDTH)-1 -: $clog2(WIDTH)];
			end
		end
		for (i = STAGES-1; i >= 0; i = i - 1) begin // pipeline stage to assign
			for (j = 1; j <= (1<<(2*(STAGES-i))); j = j + 1) begin // contiguous segment to be shifted
				for (k = 0; k < (1<<(2*i)); k = k + 1) begin // bit of contiguous segment to be shifted
					if (j*(1<<(2*i)) - 1 - k < WIDTH) begin
						for (l = 0; l < 4; l = l + 1) begin // multiplex four choices of shift
							if (i == STAGES-1) begin // exception for input stage
								if (((shift>>(2*i))&2'b11) == l) begin
									if ((j+l)*(1<<(2*i)) - 1 - k < WIDTH) begin
										stages[i*WIDTH + j*(1<<(2*i)) - 1 - k] <= in[(j+l)*(1<<(2*i)) - 1 - k];
									end else begin
										stages[i*WIDTH + j*(1<<(2*i)) - 1 - k] <= 0;
									end
								end
							end else begin
								if (((shifts[i*$clog2(WIDTH) + $clog2(WIDTH)-1 -: $clog2(WIDTH)]>>(2*i))&2'b11) == l) begin
									if ((j+l)*(1<<(2*i)) - 1 - k < WIDTH) begin
										stages[i*WIDTH + j*(1<<(2*i)) - 1 - k] <= stages[(i+1)*WIDTH + (j+l)*(1<<(2*i)) - 1 - k];
									end else begin
										stages[i*WIDTH + j*(1<<(2*i)) - 1 - k] <= 0;
									end
								end
							end
						end
					end
				end
			end
		end
	end
endmodule
