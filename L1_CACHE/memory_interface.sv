// ============================================================================
// File: memory_interface.sv
// Description: Memory-facing interface for cache refills and writebacks
// ============================================================================
module memory_interface #(
    parameter int WORDS_PER_LINE = 4,
    parameter int WORD_SEL_BITS  = 2,
    parameter int OFFSET_BITS    = 4
)(
    input  logic        clk,
    input  logic        rst_n,

    // Memory bus
    output logic        mem_req_valid,
    output logic        mem_req_we,
    output logic [31:0] mem_req_addr,
    output logic [31:0] mem_req_wdata,
    input  logic [31:0] mem_resp_rdata,
    input  logic        mem_resp_valid,

    // Controller interface
    input  logic        ctrl_mem_req,
    input  logic        ctrl_mem_we,
    input  logic [31:0] ctrl_mem_addr,
    input  logic [31:0] ctrl_mem_wdata,
    output logic [31:0] ctrl_mem_rdata,
    output logic        ctrl_mem_resp_valid
);

    // Direct passthrough for simple implementation
    assign mem_req_valid = ctrl_mem_req;
    assign mem_req_we    = ctrl_mem_we;
    assign mem_req_addr  = ctrl_mem_addr;
    assign mem_req_wdata = ctrl_mem_wdata;

    assign ctrl_mem_rdata      = mem_resp_rdata;
    assign ctrl_mem_resp_valid = mem_resp_valid;

endmodule
