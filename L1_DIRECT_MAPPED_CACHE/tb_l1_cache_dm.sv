`timescale 1ns/1ps

module tb_l1_cache_dm_fsm;

    // =============================================================
    // Parameters (must match DUT)
    // =============================================================
    localparam int ADDR_WIDTH  = 32;
    localparam int DATA_WIDTH  = 32;
    localparam int CACHE_BYTES = 256;
    localparam int LINE_BYTES  = 16;

    localparam int LINE_COUNT  = CACHE_BYTES / LINE_BYTES;
    localparam int MEM_SIZE    = 4096;

    // =============================================================
    // Clock / Reset
    // =============================================================
    logic clk, rst_n;
    initial clk = 0;
    always #5 clk = ~clk;

    // =============================================================
    // CPU ↔ L1 signals
    // =============================================================
    logic                    cpu_req_valid;
    logic                    cpu_req_rw;
    logic [ADDR_WIDTH-1:0]   cpu_req_addr;
    logic [DATA_WIDTH-1:0]   cpu_req_wdata;

    logic                    cpu_resp_valid;
    logic [DATA_WIDTH-1:0]   cpu_resp_rdata;

    // =============================================================
    // L1 ↔ Memory signals
    // =============================================================
    logic                    mem_req_valid;
    logic                    mem_req_rw;
    logic [ADDR_WIDTH-1:0]   mem_req_addr;
    logic [LINE_BYTES*8-1:0] mem_req_wdata;

    logic                    mem_resp_valid;
    logic [LINE_BYTES*8-1:0] mem_resp_rdata;

    // =============================================================
    // Statistics
    // =============================================================
    integer cpu_accesses;
    integer l1_hits;
    integer complete_misses;
    integer vc_hits; // always 0 (no VC)

    // =============================================================
    // DUT
    // =============================================================
    l1_cache_dm_fsm dut (
        .clk(clk),
        .rst_n(rst_n),

        .cpu_req_valid(cpu_req_valid),
        .cpu_req_rw(cpu_req_rw),
        .cpu_req_addr(cpu_req_addr),
        .cpu_req_wdata(cpu_req_wdata),

        .cpu_resp_valid(cpu_resp_valid),
        .cpu_resp_rdata(cpu_resp_rdata),

        .mem_req_valid(mem_req_valid),
        .mem_req_rw(mem_req_rw),
        .mem_req_addr(mem_req_addr),
        .mem_req_wdata(mem_req_wdata),

        .mem_resp_valid(mem_resp_valid),
        .mem_resp_rdata(mem_resp_rdata)
    );

    // =============================================================
    // Byte-addressable reference memory
    // =============================================================
    logic [7:0] mem [0:MEM_SIZE-1];
    integer cycle_count;
    integer i;


    initial begin
        for (i = 0; i < MEM_SIZE; i++)
            mem[i] = i[7:0];
    end

    // 1-cycle memory model
    always_ff @(posedge clk) begin
        mem_resp_valid <= 0;

        if (mem_req_valid) begin
            if (!mem_req_rw) begin
                // READ (refill)
                mem_resp_rdata <= {
                    mem[mem_req_addr + 15], mem[mem_req_addr + 14],
                    mem[mem_req_addr + 13], mem[mem_req_addr + 12],
                    mem[mem_req_addr + 11], mem[mem_req_addr + 10],
                    mem[mem_req_addr +  9], mem[mem_req_addr +  8],
                    mem[mem_req_addr +  7], mem[mem_req_addr +  6],
                    mem[mem_req_addr +  5], mem[mem_req_addr +  4],
                    mem[mem_req_addr +  3], mem[mem_req_addr +  2],
                    mem[mem_req_addr +  1], mem[mem_req_addr +  0]
                };
                mem_resp_valid <= 1;
            end else begin
                // WRITEBACK
                for (int b = 0; b < LINE_BYTES; b++)
                    mem[mem_req_addr + b] <= mem_req_wdata[b*8 +: 8];
                mem_resp_valid <= 1;
            end
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

    task automatic cpu_write(
        input logic [ADDR_WIDTH-1:0] addr,
        input logic [DATA_WIDTH-1:0] data
    );
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
        end else begin
        	cycle_count <= cycle_count + 1;
            if (dut.state == dut.LOOKUP && dut.hit)
                l1_hits++;

            if (dut.state == dut.REFILL && mem_resp_valid)begin
                complete_misses++;
            	cycle_count <= cycle_count + 100;
            end
        end
    end

    // =============================================================
    // Conflict-heavy test sequence (exactly as requested)
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

        // Step 1: Fill L1
        for (int i = 0; i < LINE_COUNT; i++)
            cpu_write(i * LINE_BYTES, i * 100 + 1);

        // Step 2: Confirm hits
        for (int i = 0; i < LINE_COUNT; i++)
            cpu_read(i * LINE_BYTES);

        // Step 3: Force evictions (same indices, new tags)
        for (int i = LINE_COUNT; i < LINE_COUNT + 4; i++)
            cpu_write(i * LINE_BYTES, i * 100 + 1);

        // Step 4: Re-access evicted blocks (pure conflict misses)
        cpu_read(0);
        cpu_read(LINE_BYTES);
        cpu_read(2 * LINE_BYTES);
        cpu_read(3 * LINE_BYTES);

        cpu_read(16 * LINE_BYTES);
        cpu_read(17 * LINE_BYTES);
        cpu_read(18 * LINE_BYTES);
        cpu_read(19 * LINE_BYTES);

        cpu_write(0, 56);
        cpu_read(LINE_BYTES);
        cpu_read(2 * LINE_BYTES);
        cpu_write(3 * LINE_BYTES, 256);

        cpu_read(16 * LINE_BYTES);
        cpu_read(17 * LINE_BYTES);
        cpu_write(18 * LINE_BYTES, 999);
        cpu_write(19 * LINE_BYTES, 666);

        // Step 5
        cpu_read(5 * LINE_BYTES);
        cpu_write(6 * LINE_BYTES, 999);

        repeat(10) @(posedge clk);

        // Step 6: Stats
        $display("\n========== L1 CACHE PERFORMANCE WITHOUT VICTIM CACHE ==========");
        $display("CPU accesses      : %0d", cpu_accesses);
        $display("L1 hits           : %0d", l1_hits);
        $display("VC hits           : %0d (not present)", vc_hits);
        $display("Complete misses   : %0d", complete_misses);
        $display("Cycle Count       : %0d\n", cycle_count);
        
        $display("Each main memory access takes 100s of cycles for access\nL1 takes 1 or 2 cycles");
    	$display("==================================================================");

        $finish;
    end

endmodule
