`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Dept. of Computer Science, National Chiao Tung University
// Engineer: Chun-Jen Tsai
// 
// Create Date: 2018/11/01 11:16:50
// Design Name: 
// Module Name: lab6
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: This is a sample circuit to show you how to initialize an SRAM
//              with a pre-defined data file. Hit BTN0/BTN1 let you browse
//              through the data.
// 
// Dependencies: LCD_module, debounce
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module lab7(
  // General system I/O ports
  input  clk,
  input  reset_n,
  input  [3:0] usr_btn,
  output [3:0] usr_led,
  //uart 
  input  uart_rx,
  output uart_tx
);

localparam [2:0] S_MAIN_INIT = 3'b100, 
                           S_MAIN_READ = 3'b001,
                           S_MAIN_CALCULATE = 3'b010, 
                           S_MAIN_REPLY = 3'b011;
localparam [1:0] S_UART_IDLE = 0, 
                           S_UART_WAIT = 1,
                           S_UART_SEND = 2, 
                           S_UART_INCR = 3;
localparam REPLY_LEN  = 169;
// declare system variables
wire read_done, print_done, print_enable;
wire [1:0]  btn_level, btn_pressed;
reg  [1:0]  prev_btn_level;
reg  [2:0]  P, P_next;
reg  [11:0] user_addr;
reg  [7:0]  user_data;
reg add, addr;
reg [17:0] subresult [3:0];
reg [1:0] Q, Q_next;
reg [4:0] c_counter;
reg signed [5:0] read_counter;
reg [4*8-1:0] A_data, B_data;
reg [16*18-1:0] result;
reg [8:0] send_counter;
reg [7:0] data[0:REPLY_LEN-1];
reg [0:REPLY_LEN*8-1] msg = {"\015\012The matrix multiplication result is:\015\012[ 00000, 00000, 00000, 00000 ]\015\012[ 00000, 00000, 00000, 00000 ]\015\012[ 00000, 00000, 00000, 00000 ]\015\012[ 00000, 00000, 00000, 00000 ]\015\012", 8'h0 };

// declare SRAM control signals
wire [10:0] sram_addr;
wire [7:0]  data_in;
wire [7:0]  data_out;
wire        sram_we, sram_en;
integer i, j;

// declare UART signals
wire transmit;
wire received;
wire [7:0] rx_byte;
reg  [7:0] rx_temp;  // if recevied is true, rx_temp latches rx_byte for ONLY ONE CLOCK CYCLE!
wire [7:0] tx_byte;
wire [7:0] echo_key; // keystrokes to be echoed to the terminal
wire is_num_key;
wire is_receiving;
wire is_transmitting;
wire recv_error;

reg [63:0]temp;

assign usr_led = P;
assign read_done = (read_counter == 8 && !addr);
  
debounce btn_db0(
  .clk(clk),
  .btn_input(usr_btn[0]),
  .btn_output(btn_level[0])
);

debounce btn_db1(
  .clk(clk),
  .btn_input(usr_btn[1]),
  .btn_output(btn_level[1])
);

/* The UART device takes a 100MHz clock to handle I/O at 9600 baudrate */
uart uart(
  .clk(clk),
  .rst(~reset_n),
  .rx(uart_rx),
  .tx(uart_tx),
  .transmit(transmit),
  .tx_byte(tx_byte),
  .received(received),
  .rx_byte(rx_byte),
  .is_receiving(is_receiving),
  .is_transmitting(is_transmitting),
  .recv_error(recv_error)
);

//
// Enable one cycle of btn_pressed per each button hit
//
always @(posedge clk) begin
  if (~reset_n)
    prev_btn_level <= 2'b00;
  else
    prev_btn_level <= btn_level;
end

assign btn_pressed = (btn_level & ~prev_btn_level);

// ------------------------------------------------------------------------
// The following code creates an initialized SRAM memory block that
// stores an 1024x8-bit unsigned numbers.
sram ram0(.clk(clk), .we(sram_we), .en(sram_en),
          .addr(sram_addr), .data_i(data_in), .data_o(data_out));

assign sram_we = usr_btn[3]; // In this demo, we do not write the SRAM. However,
                             // if you set 'we' to 0, Vivado fails to synthesize
                             // ram0 as a BRAM -- this is a bug in Vivado.
assign sram_en = (P == S_MAIN_READ); // Enable the SRAM block.
    assign sram_addr = user_addr[11:0];
assign data_in = 8'b0; // SRAM is read-only so we tie inputs to zeros.
// End of the SRAM memory block.
// ------------------------------------------------------------------------

// ------------------------------------------------------------------------
// FSM of the main controller
always @(posedge clk) begin
  if (~reset_n)
    P <= S_MAIN_INIT; // read samples at 000 first
  else 
    P <= P_next;
end

always @(*) begin // FSM next-state logic
  case (P)
    S_MAIN_INIT: // send an address to the SRAM 
      if (btn_pressed[1] == 1) P_next = S_MAIN_READ;
      else P_next = S_MAIN_INIT;
    S_MAIN_READ: // fetch the sample from the SRAM
      if (read_done == 1) P_next = S_MAIN_CALCULATE;
      else P_next = S_MAIN_READ;
    S_MAIN_CALCULATE:
      if (c_counter > 15) P_next = S_MAIN_REPLY;
      else P_next = S_MAIN_READ;
    S_MAIN_REPLY: // wait for a button click
      if (print_done == 1) P_next = S_MAIN_INIT;///test
      else P_next = S_MAIN_REPLY;
    default: P_next = P;
  endcase
end

// End of the main controller
// ------------------------------------------------------------------------

always @(posedge clk) begin
     if (~reset_n)
        addr <= 1;
    else if(P == S_MAIN_INIT || P == S_MAIN_CALCULATE)
        addr <= 1;
    else if (P == S_MAIN_READ)
        addr = ~addr;
end
///User address logic
always @(posedge clk) begin
    if (~reset_n)
        user_addr <= 12'h000;
    else if (P == S_MAIN_INIT)
        user_addr <= 12'h000;
    else if(P == S_MAIN_READ && addr) begin
        if(read_counter < 4)
            user_addr <= c_counter[1:0] + read_counter * 4;//{8'h00,read_counter[1:0]+1,c_counter[1:0]}
        else
            user_addr <= 16 + c_counter[3:2] * 4 + (read_counter - 4); //{8'h01,c_counter[3:2],read_counter[1:0]+1}
    end
end

////READ logic
always @(posedge clk) begin
     if (~reset_n)
        read_counter <= -1;
    else if(P == S_MAIN_INIT || P == S_MAIN_CALCULATE)
        read_counter <= -1;
    else if(P == S_MAIN_READ && !addr)
        read_counter <= read_counter + 1;
end

///read data from the BRAM cell
always @(posedge clk) begin
     if (~reset_n) begin
        A_data <= 0;
        B_data <= 0;
    end
    else if(P == S_MAIN_INIT || P == S_MAIN_CALCULATE) begin
        A_data <= 0;
        B_data <= 0;
    end
    else if(P == S_MAIN_READ && !addr)begin
        if(read_counter <= 4) 
            A_data[(( read_counter-1 ) * 8 + 7) -: 8] <= data_out;
        else if(read_counter <= 8)
            B_data[((read_counter-5) * 8 + 7) -: 8] <= data_out;
    end
end

///c_counter is counter that count what layer the calculating is
always @(posedge clk) begin
    if (~reset_n)
        c_counter <= 0;
    else if(P == S_MAIN_INIT)
        c_counter <= 0;
    else if(P ==  S_MAIN_CALCULATE && add)
        c_counter <= c_counter + 1;
end

//CALCULATE LOGIC
always @(posedge clk) begin
     if (~reset_n) begin
        result <= 0;
        add    <= 0;
    end
    else if(P == S_MAIN_INIT) begin
        result <= 0;
        add    <= 0;
    end
    else if(P ==  S_MAIN_CALCULATE && !add) begin
        subresult[0] <= A_data[31-:8] * B_data[31-:8];
        subresult[1] <= A_data[23-:8] * B_data[23-:8];
        subresult[2] <= A_data[15-:8] * B_data[15-:8];
        subresult[3] <= A_data[7 -:8] * B_data[7 -:8];
        add <= ~add;
    end
    else if(P ==  S_MAIN_CALCULATE && add) begin
        result[(c_counter*18+17) -: 18] <= subresult[0]+subresult[1]+subresult[2]+subresult[3];
        add <= ~add;
    end
end

always @(posedge clk) begin
    if (~reset_n) begin
        for (i = 0; i < REPLY_LEN; i = i + 1)   data[i] = msg[i*8 +: 8];
    end
    else if (P == S_MAIN_REPLY) begin
        for(i = 0; i < 4; i = i + 1) begin
            for(j = 0; j < 4; j = j + 1) begin
                data[42 + i*32 + j*7]   <= "0" + result[(j*4+i)*18+17 -: 2];
                data[42 + i*32 + j*7+1] <= ((result[(j*4+i)*18+15 -: 4] > 9) ? "7" : "0") + result[(j*4+i)*18+15 -: 4];
                data[42 + i*32 + j*7+2] <= ((result[(j*4+i)*18+11 -: 4] > 9) ? "7" : "0") + result[(j*4+i)*18+11 -: 4];
                data[42 + i*32 + j*7+3] <= ((result[(j*4+i)*18+7 -: 4]  > 9) ? "7" : "0") + result[(j*4+i)*18+7  -: 4];
                data[42 + i*32 + j*7+4] <= ((result[(j*4+i)*18+3 -: 4]  > 9) ? "7" : "0") + result[(j*4+i)*18+3  -: 4];
            end
        end
    end
end

// ------------------------------------------------------------------------
// FSM of the controller that sends a string to the UART.
always @(posedge clk) begin
  if (~reset_n) Q <= S_UART_IDLE;
  else Q <= Q_next;
end

always @(*) begin // FSM next-state logic
  case (Q)
    S_UART_IDLE: // wait for the print_string flag
      if (print_enable) Q_next = S_UART_WAIT;
      else Q_next = S_UART_IDLE;
    S_UART_WAIT: // wait for the transmission of current data byte begins
      if (is_transmitting == 1) Q_next = S_UART_SEND;
      else Q_next = S_UART_WAIT;
    S_UART_SEND: // wait for the transmission of current data byte finishes
      if (is_transmitting == 0) Q_next = S_UART_INCR; // transmit next character
      else Q_next = S_UART_SEND;
    S_UART_INCR:
      if (tx_byte == 8'h0) Q_next = S_UART_IDLE; // string transmission ends
      else Q_next = S_UART_WAIT;
  endcase
end

// FSM output logics: UART transmission control signals
assign transmit = (Q_next == S_UART_WAIT ||
                  (print_enable));
// UART send_counter control circuit
always @(posedge clk) begin
    if(P_next == S_MAIN_INIT)
        send_counter <= 0;
    else
        send_counter <= send_counter + (Q_next == S_UART_INCR);
end

assign print_enable = (P == S_MAIN_CALCULATE && P_next == S_MAIN_REPLY);
assign print_done = (tx_byte == 8'h0);
assign tx_byte  = data[send_counter];
// End of the FSM of the print string controller
// ------------------------------------------------------------------------

endmodule