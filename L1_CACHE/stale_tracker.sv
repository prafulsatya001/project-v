module stale_tracker #(
    parameter int NUM_SETS = 64,
    parameter int NUM_WAYS = 4,
    parameter int INDEX_BITS = $clog2(NUM_SETS),
    parameter int WAY_BITS = (NUM_WAYS > 1) ? $clog2(NUM_WAYS) : 1
)(
    input  logic                   clk,
    input  logic                   rst_n,
    input  logic                   access_en,
    input  logic [INDEX_BITS-1:0]  access_index,
    input  logic [WAY_BITS-1:0]    access_way,
    input  logic                   tick_en,
    input  logic [3:0]             stale_threshold,
    output logic                   stale_event
);

    logic [3:0] counters [0:NUM_SETS-1][0:NUM_WAYS-1];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stale_event <= 1'b0;
            for (int si = 0; si < NUM_SETS; si++) begin
                for (int wi = 0; wi < NUM_WAYS; wi++) begin
                    counters[si][wi] <= 4'd0;
                end
            end
        end else begin
            stale_event <= 1'b0;
            
            if (tick_en) begin
                for (int si = 0; si < NUM_SETS; si++) begin
                    for (int wi = 0; wi < NUM_WAYS; wi++) begin
                        if (counters[si][wi] != 4'hF) begin
                            // Check threshold
                            if ((stale_threshold != 4'd0) && (counters[si][wi] >= stale_threshold - 1)) begin
                                stale_event <= 1'b1;
                            end
                            // Increment saturation counter
                            counters[si][wi] <= counters[si][wi] + 1'b1;
                        end
                    end
                end
            end
            
            // Reset counter on access
            if (access_en) begin
                counters[access_index][access_way] <= 4'd0;
            end
        end
    end

endmodule