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
//
`default_nettype none
module multiDtsWorker(clk, reset, poll, ready, rowAddr, row, anotherOneBroadcast, doneAggregate);

	parameter n = 3; // num blocks
	parameter k = 3; // num marks per block (excluding zero mark
	parameter M = 19; // max mark to consider
	parameter NUM_WORKERS = 3;

	parameter MARKGEN_STAGES = 2;
	parameter BLOCKGEN_THRESH = (9+1)*4 + 100;
	parameter PARMARKS = 1;
	parameter DTSGEN_THRESH = 255*1000;

	// control
	input wire clk;
	input wire reset;
	input wire poll;
	reg pollB;
	always @(posedge clk) begin
		pollB <= poll;
	end
	output reg ready;

	// result RAM access
	input wire [$clog2(n)-1:0] rowAddr;
	output wire [M:0] row;

	// dts worker io
	input wire anotherOneBroadcast;
	output reg doneAggregate;

	// dts workers
	wire [NUM_WORKERS*(M+1)-1:0] workerPorts;
	wire [NUM_WORKERS-1:0] doneSigs;
	genvar u;
	generate
		for (u = 0; u < NUM_WORKERS; u = u + 1) begin:unit
			dtsWorkerPipelinedBlockRAM #(
								.workerIndex(u),
								.MARKGEN_STAGES(MARKGEN_STAGES),
								.BLOCKGEN_THRESH(BLOCKGEN_THRESH),
								.PARMARKS(PARMARKS),
								.DTSGEN_THRESH(DTSGEN_THRESH),
								.n(n),
								.k(k),
								.M(M)
								) worker (
								.clk(clk),
								.reset(reset),
								.rowStream(workerPorts[u*(M+1)+(M+1)-1 -: M+1]),
								.done(doneSigs[u]),
								.anotherOne(anotherOneBroadcast)
								);
		end
	endgenerate
	always @(posedge clk) begin
		if (reset|anotherOneBroadcast) begin
			doneAggregate <= 0;
		end else begin
			doneAggregate <= |doneSigs;
		end
	end

	// assertion of poll triggers selection of worker RAM port
	// with priority given to a done worker
	reg [NUM_WORKERS-1:0] selSig;
//	reg [NUM_WORKERS-1:0] selSigIn;
	integer a;
//	always @(*) begin
//		selSigIn = 1'b1;
//		for (a = 0; a < NUM_WORKERS; a = a + 1) begin
//			if (doneSigs[a]) begin
//				selSigIn = 1'b1 << a;
//			end
//		end
//	end
//	always @(posedge clk) begin
//		if (pollB) begin
//			selSig <= selSigIn;
//		end
//	end
    always @(posedge clk) begin
		if (pollB) begin
			selSig <= doneSigs;
		end
	end

	reg [NUM_WORKERS-1:0] validHose;
	always @(posedge clk) begin
		if (pollB) begin
			validHose <= 0;
		end else begin
			for (a = 0; a < NUM_WORKERS; a = a + 1) begin
				if (a == NUM_WORKERS-1) begin
					validHose[a] <= 1;
				end else begin
					validHose[a] <= validHose[a+1];
				end
			end
		end
	end
	reg [NUM_WORKERS*(M+1)-1:0] streamPath;
	always @(posedge clk) begin
		for (a = 0; a < NUM_WORKERS; a = a + 1) begin
			if (a == NUM_WORKERS-1) begin
				streamPath[a*(M+1)+(M+1)-1 -: M+1] <= workerPorts[a*(M+1)+(M+1)-1 -: M+1];
			end else begin
				if (selSig[a]) begin
					streamPath[a*(M+1)+(M+1)-1 -: M+1] <= workerPorts[a*(M+1)+(M+1)-1 -: M+1];
				end else begin
					streamPath[a*(M+1)+(M+1)-1 -: M+1] <= streamPath[(a+1)*(M+1)+(M+1)-1 -: M+1];
				end
			end
		end
	end
	wire [M:0] selOut;
	wire selReady;
	assign selOut = streamPath[0*(M+1)+(M+1)-1 -: M+1];
	assign selReady = validHose[0];

	// write n words coming from the selected port to RAM
	// once valid. doesn't matter which n as long as
	// contiguous
	parameter WAITING_FOR_SELECTION = 0;
	parameter FILLING_RESULT_RAM = 1;
	parameter HOLDING_RESULT_RAM = 2;

	reg [1:0] state;
	reg [1:0] next_state;
	reg [$clog2(n)-1:0] i;
	reg [$clog2(n)-1:0] next_i;
	reg resultRAM_we;
	reg [$clog2(n)-1:0] resultRAM_addr;
	reg readyIn;
	always @(*) begin
		next_state = state;
		next_i = i;
		resultRAM_we = 0;
		resultRAM_addr = rowAddr;
		readyIn = 0;
		case (state)
			WAITING_FOR_SELECTION : begin
				if (selReady) begin
					next_state = FILLING_RESULT_RAM;
				end
			end
			FILLING_RESULT_RAM : begin
				resultRAM_we = 1;
				resultRAM_addr = i;
				if (i == n-1) begin
					next_state = HOLDING_RESULT_RAM;
					next_i = 0;
				end else begin
					next_i = i + 1;
				end
			end
			HOLDING_RESULT_RAM : begin
				readyIn = 1;
			end
			default : ;
		endcase
	end
	always @(posedge clk) begin
		if (pollB) begin
			state <= WAITING_FOR_SELECTION;
			i <= 0;
			ready <= 0;
		end else begin
			state <= next_state;
			i <= next_i;
			ready <= readyIn;
		end
	end
	ram #(.n(n), .M(M)) resultRAM (
									.clk(clk),
									.we(resultRAM_we),
									.en(1'b1),
									.addr(resultRAM_addr),
									.di(selOut),
									.dout(row)
									);

endmodule
