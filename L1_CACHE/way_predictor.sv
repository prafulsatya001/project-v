module way_predictor #(
    parameter int NUM_SETS = 64,
    parameter int NUM_WAYS = 4,
    parameter int INDEX_BITS = $clog2(NUM_SETS),
    parameter int WAY_BITS = (NUM_WAYS > 1) ? $clog2(NUM_WAYS) : 1
)(
    input  logic                   clk,
    input  logic                   rst_n,
    input  logic                   update_en,
    input  logic [INDEX_BITS-1:0]  index,
    input  logic [WAY_BITS-1:0]    actual_way,
    output logic [WAY_BITS-1:0]    predicted_way
);

    logic [WAY_BITS-1:0] ta_ble [0:NUM_SETS-1];
    logic [WAY_BITS-1:0] predicted_way_r;

    assign predicted_way = predicted_way_r;

    always_comb begin
        predicted_way_r = ta_ble[index];
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < NUM_SETS; i++) begin
                ta_ble[i] <= '0;
            end
        end else if (update_en) begin
            ta_ble[index] <= actual_way;
        end
    end

endmodule