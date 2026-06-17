////Button to select channel
module key_filter(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        key_in,
    output reg [2:0]   addr,
    output reg         adc_start
    );
    wire key_p_flag;
    wire key_r_flag;
    key key_inst (
        .clk(clk),
        .rst_n(rst_n),
        .key(key_in),
        .key_p_flag(key_p_flag),
        .key_r_flag(key_r_flag)
    );
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            addr <= 0;
            adc_start <= 0;
        end else begin
            adc_start <= 0;
            if (key_p_flag) begin
                adc_start <= 1;
                if (addr == 3'b111)
                    addr <= 0;
                else
                    addr <= addr + 1;
            end
        end
    end

endmodule
