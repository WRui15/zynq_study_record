// 12-bit ADC128S102 driver module
// clk = 50MHz
// sclk = 12.5MHz
// method: Linear sequence machine
module adc128s102_driver (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        dout,
    input  wire [2:0]  addr,
    input  wire        start,

    output reg         done,
    output reg         cs,
    output reg         sclk,
    output reg         din,
    output reg [11:0]  data
);

    //==================================================
    // parameter
    //==================================================
    parameter CLK_FRE  = 50_000_000;
    parameter SCLK_FRE = 12_500_000;
    parameter MAX_CNT  = CLK_FRE / (SCLK_FRE * 2); // 2

    //==================================================
    // start rising edge detect, based on clk posedge
    //==================================================
    reg start_d;

    wire start_pulse;

    assign start_pulse = start & ~start_d;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            start_d <= 1'b0;
        else
            start_d <= start;
    end

    //==================================================
    // busy flag
    //==================================================
    reg busy;

    //==================================================
    // SCLK generate
    // idle: sclk = 1
    // busy: toggle sclk
    //==================================================
    reg [2:0] cnt;

    wire sclk_toggle;
    wire sclk_posedge;
    wire sclk_negedge;

    assign sclk_toggle  = busy && (cnt == MAX_CNT - 1);
    assign sclk_posedge = sclk_toggle && (sclk == 1'b0);
    assign sclk_negedge = sclk_toggle && (sclk == 1'b1);

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            cnt  <= 3'd0;
            sclk <= 1'b1;
        end else begin
            if(!busy) begin
                cnt  <= 3'd0;
                sclk <= 1'b1;
            end else begin
                if(cnt == MAX_CNT - 1) begin
                    cnt  <= 3'd0;
                    sclk <= ~sclk;
                end else begin
                    cnt <= cnt + 1'b1;
                end
            end
        end
    end

    //==================================================
    // Linear sequence counter
    // 0 ~ 15 represents 16 SCLK cycles
    //==================================================
    reg [3:0] sclk_sel;

    // receive temp register
    reg [11:0] data_temp;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            busy      <= 1'b0;
            cs        <= 1'b1;
            din       <= 1'b0;
            done      <= 1'b0;
            data      <= 12'd0;
            data_temp <= 12'd0;
            sclk_sel  <= 4'd0;
        end else begin
            done <= 1'b0;

            //==================================================
            // start one conversion
            //==================================================
            if(!busy && start_pulse) begin
                busy      <= 1'b1;
                cs        <= 1'b0;
                din       <= 1'b0;
                sclk_sel  <= 4'd0;
                data_temp <= 12'd0;
            end

            //==================================================
            // DIN changes on SCLK falling edge
            // ADC samples DIN on SCLK rising edge
            //==================================================
            if(busy && sclk_negedge) begin
                case(sclk_sel)
                    4'd0: din <= 1'b0;      // don't care
                    4'd1: din <= 1'b0;      // don't care
                    4'd2: din <= addr[2];   // ADD2
                    4'd3: din <= addr[1];   // ADD1
                    4'd4: din <= addr[0];   // ADD0
                    default: din <= 1'b0;
                endcase
            end

            //==================================================
            // DOUT sampled on SCLK rising edge
            // First four bits are zeros
            // Then DB11 ~ DB0
            //==================================================
            if(busy && sclk_posedge) begin
                case(sclk_sel)
                    4'd4:  data_temp[11] <= dout;
                    4'd5:  data_temp[10] <= dout;
                    4'd6:  data_temp[9]  <= dout;
                    4'd7:  data_temp[8]  <= dout;
                    4'd8:  data_temp[7]  <= dout;
                    4'd9:  data_temp[6]  <= dout;
                    4'd10: data_temp[5]  <= dout;
                    4'd11: data_temp[4]  <= dout;
                    4'd12: data_temp[3]  <= dout;
                    4'd13: data_temp[2]  <= dout;
                    4'd14: data_temp[1]  <= dout;
                    4'd15: data_temp[0]  <= dout;
                    default: ;
                endcase

                //==================================================
                // one frame finished
                //==================================================
                if(sclk_sel == 4'd15) begin
                    data <= {data_temp[11:1], dout};

                    busy     <= 1'b0;
                    cs       <= 1'b1;
                    din      <= 1'b0;
                    done     <= 1'b1;
                    sclk_sel <= 4'd0;
                end else begin
                    sclk_sel <= sclk_sel + 1'b1;
                end
            end
        end
    end

endmodule