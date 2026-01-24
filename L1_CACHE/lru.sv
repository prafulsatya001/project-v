module lru #(
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
    output logic [WAY_BITS-1:0]    victim_way
);

    logic [WAY_BITS-1:0] next_way [0:NUM_SETS-1];

    assign victim_way = next_way[access_index];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int s = 0; s < NUM_SETS; s++) begin
                next_way[s] <= '0;
            end
        end else if (access_en) begin
            // Pseudo-LRU or Round-Robin style update (based on input logic)
            next_way[access_index] <= access_way + 1'b1;
        end
    end

endmodule