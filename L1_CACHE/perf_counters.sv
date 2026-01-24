module perf_counters(
    input  logic        clk,
    input  logic        rst_n,
    input  logic        hit_pulse,
    input  logic        miss_pulse,
    input  logic        eviction_pulse,
    input  logic        dirty_eviction_pulse,
    input  logic        predictor_hit_pulse,
    input  logic        predictor_miss_pulse,
    input  logic        stale_event_pulse,
    output logic [31:0] hits,
    output logic [31:0] misses,
    output logic [31:0] evictions,
    output logic [31:0] dirty_evictions,
    output logic [31:0] predictor_hits,
    output logic [31:0] predictor_misses,
    output logic [31:0] stale_events
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hits             <= 32'd0;
            misses           <= 32'd0;
            evictions        <= 32'd0;
            dirty_evictions  <= 32'd0;
            predictor_hits   <= 32'd0;
            predictor_misses <= 32'd0;
            stale_events     <= 32'd0;
        end else begin
            if (hit_pulse)            hits <= hits + 1'b1;
            if (miss_pulse)           misses <= misses + 1'b1;
            if (eviction_pulse)       evictions <= evictions + 1'b1;
            if (dirty_eviction_pulse) dirty_evictions <= dirty_evictions + 1'b1;
            if (predictor_hit_pulse)  predictor_hits <= predictor_hits + 1'b1;
            if (predictor_miss_pulse) predictor_misses <= predictor_misses + 1'b1;
            if (stale_event_pulse)    stale_events <= stale_events + 1'b1;
        end
    end

endmodule