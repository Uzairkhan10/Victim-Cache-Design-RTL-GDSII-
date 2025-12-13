`timescale 1ns/1ps

module tb_l1_cache_dm_fsm_corner;

    // Clock & Reset
    logic clk;
    logic rst_n;
    always #5 clk = ~clk; // 100 MHz

    // CPU interface signals
    logic        cpu_req_valid;
    logic        cpu_req_rw;
    logic [31:0] cpu_req_addr;
    logic [31:0] cpu_req_wdata;

    logic        cpu_resp_valid;
    logic [31:0] cpu_resp_rdata;

    // Memory interface signals
    logic        mem_req_valid;
    logic        mem_req_rw;
    logic [31:0] mem_req_addr;
    logic [127:0] mem_req_wdata;

    logic        mem_resp_valid;
    logic [127:0] mem_resp_rdata;
    logic [127:0] mem_resp_rdata_tb;

    // Instantiate DUT
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
        .mem_resp_rdata(mem_resp_rdata_tb)
    );

    // Main memory model (single-cycle)
    logic [127:0] memory [0:255]; // 256 blocks

    always_ff @(posedge clk) begin
        mem_resp_valid <= 1'b0;
        if (mem_req_valid) begin
            mem_resp_valid <= 1'b1;
            if (mem_req_rw) begin
                // Writeback
                memory[mem_req_addr[11:4]] <= mem_req_wdata;
            end else begin
                // Read refill
                mem_resp_rdata_tb <= memory[mem_req_addr[11:4]];
            end
        end
    end

    // Task for CPU read with assertion
    task cpu_read(input [31:0] addr, input [31:0] expected);
        begin
            @(posedge clk);
            cpu_req_valid <= 1'b1;
            cpu_req_rw    <= 1'b0;
            cpu_req_addr  <= addr;
            @(posedge clk);
            cpu_req_valid <= 1'b0;
            wait (cpu_resp_valid);
            $display("READ  addr=%08h data=%08h expected=%08h time=%0t", 
                      addr, cpu_resp_rdata, expected, $time);
            assert(cpu_resp_rdata === expected) else 
                $error("READ MISMATCH at addr=%08h", addr);
        end
    endtask

    // Task for CPU write
    task cpu_write(input [31:0] addr, input [31:0] data);
        begin
            @(posedge clk);
            cpu_req_valid <= 1'b1;
            cpu_req_rw    <= 1'b1;
            cpu_req_addr  <= addr;
            cpu_req_wdata <= data;
            @(posedge clk);
            cpu_req_valid <= 1'b0;
            wait(cpu_resp_valid);
            $display("WRITE addr=%08h data=%08h time=%0t", addr, data, $time);
        end
    endtask

    integer i;
    initial begin
        clk = 0;
        rst_n = 0;
        cpu_req_valid = 0;
        cpu_req_rw = 0;
        cpu_req_addr = 0;
        cpu_req_wdata = 0;
        mem_resp_rdata = 0;

        // Initialize memory: each 128-bit block contains 4 sequential words
        for (i = 0; i < 256; i = i + 1)
            memory[i] = {32'h1000_0003 + i, 32'h1000_0002 + i, 
                         32'h1000_0001 + i, 32'h1000_0000 + i};

        // Reset
        repeat (3) @(posedge clk);
        rst_n = 1;

        $display("\n=== 1. Compulsory Misses ===");
        cpu_read(32'h0000_0000, 32'h1000_0000);
        cpu_read(32'h0000_0010, 32'h1000_0010);

        $display("\n=== 2. Read Hits ===");
        cpu_read(32'h0000_0000, 32'h1000_0000);
        cpu_read(32'h0000_0004, 32'h1000_0001);

        $display("\n=== 3. Write Hit (Dirty) ===");
        cpu_write(32'h0000_0000, 32'hDEAD_BEEF);
        cpu_read(32'h0000_0000, 32'hDEAD_BEEF);

        $display("\n=== 4. Write Miss (Write-Allocate) ===");
        cpu_write(32'h0000_0100, 32'hCAFEBABE);
        cpu_read(32'h0000_0100, 32'hCAFEBABE);

        $display("\n=== 5. Conflict Miss / Eviction ===");
        cpu_write(32'h0000_0000, 32'hAAAABBBB);
        cpu_write(32'h0001_0000, 32'hCCCCDDDD);
        cpu_read(32'h0000_0000, 32'hAAAABBBB);

        $display("\n=== 6. Sequential Word Access ===");
        cpu_write(32'h0000_0020, 32'h11111111);
        cpu_write(32'h0000_0024, 32'h22222222);
        cpu_write(32'h0000_0028, 32'h33333333);
        cpu_write(32'h0000_002C, 32'h44444444);
        cpu_read(32'h0000_0020, 32'h11111111);
        cpu_read(32'h0000_0024, 32'h22222222);
        cpu_read(32'h0000_0028, 32'h33333333);
        cpu_read(32'h0000_002C, 32'h44444444);

        $display("\n=== 7. Back-to-Back Requests ===");
        cpu_write(32'h0000_0030, 32'hAAAA1111);
        cpu_write(32'h0000_0034, 32'hBBBB2222);
        cpu_read(32'h0000_0030, 32'hAAAA1111);
        cpu_read(32'h0000_0034, 32'hBBBB2222);

        $display("\n=== 8. Full Cache Stress (Eviction) ===");
        for (i = 0; i < 32; i = i + 1) begin
            cpu_write(32'h00000000 + i*16, 32'h10000000 + i);
        end
        // Read first line after full stress
	
        cpu_read(32'h0000_0000, 32'h1000001F); // latest line after eviction

	

        $display("\n=== 9. Edge Addresses RAW ===");
	cpu_write(32'hFFFF_FFF0, 32'h1000_00F0);
	cpu_write('0, 32'h1F00_00F0);
        cpu_read(32'hFFFF_FFF0, 32'h1000_00F0);
        cpu_read('0, 32'h1F00_00F0);
	

        $display("\n=== 10. Read After Write (RAW Hazard) ===");
        cpu_write(32'h0000_0050, 32'h12345678);
        cpu_read(32'h0000_0050, 32'h12345678);

        $display("\n=== All corner test cases completed ===");
        #20 $finish;
    end

endmodule

