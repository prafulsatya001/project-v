module tag_array #(
    parameter int NUM_SETS = 64,
    parameter int NUM_WAYS = 4,
    parameter int TAG_BITS = 22,
    parameter int INDEX_BITS = $clog2(NUM_SETS),
    parameter int WAY_BITS = (NUM_WAYS > 1) ? $clog2(NUM_WAYS) : 1
)(
    input  logic                  clk,
    input  logic                  we,
    input  logic [INDEX_BITS-1:0] index,
    input  logic [WAY_BITS-1:0]   way,
    input  logic [TAG_BITS-1:0]   tag_in,
    output logic [TAG_BITS-1:0]   tag_out
);

    logic [TAG_BITS-1:0] mem [0:NUM_SETS-1];
    logic [TAG_BITS-1:0] tag_out_r;

    // Note: 'way' input is unused in original logic
    logic unused_way;
    assign unused_way = |way;

    assign tag_out = tag_out_r;

    always_comb begin
        tag_out_r = mem[index];
    end

    always_ff @(posedge clk) begin
        if (we) begin
            mem[index] <= tag_in;
        end
    end

endmodule