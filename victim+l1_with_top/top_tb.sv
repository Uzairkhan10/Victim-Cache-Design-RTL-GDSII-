`timescale 1ns/1ps

module tb_l1_vc_top;

    // =============================================================
    // Parameters
    // =============================================================
    localparam ADDR_WIDTH = 32;
    localparam DATA_WIDTH = 32;
    localparam LINE_BYTES = 16;
    localparam CACHE_BYTES = 256;
    localparam VICTIM_TAG_WIDTH = 27;
    localparam LINE_WIDTH = LINE_BYTES*8;

    // =============================================================
    // Clock / Reset
    // =============================================================
    logic clk, rst_n;
    initial clk = 0;
    always #5 clk = ~clk;

    // =============================================================
    // CPU interface
    // =============================================================
    logic                    cpu_req_valid;
    logic                    cpu_req_rw;
    logic [ADDR_WIDTH-1:0]   cpu_req_addr;
    logic [DATA_WIDTH-1:0]   cpu_req_wdata;
    logic                    cpu_resp_valid;
    logic [DATA_WIDTH-1:0]   cpu_resp_rdata;

    // =============================================================
    // Memory interface
    // =============================================================
    logic                    mem_req_valid;
    logic                    mem_req_rw;
    logic [ADDR_WIDTH-1:0]   mem_req_addr;
    logic [LINE_WIDTH-1:0]   mem_req_wdata;
    logic                    mem_resp_valid;
    logic [LINE_WIDTH-1:0]   mem_resp_rdata;

    // =============================================================
    // Instantiate top
    // =============================================================
    top #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .CACHE_BYTES(CACHE_BYTES),
        .LINE_BYTES(LINE_BYTES),
        .VICTIM_TAG_WIDTH(VICTIM_TAG_WIDTH)
    ) DUT (
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
    // Byte-addressable memory model
    // =============================================================
    localparam MEM_SIZE = 4096;
    logic [7:0] mem [0:MEM_SIZE-1];

    integer i;
    initial for (i=0;i<MEM_SIZE;i++) mem[i] = i[7:0];

    // memory response signals
    always_ff @(posedge clk) begin
        mem_resp_valid <= 0;

        if (mem_req_valid) begin
            if (mem_req_rw == 1'b0) begin
                // read
                mem_resp_rdata <= {mem[mem_req_addr+12], mem[mem_req_addr+13],
                                   mem[mem_req_addr+14], mem[mem_req_addr+15],
                                   mem[mem_req_addr+8],  mem[mem_req_addr+9],
                                   mem[mem_req_addr+10], mem[mem_req_addr+11],
                                   mem[mem_req_addr+4],  mem[mem_req_addr+5],
                                   mem[mem_req_addr+6],  mem[mem_req_addr+7],
                                   mem[mem_req_addr+0],  mem[mem_req_addr+1],
                                   mem[mem_req_addr+2],  mem[mem_req_addr+3]};
                mem_resp_valid <= 1;
            end else begin
                // write
                for (int b=0; b<LINE_BYTES; b++) begin
                    mem[mem_req_addr+b] <= mem_req_wdata[b*8 +: 8];
                end
                mem_resp_valid <= 1; // write ack
            end
        end
    end
    
        // =============================================================
    // Statistics
    // =============================================================
    integer cpu_accesses, l1_hits, vc_hits, complete_misses, cycle_count;
    
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
            if (DUT.DUT.hit)	l1_hits++;
            if (DUT.vc_probe_ready && DUT.vc_probe_hit) begin
            	vc_hits++;
            	cycle_count <= cycle_count + 4;
            end
            if (DUT.DUT.state == DUT.DUT.S_REFILL_REQ) begin 
            	complete_misses++;
           		cycle_count <= cycle_count + 100;
           	end
        end
    end

    // =============================================================
    // CPU tasks
    // =============================================================
    task automatic cpu_read(input logic [ADDR_WIDTH-1:0] addr);
        @(posedge clk);
        cpu_accesses++;
        cpu_req_valid <= 1;
        cpu_req_rw    <= 0;
        cpu_req_addr  <= addr;
        @(posedge clk);
        cpu_req_valid <= 0;
        wait(cpu_resp_valid);
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
        wait(cpu_resp_valid);
    endtask

    // =============================================================
    // Test sequence
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

        // Fill L1 cache completely
        for (int i = 0; i < (CACHE_BYTES/LINE_BYTES); i++)
            cpu_write(i*LINE_BYTES, i*100 + 1);

        // Re-access to confirm hits
        for (int i = 0; i < (CACHE_BYTES/LINE_BYTES); i++)
            cpu_read(i*LINE_BYTES);

        // Force L1 evictions into VC
        for (int i = (CACHE_BYTES/LINE_BYTES); i < (CACHE_BYTES/LINE_BYTES)+4; i++)
            cpu_write(i*LINE_BYTES, i*100 + 1);

        // Re-access evicted lines (should hit VC)
        cpu_read(0);
        cpu_read(LINE_BYTES);
        cpu_read(2*LINE_BYTES);
        cpu_read(3*LINE_BYTES);

        cpu_read(16*LINE_BYTES);
        cpu_read(17*LINE_BYTES);
        cpu_read(18*LINE_BYTES);
        cpu_read(19*LINE_BYTES);

        cpu_write(0, 56);
        cpu_read(LINE_BYTES);
        cpu_read(2*LINE_BYTES);
        cpu_write(3*LINE_BYTES, 256);

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
        $display("Test sequence completed");
        
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

