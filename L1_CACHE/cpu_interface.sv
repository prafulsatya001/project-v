// ============================================================================
// File: cpu_interface.sv
// Description: CPU-facing interface for L1 cache
// ============================================================================
module cpu_interface #(
    parameter int INDEX_BITS     = 6,
    parameter int OFFSET_BITS    = 4,
    parameter int TAG_BITS       = 22,
    parameter int WORD_SEL_BITS  = 2
)(
    input  logic        clk,
    input  logic        rst_n,

    // CPU Request
    input  logic        req_valid,
    input  logic        req_we,
    input  logic [31:0] req_addr,
    input  logic [31:0] req_wdata,
    input  logic [3:0]  req_wstrb,

    // CPU Response
    output logic        resp_valid,
    output logic [31:0] resp_rdata,
    output logic        resp_stall,

    // Internal interface to controller
    output logic        int_req_valid,
    output logic        int_req_we,
    output logic [31:0] int_req_addr,
    output logic [31:0] int_req_wdata,
    output logic [3:0]  int_req_wstrb,
    output logic [INDEX_BITS-1:0]    int_index,
    output logic [TAG_BITS-1:0]      int_tag,
    output logic [WORD_SEL_BITS-1:0] int_word_sel,

    input  logic        int_resp_valid,
    input  logic [31:0] int_resp_rdata,
    input  logic        int_stall
);

    // Address decomposition
    assign int_index    = req_addr[OFFSET_BITS +: INDEX_BITS];
    assign int_tag      = req_addr[32-TAG_BITS +: TAG_BITS];
    assign int_word_sel = req_addr[2 +: WORD_SEL_BITS];

    // Request capture and forwarding
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            int_req_valid <= '0;
            int_req_we    <= '0;
            int_req_addr  <= '0;
            int_req_wdata <= '0;
            int_req_wstrb <= '0;
        end else begin
            if (req_valid && !int_stall) begin
                int_req_valid <= req_valid;
                int_req_we    <= req_we;
                int_req_addr  <= req_addr;
                int_req_wdata <= req_wdata;
                int_req_wstrb <= req_wstrb;
            end else if (!int_stall) begin
                int_req_valid <= '0;
            end
        end
    end

    // Response forwarding
    assign resp_valid = int_resp_valid;
    assign resp_rdata = int_resp_rdata;
    assign resp_stall = int_stall;

endmodule
