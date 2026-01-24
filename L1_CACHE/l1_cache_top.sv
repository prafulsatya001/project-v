module l1_cache_top #(
    parameter int NUM_SETS   = 64,
    parameter int NUM_WAYS   = 4,
    parameter int LINE_BYTES = 16
)(
    input  logic        clk,
    input  logic        rst_n,

    // CPU-side request interface
    input  logic        req_valid,
    input  logic        req_we,
    input  logic [31:0] req_addr,
    input  logic [31:0] req_wdata,
    input  logic [3:0]  req_wstrb,

    // CPU-side response interface
    output logic        resp_valid,
    output logic [31:0] resp_rdata,
    output logic        resp_stall,

    // Simple memory interface (hooked up in testbench)
    output logic        mem_req_valid,
    output logic        mem_req_we,
    output logic [31:0] mem_req_addr,
    output logic [31:0] mem_req_wdata,
    input  logic [31:0] mem_resp_rdata,
    input  logic        mem_resp_valid,

    // Performance counters
    output logic [31:0] hits,
    output logic [31:0] misses,
    output logic [31:0] evictions,
    output logic [31:0] dirty_evictions,
    output logic [31:0] predictor_hits,
    output logic [31:0] predictor_misses,
    output logic [31:0] stale_events
);

    logic hit_pulse;
    logic miss_pulse;
    logic eviction_pulse;
    logic dirty_eviction_pulse;
    logic predictor_hit_pulse;
    logic predictor_miss_pulse;
    logic stale_event_pulse;

    // Core instantiation
    l1_cache_core #(
        .NUM_SETS(NUM_SETS),
        .NUM_WAYS(NUM_WAYS),
        .LINE_BYTES(LINE_BYTES)
    ) core (
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
        .mem_req_valid(mem_req_valid),
        .mem_req_we(mem_req_we),
        .mem_req_addr(mem_req_addr),
        .mem_req_wdata(mem_req_wdata),
        .mem_resp_rdata(mem_resp_rdata),
        .mem_resp_valid(mem_resp_valid),
        .hit_pulse(hit_pulse),
        .miss_pulse(miss_pulse),
        .eviction_pulse(eviction_pulse),
        .dirty_eviction_pulse(dirty_eviction_pulse),
        .predictor_hit_pulse(predictor_hit_pulse),
        .predictor_miss_pulse(predictor_miss_pulse),
        .stale_event_pulse(stale_event_pulse)
    );

    // Performance counters instantiation
    perf_counters perf (
        .clk(clk),
        .rst_n(rst_n),
        .hit_pulse(hit_pulse),
        .miss_pulse(miss_pulse),
        .eviction_pulse(eviction_pulse),
        .dirty_eviction_pulse(dirty_eviction_pulse),
        .predictor_hit_pulse(predictor_hit_pulse),
        .predictor_miss_pulse(predictor_miss_pulse),
        .stale_event_pulse(stale_event_pulse),
        .hits(hits),
        .misses(misses),
        .evictions(evictions),
        .dirty_evictions(dirty_evictions),
        .predictor_hits(predictor_hits),
        .predictor_misses(predictor_misses),
        .stale_events(stale_events)
    );

endmodule