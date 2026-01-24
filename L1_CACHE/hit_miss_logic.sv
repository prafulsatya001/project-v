// ============================================================================
// File: hit_miss_logic.sv
// Description: Cache hit/miss detection and way selection
// ============================================================================
module hit_miss_logic #(
    parameter int NUM_SETS  = 64,
    parameter int NUM_WAYS  = 4,
    parameter int TAG_BITS  = 22,
    parameter int INDEX_BITS = 6,
    parameter int WAY_BITS  = 2
)(
    input  logic                       clk,
    input  logic                       rst_n,

    // Lookup request
    input  logic                       lookup_en,
    input  logic [INDEX_BITS-1:0]      lookup_index,
    input  logic [TAG_BITS-1:0]        lookup_tag,

    // Tag array read interface
    input  logic [TAG_BITS-1:0]        tag_rd [NUM_WAYS],

    // Valid/dirty bits
    input  logic                       valid_bits [NUM_SETS][NUM_WAYS],
    input  logic                       dirty_bits [NUM_SETS][NUM_WAYS],

    // Hit/miss results
    output logic                       hit_found,
    output logic [WAY_BITS-1:0]        hit_way,
    output logic                       miss_found,

    // LRU victim way
    input  logic [WAY_BITS-1:0]        lru_victim_way,

    // Victim selection for miss
    output logic [WAY_BITS-1:0]        victim_way,
    output logic                       victim_valid,
    output logic                       victim_dirty
);

    // Hit detection logic
    always_comb begin
        hit_found = '0;
        hit_way   = '0;
        
        for (int h = 0; h < NUM_WAYS; h++) begin
            if (valid_bits[lookup_index][h] && (tag_rd[h] == lookup_tag)) begin
                hit_found = 1'b1;
                hit_way   = h[WAY_BITS-1:0];
            end
        end
        
        miss_found = lookup_en && !hit_found;
    end

    // Victim selection (prefer invalid way, else use LRU)
    always_comb begin
        logic found_invalid;
        
        victim_way   = lru_victim_way;
        found_invalid = '0;
        
        for (int inv_idx = 0; inv_idx < NUM_WAYS; inv_idx++) begin
            if (!valid_bits[lookup_index][inv_idx] && !found_invalid) begin
                victim_way    = inv_idx[WAY_BITS-1:0];
                found_invalid = 1'b1;
            end
        end
        
        victim_valid = valid_bits[lookup_index][victim_way];
        victim_dirty = valid_bits[lookup_index][victim_way] && 
                       dirty_bits[lookup_index][victim_way];
    end

endmodule