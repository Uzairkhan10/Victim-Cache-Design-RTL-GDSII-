// l1_cache_dm_with_vc_v2.sv
`timescale 1ns/1ps

module l1_cache_dm_with_vc #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32,
    parameter int CACHE_BYTES = 256,
    parameter int VICTIM_TAG_WIDTH = 27,
    parameter int LINE_BYTES  = 16
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
    output logic                    mem_req_rw,
    output logic [ADDR_WIDTH-1:0]   mem_req_addr,
    output logic [LINE_BYTES*8-1:0] mem_req_wdata,

    input  logic                    mem_resp_valid,
    input  logic [LINE_BYTES*8-1:0] mem_resp_rdata,

    // Victim Cache interface
    // Probe: L1 -> VC; VC responds by asserting vc_probe_ready and driving the hit/dirty/line outputs.
    output logic                    vc_probe_valid,
    output logic [VICTIM_TAG_WIDTH-1:0]   vc_probe_tag,
    input logic 					vc_ready,
    input  logic                    vc_probe_ready,
    input  logic                    vc_probe_hit,
    input  logic                    vc_probe_dirty,
    input  logic [LINE_BYTES*8-1:0] vc_probe_line,

    // Evict: L1 -> VC (L1 sends evicted line); VC ack's with vc_evict_ack when accepted.
    output logic                    vc_evict_valid,
    output logic [VICTIM_TAG_WIDTH-1:0]   vc_evict_tag,
    output logic [LINE_BYTES*8-1:0] vc_evict_line,
    output logic                    vc_evict_dirty,
    input  logic                    vc_evict_ack
);

    // Derived params
    localparam int LINE_COUNT = CACHE_BYTES / LINE_BYTES;
    localparam int OFFSET_BITS = $clog2(LINE_BYTES);
    localparam int INDEX_BITS  = $clog2(LINE_COUNT);
    localparam int TAG_BITS    = ADDR_WIDTH - INDEX_BITS - OFFSET_BITS;
    localparam int WORDS_PER_LINE = LINE_BYTES / (DATA_WIDTH/8);
    localparam int WORD_SEL_WIDTH = (WORDS_PER_LINE>1) ? $clog2(WORDS_PER_LINE) : 1;
    

    // Address fields
    logic [TAG_BITS-1:0]    addr_tag;
    logic [INDEX_BITS-1:0]  addr_index;
    logic [OFFSET_BITS-1:0] addr_offset;
    assign addr_tag    = cpu_req_addr[ADDR_WIDTH-1 -: TAG_BITS];
    assign addr_index  = cpu_req_addr[OFFSET_BITS +: INDEX_BITS];
    assign addr_offset = cpu_req_addr[OFFSET_BITS-1:0];

    // Word select
    wire [WORD_SEL_WIDTH-1:0] word_sel = addr_offset[OFFSET_BITS-1 -: WORD_SEL_WIDTH];

    // Storage arrays
    logic [TAG_BITS-1:0]    tag_array   [0:LINE_COUNT-1];
    logic                  valid_array [0:LINE_COUNT-1];
    logic                  dirty_array [0:LINE_COUNT-1];
    logic [DATA_WIDTH-1:0]  data_array  [0:LINE_COUNT-1][0:WORDS_PER_LINE-1];

    // Hit logic
    logic hit;
    //assign hit = valid_array[addr_index] && (tag_array[addr_index] == addr_tag);

    // FSM states
    typedef enum logic [3:0] {
        S_IDLE,
        S_LOOKUP,
        S_VC_PROBE,
        S_VC_WAIT,
        S_AFTER_VC,
        S_EVICT_TO_VC,
        S_WAIT_EVICT_ACK,
        S_REFILL_REQ,
        S_WAIT_MEM,
        S_INSTALL,
        S_RESPOND
    } state_t;

    state_t state, next_state;

    // Registers to hold actions/handshakes (single-writer)
    logic mem_req_valid_r;
    logic mem_req_rw_r;
    logic [ADDR_WIDTH-1:0] mem_req_addr_r;
    logic [LINE_BYTES*8-1:0] mem_req_wdata_r;

    logic vc_probe_valid_r;
    logic [VICTIM_TAG_WIDTH-1:0] vc_probe_tag_r;

    logic vc_evict_valid_r;
    logic [VICTIM_TAG_WIDTH-1:0] vc_evict_tag_r;
    logic [LINE_BYTES*8-1:0] vc_evict_line_r;
    logic vc_evict_dirty_r;

    logic cpu_resp_valid_r;
    logic [DATA_WIDTH-1:0] cpu_resp_rdata_r;

    // Captured VC line and flags (sampled when vc_probe_ready asserted)
    logic [LINE_BYTES*8-1:0] vc_line_r;
    logic                    vc_line_valid_r;
    logic                    vc_line_dirty_r;

    // requested block address (block-aligned)
    logic [ADDR_WIDTH-1:0] requested_block_addr_r;

    // state register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= S_IDLE;
        else state <= next_state;
    end
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) hit <= 1'b0;
        else if (state == S_IDLE)
        	 hit <= valid_array[addr_index] && (tag_array[addr_index] == addr_tag);
       	else
       		hit <= 1'b0;
    end

    // next-state combinational: use registered sampled vc_line_valid_r in S_AFTER_VC
    always_comb begin
        next_state = state;
        unique case (state)
            S_IDLE: begin
            	vc_evict_valid_r = 1'b0;
                if (cpu_req_valid) next_state = S_LOOKUP;
            end

            S_LOOKUP: begin
                if (hit) next_state = S_RESPOND;
                else     next_state = S_VC_PROBE;
            end

            S_VC_PROBE: begin
		        if(vc_ready) begin
		            next_state = S_VC_WAIT;
		            vc_probe_valid_r = 1'b1;
		        end
		        else
		        	next_state = S_VC_PROBE;
		    end

            S_VC_WAIT: begin
                if (vc_probe_ready)begin
                	next_state = S_AFTER_VC; // we sample on-clock; decision next
                	vc_probe_valid_r = 1'b0;
                end
                else next_state = S_VC_WAIT;
            end

            S_AFTER_VC: begin
                // now examine sampled vc_line_valid_r (set in sequential when probe_ready arrived)
                if (valid_array[addr_index]) begin
                    // if L1 victim slot is valid it must be evicted to VC first
                    next_state = S_EVICT_TO_VC;
                end else begin
                    // no eviction required; if we have a VC line, install it; else request refill
                    if (vc_line_valid_r) next_state = S_INSTALL;
                    else next_state = S_REFILL_REQ;
                end
            end

            S_EVICT_TO_VC: begin
            	if(vc_ready)begin
            		vc_evict_valid_r = 1'b1;
            		next_state = S_WAIT_EVICT_ACK;
            	end
            	else
            		next_state = S_EVICT_TO_VC;
			end
			
            S_WAIT_EVICT_ACK: begin
                if (vc_evict_ack) begin
                	vc_evict_valid_r = 1'b0;
                    // after ack, if we captured a VC line we install it, else ask memory
                    if (vc_line_valid_r) next_state = S_INSTALL; //if evict was after VC hit, then write the line from the temp register. 
                    else next_state = S_REFILL_REQ;
                end else next_state = S_WAIT_EVICT_ACK;
            end

            S_REFILL_REQ: next_state = S_WAIT_MEM;

            S_WAIT_MEM: begin
                if (mem_resp_valid) next_state = S_INSTALL;
                else next_state = S_WAIT_MEM;
            end

            S_INSTALL: next_state = S_RESPOND;

            S_RESPOND: next_state = S_IDLE;

            default: begin 
            	next_state = S_IDLE;
            	vc_probe_valid_r = 1'b0;
            end
        endcase
    end

    // sequential datapath + registered outputs: single-writer style
    integer i, w;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // clear arrays and regs
            cpu_resp_valid_r <= 1'b0;
            cpu_resp_rdata_r <= '0;

            mem_req_valid_r  <= 1'b0;
            mem_req_rw_r     <= 1'b0;
            mem_req_addr_r   <= '0;
            mem_req_wdata_r  <= '0;

            //vc_probe_valid_r <= 1'b0;
            vc_probe_tag_r   <= '0;

            //vc_evict_valid_r <= 1'b0;
            vc_evict_tag_r   <= '0;
            vc_evict_line_r  <= '0;
            vc_evict_dirty_r <= 1'b0;

            //vc_line_r <= '0;
            //vc_line_valid_r <= 1'b0;
            //vc_line_dirty_r <= 1'b0;
            requested_block_addr_r <= '0;

            for (i = 0; i < LINE_COUNT; i = i + 1) begin
                tag_array[i] <= '0;
                valid_array[i] <= 1'b0;
                dirty_array[i] <= 1'b0;
                for (w = 0; w < WORDS_PER_LINE; w = w + 1)
                    data_array[i][w] <= '0;
            end
        	end else begin
            // defaults: single-cycle pulses cleared
            cpu_resp_valid_r <= 1'b0;
            mem_req_valid_r  <= 1'b0;
            //vc_probe_valid_r <= 1'b0;
            //vc_evict_valid_r <= 1'b0;

            case (state)
                S_IDLE: begin
                    // nothing
                end

                S_LOOKUP: begin
                    // for write-hit update data and mark dirty immediately
                    if (hit && cpu_req_rw) begin
                        data_array[addr_index][word_sel] <= cpu_req_wdata;
                        dirty_array[addr_index] <= 1'b1;
                    end
                end

                S_VC_PROBE: begin
                    // assert probe (one-cycle pulse registered; will be re-asserted in S_VC_WAIT)
                    //vc_probe_valid_r <= 1'b1;
                    vc_probe_tag_r   <= { addr_tag, addr_index };
                    requested_block_addr_r <= { addr_tag, addr_index };
                end

                S_VC_WAIT: begin
                    // keep asserting probe while waiting
                    //vc_probe_valid_r <= 1'b1;
                    vc_probe_tag_r   <= requested_block_addr_r;
                end

                // Sample VC response synchronously when ready asserted
                default: begin end
            endcase

            // SAMPLE VC response on the clock when vc_probe_ready arrives while in S_VC_WAIT
            if (state == S_VC_WAIT && vc_probe_ready) begin
                if (vc_probe_hit) begin
                    vc_line_r <= vc_probe_line;
                    vc_line_valid_r <= 1'b1;
                    vc_line_dirty_r <= vc_probe_dirty;
                end else begin
                    vc_line_r <= '0;
                    vc_line_valid_r <= 1'b0;
                    vc_line_dirty_r <= 1'b0;
                end
            end
          

            // Eviction: build line payload and assert vc_evict_valid_r until ack
            if (state == S_EVICT_TO_VC) begin
                logic [LINE_BYTES*8-1:0] tmp_line;
                tmp_line = '0;
                for (w = 0; w < WORDS_PER_LINE; w = w + 1) begin
                    tmp_line[w*DATA_WIDTH +: DATA_WIDTH] = data_array[addr_index][w];
                end
                //vc_evict_valid_r <= 1'b1;
                vc_evict_tag_r   <= { tag_array[addr_index], addr_index };
                vc_evict_line_r  <= tmp_line;
                vc_evict_dirty_r <= dirty_array[addr_index];
            end 
            else if (state == S_WAIT_EVICT_ACK) begin
                // hold evict_valid until ack; when ack, clear L1 slot
                if (vc_evict_ack) begin
                    // ack received; clear the line in L1
                    //vc_evict_valid_r <= 1'b0;
                    valid_array[addr_index] <= 1'b0;
                    dirty_array[addr_index] <= 1'b0;
                    tag_array[addr_index] <= '0;
                end
            end

            // Refill request to memory
            if (state == S_REFILL_REQ) begin
                mem_req_valid_r <= 1'b1;
                mem_req_rw_r <= 1'b0; // read
                mem_req_addr_r <= { addr_tag, addr_index, {OFFSET_BITS{1'b0}} };
                // mem_req_wdata_r unused for read
            end

            // Install: either from sampled VC line (vc_line_r) or from mem_resp_rdata
            if (state == S_INSTALL) begin
                logic [LINE_BYTES*8-1:0] install_line;
                if (vc_line_valid_r) begin
                    install_line = vc_line_r;
                    dirty_array[addr_index] = vc_line_dirty_r;
                end else begin
                    // mem_resp_rdata is valid in the cycle we transitioned from S_WAIT_MEM to S_INSTALL
                    install_line = mem_resp_rdata;
                    dirty_array[addr_index] = 1'b0;
                end

                // write words into data_array
                for (w = 0; w < WORDS_PER_LINE; w = w + 1) begin
                    data_array[addr_index][w] <= install_line[w*DATA_WIDTH +: DATA_WIDTH];
                end

                tag_array[addr_index] <= addr_tag;
                valid_array[addr_index] <= 1'b1;

                // If CPU was performing a write as part of the original request, apply and mark dirty
                if (cpu_req_rw) begin
                    data_array[addr_index][word_sel] <= cpu_req_wdata;
                    dirty_array[addr_index] <= 1'b1;
                end else begin
                    // preserve vc dirty if source was VC; else clear
                    if (vc_line_valid_r) dirty_array[addr_index] <= vc_line_dirty_r;
                    else dirty_array[addr_index] <= 1'b0;
                end

                // clear captured VC line after install
                vc_line_valid_r <= 1'b0;
                vc_line_r <= '0;
                vc_line_dirty_r <= 1'b0;
            end

            // Respond to CPU (single-cycle pulse)
            if (state == S_RESPOND) begin
                cpu_resp_valid_r <= 1'b1;
                cpu_resp_rdata_r <= data_array[addr_index][word_sel];
            end
        end
    end

    // output assignments from registers (single driver)
    assign mem_req_valid = mem_req_valid_r;
    assign mem_req_rw    = mem_req_rw_r;
    assign mem_req_addr  = mem_req_addr_r;
    assign mem_req_wdata = mem_req_wdata_r;

    assign vc_probe_valid = vc_probe_valid_r;
    assign vc_probe_tag   = vc_probe_tag_r;

    assign vc_evict_valid = vc_evict_valid_r;
    assign vc_evict_tag   = vc_evict_tag_r;
    assign vc_evict_line  = vc_evict_line_r;
    assign vc_evict_dirty = vc_evict_dirty_r;

    assign cpu_resp_valid = cpu_resp_valid_r;
    assign cpu_resp_rdata = cpu_resp_rdata_r;

endmodule

