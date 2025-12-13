// FSM-based Direct-Mapped L1 Cache
// Write-back + Write-allocate

`timescale 1ns/1ps

module l1_cache_dm_fsm #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter CACHE_BYTES = 256,
    parameter LINE_BYTES  = 16
)(
    input  logic                    clk,
    input  logic                    rst_n,

    // CPU interface
    input  logic                    cpu_req_valid,
    input  logic                    cpu_req_rw,      // 0=read, 1=write
    input  logic [ADDR_WIDTH-1:0]   cpu_req_addr,
    input  logic [DATA_WIDTH-1:0]   cpu_req_wdata,

    output logic                    cpu_resp_valid,
    output logic [DATA_WIDTH-1:0]   cpu_resp_rdata,

    // Memory interface
    output logic                    mem_req_valid,
    output logic                    mem_req_rw,      // 0=read, 1=writeback
    output logic [ADDR_WIDTH-1:0]   mem_req_addr,
    output logic [LINE_BYTES*8-1:0] mem_req_wdata,

    input  logic                    mem_resp_valid,
    input  logic [LINE_BYTES*8-1:0] mem_resp_rdata
);

    
    // Derived parameters
   
    localparam LINE_COUNT  = CACHE_BYTES / LINE_BYTES;   // 16 lines
    localparam OFFSET_BITS = $clog2(LINE_BYTES);         // 4
    localparam INDEX_BITS  = $clog2(LINE_COUNT);         // 4
    localparam TAG_BITS    = ADDR_WIDTH - INDEX_BITS - OFFSET_BITS; // 24


    // Address fields

    logic [TAG_BITS-1:0]    addr_tag;
    logic [INDEX_BITS-1:0]  addr_index;
    logic [OFFSET_BITS-1:0] addr_offset;

    assign addr_tag    = cpu_req_addr[ADDR_WIDTH-1 -: TAG_BITS];
    assign addr_index  = cpu_req_addr[OFFSET_BITS +: INDEX_BITS];
    assign addr_offset = cpu_req_addr[OFFSET_BITS-1:0];

    // Word select inside block
    wire [1:0] word_sel = addr_offset[3:2];


    // Cache storage arrays

    logic [TAG_BITS-1:0]   tag_array   [0:LINE_COUNT-1];
    logic                 valid_array [0:LINE_COUNT-1];
    logic                 dirty_array [0:LINE_COUNT-1];
    logic [DATA_WIDTH-1:0] data_array [0:LINE_COUNT-1][0:3];


    // FSM states

    typedef enum logic [2:0] {
        IDLE,
        LOOKUP,
        MISS,
        WRITEBACK,
        REFILL,
        RESPOND
    } state_t;

    state_t state, next_state;


    // Hit logic

    logic hit;
    assign hit = valid_array[addr_index] && (tag_array[addr_index] == addr_tag);


    // FSM sequential

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end


    // FSM combinational

    always_comb begin
        next_state = state;
        case (state)
            IDLE:      if (cpu_req_valid) next_state = LOOKUP;
            LOOKUP:    if (hit)            next_state = RESPOND;
                       else                next_state = MISS;
            MISS:      if (valid_array[addr_index] && dirty_array[addr_index])
                            next_state = WRITEBACK;
                       else
                            next_state = REFILL;
            WRITEBACK: if (mem_resp_valid) next_state = REFILL;
            REFILL:    if (mem_resp_valid) next_state = RESPOND;
            RESPOND:   next_state = IDLE;
        endcase
    end


    // Memory request logic

    always_comb begin
        mem_req_valid = 1'b0;
        mem_req_rw    = 1'b0;
        mem_req_addr  = '0;
        mem_req_wdata = '0;

        case (state)
            WRITEBACK: begin
                mem_req_valid = 1'b1;
                mem_req_rw    = 1'b1; // write
                mem_req_addr  = {tag_array[addr_index], addr_index, {OFFSET_BITS{1'b0}}};
                mem_req_wdata = {data_array[addr_index][3],
                                  data_array[addr_index][2],
                                  data_array[addr_index][1],
                                  data_array[addr_index][0]};
            end
            REFILL: begin
                mem_req_valid = 1'b1;
                mem_req_rw    = 1'b0; // read
                mem_req_addr  = {addr_tag, addr_index, {OFFSET_BITS{1'b0}}};
            end
        endcase
    end


    // Cache update logic

    integer i;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cpu_resp_valid <= 1'b0;
            cpu_resp_rdata <= '0;
            for (i = 0; i < LINE_COUNT; i = i + 1) begin
                valid_array[i] <= 1'b0;
                dirty_array[i] <= 1'b0;
            end
        end else begin
            cpu_resp_valid <= 1'b0;

            case (state)
                LOOKUP: begin
                    if (hit && cpu_req_rw) begin
                        data_array[addr_index][word_sel] <= cpu_req_wdata;
                        dirty_array[addr_index] <= 1'b1;
                    end
                end

                REFILL: begin
                    if (mem_resp_valid) begin
                        {data_array[addr_index][3],
                         data_array[addr_index][2],
                         data_array[addr_index][1],
                         data_array[addr_index][0]} <= mem_resp_rdata;

                        tag_array[addr_index]   <= addr_tag;
                        valid_array[addr_index] <= 1'b1;
                        dirty_array[addr_index] <= cpu_req_rw;

                        if (cpu_req_rw)
                            data_array[addr_index][word_sel] <= cpu_req_wdata;
                    end
                end

                RESPOND: begin
                    cpu_resp_valid <= 1'b1;
                    cpu_resp_rdata <= data_array[addr_index][word_sel];
                end
            endcase
        end
    end

endmodule

