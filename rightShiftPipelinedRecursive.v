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
module rightShiftPipelinedRecursive(clk, reset, out, in, shift);

	parameter WIDTH = 13; // width of input to be shifted
	parameter STAGES = 2; // stages/latency
	parameter PADDED_WIDTH = 1<<(2*STAGES); // max shift is by 2^(2*STAGES) - 1

	input wire clk;
	input wire reset;

	output wire [WIDTH-1:0] out;
	input wire [WIDTH-1:0] in;
	input wire [$clog2(WIDTH)-1:0] shift;


	wire [PADDED_WIDTH-1:0] inPadded;
	assign inPadded = in;
	wire [(2*STAGES)-1:0] shiftPadded;
	assign shiftPadded = shift;

	reg [STAGES*PADDED_WIDTH-1:0] stages;
	reg [STAGES*(2*STAGES)-1:0] shifts;

	integer i, j, k;
	always @(posedge clk) begin
		if (reset) begin
			stages <= 0;
			shifts <= 0;
		end else begin
			// checked:
			shifts[(STAGES-1)*(2*STAGES) + (2*STAGES)-1 -: (2*STAGES)] <= shiftPadded;
			for (i = STAGES-1; i >= 1; i = i - 1) begin
				shifts[(i-1)*(2*STAGES) + (2*STAGES)-1 -: (2*STAGES)] <= shifts[i*(2*STAGES) + (2*STAGES)-1 -: (2*STAGES)];
			end
			case (shiftPadded[(2*STAGES)-1 -: 2])
				0 : begin
					for (j = 1; j <= (1<<(2*(1))); j = j + 1) begin
						stages[(STAGES-1)*PADDED_WIDTH + j*(1<<(2*(STAGES-1))) - 1 -: (1<<(2*(STAGES-1)))] <=
								inPadded[j*(1<<(2*(STAGES-1))) - 1 -: (1<<(2*(STAGES-1)))];
					end
				end
				1 : begin
					for (j = 1; j <= (1<<(2*(1)))-1; j = j + 1) begin
						stages[(STAGES-1)*PADDED_WIDTH + j*(1<<(2*(STAGES-1))) - 1 -: (1<<(2*(STAGES-1)))] <=
								inPadded[(j+1)*(1<<(2*(STAGES-1))) - 1 -: (1<<(2*(STAGES-1)))];
					end
					stages[(STAGES-1)*PADDED_WIDTH + (1<<(2*(1)))*(1<<(2*(STAGES-1))) - 1 -: (1<<(2*(STAGES-1)))] <= 0;
				end
				2 : begin
					for (j = 1; j <= (1<<(2*(1)))-2; j = j + 1) begin
						stages[(STAGES-1)*PADDED_WIDTH + j*(1<<(2*(STAGES-1))) - 1 -: (1<<(2*(STAGES-1)))] <=
								inPadded[(j+2)*(1<<(2*(STAGES-1))) - 1 -: (1<<(2*(STAGES-1)))];
					end
					stages[(STAGES-1)*PADDED_WIDTH + ((1<<(2*(1)))-1)*(1<<(2*(STAGES-1))) - 1 -: (1<<(2*(STAGES-1)))] <= 0;
					stages[(STAGES-1)*PADDED_WIDTH + (1<<(2*(1)))*(1<<(2*(STAGES-1))) - 1 -: (1<<(2*(STAGES-1)))] <= 0;
				end
				3 : begin
					for (j = 1; j <= (1<<(2*(1)))-3; j = j + 1) begin
						stages[(STAGES-1)*PADDED_WIDTH + j*(1<<(2*(STAGES-1))) - 1 -: (1<<(2*(STAGES-1)))] <=
								inPadded[(j+3)*(1<<(2*(STAGES-1))) - 1 -: (1<<(2*(STAGES-1)))];
					end
					stages[(STAGES-1)*PADDED_WIDTH + ((1<<(2*(1)))-2)*(1<<(2*(STAGES-1))) - 1 -: (1<<(2*(STAGES-1)))] <= 0;
					stages[(STAGES-1)*PADDED_WIDTH + ((1<<(2*(1)))-1)*(1<<(2*(STAGES-1))) - 1 -: (1<<(2*(STAGES-1)))] <= 0;
					stages[(STAGES-1)*PADDED_WIDTH + (1<<(2*(1)))*(1<<(2*(STAGES-1))) - 1 -: (1<<(2*(STAGES-1)))] <= 0;
				end
			endcase
			for (i = STAGES-1; i >= 1; i = i - 1) begin
				case (shifts[i*(2*STAGES) + (2*STAGES)-1 - 2*(STAGES-i) -: 2])
					0 : begin
						for (j = 1; j <= (1<<(2*(STAGES-(i-1)))); j = j + 1) begin
							for (k = 0; k < (1<<(2*(i-1))); k = k + 1) begin
								stages[(i-1)*PADDED_WIDTH + j*(1<<(2*(i-1))) - 1 - k] <=
										stages[i*PADDED_WIDTH + j*(1<<(2*(i-1))) - 1 - k];
							end
						end
					end
					1 : begin
						for (j = 1; j <= (1<<(2*(STAGES-(i-1))))-1; j = j + 1 ) begin
							for (k = 0; k < (1<<(2*(i-1))); k = k + 1) begin
								stages[(i-1)*PADDED_WIDTH + j*(1<<(2*(i-1))) - 1 - k] <=
										stages[i*PADDED_WIDTH + (j+1)*(1<<(2*(i-1))) - 1 - k];
							end
						end
						for (k = 0; k < (1<<(2*(i-1))); k = k + 1) begin
							stages[(i-1)*PADDED_WIDTH + (1<<(2*(STAGES-(i-1))))*(1<<(2*(i-1))) - 1 - k] <= 0;
						end
					end
					2 : begin
						for (j = 1; j <= (1<<(2*(STAGES-(i-1))))-2; j = j + 1 ) begin
							for (k = 0; k < (1<<(2*(i-1))); k = k + 1) begin
								stages[(i-1)*PADDED_WIDTH + j*(1<<(2*(i-1))) - 1 - k] <=
										stages[i*PADDED_WIDTH + (j+2)*(1<<(2*(i-1))) - 1 - k];
							end
						end
						for (k = 0; k < (1<<(2*(i-1))); k = k + 1) begin
							stages[(i-1)*PADDED_WIDTH + ((1<<(2*(STAGES-(i-1))))-1)*(1<<(2*(i-1))) - 1 - k] <= 0;
							stages[(i-1)*PADDED_WIDTH + (1<<(2*(STAGES-(i-1))))*(1<<(2*(i-1))) - 1 - k] <= 0;
						end
					end
					3 : begin
						for (j = 1; j <= (1<<(2*(STAGES-(i-1))))-3; j = j + 1 ) begin
							for (k = 0; k < (1<<(2*(i-1))); k = k + 1) begin
								stages[(i-1)*PADDED_WIDTH + j*(1<<(2*(i-1))) - 1 - k] <=
										stages[i*PADDED_WIDTH + (j+3)*(1<<(2*(i-1))) - 1 - k];
							end
						end
						for (k = 0; k < (1<<(2*(i-1))); k = k + 1) begin
							stages[(i-1)*PADDED_WIDTH + ((1<<(2*(STAGES-(i-1))))-2)*(1<<(2*(i-1))) - 1 - k] <= 0;
							stages[(i-1)*PADDED_WIDTH + ((1<<(2*(STAGES-(i-1))))-1)*(1<<(2*(i-1))) - 1 - k] <= 0;
							stages[(i-1)*PADDED_WIDTH + (1<<(2*(STAGES-(i-1))))*(1<<(2*(i-1))) - 1 - k] <= 0;
						end
					end
				endcase
			end
		end
	end
	assign out = stages[WIDTH-1 -: WIDTH];
endmodule
