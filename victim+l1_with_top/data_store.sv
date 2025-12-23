// -------------------------------------------------------------
// data_store: simple line-granular storage (full-line read/write)
// -------------------------------------------------------------
module data_store #(
    parameter int LINE_BYTES = 16,
    parameter int NUM_WAYS   = 4
)(
    input  logic                       clk,
    input  logic                       rst_n,

    // full-line write
    
    input  logic                       write_en,
    input  logic [$clog2(NUM_WAYS)-1:0] write_way,
    input  logic [LINE_BYTES*8-1:0]    write_data,

    // line read (combinational)
    input  logic                       read_en,
    input  logic [$clog2(NUM_WAYS)-1:0] read_way,
    output logic [LINE_BYTES*8-1:0]    read_data
);

    localparam int LINE_WIDTH = LINE_BYTES*8;
    logic [LINE_WIDTH-1:0] mem [NUM_WAYS-1:0];

    integer i;
    // reset and write path
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < NUM_WAYS; i = i + 1)
                mem[i] <= '0;
        end else begin
            if (write_en) begin
                mem[write_way] <= write_data;
            end
        end
    end

    // combinational read
    always_comb begin
        if (read_en)
            read_data = mem[read_way];
        else
            read_data = '0;
    end
endmodule
