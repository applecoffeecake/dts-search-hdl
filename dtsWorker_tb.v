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
