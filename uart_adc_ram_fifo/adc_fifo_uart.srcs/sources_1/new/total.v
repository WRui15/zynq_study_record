module total(
    input  wire clk,
    input  wire rst_n,
    input  wire uart_rx,
    input  wire key0,      // key0 is used to select ADC channel
    input  wire key1,      // key1 is used to trigger data readout from RAM
    input  wire adc_dout,
    output wire adc_cs,
    output wire adc_sclk,
    output wire adc_din,
    output wire uart_tx
    );

    // UART command format: ff a0 xx ff
    // xx = sample count, 8'h00 means 256 samples.
    wire [7:0] uart_data;
    wire       uart_done;

    reg [1:0]  rx_4_cnt;
    reg        uart_cmd_done;
    reg [7:0]  cmd_sample_count;
    reg [31:0] uart_data_shift;
    wire [31:0] uart_frame_next;

    reg [8:0] sample_target;
    reg [8:0] sample_cnt;
    reg [8:0] stored_sample_count;
    reg       sampling;
    reg       sample_adc_start;

    wire [15:0] adc_data;
    wire        adc_change_done;

    wire        ena;
    wire        wea;
    wire [7:0]  addra;
    wire [15:0] ram_dina;

    reg        enb;
    reg [7:0]  addrb;
    wire [15:0] doutb;

    wire key_p_flag;
    wire key_r_flag;

    reg [2:0]  ram_rd_state;
    reg [8:0]  ram_rd_cnt;
    reg [15:0] fifo_din;
    reg        fifo_wr_flag;

    wire [7:0] fifo_dout;
    wire       full;
    wire       almost_full;
    wire       empty;
    wire       almost_empty;
    wire [9:0] rd_data_count;
    wire [8:0] wr_data_count;
    wire       wr_rst_busy;
    wire       rd_rst_busy;
    reg        rd_en;

    reg [2:0] tx_state;
    reg [7:0] uart_tx_data;
    reg       uart_tx_start;
    wire      uart_tx_busy;
    wire      uart_tx_done;

    localparam RD_IDLE  = 3'd0;
    localparam RD_REQ   = 3'd1;
    localparam RD_WAIT1 = 3'd2;
    localparam RD_WAIT2 = 3'd3;
    localparam RD_WRITE = 3'd4;

    localparam TX_IDLE      = 3'd0;
    localparam TX_RD_FIFO   = 3'd1;
    localparam TX_SEND      = 3'd2;
    localparam TX_WAIT_DONE = 3'd3;

    assign ena      = adc_change_done && sampling;
    assign wea      = adc_change_done && sampling;
    assign addra    = sample_cnt[7:0];
    assign ram_dina = adc_data;
    assign uart_frame_next = {uart_data_shift[23:0], uart_data};

    uart_rx uart_rx_inst (
        .clk     (clk),
        .rst_n   (rst_n),
        .rx      (uart_rx),
        .rx_data (uart_data),
        .rx_done (uart_done)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_4_cnt        <= 2'd0;
            uart_cmd_done   <= 1'b0;
            cmd_sample_count <= 8'd0;
            uart_data_shift <= 32'd0;
        end else begin
            uart_cmd_done <= 1'b0;

            if (uart_done) begin
                uart_data_shift <= uart_frame_next;

                if (rx_4_cnt == 2'd3) begin
                    rx_4_cnt <= 2'd0;

                    if (uart_frame_next[31:24] == 8'hff &&
                        uart_frame_next[23:16] == 8'ha0 &&
                        uart_frame_next[7:0]   == 8'hff) begin
                        cmd_sample_count <= uart_frame_next[15:8];
                        uart_cmd_done    <= 1'b1;
                    end
                end else begin
                    rx_4_cnt <= rx_4_cnt + 1'b1;
                end
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sample_target      <= 9'd0;
            sample_cnt         <= 9'd0;
            stored_sample_count <= 9'd0;
            sampling           <= 1'b0;
            sample_adc_start    <= 1'b0;
        end else begin
            sample_adc_start <= 1'b0;

            if (uart_cmd_done) begin
                sample_target       <= (cmd_sample_count == 8'd0) ? 9'd256 : {1'b0, cmd_sample_count};
                sample_cnt          <= 9'd0;
                stored_sample_count <= 9'd0;
                sampling            <= 1'b1;
                sample_adc_start    <= 1'b1;
            end else if (adc_change_done && sampling) begin
                if ((sample_cnt + 1'b1) >= sample_target) begin
                    sampling            <= 1'b0;
                    stored_sample_count <= sample_cnt + 1'b1;
                end else begin
                    sample_cnt      <= sample_cnt + 1'b1;
                    sample_adc_start <= 1'b1;
                end
            end
        end
    end

    digital_voltmeter digital_voltmeter_inst (
        .clk         (clk),
        .rst_n       (rst_n),
        .key         (key0),
        .start       (sample_adc_start),
        .adc_dout    (adc_dout),
        .adc_cs      (adc_cs),
        .adc_sclk    (adc_sclk),
        .adc_din     (adc_din),
        .voltage     (adc_data),
        .change_done (adc_change_done)
    );

    ram_16_256 ram (
        .clka  (clk),
        .ena   (ena),
        .wea   (wea),
        .addra (addra),
        .dina  (ram_dina),
        .clkb  (clk),
        .enb   (enb),
        .addrb (addrb),
        .doutb (doutb)
    );

    key key1_inst(
        .clk        (clk),
        .rst_n      (rst_n),
        .key        (key1),
        .key_p_flag (key_p_flag),
        .key_r_flag (key_r_flag)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ram_rd_state <= RD_IDLE;
            ram_rd_cnt   <= 9'd0;
            enb          <= 1'b0;
            addrb        <= 8'd0;
            fifo_din     <= 16'd0;
            fifo_wr_flag <= 1'b0;
        end else begin
            enb          <= 1'b0;
            fifo_wr_flag <= 1'b0;
            fifo_din     <= 16'd0;

            case (ram_rd_state)
                RD_IDLE: begin
                    ram_rd_cnt <= 9'd0;
                    if (key_p_flag && stored_sample_count != 9'd0 &&
                        !wr_rst_busy && !rd_rst_busy) begin
                        ram_rd_state <= RD_REQ;
                    end
                end

                RD_REQ: begin
                    if (!full && !wr_rst_busy) begin
                        enb          <= 1'b1;
                        addrb        <= ram_rd_cnt[7:0];
                        ram_rd_state <= RD_WAIT1;
                    end
                end

                RD_WAIT1: begin
                    enb          <= 1'b1;
                    ram_rd_state <= RD_WAIT2;
                end

                RD_WAIT2: begin
                    enb          <= 1'b1;
                    ram_rd_state <= RD_WRITE;
                end

                RD_WRITE: begin   
                    if (!full && !wr_rst_busy) begin
                        fifo_din     <= doutb;
                        fifo_wr_flag <= 1'b1;

                        if ((ram_rd_cnt + 1'b1) >= stored_sample_count) begin
                            ram_rd_state <= RD_IDLE;
                        end else begin
                            ram_rd_cnt   <= ram_rd_cnt + 1'b1;
                            ram_rd_state <= RD_REQ;
                        end
                    end
                end

                default: begin
                    ram_rd_state <= RD_IDLE;
                end
            endcase
        end
    end

    fifo_ram_to_uart fifo (
        .rst           (~rst_n),
        .wr_clk        (clk),
        .rd_clk        (clk),
        .din           (fifo_din),
        .wr_en         (fifo_wr_flag),
        .rd_en         (rd_en),
        .dout          (fifo_dout),
        .full          (full),
        .almost_full   (almost_full),
        .empty         (empty),
        .almost_empty  (almost_empty),
        .rd_data_count (rd_data_count),
        .wr_data_count (wr_data_count),
        .wr_rst_busy   (wr_rst_busy),
        .rd_rst_busy   (rd_rst_busy)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_state      <= TX_IDLE;
            rd_en         <= 1'b0;
            uart_tx_start <= 1'b0;
            uart_tx_data  <= 8'd0;
        end else begin
            rd_en         <= 1'b0;
            uart_tx_start <= 1'b0;

            case (tx_state)
                TX_IDLE: begin
                    if (!empty && !rd_rst_busy && !uart_tx_busy)
                        tx_state <= TX_RD_FIFO;
                end

                TX_RD_FIFO: begin
                    if (!empty && !rd_rst_busy && !uart_tx_busy) begin
                        rd_en    <= 1'b1;
                        tx_state <= TX_SEND;
                    end else begin
                        tx_state <= TX_IDLE;
                    end
                end

                TX_SEND: begin
                    if (!uart_tx_busy) begin
                        uart_tx_data  <= fifo_dout;
                        uart_tx_start <= 1'b1;
                        tx_state      <= TX_WAIT_DONE;
                    end
                end

                TX_WAIT_DONE: begin
                    if (uart_tx_done)
                        tx_state <= TX_IDLE;
                end

                default: begin
                    tx_state <= TX_IDLE;
                end
            endcase
        end
    end

    uart_tx uart_tx_inst (
        .clk      (clk),
        .rst_n    (rst_n),
        .tx_data  (uart_tx_data),
        .tx_en    (uart_tx_start),
        .tx       (uart_tx),
        .tx_busy  (uart_tx_busy),
        .tx_done  (uart_tx_done)
    );

endmodule
