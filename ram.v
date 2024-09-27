module ram(clk, we, en, addr, di, dout);
	parameter n = 3;
	parameter M = 19;
	input wire clk;
	input wire we;
	input wire en;
	input wire [$clog2(n)-1:0] addr;
	input wire [M:0] di;
	output reg [M:0] dout;
	reg [M:0] RAM [(1<<($clog2(n)))-1:0];
	always @(posedge clk) begin
		if (en) begin
			if (we) begin
				RAM[addr] <= di;
			end else begin
				dout <= RAM[addr];
			end
		end
	end
endmodule
