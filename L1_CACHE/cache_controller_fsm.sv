// ============================================================================
// File: cache_controller_fsm.sv
// Description: Main cache controller state machine
// ============================================================================
module cache_controller_fsm #(
    parameter int NUM_SETS      = 64,
    parameter int NUM_WAYS      = 4,
    parameter int LINE_BYTES    = 16,
    parameter int INDEX_BITS    = 6,
    parameter int OFFSET_BITS   = 4,
    parameter int TAG_BITS      = 22,
    parameter int WAY_BITS      = 2,
    parameter int WORDS_PER_LINE = 4,
    parameter int WORD_SEL_BITS = 2
)(
    input  logic        clk,
    input  logic        rst_n,

    // CPU interface
    input  logic        cpu_req_valid,
    input  logic        cpu_req_we,
    input  logic [31:0] cpu_req_addr,
    input  logic [31:0] cpu_req_wdata,
    input  logic [3:0]  cpu_req_wstrb,
    input  logic [INDEX_BITS-1:0]    cpu_index,
    input  logic [TAG_BITS-1:0]      cpu_tag,
    input  logic [WORD_SEL_BITS-1:0] cpu_word_sel,

    output logic        cpu_resp_valid,
    output logic [31:0] cpu_resp_rdata,
    output logic        cpu_stall,

    // Memory interface
    output logic        mem_req,
    output logic        mem_we,
    output logic [31:0] mem_addr,
    output logic [31:0] mem_wdata,
    input  logic [31:0] mem_rdata,
    input  logic        mem_resp_valid,

    // Tag/Data array interfaces
    output logic [TAG_BITS-1:0]      tag_rd [NUM_WAYS],
    output logic [31:0]              data_rd [NUM_WAYS],
    output logic                     tag_we,
    output logic [INDEX_BITS-1:0]    tag_index,
    output logic [WAY_BITS-1:0]      tag_way,
    output logic [TAG_BITS-1:0]      tag_data,
    output logic                     data_we,
    output logic [INDEX_BITS-1:0]    data_index,
    output logic [WAY_BITS-1:0]      data_way,
    output logic [31:0]              data_wdata,
    output logic [WORD_SEL_BITS-1:0] array_word_sel,
    input  logic [TAG_BITS-1:0]      tag_rd_in [NUM_WAYS],
    input  logic [31:0]              data_rd_in [NUM_WAYS],

    // Metadata arrays
    output logic valid_bits [NUM_SETS][NUM_WAYS],
    output logic dirty_bits [NUM_SETS][NUM_WAYS],

    // LRU interface
    output logic                lru_update_en,
    output logic [WAY_BITS-1:0] lru_access_way,
    input  logic [WAY_BITS-1:0] lru_victim_way,

    // Way predictor interface
    output logic                predictor_update_en,
    output logic [WAY_BITS-1:0] predictor_actual_way,
    input  logic [WAY_BITS-1:0] predicted_way,

    // Stale tracker interface
    output logic                stale_access_en,
    output logic [INDEX_BITS-1:0] stale_access_index,
    output logic [WAY_BITS-1:0] stale_access_way,

    // Performance monitoring
    output logic hit_pulse,
    output logic miss_pulse,
    output logic eviction_pulse,
    output logic dirty_eviction_pulse,
    output logic predictor_hit_pulse,
    output logic predictor_miss_pulse
);

    // State machine states
    typedef enum logic [2:0] {
        S_IDLE            = 3'd0,
        S_LOOKUP          = 3'd1,
        S_MISS_SELECT     = 3'd2,
        S_WRITEBACK_REQ   = 3'd3,
        S_WRITEBACK_WAIT  = 3'd4,
        S_REFILL_REQ      = 3'd5,
        S_REFILL_WAIT     = 3'd6,
        S_RESPOND         = 3'd7
    } state_t;

    state_t state;

    // Current request registers
    logic [31:0] cur_req_addr;
    logic        cur_req_we;
    logic [31:0] cur_req_wdata;
    logic [3:0]  cur_req_wstrb;

    logic [INDEX_BITS-1:0]    cur_index;
    logic [TAG_BITS-1:0]      cur_tag;
    logic [WORD_SEL_BITS-1:0] cur_word_sel;

    logic [WAY_BITS-1:0] active_way;

    // Miss/refill tracking
    logic [WAY_BITS-1:0]             victim_way_r;
    logic [TAG_BITS-1:0]             victim_tag_r;
    logic [31:0]                     victim_addr_r;
    logic                            victim_dirty_r;
    logic [$clog2(WORDS_PER_LINE):0] transfer_cnt;
    logic                            resp_from_fill;

    // Hit/miss detection signals
    logic                hit_found;
    logic [WAY_BITS-1:0] hit_way;
    logic                victim_valid;
    logic                victim_dirty;

    assign cpu_stall = (state != S_IDLE);
    assign tag_rd = tag_rd_in;
    assign data_rd = data_rd_in;

    // Instantiate hit/miss logic
    hit_miss_logic #(
        .NUM_SETS(NUM_SETS),
        .NUM_WAYS(NUM_WAYS),
        .TAG_BITS(TAG_BITS),
        .INDEX_BITS(INDEX_BITS),
        .WAY_BITS(WAY_BITS)
    ) hit_miss (
        .clk(clk),
        .rst_n(rst_n),
        .lookup_en(state == S_LOOKUP),
        .lookup_index(cur_index),
        .lookup_tag(cur_tag),
        .tag_rd(tag_rd_in),
        .valid_bits(valid_bits),
        .dirty_bits(dirty_bits),
        .hit_found(hit_found),
        .hit_way(hit_way),
        .miss_found(),
        .lru_victim_way(lru_victim_way),
        .victim_way(/* connected in S_MISS_SELECT */),
        .victim_valid(victim_valid),
        .victim_dirty(victim_dirty)
    );

    // Utility function
    function automatic logic [31:0] mask_from_strb(logic [3:0] strb);
        return {{8{strb[3]}}, {8{strb[2]}}, {8{strb[1]}}, {8{strb[0]}}};
    endfunction

    // Main state machine
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state                <= S_IDLE;
            cur_req_addr         <= '0;
            cur_req_we           <= '0;
            cur_req_wdata        <= '0;
            cur_req_wstrb        <= '0;
            array_word_sel       <= '0;
            cpu_resp_valid       <= '0;
            cpu_resp_rdata       <= '0;
            tag_we               <= '0;
            data_we              <= '0;
            mem_req              <= '0;
            mem_we               <= '0;
            mem_addr             <= '0;
            mem_wdata            <= '0;
            hit_pulse            <= '0;
            miss_pulse           <= '0;
            eviction_pulse       <= '0;
            dirty_eviction_pulse <= '0;
            predictor_hit_pulse  <= '0;
            predictor_miss_pulse <= '0;
            predictor_update_en  <= '0;
            lru_update_en        <= '0;
            stale_access_en      <= '0;
            transfer_cnt         <= '0;
            victim_way_r         <= '0;
            victim_tag_r         <= '0;
            victim_addr_r        <= '0;
            victim_dirty_r       <= '0;
            active_way           <= '0;
            resp_from_fill       <= '0;

            for (int si = 0; si < NUM_SETS; si++) begin
                for (int wi = 0; wi < NUM_WAYS; wi++) begin
                    valid_bits[si][wi] <= '0;
                    dirty_bits[si][wi] <= '0;
                end
            end
        end else begin
            // Clear one-cycle signals
            cpu_resp_valid       <= '0;
            tag_we               <= '0;
            data_we              <= '0;
            mem_req              <= '0;
            hit_pulse            <= '0;
            miss_pulse           <= '0;
            eviction_pulse       <= '0;
            dirty_eviction_pulse <= '0;
            predictor_hit_pulse  <= '0;
            predictor_miss_pulse <= '0;
            predictor_update_en  <= '0;
            lru_update_en        <= '0;
            stale_access_en      <= '0;
            data_index           <= cur_index;
            tag_index            <= cur_index;

            unique case (state)
                S_IDLE: begin
                    if (cpu_req_valid) begin
                        cur_req_addr   <= cpu_req_addr;
                        cur_req_we     <= cpu_req_we;
                        cur_req_wdata  <= cpu_req_wdata;
                        cur_req_wstrb  <= cpu_req_wstrb;
                        cur_index      <= cpu_index;
                        cur_tag        <= cpu_tag;
                        cur_word_sel   <= cpu_word_sel;
                        array_word_sel <= cpu_word_sel;
                        state          <= S_LOOKUP;
                    end
                end

                S_LOOKUP: begin
                    if (hit_found) begin
                        // Cache Hit
                        active_way <= hit_way;

                        predictor_update_en  <= 1'b1;
                        predictor_actual_way <= hit_way;
                        predictor_hit_pulse  <= (hit_way == predicted_way);
                        predictor_miss_pulse <= (hit_way != predicted_way);

                        lru_update_en  <= 1'b1;
                        lru_access_way <= hit_way;

                        stale_access_en    <= 1'b1;
                        stale_access_index <= cur_index;
                        stale_access_way   <= hit_way;

                        hit_pulse <= 1'b1;

                        if (cur_req_we) begin
                            data_index     <= cur_index;
                            data_way       <= hit_way;
                            array_word_sel <= cur_word_sel;
                            data_wdata     <= (data_rd_in[hit_way] & ~mask_from_strb(cur_req_wstrb)) |
                                              (cur_req_wdata & mask_from_strb(cur_req_wstrb));
                            data_we        <= 1'b1;
                            dirty_bits[cur_index][hit_way] <= 1'b1;
                            cpu_resp_rdata <= '0;
                        end else begin
                            cpu_resp_rdata <= data_rd_in[hit_way];
                        end

                        resp_from_fill <= '0;
                        state          <= S_RESPOND;
                    end else begin
                        miss_pulse <= 1'b1;
                        state      <= S_MISS_SELECT;
                    end
                end

                S_MISS_SELECT: begin
                    logic [WAY_BITS-1:0] sel_way;
                    logic                found_invalid;

                    sel_way       = lru_victim_way;
                    found_invalid = '0;

                    for (int inv_idx = 0; inv_idx < NUM_WAYS; inv_idx++) begin
                        if (!valid_bits[cur_index][inv_idx] && !found_invalid) begin
                            sel_way       = inv_idx[WAY_BITS-1:0];
                            found_invalid = 1'b1;
                        end
                    end

                    victim_way_r   <= sel_way;
                    victim_tag_r   <= tag_rd_in[sel_way];
                    victim_addr_r  <= {tag_rd_in[sel_way], cur_index, {OFFSET_BITS{1'b0}}};
                    victim_dirty_r <= valid_bits[cur_index][sel_way] && dirty_bits[cur_index][sel_way];
                    transfer_cnt   <= '0;

                    if (valid_bits[cur_index][sel_way]) begin
                        eviction_pulse <= 1'b1;
                        if (dirty_bits[cur_index][sel_way]) begin
                            dirty_eviction_pulse <= 1'b1;
                        end
                    end

                    if (valid_bits[cur_index][sel_way] && dirty_bits[cur_index][sel_way]) begin
                        array_word_sel <= '0;
                        state          <= S_WRITEBACK_REQ;
                    end else begin
                        array_word_sel <= '0;
                        state          <= S_REFILL_REQ;
                    end
                end

                S_WRITEBACK_REQ: begin
                    array_word_sel <= transfer_cnt[WORD_SEL_BITS-1:0];
                    mem_req        <= 1'b1;
                    mem_we         <= 1'b1;
                    mem_addr       <= victim_addr_r + (transfer_cnt << 2);
                    mem_wdata      <= data_rd_in[victim_way_r];
                    state          <= S_WRITEBACK_WAIT;
                end

                S_WRITEBACK_WAIT: begin
                    if (mem_resp_valid) begin
                        if (transfer_cnt == WORDS_PER_LINE - 1) begin
                            transfer_cnt <= '0;
                            state        <= S_REFILL_REQ;
                        end else begin
                            transfer_cnt <= transfer_cnt + 1'b1;
                            state        <= S_WRITEBACK_REQ;
                        end
                    end
                end

                S_REFILL_REQ: begin
                    array_word_sel <= transfer_cnt[WORD_SEL_BITS-1:0];
                    mem_req        <= 1'b1;
                    mem_we         <= '0;
                    mem_addr       <= {cur_req_addr[31:OFFSET_BITS], {OFFSET_BITS{1'b0}}} + (transfer_cnt << 2);
                    state          <= S_REFILL_WAIT;
                end

                S_REFILL_WAIT: begin
                    if (mem_resp_valid) begin
                        data_index     <= cur_index;
                        data_way       <= victim_way_r;
                        array_word_sel <= transfer_cnt[WORD_SEL_BITS-1:0];
                        data_wdata     <= mem_rdata;
                        data_we        <= 1'b1;

                        if (transfer_cnt == WORDS_PER_LINE - 1) begin
                            transfer_cnt <= '0;
                            tag_index    <= cur_index;
                            tag_way      <= victim_way_r;
                            tag_data     <= cur_tag;
                            tag_we       <= 1'b1;

                            valid_bits[cur_index][victim_way_r] <= 1'b1;
                            dirty_bits[cur_index][victim_way_r] <= cur_req_we;

                            active_way     <= victim_way_r;
                            resp_from_fill <= 1'b1;

                            lru_update_en  <= 1'b1;
                            lru_access_way <= victim_way_r;

                            stale_access_en    <= 1'b1;
                            stale_access_index <= cur_index;
                            stale_access_way   <= victim_way_r;

                            state          <= S_RESPOND;
                            array_word_sel <= cur_word_sel;
                        end else begin
                            transfer_cnt <= transfer_cnt + 1'b1;
                            state        <= S_REFILL_REQ;
                        end
                    end
                end

                S_RESPOND: begin
                    predictor_update_en  <= 1'b1;
                    predictor_actual_way <= active_way;

                    if (resp_from_fill) begin
                        predictor_hit_pulse  <= (active_way == predicted_way);
                        predictor_miss_pulse <= (active_way != predicted_way);
                    end

                    if (cur_req_we) begin
                        array_word_sel <= cur_word_sel;
                        data_index     <= cur_index;
                        data_way       <= active_way;
                        data_wdata     <= (data_rd_in[active_way] & ~mask_from_strb(cur_req_wstrb)) |
                                          (cur_req_wdata & mask_from_strb(cur_req_wstrb));
                        data_we        <= 1'b1;
                        dirty_bits[cur_index][active_way] <= 1'b1;
                        cpu_resp_rdata <= '0;
                    end else begin
                        array_word_sel <= cur_word_sel;
                        cpu_resp_rdata <= data_rd_in[active_way];
                    end

                    cpu_resp_valid <= 1'b1;
                    resp_from_fill <= '0;
                    state          <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule