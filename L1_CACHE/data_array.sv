module data_array #(
    parameter int NUM_SETS = 64,
    parameter int NUM_WAYS = 4,
    parameter int LINE_BYTES = 16,
    parameter int INDEX_BITS = $clog2(NUM_SETS),
    parameter int WAY_BITS = (NUM_WAYS > 1) ? $clog2(NUM_WAYS) : 1,
    parameter int WORD_SEL_BITS = (LINE_BYTES > 4) ? $clog2(LINE_BYTES/4) : 1
)(
    input  logic                     clk,
    input  logic                     we,
    input  logic [INDEX_BITS-1:0]    index,
    input  logic [WAY_BITS-1:0]      way,
    input  logic [WORD_SEL_BITS-1:0] word_sel,
    input  logic [31:0]              wdata,
    output logic [31:0]              rdata
);

    localparam int WORDS_PER_LINE = LINE_BYTES / 4;

    logic [31:0] mem [0:NUM_SETS-1][0:WORDS_PER_LINE-1];
    logic [31:0] rdata_r;
    
    // Note: 'way' input is unused in original logic (likely direct-mapped slice or specific implementation)
    logic unused_way;
    assign unused_way = |way;

    assign rdata = rdata_r;

    always_comb begin
        rdata_r = mem[index][word_sel];
    end

    always_ff @(posedge clk) begin
        if (we) begin
            mem[index][word_sel] <= wdata;
        end
    end

endmodule