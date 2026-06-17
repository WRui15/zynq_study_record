//key :Use state machines to debounce
//Active low
module key (
    input wire clk,
    input wire rst_n,
    input wire key,
    output reg key_p_flag,
    output reg key_r_flag
);
    //Three-stage d flip-flop eliminates metastability
    reg sync_d0_key;
    reg sync_d1_key;
    reg r_key;
    wire pedge_key;
    wire nedge_key;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sync_d0_key <= 1;
            sync_d1_key <= 1;
            r_key       <= 1;
        end else begin
        sync_d0_key <= key;
        sync_d1_key <= sync_d0_key;
        r_key       <= sync_d1_key;
        end
    end
    assign pedge_key = ~r_key & sync_d1_key;  // 0 -> 1
    assign nedge_key = r_key & ~sync_d1_key;  // 1 -> 0

    //20ms anti-shake, main frequency 50mhz
    parameter CNT_MAX = 1_000_000 - 1;
    reg [23:0] cnt;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            cnt <= 24'd0;
        end else begin
            if(state == P_FILTER || state == R_FILTER) begin
                if(cnt < CNT_MAX)
                    cnt <= cnt + 1'b1;
                else
                    cnt <= cnt;
            end else begin
                cnt <= 24'd0;
            end
        end
    end

    //Key state machine
    //state0:idle state1:p_filter state2:wait_r state3:r_filter 
    reg [1:0] state;
    localparam IDLE = 2'b00,
               P_FILTER = 2'b01,
               WAIT_R = 2'b10,
               R_FILTER = 2'b11;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= 2'b00;
            key_p_flag <= 0;
            key_r_flag <= 0;
        end else begin
            key_r_flag <= 0;
            key_p_flag <= 0;

            case (state)
                IDLE: begin
                    if (nedge_key) begin
                        state <= P_FILTER;
                    end else 
                        state <= IDLE;
                end
                P_FILTER: begin
                    if(cnt >= CNT_MAX) begin 
                        state <= WAIT_R;
                        key_p_flag <= 1;
                    end else if(pedge_key) begin
                        state <= IDLE;
                    end else begin
                        state <= P_FILTER;
                    end
                end
                WAIT_R: begin
                    if (pedge_key) begin
                        state <= R_FILTER;
                    end else begin
                        state <= WAIT_R;
                    end                   
                end
                R_FILTER: begin
                    if(cnt >= CNT_MAX) begin 
                        state <= IDLE;
                        key_r_flag <= 1;
                    end else if(nedge_key ) begin
                        state <= WAIT_R;
                    end else begin
                        state <= R_FILTER;
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule














