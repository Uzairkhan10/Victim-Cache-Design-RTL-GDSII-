// -------------------------------------------------------------
// tag_store_vc: tag + valid + dirty for Victim Cache
// -------------------------------------------------------------
module tag_store_vc #(
    parameter TAG_WIDTH = 20,
    parameter NUM_WAYS  = 4
)(
    input  logic                         clk,
    input  logic                         rst_n,

    // write a full line (install from L1 eviction)
    input  logic                         write_en,
    input  logic [$clog2(NUM_WAYS)-1:0]  way_index_in,
    input  logic [TAG_WIDTH-1:0]         tag_in,
    input  logic                         dirty_in,

    // invalidate a way (used when returning line to L1)
    input  logic                         invalidate_en,
    input  logic [$clog2(NUM_WAYS)-1:0]  invalidate_way,

    // read one way (combinationally available)
    input  logic                         read_en,
    input  logic [$clog2(NUM_WAYS)-1:0]  read_way_index,
    output logic [TAG_WIDTH-1:0]         tag_read,
    output logic                         dirty_read,
    output logic                         valid_read,

    // lookup (combinational): present a tag_in_lookup, get hit & index
    input  logic [TAG_WIDTH-1:0]         tag_in_lookup,
    output logic                         hit,
    output logic [$clog2(NUM_WAYS)-1:0]  hit_way_index
);

    logic [TAG_WIDTH-1:0] tag_array [NUM_WAYS-1:0];
    logic valid_array [NUM_WAYS-1:0];
    logic dirty_array [NUM_WAYS-1:0];

    // combinational lookup
    always_comb begin
        hit = 1'b0;
        hit_way_index = '0;
        for(int i = 0; i < NUM_WAYS; i++) begin
            if (valid_array[i] && tag_array[i] == tag_in_lookup) begin
                hit = 1'b1;
                hit_way_index = i[$clog2(NUM_WAYS)-1:0];
            end
        end
    end

    // combinational read (for read_en)
    always_comb begin
        if (read_en) begin
            tag_read = tag_array[read_way_index];
            dirty_read = dirty_array[read_way_index];
            valid_read = valid_array[read_way_index];
        end else begin
            tag_read = '0;
            dirty_read = 1'b0;
            valid_read = 1'b0;
        end
    end

    // sequential writes / invalidates
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < NUM_WAYS; i++) begin
                tag_array[i] <= '0;
                valid_array[i] <= 1'b0;
                dirty_array[i] <= 1'b0;
            end
        end else begin
            if (invalidate_en) begin
                // invalidate explicitly (clear valid and dirty and tag)
                tag_array[invalidate_way] <= '0;
                valid_array[invalidate_way] <= 1'b0;
                dirty_array[invalidate_way] <= 1'b0;
            end
            else if (write_en) begin
                // install full line (tag + dirty), mark valid
                tag_array[way_index_in] <= tag_in;
                valid_array[way_index_in] <= 1'b1;
                dirty_array[way_index_in] <= dirty_in;
            end
        end
    end

endmodule
