`timescale 1ns/1ps

module tb_l1_vc_byte_mem;

    // =============================================================
    // Parameters (must match DUT)
    // =============================================================
    localparam int ADDR_WIDTH  = 32;
    localparam int DATA_WIDTH  = 32;
    localparam int LINE_BYTES  = 16;
    localparam int CACHE_BYTES = 256;
    localparam int VICTIM_TAG_WIDTH = 27;

    localparam int LINE_WIDTH  = LINE_BYTES * 8;
    localparam int OFFSET_BITS = $clog2(LINE_BYTES);
    localparam int LINE_COUNT  = CACHE_BYTES / LINE_BYTES;

    // =============================================================
    // Clock / Reset
    // =============================================================
    logic clk, rst_n;
    initial clk = 0;
    always #5 clk = ~clk;

    // =============================================================
    // CPU ↔ L1 interface
    // =============================================================
    logic                    cpu_req_valid;
    logic                    cpu_req_rw;
    logic [ADDR_WIDTH-1:0]   cpu_req_addr;
    logic [DATA_WIDTH-1:0]   cpu_req_wdata;
    logic                    cpu_resp_valid;
    logic [DATA_WIDTH-1:0]   cpu_resp_rdata;

    // =============================================================
    // L1 ↔ Memory
    // =============================================================
    logic                    l1_mem_req_valid;
    logic                    l1_mem_req_rw;
    logic [ADDR_WIDTH-1:0]   l1_mem_req_addr;
    logic [LINE_WIDTH-1:0]   l1_mem_req_wdata;
    logic                    l1_mem_resp_valid;
    logic [LINE_WIDTH-1:0]   l1_mem_resp_rdata;

    // =============================================================
    // L1 ↔ VC
    // =============================================================
    logic                    vc_probe_valid;
    logic [VICTIM_TAG_WIDTH-1:0] vc_probe_tag;
    logic                    vc_probe_ready;
    logic                    vc_probe_hit;
    logic                    vc_probe_dirty;
    logic [LINE_WIDTH-1:0]   vc_probe_line;

    logic                    vc_evict_valid;
    logic [VICTIM_TAG_WIDTH-1:0] vc_evict_tag;
    logic [LINE_WIDTH-1:0]   vc_evict_line;
    logic                    vc_evict_dirty;
    logic                    vc_evict_ack;

    logic                    vc_ready;

    // =============================================================
    // VC ↔ Memory
    // =============================================================
    logic                    vc_mem_req;
    logic                    vc_mem_req_write;
    logic [VICTIM_TAG_WIDTH-1:0] vc_mem_req_tag;
    logic [LINE_WIDTH-1:0]   vc_mem_req_wdata;
    logic                    vc_mem_resp_valid;

    // =============================================================
    // Statistics
    // =============================================================
    integer cpu_accesses, l1_hits, vc_hits, complete_misses;

    // =============================================================
    // DUT instantiation
    // =============================================================
    l1_cache_dm_with_vc #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .CACHE_BYTES(CACHE_BYTES),
        .LINE_BYTES(LINE_BYTES),
        .VICTIM_TAG_WIDTH(VICTIM_TAG_WIDTH)
    ) l1 (
        .clk(clk),
        .rst_n(rst_n),
        .cpu_req_valid(cpu_req_valid),
        .cpu_req_rw(cpu_req_rw),
        .cpu_req_addr(cpu_req_addr),
        .cpu_req_wdata(cpu_req_wdata),
        .cpu_resp_valid(cpu_resp_valid),
        .cpu_resp_rdata(cpu_resp_rdata),
        .mem_req_valid(l1_mem_req_valid),
        .mem_req_rw(l1_mem_req_rw),
        .mem_req_addr(l1_mem_req_addr),
        .mem_req_wdata(l1_mem_req_wdata),
        .mem_resp_valid(l1_mem_resp_valid),
        .mem_resp_rdata(l1_mem_resp_rdata),
        .vc_probe_valid(vc_probe_valid),
        .vc_probe_tag(vc_probe_tag),
        .vc_ready(vc_ready),
        .vc_probe_ready(vc_probe_ready),
        .vc_probe_hit(vc_probe_hit),
        .vc_probe_dirty(vc_probe_dirty),
        .vc_probe_line(vc_probe_line),
        .vc_evict_valid(vc_evict_valid),
        .vc_evict_tag(vc_evict_tag),
        .vc_evict_line(vc_evict_line),
        .vc_evict_dirty(vc_evict_dirty),
        .vc_evict_ack(vc_evict_ack)
    );

    victim_cache_controller #(
        .TAG_WIDTH(VICTIM_TAG_WIDTH),
        .LINE_BYTES(LINE_BYTES),
        .NUM_WAYS(4)
    ) vc (
        .clk(clk),
        .rst_n(rst_n),
        .vc_ready(vc_ready),
        .probe_valid(vc_probe_valid),
        .probe_tag(vc_probe_tag),
        .probe_hit(vc_probe_hit),
        .probe_line(vc_probe_line),
        .probe_ready(vc_probe_ready),
        .probe_dirty(vc_probe_dirty),
        .evict_valid(vc_evict_valid),
        .evict_tag(vc_evict_tag),
        .evict_line(vc_evict_line),
        .evict_dirty(vc_evict_dirty),
        .evict_ack(vc_evict_ack),
        .mem_req(vc_mem_req),
        .mem_req_write(vc_mem_req_write),
        .mem_req_tag(vc_mem_req_tag),
        .mem_req_wdata(vc_mem_req_wdata),
        .mem_resp_valid(vc_mem_resp_valid)
    );

    // =============================================================
    // Byte-addressable reference memory
    // =============================================================
    localparam int MEM_SIZE = 4096;
    logic [7:0] mem [0:MEM_SIZE-1];

    integer i;
    
    integer cycle_count;
    
    initial for (i=0;i<MEM_SIZE;i++) mem[i] = i[7:0];

    always_ff @(posedge clk) begin
        // L1 memory access
        l1_mem_resp_valid <= 0;
        if (l1_mem_req_valid) begin
            l1_mem_resp_rdata <= {mem[l1_mem_req_addr+12], mem[l1_mem_req_addr+13],
                                   mem[l1_mem_req_addr+14], mem[l1_mem_req_addr+15],
                                   mem[l1_mem_req_addr+8],  mem[l1_mem_req_addr+9],
                                   mem[l1_mem_req_addr+10], mem[l1_mem_req_addr+11],
                                   mem[l1_mem_req_addr+4],  mem[l1_mem_req_addr+5],
                                   mem[l1_mem_req_addr+6],  mem[l1_mem_req_addr+7],
                                   mem[l1_mem_req_addr+0],  mem[l1_mem_req_addr+1],
                                   mem[l1_mem_req_addr+2],  mem[l1_mem_req_addr+3]};
            l1_mem_resp_valid <= 1;
        end

        // VC memory write-back
        vc_mem_resp_valid <= 0;
        if (vc_mem_req && vc_mem_req_write) begin
            for (int b=0; b<LINE_BYTES; b++) begin
                mem[vc_mem_req_tag*LINE_BYTES + b] <= vc_mem_req_wdata[b*8 +: 8];
            end
            vc_mem_resp_valid <= 1;
        end
    end

    // =============================================================
    // CPU Tasks
    // =============================================================
    task automatic cpu_read(input logic [ADDR_WIDTH-1:0] addr);
        @(posedge clk);
        cpu_accesses++;
        cpu_req_valid <= 1;
        cpu_req_rw    <= 0;
        cpu_req_addr  <= addr;
        @(posedge clk);
        cpu_req_valid <= 0;
        wait (cpu_resp_valid);
    endtask

    task automatic cpu_write(input logic [ADDR_WIDTH-1:0] addr, input logic [DATA_WIDTH-1:0] data);
        @(posedge clk);
        cpu_accesses++;
        cpu_req_valid <= 1;
        cpu_req_rw    <= 1;
        cpu_req_addr  <= addr;
        cpu_req_wdata <= data;
        @(posedge clk);
        cpu_req_valid <= 0;
        wait (cpu_resp_valid);
    endtask

    // =============================================================
    // Counters
    // =============================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cpu_accesses    <= 0;
            l1_hits         <= 0;
            vc_hits         <= 0;
            complete_misses <= 0;
            cycle_count <= 0;
        end 
        else begin
            if (l1.hit)	l1_hits++;
            if (vc_probe_ready && vc_probe_hit) begin
            	vc_hits++;
            	cycle_count <= cycle_count + 4;
            end
            if (l1.state == l1.S_REFILL_REQ) begin 
            	complete_misses++;
           		cycle_count <= cycle_count + 100;
           	end
        end
    end

    // =============================================================
    // Conflict-heavy test sequence
    // =============================================================
    initial begin
    rst_n = 0;
    cpu_req_valid = 0;
    cpu_req_rw = 0;
    cpu_req_addr = 0;
    cpu_req_wdata = 0;
    repeat(5) @(posedge clk);
    rst_n = 1;
    repeat(5) @(posedge clk);

    // -------------------------
    // Step 1: Fill L1 completely
    // -------------------------
    for (int i = 0; i < LINE_COUNT; i++) begin
        cpu_write(i*LINE_BYTES, i*100 + 1);
    end

    // -------------------------
    // Step 2: Access some L1 lines to confirm hits
    // -------------------------
    for (int i = 0; i < LINE_COUNT; i++) begin
        cpu_read(i*LINE_BYTES);
    end

    // -------------------------
    // Step 3: Access more unique blocks to force L1 evictions into VC
    // -------------------------
    for (int i = LINE_COUNT; i < LINE_COUNT + 4; i++) begin
        cpu_write(i*LINE_BYTES, i*100 + 1);
    end

    // -------------------------
    // Step 4: Re-access some of the evicted lines (should hit VC)
    // -------------------------
    cpu_read(0);                // hit in VC
    cpu_read(LINE_BYTES);       // hit in VC
    cpu_read(2*LINE_BYTES);     // hit in VC
    cpu_read(3*LINE_BYTES);     // hit in VC
    
    cpu_read(16*LINE_BYTES);                
    cpu_read(17*LINE_BYTES);      
    cpu_read(18*LINE_BYTES);     
    cpu_read(19*LINE_BYTES);     
    
    cpu_write(0, 56);                // hit in VC
    cpu_read(LINE_BYTES);       // hit in VC
    cpu_read(2*LINE_BYTES);     // hit in VC
    cpu_write(3*LINE_BYTES, 256);     // hit in VC
    
    cpu_read(16*LINE_BYTES);                
    cpu_read(17*LINE_BYTES);      
    cpu_write(18*LINE_BYTES, 999);     
    cpu_write(19*LINE_BYTES, 666);   

    // -------------------------
    // Step 5: Optional: additional random accesses
    // -------------------------
    cpu_read(5*LINE_BYTES);
    cpu_write(6*LINE_BYTES, 999);

    repeat(10) @(posedge clk);

    // -------------------------
    // Step 6: Print statistics
    // -------------------------
    $display("\n==== L1 CACHE PERFORMANCE WITH VICTIM CACHE ====");
    $display("CPU accesses      : %0d", cpu_accesses);
    $display("L1 hits           : %0d", cpu_accesses - vc_hits - complete_misses);
    $display("VC hits           : %0d", vc_hits);
    $display("Complete misses   : %0d", complete_misses);
    $display("Cycle Count       : %0d\n", cycle_count);
        
    $display("Each main memory access takes 100s of cycles for access\nL1 takes 1 or 2 cycles\nVictim Cache takes 3-4 cycles");
    $display("==================================================");

    $finish;
end

endmodule

