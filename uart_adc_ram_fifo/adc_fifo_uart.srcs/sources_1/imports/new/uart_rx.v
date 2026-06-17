// uart_rx 1 bit start bit + 8 bit data + 1 bit stop bit
module uart_rx (
    input wire clk,
    input wire rst_n,
    input wire rx,

    output reg [7:0] rx_data,
    output reg rx_done
);

    parameter CLK_FREQ  = 50_000_000;
    parameter BAUD_RATE = 9600;

    parameter baud_cnt_max = CLK_FREQ / BAUD_RATE - 1; 
    parameter half_baud    = baud_cnt_max / 2;

    reg [29:0] baud_cnt;
    reg [3:0]  bit_cnt;
    reg        rx_busy;
    reg        [7:0] r_rxdata;  // for metastability
    // baud rate counter
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            baud_cnt <= 0;
        end else if(rx_busy) begin
            if(baud_cnt == baud_cnt_max)
                baud_cnt <= 0;
            else
                baud_cnt <= baud_cnt + 1;
        end else begin
            baud_cnt <= 0;
        end
    end

    // uart receive control
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            bit_cnt <= 0;
            rx_busy <= 0;
            rx_done <= 0;
            rx_data <= 0;
            r_rxdata <= 0;
        end else begin
            rx_done <= 0;
            if(rx_busy) begin

                // sample at middle of each bit
                if(baud_cnt == half_baud) begin

                    // start bit
                    if(bit_cnt == 0) begin
                        if(rx != 0) begin
                            rx_busy <= 0;
                            bit_cnt <= 0;
                        end
                    end

                    // data bit
                    else if(bit_cnt >= 1 && bit_cnt <= 8) begin
                        r_rxdata[bit_cnt - 1] <= rx;
                    end

                    // stop bit
                    else if(bit_cnt == 9) begin
                        if(rx == 1) begin
                            rx_done <= 1;
                            rx_data <= r_rxdata;
                        end
                    end
                end

                // update bit counter at end of each bit
                if(baud_cnt == baud_cnt_max) begin
                    if(bit_cnt == 9) begin
                        rx_busy <= 0;
                        bit_cnt <= 0;
                    end else begin
                        bit_cnt <= bit_cnt + 1;
                    end
                end

            end else begin
                if(rx == 0) begin 
                    rx_busy <= 1;
                    bit_cnt <= 0;
                end
            end
        end
    end

endmodule
