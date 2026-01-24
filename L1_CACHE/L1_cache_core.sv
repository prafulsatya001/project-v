// ============================================================================
// File: l1_cache_core.sv (Top-level integration)
// Description: Integrates all cache modules
// ============================================================================
module l1_cache_core #(
    parameter int NUM_SETS   = 64,
    parameter int NUM_WAYS   = 4,
    parameter int LINE_BYTES = 16
)(
    input  logic        clk,
    input  logic        rst_n,

    // CPU Interface
    input  logic        req_valid,
    input  logic        req_we,
    input  logic [31:0] req_addr,
    input  logic [31:0] req_wdata,
    input  logic [3:0]  req_wstrb,
    output logic        resp_valid,
    output logic [31:0] resp_rdata,
    output logic        resp_stall,

    // Memory Interface
    output logic        mem_req_valid,
    output logic        mem_req_we,
    output logic [31:0] mem_req_addr,
    output logic [31:0] mem_req_wdata,
    input  logic [31:0] mem_resp_rdata,
    input  logic        mem_resp_valid,

    // Performance Monitoring
    output logic        hit_pulse,
    output logic        miss_pulse,
    output logic        eviction_pulse,
    output logic        dirty_eviction_pulse,
    output logic        predictor_hit_pulse,
    output logic        predictor_miss_pulse,
    output logic        stale_event_pulse
);

    localparam int INDEX_BITS     = $clog2(NUM_SETS);
    localparam int OFFSET_BITS    = $clog2(LINE_BYTES);
    localparam int TAG_BITS       = 32 - INDEX_BITS - OFFSET_BITS;
    localparam int WAY_BITS       = (NUM_WAYS > 1) ? $clog2(NUM_WAYS) : 1;
    localparam int WORDS_PER_LINE = LINE_BYTES / 4;
    localparam int WORD_SEL_BITS  = (OFFSET_BITS > 2) ? (OFFSET_BITS - 2) : 1;

    // Internal CPU interface signals
    logic        int_req_valid;
    logic        int_req_we;
    logic [31:0] int_req_addr;
    logic [31:0] int_req_wdata;
    logic [3:0]  int_req_wstrb;
    logic [INDEX_BITS-1:0]    int_index;
    logic [TAG_BITS-1:0]      int_tag;
    logic [WORD_SEL_BITS-1:0] int_word_sel;
    logic        int_resp_valid;
    logic [31:0] int_resp_rdata;
    logic        int_stall;

    // Internal memory interface signals
    logic        ctrl_mem_req;
    logic        ctrl_mem_we;
    logic [31:0] ctrl_mem_addr;
    logic [31:0] ctrl_mem_wdata;
    logic [31:0] ctrl_mem_rdata;
    logic        ctrl_mem_resp_valid;

    // Tag/Data array signals
    logic [TAG_BITS-1:0]      tag_rd [NUM_WAYS];
    logic [31:0]              data_rd [NUM_WAYS];
    logic                     tag_we;
    logic [INDEX_BITS-1:0]    tag_index;
    logic [WAY_BITS-1:0]      tag_way;
    logic [TAG_BITS-1:0]      tag_data;
    logic                     data_we;
    logic [INDEX_BITS-1:0]    data_index;
    logic [WAY_BITS-1:0]      data_way;
    logic [31:0]              data_wdata;
    logic [WORD_SEL_BITS-1:0] array_word_sel;

    // Valid/dirty bits
    logic valid_bits [NUM_SETS][NUM_WAYS];
    logic dirty_bits [NUM_SETS][NUM_WAYS];

    // LRU signals
    logic                lru_update_en;
    logic [WAY_BITS-1:0] lru_access_way;
    logic [WAY_BITS-1:0] lru_victim_way;

    // Predictor signals
    logic                predictor_update_en;
    logic [WAY_BITS-1:0] predictor_actual_way;
    logic [WAY_BITS-1:0] predicted_way;

    // Stale tracker signals
    logic                  stale_access_en;
    logic [INDEX_BITS-1:0] stale_access_index;
    logic [WAY_BITS-1:0]   stale_access_way;

    // Instantiate CPU interface
    cpu_interface #(
        .INDEX_BITS(INDEX_BITS),
        .OFFSET_BITS(OFFSET_BITS),
        .TAG_BITS(TAG_BITS),
        .WORD_SEL_BITS(WORD_SEL_BITS)
    ) cpu_if (
        .clk(clk),
        .rst_n(rst_n),
        .req_valid(req_valid),
        .req_we(req_we),
        .req_addr(req_addr),
        .req_wdata(req_wdata),
        .req_wstrb(req_wstrb),
        .resp_valid(resp_valid),
        .resp_rdata(resp_rdata),
        .resp_stall(resp_stall),
        .int_req_valid(int_req_valid),
        .int_req_we(int_req_we),
        .int_req_addr(int_req_addr),
        .int_req_wdata(int_req_wdata),
        .int_req_wstrb(int_req_wstrb),
        .int_index(int_index),
        .int_tag(int_tag),
        .int_word_sel(int_word_sel),
        .int_resp_valid(int_resp_valid),
        .int_resp_rdata(int_resp_rdata),
        .int_stall(int_stall)
    );

    // Instantiate memory interface
    memory_interface #(
        .WORDS_PER_LINE(WORDS_PER_LINE),
        .WORD_SEL_BITS(WORD_SEL_BITS),
        .OFFSET_BITS(OFFSET_BITS)
    ) mem_if (
        .clk(clk),
        .rst_n(rst_n),
        .mem_req_valid(mem_req_valid),
        .mem_req_we(mem_req_we),
        .mem_req_addr(mem_req_addr),
        .mem_req_wdata(mem_req_wdata),
        .mem_resp_rdata(mem_resp_rdata),
        .mem_resp_valid(mem_resp_valid),
        .ctrl_mem_req(ctrl_mem_req),
        .ctrl_mem_we(ctrl_mem_we),
        .ctrl_mem_addr(ctrl_mem_addr),
        .ctrl_mem_wdata(ctrl_mem_wdata),
        .ctrl_mem_rdata(ctrl_mem_rdata),
        .ctrl_mem_resp_valid(ctrl_mem_resp_valid)
    );

    // Instantiate FSM controller
    cache_controller_fsm #(
        .NUM_SETS(NUM_SETS),
        .NUM_WAYS(NUM_WAYS),
        .LINE_BYTES(LINE_BYTES),
        .INDEX_BITS(INDEX_BITS),
        .OFFSET_BITS(OFFSET_BITS),
        .TAG_BITS(TAG_BITS),
        .WAY_BITS(WAY_BITS),
        .WORDS_PER_LINE(WORDS_PER_LINE),
        .WORD_SEL_BITS(WORD_SEL_BITS)
    ) fsm (
        .clk(clk),
        .rst_n(rst_n),
        .cpu_req_valid(int_req_valid),
        .cpu_req_we(int_req_we),
        .cpu_req_addr(int_req_addr),
        .cpu_req_wdata(int_req_wdata),
        .cpu_req_wstrb(int_req_wstrb),
        .cpu_index(int_index),
        .cpu_tag(int_tag),
        .cpu_word_sel(int_word_sel),
        .cpu_resp_valid(int_resp_valid),
        .cpu_resp_rdata(int_resp_rdata),
        .cpu_stall(int_stall),
        .mem_req(ctrl_mem_req),
        .mem_we(ctrl_mem_we),
        .mem_addr(ctrl_mem_addr),
        .mem_wdata(ctrl_mem_wdata),
        .mem_rdata(ctrl_mem_rdata),
        .mem_resp_valid(ctrl_mem_resp_valid),
        .tag_rd(tag_rd),
        .data_rd(data_rd),
        .tag_we(tag_we),
        .tag_index(tag_index),
        .tag_way(tag_way),
        .tag_data(tag_data),
        .data_we(data_we),
        .data_index(data_index),
        .data_way(data_way),
        .data_wdata(data_wdata),
        .array_word_sel(array_word_sel),
        .tag_rd_in(tag_rd),
        .data_rd_in(data_rd),
        .valid_bits(valid_bits),
        .dirty_bits(dirty_bits),
        .lru_update_en(lru_update_en),
        .lru_access_way(lru_access_way),
        .lru_victim_way(lru_victim_way),
        .predictor_update_en(predictor_update_en),
        .predictor_actual_way(predictor_actual_way),
        .predicted_way(predicted_way),
        .stale_access_en(stale_access_en),
        .stale_access_index(stale_access_index),
        .stale_access_way(stale_access_way),
        .hit_pulse(hit_pulse),
        .miss_pulse(miss_pulse),
        .eviction_pulse(eviction_pulse),
        .dirty_eviction_pulse(dirty_eviction_pulse),
        .predictor_hit_pulse(predictor_hit_pulse),
        .predictor_miss_pulse(predictor_miss_pulse)
    );

    // Generate tag and data arrays
    generate
        for (genvar w = 0; w < NUM_WAYS; w++) begin : gen_arrays
            tag_array #(
                .NUM_SETS(NUM_SETS),
                .NUM_WAYS(NUM_WAYS),
                .TAG_BITS(TAG_BITS)
            ) tags (
                .clk(clk),
                .we(tag_we && (tag_way == w[WAY_BITS-1:0])),
                .index(tag_index),
                .way(w[WAY_BITS-1:0]),
                .tag_in(tag_data),
                .tag_out(tag_rd[w])
            );

            data_array #(
                .NUM_SETS(NUM_SETS),
                .NUM_WAYS(NUM_WAYS),
                .LINE_BYTES(LINE_BYTES)
            ) data (
                .clk(clk),
                .we(data_we && (data_way == w[WAY_BITS-1:0])),
                .index(data_index),
                .way(w[WAY_BITS-1:0]),
                .word_sel(array_word_sel),
                .wdata(data_wdata),
                .rdata(data_rd[w])
            );
        end
    endgenerate

    // Instantiate way predictor
    way_predictor #(
        .NUM_SETS(NUM_SETS),
        .NUM_WAYS(NUM_WAYS)
    ) predictor (
        .clk(clk),
        .rst_n(rst_n),
        .update_en(predictor_update_en),
        .index(int_index),
        .actual_way(predictor_actual_way),
        .predicted_way(predicted_way)
    );

    // Instantiate LRU
    lru #(
        .NUM_SETS(NUM_SETS),
        .NUM_WAYS(NUM_WAYS)
    ) lru_inst (
        .clk(clk),
        .rst_n(rst_n),
        .access_en(lru_update_en),
        .access_index(int_index),
        .access_way(lru_access_way),
        .victim_way(lru_victim_way)
    );

    // Instantiate stale tracker
    stale_tracker #(
        .NUM_SETS(NUM_SETS),
        .NUM_WAYS(NUM_WAYS)
    ) stale (
        .clk(clk),
        .rst_n(rst_n),
        .access_en(stale_access_en),
        .access_index(stale_access_index),
        .access_way(stale_access_way),
        .tick_en(1'b1),
        .stale_threshold(4'd8),
        .stale_event(stale_event_pulse)
    );

endmodule