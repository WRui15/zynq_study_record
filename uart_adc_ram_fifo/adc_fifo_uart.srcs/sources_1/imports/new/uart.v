// UART TX Module
// 8 data bits, 1 start bit, 1 stop bit, no parity
module uart_tx #(
    parameter CLK_FREQ  = 50_000_000,   // system clock frequency
    parameter BAUD_RATE = 9600          // uart baud rate
)(
    input              clk,
    input              rst_n,

    input      [7:0]   tx_data,         // data to send
    input              tx_en,           // send enable, high for one clk

    output reg         tx,              // uart tx line
    output reg         tx_busy,         // sending flag
    output reg         tx_done          // send done pulse
);

    localparam BAUD_CNT_MAX = CLK_FREQ / BAUD_RATE;

    reg [29:0] baud_cnt;
    reg [3:0]  bit_cnt;
    reg [9:0]  tx_shift;

    wire baud_tick;

    assign baud_tick = (baud_cnt == BAUD_CNT_MAX - 1);

    // baud counter
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            baud_cnt <= 16'd0;
        end else if(tx_busy) begin
            if(baud_tick)
                baud_cnt <= 16'd0;
            else
                baud_cnt <= baud_cnt + 1'b1;
        end else begin
            baud_cnt <= 16'd0;
        end
    end

    // uart transmit control
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            tx       <= 1'b1;              // uart idle is high
            tx_busy  <= 1'b0;
            tx_done  <= 1'b0;
            bit_cnt  <= 4'd0;
            tx_shift <= 10'b1111111111;
        end else begin
            tx_done <= 1'b0;

            // idle state
            if(!tx_busy) begin
                tx      <= 1'b1;
                bit_cnt <= 4'd0;

                if(tx_en) begin
                    // UART frame:
                    // tx_shift[0] = start bit 0
                    // tx_shift[1]~tx_shift[8] = data[0]~data[7]
                    // tx_shift[9] = stop bit 1
                    tx_shift <= {1'b1, tx_data, 1'b0};

                    tx_busy <= 1'b1;
                    tx      <= 1'b0;      // send start bit immediately
                end
            end

            // sending state
            else begin
                if(baud_tick) begin
                    if(bit_cnt == 4'd9) begin
                        tx_busy <= 1'b0;
                        tx_done <= 1'b1;
                        bit_cnt <= 4'd0;
                        tx      <= 1'b1;  // back to idle
                    end else begin
                        bit_cnt <= bit_cnt + 1'b1;
                        tx      <= tx_shift[bit_cnt + 1'b1];
                    end
                end
            end
        end
    end

endmodule