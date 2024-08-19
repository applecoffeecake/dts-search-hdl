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

`timescale 1 ns / 1 ns
module dtsWorker_tb;
	reg clk;
	reg reset;
	parameter n = 3; // num blocks
	parameter M = 19; // max mark to consider
	wire [n*(M+1) - 1 : 0] res;
	wire doneSig;
	dtsWorker dut(clk, reset, res, doneSig);
	always begin
		clk = 0; #10;
		clk = 1; #10;
	end
	integer cycleCount = 0;
	initial begin
		reset = 0; #20;
		reset = 1; #20;
		repeat (1000*1000) begin
			reset = 0;
			#20;
			$display("%b doneSig %b clock cycles %d", res, doneSig, cycleCount);
			cycleCount = cycleCount + 1;
			if (doneSig) begin
				$display("%d clock cycles", cycleCount);
				$finish;
			end
		end
		$finish;
	end
	/*
	initial begin
		$dumpfile("dtsWorker_tb_dump.vcd");
		$dumpvars(0, dtsWorker_tb);
	end
	*/
endmodule
