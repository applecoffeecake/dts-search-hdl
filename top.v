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
module top(
	sysclk_n, sysclk_p,
	cpu_resetn,
	led,
	FAN_PWM,
	uart_rx_out,
	uart_tx_in
	//btnc, btnd, btnl, btnr, btnu
	);
	input wire sysclk_n, sysclk_p;
	input wire cpu_resetn;
	output wire [7:0] led;
	output wire FAN_PWM;
	output wire uart_rx_out;
	input wire uart_tx_in;
	//input wire btnc, btnd, btnl, btnr, btnu;

	// clocking IP
	wire clk;
	clk_wiz_0 clkConv(
					.clk_in1_n(sysclk_n),
					.clk_in1_p(sysclk_p),
					.clk_out1(clk)
					);

	// two-FF synchronizer
	wire cpu_resetn_sync;
	(* ASYNC_REG = "TRUE" *) reg [1:0] syncRegs;
	always @(posedge clk) begin
		syncRegs <= {cpu_resetn, syncRegs[1]};
	end
	assign cpu_resetn_sync = syncRegs[0];

	reg reset;
	wire internalReset;
	always @(posedge clk) begin
		reset <= ~cpu_resetn_sync|internalReset;
	end

	// simple fan control with internal adc IP
	xadc_wiz_0 xadc(
				.busy_out(),
				.channel_out(),
				.eoc_out(),
				.eos_out(),
				.user_temp_alarm_out(FAN_PWM),
				.alarm_out(),
				.vp_in(1'b0),
				.vn_in(1'b0)
				);

	// slow enable generator for human-time signals
	// slowEnaCtr[i] period is (2^(i+1))*T_clk ns
	// if clk T_clk = 5 ns or f_clk = 200 MHz
	// then slowEnaCtr[27] period is ~1.34 s
	reg [28-1:0] slowEnaCtr;
	always @(posedge clk) begin
		if (reset) begin
			slowEnaCtr <= 0;
		end else begin
			slowEnaCtr <= slowEnaCtr + 1;
		end
	end
	reg slowEna;
	always @(posedge clk) begin
		if (reset) begin
			slowEna <= 0;
		end else begin
			slowEna <= &slowEnaCtr;
		end
	end

	// clock
	// parameter UART_BITDUR = 3472; // for 400 MHz
	// parameter UART_BITDUR = 3038; // for 350 MHz
	parameter UART_BITDUR = 2604; // for 300 MHz
	// parameter UART_BITDUR = 2170; // for 250 MHz
	// parameter UART_BITDUR = 1736; // for 200 MHz
	// parameter UART_BITDUR = 1302; // for 150 MHz
	// parameter UART_BITDUR = 1128; // for 130 MHz
	// parameter UART_BITDUR = 868; // for 100 MHz
	// parameter UART_BITDUR = 347; // for 40 MHz


	parameter HEADER_LEN = 27;
	reg [0:8*HEADER_LEN-1] header;
	always @(posedge clk) begin
		header <= "Mohannad's Kintex 7 |.oo.|\n";
	end

	parameter n = 14; // num blocks
	parameter k = 4; // num marks per block (excluding zero mark
	parameter M = 140; // max mark to consider
	parameter NUM_WORKERS = 8;
	wire [NUM_WORKERS*n*(M+1)-1:0] results;
	wire [NUM_WORKERS-1:0] doneSigs;
	reg anotherOne;
	genvar u;
	generate
		for (u = 0; u < NUM_WORKERS; u = u + 1) begin:unit
			dtsWorkerPipelined #(
								.workerIndex(u),
								.MARKGEN_STAGES(64),
								.BLOCKGEN_THRESH((9+1)*4 + 25),
								.PARMARKS(4),
								.DTSGEN_THRESH(2*100*1000),
								.n(n),
								.k(k),
								.M(M)
								) worker(
								.clk(clk),
								.reset(reset),
								.natRuler(results[n*(M+1)*u + n*(M+1)-1 -: n*(M+1)]),
								.done(doneSigs[u]),
								.anotherOne(anotherOne)
								);
		end
	endgenerate

	//	The following is low-cost selection technique for the result of any "done" worker.
	reg [NUM_WORKERS*n*(M+1)-1:0] resultsB;
	always @(posedge clk) begin
		resultsB <= results;
	end
	reg [NUM_WORKERS-1:0] doneSigsB;
	always @(posedge clk) begin
		if (reset) begin
			doneSigsB <= 0;
		end else begin
			doneSigsB <= doneSigs;
		end
	end
	reg [NUM_WORKERS*n*(M+1)-1:0] resultsShiftReg;
	reg [NUM_WORKERS-1:0] doneSigsShiftReg;
	integer b;
	always @(posedge clk) begin
		for (b = 0; b < NUM_WORKERS; b = b + 1) begin
			if (b == NUM_WORKERS-1) begin
				resultsShiftReg[n*(M+1)*b + n*(M+1)-1 -: n*(M+1)] <= resultsB[n*(M+1)*b + n*(M+1)-1 -: n*(M+1)];
				doneSigsShiftReg[b] <= doneSigsB[b];
			end else begin
				if (doneSigsShiftReg[b+1]) begin
					resultsShiftReg[n*(M+1)*b + n*(M+1)-1 -: n*(M+1)] <= resultsShiftReg[n*(M+1)*(b+1) + n*(M+1)-1 -: n*(M+1)];
					doneSigsShiftReg[b] <= doneSigsShiftReg[b+1];
				end else begin
					resultsShiftReg[n*(M+1)*b + n*(M+1)-1 -: n*(M+1)] <= resultsB[n*(M+1)*b + n*(M+1)-1 -: n*(M+1)];
					doneSigsShiftReg[b] <= doneSigsB[b];
				end
			end
		end
	end
	reg doneSig;
	reg [n*(M+1) - 1 : 0] result;
	always @(posedge clk) begin
		if (reset) begin
			doneSig <= 0;
			result <= 0;
		end else begin
			doneSig <= doneSigsShiftReg[0];
			result <= resultsShiftReg[n*(M+1)*0 + n*(M+1)-1 -: n*(M+1)];
		end
	end

	/*
		Assemble an ascii signal of total width 8*MESS_LEN.
		First part converts a numerical value of width
		NUMER_MESS_LEN into ascii of width 8*NUMER_MESS_LEN.
		Second part adds a header and newline characters.
	*/
	parameter NUMER_MESS_LEN = n*(M+1)+1;
	wire [NUMER_MESS_LEN-1:0] numerMess;
	assign numerMess = {result, doneSig};


	/*
		Transmit message vector containing MESS_LEN bytes
		one byte at a time with the uart.
		Transmission is triggered by asserting startMessage which
		is currently driven by slowEna.

	*/
	reg startByteTx;
	wire readyTx;
	wire startMessage;
	assign startMessage = slowEna;

	reg [NUMER_MESS_LEN-1:0] numerMessB;
	reg [0:7] txByte;

	reg [1:0] state;
	reg [$clog2(NUMER_MESS_LEN+HEADER_LEN)-1:0] i; // char index
	parameter A = 0, B = 1, C = 2, D = 3;
	/*
		A : idle
		B : sending header bytes on readyTx,
			incrementing i
		C : sending numerical message bytes on
			readyTx, incrementing i
	*/
	always @(posedge clk) begin
		case (state)
			A : begin
				numerMessB <= numerMess;
				if (startMessage) begin
					state <= B;
					i <= 0;
					startByteTx <= 1;
				end
			end
			B : begin
				if (readyTx) begin
					if (i == HEADER_LEN-1) begin
						state <= C;
						i <= NUMER_MESS_LEN-1;
					end else begin
						i <= i + 1;
					end
					txByte <= header[8*i +: 8];
				end
			end
			C : begin
				if (readyTx) begin
					if (i == 0) begin
						state <= D;
					end else begin
						i <= i - 1;
					end
					numerMessB <= numerMessB << 1;
					txByte <= numerMessB[NUMER_MESS_LEN-1] ? "1" : "0";
				end
			end
			D : begin
				if (readyTx) begin
					state <= A;
					txByte <= "\n";
					startByteTx <= 0;
				end
			end
		endcase
	end
	uartTx #(.BITDUR(UART_BITDUR)) tx(
									.clk(clk),
									.reset(reset),
									.start(startByteTx),
                                    .data(txByte),
									.ready(readyTx),
									.out(uart_rx_out)
									);

	/*
		Receive byte with uart and store in register.
		Some bytes represent commands which drive signals.
		When such a byte received, the register is cleared
		in the next clock cycle so that command-controlled
		signals are only asserted for one clock cycle.

	*/
	reg [7:0] dataRxReg;
	wire [7:0] dataRx;
	wire readyRx;
	always @(posedge clk) begin
		if (reset) begin
			dataRxReg <= 0;
		end else if (readyRx) begin
			dataRxReg <= dataRx;
		end else if (dataRxReg == "r") begin
			dataRxReg <= 0;
		end else if (dataRxReg == "n") begin
			dataRxReg <= 0;
		end
	end
	assign internalReset = dataRxReg == "r";
	wire anotherOneIn;
	assign anotherOneIn = dataRxReg == "n";
	always @(posedge clk) begin
		anotherOne <= anotherOneIn;
	end

	assign led = dataRxReg;
	uartRx #(.BITDUR(UART_BITDUR)) rx(
									.clk(clk),
									.reset(reset),
									.data(dataRx),
									.ready(readyRx),
									.in(uart_tx_in)
									);

endmodule
