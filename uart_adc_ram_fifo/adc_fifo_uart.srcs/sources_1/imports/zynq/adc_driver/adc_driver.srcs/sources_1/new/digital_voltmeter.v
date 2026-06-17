module digital_voltmeter(
    input wire clk,
    input wire rst_n,
    input wire key,
    input wire adc_dout,
    input wire start,
    output wire adc_cs,
    output wire adc_sclk,
    output wire adc_din,
    output wire [15:0] voltage,
    output wire change_done
    );
    wire [2:0] addr;
    key_filter channel_select (
        .clk(clk),
        .rst_n(rst_n),
        .key_in(key),
        .addr(addr)
    );

    wire done;
    wire [11:0] data;
    adc128s102_driver adc_driver (
        .clk(clk),
        .rst_n(rst_n),
        .dout(adc_dout),
        .addr(addr),
        .start(start),
        .done(done),
        .cs(adc_cs),
        .sclk(adc_sclk),
        .din(adc_din),
        .data(data)
    );
    hex_to_v hex_to_mv (
        .clk(clk),
        .rst_n(rst_n),
        .done(done),
        .data(data),
        .voltage(voltage),
        .change_done(change_done)
    );
    

   
endmodule
