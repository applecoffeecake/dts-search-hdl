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
	parameter UART_BITDUR = 2604; // for 300 MHz
	// parameter UART_BITDUR = 2170; // for 250 MHz
	// parameter UART_BITDUR = 1736; // for 200 MHz
	// parameter UART_BITDUR = 1302; // for 150 MHz
	// parameter UART_BITDUR = 868; // for 100 MHz


	parameter HEADER_LEN = 28;
	reg [0:8*HEADER_LEN-1] header;
	always @(posedge clk) begin
		header <= "Mohannad's XC7K325T (.oo.):\n";
	end


	/*
		BLOCKGEN_THRESH and DTSGEN_THRESH have to be carefully tuned
		to get good results.
		When DTSGEN_THRESH is too small, it will be detected by seeing
		that the DTS doesn't populate to near completion before restarting.
		This can be observed by outputing the i value.
		When DTSGEN_THRESH is too large, too much time might be wasted in
		a cyclic pattern of being stuck on the same hopeless partial
		DTS which the backtracking move is not strong enough to escape.
		When BLOCKGEN_THRESH is too small, the DTS will simply not
		populate and can be seen by outputing j. However, it is NOT beneficial
		to have PARMARKS or PARMARKS*BLOCKGEN_THRESH be too large!
		It is better to backtrack if marks sampled from the specified
		distributions don't fit than it is to force any mark to fit.
		Marks sampled from the specified distributions are more likely
		to allow eventual completion of the entire DTS.
	*/


	parameter n = 14; // num blocks
	parameter k = 4; // num marks per block (excluding zero mark
	parameter M = 140; // max mark to consider
	parameter NUM_WORKERS = 48;

	parameter MARKGEN_STAGES = 2;
	parameter BLOCKGEN_THRESH = (9+1)*4 + 100-4;
	parameter PARMARKS = 1;
	// parameter BLOCKGEN_THRESH = (9+1)*4 + 16;
	// parameter PARMARKS = 5;
	parameter DTSGEN_THRESH = 200*1000;

	wire poll;
	assign poll = slowEna;
	wire readyPoll;
	reg [$clog2(n+1)-1:0] rowAddr;
	wire [M:0] row;
	reg anotherOne;
	wire doneSig;
	multiDtsWorker #(
						.NUM_WORKERS(NUM_WORKERS),
						.MARKGEN_STAGES(MARKGEN_STAGES),
						.BLOCKGEN_THRESH(BLOCKGEN_THRESH),
						.PARMARKS(PARMARKS),
						.DTSGEN_THRESH(DTSGEN_THRESH),
						.n(n),
						.k(k),
						.M(M)
					) main (
						clk,
						reset,
						poll,
						readyPoll,
						rowAddr,
						row,
						anotherOne,
						doneSig
					);

	wire readyTx;
	reg sendByte;
	reg [M:0] rowB;
	reg [0:7] txByte;
	reg [2:0] state;

	parameter IDLE = 0;
	parameter SENDING_HEADER = 1;
	parameter WAITING_ON_POLL = 2;
	parameter SENDING_ROW = 3;
	parameter READING_ROW = 4;
	parameter SENDING_DONE_STATUS = 5;
	parameter SENDING_NEWLINE = 6;
	parameter BUFFERING_ROW = 7;

	reg [$clog2(M+1+HEADER_LEN)-1:0] i; // char index

	always @(posedge clk) begin
		case (state)
			IDLE : begin
				if (poll) begin
					state <= SENDING_HEADER;
					sendByte <= 1;
					i <= 0;
				end
			end
			SENDING_HEADER : begin
				if (readyTx) begin
					if (i == HEADER_LEN - 1) begin
						state <= WAITING_ON_POLL;
						rowAddr <= 0;
					end else begin
						i <= i + 1;
					end
					txByte <= header[8*i +: 8];
				end
			end
			WAITING_ON_POLL : begin
				sendByte <= 0;
				if (readyPoll) begin
					state <= READING_ROW;
				end
			end
			READING_ROW : begin
				if (rowAddr == n) begin
					state <= SENDING_DONE_STATUS;
					sendByte <= 1;
				end else begin
					rowAddr <= rowAddr + 1;
					state <= BUFFERING_ROW;
					sendByte <= 0;
				end
			end
			BUFFERING_ROW : begin
				rowB <= row;
				state <= SENDING_ROW;
				sendByte <= 1;
				i <= 0;
			end
			SENDING_ROW : begin
				if (readyTx) begin
					if (i == M) begin
						state <= READING_ROW;
					end else begin
						i <= i + 1;
					end
					rowB <= rowB << 1;
					txByte <= rowB[M] ? "1" : "0";
				end
			end
			SENDING_DONE_STATUS : begin
				if (readyTx) begin
					state <= SENDING_NEWLINE;
					txByte <= doneSig ? "1" : "0";
				end
			end
			SENDING_NEWLINE : begin
				if (readyTx) begin
					state <= IDLE;
					txByte <= "\n";
					sendByte <= 0;
				end
			end
		endcase
	end
	uartTx #(.BITDUR(UART_BITDUR)) tx(
									.clk(clk),
									.reset(reset),
									.start(sendByte),
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

