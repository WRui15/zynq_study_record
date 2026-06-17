//This module converts 12-bit input data into millivolts
module hex_to_v(
    input wire clk,
    input wire rst_n,
    input wire done,
    input wire [11:0] data,
    output reg [15:0] voltage,
    output reg change_done
    );
    //Calculation method: 
    //voltage = (data / 4095) * 3.3
    //voltage = [3.3 * 65535 * data /4096] >> 16
    //voltage = 52.8 * data >> 16
    //voltage = 52800 * data >> 16   (mv)

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            voltage <= 0;
            change_done <= 0;
        end else if (done) begin
            voltage <= (52800 * data) >> 16;
            change_done <= 1;
        end else begin
            change_done <= 0;
        end
    end
endmodule
