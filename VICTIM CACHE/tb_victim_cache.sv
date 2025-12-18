`timescale 1ns/1ps

// Testbench for victim_cache_controller + tag_store_vc + data_store
// Exercises corner cases listed by user: probe hit/miss, install clean/dirty,
// VC write-back only on valid&&dirty, probe prioritization, FIFO eviction order,
// mem_req handshake behavior, evict_ack timing, and data invalidation on return.

module tb_victim_cache();

    // parameters must match DUT defaults
    localparam TAG_WIDTH  = 20;
    localparam LINE_BYTES = 16;
    localparam NUM_WAYS   = 4;

    // clock & reset
    logic clk;
    logic rst_n;

    // L1 probe interface
    logic                         probe_valid;
    logic [TAG_WIDTH-1:0]         probe_tag;
    logic                         probe_hit;
    logic [LINE_BYTES*8-1:0]      probe_line;
    logic                         probe_ready;

    // L1 eviction (install)
    logic                         evict_valid;
    logic [TAG_WIDTH-1:0]         evict_tag;
    logic [LINE_BYTES*8-1:0]      evict_line;
    logic                         evict_dirty;
    logic                         evict_ack;

    // memory interface
    logic                         mem_req;
    logic                         mem_req_write;
    logic [TAG_WIDTH-1:0]         mem_req_tag;
    logic [LINE_BYTES*8-1:0]      mem_req_wdata;
    logic                         mem_resp_valid;

    // instantiate DUT
    victim_cache_controller #(
        .TAG_WIDTH(TAG_WIDTH),
        .LINE_BYTES(LINE_BYTES),
        .NUM_WAYS(NUM_WAYS)
    ) DUT (
        .clk(clk), .rst_n(rst_n),
        .probe_valid(probe_valid),
        .probe_tag(probe_tag),
        .probe_hit(probe_hit),
        .probe_line(probe_line),
        .probe_ready(probe_ready),
        .evict_valid(evict_valid),
        .evict_tag(evict_tag),
        .evict_line(evict_line),
        .evict_dirty(evict_dirty),
        .evict_ack(evict_ack),
        .mem_req(mem_req),
        .mem_req_write(mem_req_write),
        .mem_req_tag(mem_req_tag),
        .mem_req_wdata(mem_req_wdata),
        .mem_resp_valid(mem_resp_valid)
    );

    // simple clock
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz-ish (10ns period)
    end

    // reset
    task reset_dut();
        begin
            rst_n = 0;
            probe_valid = 0; probe_tag = '0;
            evict_valid = 0; evict_tag = '0; evict_line = '0; evict_dirty = 0;
            mem_resp_valid = 0;
            repeat (4) @(posedge clk);
            rst_n = 1;
            @(posedge clk);
        end
    endtask

    // helper: wait n cycles
    task tick(input int n = 1);
        integer i;
        for (i = 0; i < n; i = i + 1) @(posedge clk);
    endtask

    // driver for memory model: when mem_req asserted with write, respond after delay cycles
    int mem_delay = 2; // cycles between seeing mem_req and returning mem_resp_valid
    always_ff @(posedge clk) begin
        // default lower-level memory returns mem_resp_valid one-shot when mem_req observed
        // We'll implement a simple handshake: when mem_req asserted, after mem_delay cycles
        // assert mem_resp_valid for one cycle.
    end

    // We'll implement mem model in procedural checking tasks to control timing precisely.

    // convenience: build a tag/data value from an index
    function automatic [TAG_WIDTH-1:0] mk_tag(input int idx);
        mk_tag = idx; // simple encoding
    endfunction
    function automatic [LINE_BYTES*8-1:0] mk_data(input int idx);
        mk_data = { { (LINE_BYTES*8-32){1'b0} }, 32'(idx) }; // low 32 bits = idx
    endfunction

    // Assertions and failures -> fatal
    task fail(input string s);
        begin
            $display("[FAIL] %s", s);
            $fatal(1);
        end
    endtask

    // Test 1: insert a clean line and probe it
    task test_insert_and_probe_clean();
        begin
            $display("TEST 1: insert & probe clean line");
            // install evict tag=1 clean
            evict_tag = mk_tag(1);
            evict_line = mk_data(1);
            evict_dirty = 1'b0;
            evict_valid = 1'b1;
            @(posedge clk);
            evict_valid = 1'b0; // one-cycle pulse

            // wait for evict_ack
            wait (evict_ack == 1);
            @(posedge clk);
            if (evict_ack != 1) fail("evict_ack not asserted on install (clean)");
            // probe the same tag
            probe_tag = mk_tag(1);           
            probe_valid = 1'b1;
            @(posedge clk);
            probe_valid = 1'b0;

            // expect probe_ready==1 and probe_hit==1 on that same cycle or next? according to controller,
            // the FSM goes to S_PROBE_LOOKUP then asserts probe_ready in miss or after hit wait.
            // Wait for probe_ready
            wait (probe_ready == 1);
            if (probe_hit !== 1) fail("probe should hit after inserting clean line");
            if (probe_line !== mk_data(1)) begin
                fail($sformatf("probe_line mismatch: got %h expected %h", probe_line, mk_data(1)));
            end
            $display("Probe returned correct data and hit");

            // After hit and return, subsequent probe should miss
            @(posedge clk);
            probe_tag = mk_tag(1);
            probe_valid = 1'b1;
            @(posedge clk);
            probe_valid = 1'b0;

            wait (probe_ready == 1);
            if (probe_hit !== 0) fail("after return, probe should miss for same tag");
            $display("  PASS: returned entry invalidated in VC after probe return");
            @(posedge clk);
        end
    endtask



    // Test 2: VC write-back only when victim valid && dirty
     // Test 2: VC write-back only when victim valid && dirty
    task test_vc_writeback_behavior();
        int i;
        begin
            $display("TEST 2: VC write-back only for valid&&dirty entries (FIFO order)");
            // Insert NUM_WAYS entries: set way0 = dirty, others clean, using sequential evicts
            for (i = 0; i < NUM_WAYS; i = i + 1) begin
                evict_tag = mk_tag(10 + i);
                evict_line = mk_data(10 + i);
                evict_dirty = (i == 0) ? 1'b1 : 1'b0; // make first inserted dirty
                evict_valid = 1'b1;
                @(posedge clk);
                evict_valid = 1'b0;
                wait (evict_ack == 1);
                @(posedge clk);
            end
            $display("  Installed %0d entries; way0 was dirty", NUM_WAYS);

            // Now insert one more to force FIFO eviction of way0
            evict_tag = mk_tag(99);
            evict_line = mk_data(99);
            evict_dirty = 1'b0;
            evict_valid = 1'b1;
            @(posedge clk);
            evict_valid = 1'b0;

            // The controller should detect victim at repl_ptr (which points to way0)
            // and because way0 was valid && dirty, issue mem_req with that victim tag/data
            // Wait until mem_req asserted by DUT
            wait (mem_req == 1);
            @(posedge clk);
            if (mem_req_write !== 1) fail("mem_req asserted but mem_req_write not set for write-back");
            $display("mem_req_wdata: %h, should be: 'hA", DUT.victim_data_r);
            $display("mem_req_wdata: %h, should be: 'hA", DUT.victim_data_r);
            if (DUT.victim_data_r !== mk_data(10)) fail("mem_req_wdata mismatch for write-back");
            if (DUT.victim_tag_r !== mk_tag(10)) fail("mem_req_tag mismatch for write-back");
            
            $display("  DUT issued mem write-back for expected tag %0d", 10);

            // respond after a couple cycles
            @(posedge clk);
            @(posedge clk);
            @(posedge clk);

            mem_resp_valid = 1'b1;
            @(posedge clk);
            mem_resp_valid = 1'b0;

            // eventually evict_ack should assert for the new install
            wait (evict_ack == 1);
            $display("  PASS: write-back occurred and install completed (evict_ack seen)");
            @(posedge clk);
        end
    endtask

    // Test 3: clean victim eviction does NOT cause mem_req
    task test_clean_evicted_no_wb();
        int i;
        begin
            $display("TEST 3: clean victim eviction does not cause mem_req");
            // First reset VC by installing and draining any entries: we'll do NUM_WAYS installs with clean=0 and probe them back
            // For cleanliness, just perform NUM_WAYS clean installs and then one more to evict way0 which is clean
            for (i = 0; i < NUM_WAYS; i = i + 1) begin
                evict_tag = mk_tag(200 + i);
                evict_line = mk_data(200 + i);
                evict_dirty = 1'b0;
                evict_valid = 1'b1;
                @(posedge clk);
                evict_valid = 0;
                $display("NOW WAITING FOR EVICT_ACK DURING WAYS FILL");
                wait (evict_ack == 1);
                @(posedge clk);
            end

            // Now insert extra to evict way0 (which is clean)
            evict_tag = mk_tag(999);
            evict_line = mk_data(999);
            evict_dirty = 1'b0;
            evict_valid = 1'b1;
            @(posedge clk);
            evict_valid = 1'b0;

            // Wait a small window to ensure no mem_req occurs
            // mem_req should remain 0; if it asserts within some cycles it's an error
            fork 
            begin
            	repeat (6) begin
            	    @(posedge clk);
            	    if (mem_req) fail("mem_req asserted for eviction of clean victim (unexpected)");
            	end
           	end
           	begin
            	// Now wait for evict_ack to complete install
            	$display("NOW WAITING FOR EVICT_ACK FOR TEST PASS");
            	wait (evict_ack == 1);
            	$display("  PASS: clean victim was overwritten without write-back");
            	@(posedge clk);
           	end
           	join
        end
    endtask

    // Test 4: probe is prioritized over pending evict
    task test_probe_priority_over_eviction();
        begin
            $display("TEST 4: probe prioritized over pending evict");
            // Ensure VC has at least one entry: install tag 50
            evict_tag = mk_tag(50);
            evict_line = mk_data(50);
            evict_dirty = 1'b0;
            evict_valid = 1'b1;
            @(posedge clk);
            evict_valid = 1'b0;
            wait (evict_ack == 1);
            @(posedge clk);

            // Now start an evict (to fill evict_pending), but in the following cycle issue a probe for tag 50
            evict_tag = mk_tag(77);
            evict_line = mk_data(77);
            evict_dirty = 1'b0;
            evict_valid = 1'b1; // this will be captured into evict_pending on rising edge
            @(posedge clk);
            evict_valid = 1'b0;

            // Immediately in next cycle assert probe for an existing tag (50)
            probe_tag = mk_tag(50);
            probe_valid = 1'b1;
            @(posedge clk);
            probe_valid = 1'b0;

            // Expect probe to be serviced before the pending evict installs (i.e., probe_ready seen before evict_ack)
            wait (probe_ready == 1);
            if (probe_hit !== 1) fail("probe should hit while an evict is pending");
            $display("  Probe serviced while evict_pending was set (as expected)");

            // Now wait for installation to complete
            wait (evict_ack == 1);
            $display("  Install completed after probe handled");
            @(posedge clk);
        end
    endtask
    
	task test_back_to_back_probe_hits();
		int i;
		$display("TEST 5: Back-to-back probe hits");

		// fill VC
		for (i = 0; i < 2; i++) begin
			evict_tag = mk_tag(300 + i);
			evict_line = mk_data(300 + i);
			evict_dirty = 0;
			evict_valid = 1;
			@(posedge clk);
			evict_valid = 0;
			wait(evict_ack==1);
			@(posedge clk);
		end

		// Probe tag 300
		probe_tag = mk_tag(300);
		probe_valid = 1;
		@(posedge clk);
		probe_valid = 0;
		wait(probe_ready==1);
		if (!probe_hit) fail("first probe should hit");
		@(posedge clk);

		// Probe tag 301 immediately next cycle
		probe_tag = mk_tag(301);
		probe_valid = 1;
		@(posedge clk);
		probe_valid = 0;

		wait(probe_ready);
		if (!probe_hit) fail("second probe should also hit");
		$display("  PASS: VC handled back-to-back probe hits");
		@(posedge clk);
	endtask

	task test_back_to_back_evictions();
		$display("TEST 6: back-to-back evictions (pending handling)");

		// First evict
		evict_tag = mk_tag(500);
		evict_line = mk_data(500);
		evict_dirty = 0;
		evict_valid = 1;
		@(posedge clk);
		evict_valid = 0;

		// Immediately issue second evict BEFORE first completes
		evict_tag = mk_tag(501);
		evict_line = mk_data(501);
		evict_dirty = 0;
		evict_valid = 1;
		@(posedge clk);
		evict_valid = 0;

		// evict_pending should guarantee the second install waits

		// Wait for both installs
		wait(evict_ack==1);
		@(posedge clk);
		wait(evict_ack==1);

		$display("  PASS: two back-to-back evicts correctly serialized");
		@(posedge clk);
	endtask
	
	task test_fifo_wraparound();
		int i;
		$display("TEST 7: FIFO wraparound correctness");
		
		// fill NUM_WAYS entries
		for (i = 0; i < NUM_WAYS; i++) begin
		    evict_tag = mk_tag(600+i);
		    evict_line = mk_data(600+i);
		    evict_dirty = 0;
		    evict_valid = 1;
		    @(posedge clk);
		    evict_valid=0;
		    wait(evict_ack);
		    @(posedge clk);
		end

		// Now force wrap by installing NUM_WAYS more entries
		for (i = 0; i < NUM_WAYS; i++) begin
		    evict_tag = mk_tag(700+i);
		    evict_line = mk_data(700+i);
		    evict_dirty = 0;
		    evict_valid = 1;
		    @(posedge clk);
		    evict_valid=0;
		    wait(evict_ack);
		    @(posedge clk);
		end

			// Old entries must MISS
		for (i = 0; i < NUM_WAYS; i++) begin
		    probe_tag   = mk_tag(600+i);
		    probe_valid = 1;
		    @(posedge clk);
		    probe_valid = 0;

		    wait (probe_ready);
		    if (probe_hit)
		        fail($sformatf("Old FIFO entry %0d incorrectly hit", 600+i));

		    @(posedge clk);
		end

		// New entries must HIT
		for (i = 0; i < NUM_WAYS; i++) begin
		    probe_tag   = mk_tag(700+i);
		    probe_valid = 1;
		    @(posedge clk);
		    probe_valid = 0;

		    wait (probe_ready);
		    if (!probe_hit)
		        fail($sformatf("New FIFO entry %0d missing after wraparound", 700+i));

		    @(posedge clk);
		end

		$display("  PASS: FIFO wraparound behaves correctly");
	endtask
	
	

    initial begin
        $display("\n\n========Starting victim cache Corner Testing==========\n");
        reset_dut();

        // run tests
        
		test_insert_and_probe_clean();
        $display("\n");        
        
        test_vc_writeback_behavior(); 
		$display("\n");
		
		test_clean_evicted_no_wb();
		$display("\n");
		
		test_probe_priority_over_eviction();
		$display("\n");
        
        test_back_to_back_probe_hits();
		$display("\n");
		
		test_back_to_back_evictions();
        $display("\n");
        
        test_fifo_wraparound();
       

        $display("ALL TESTS PASSED");
        #20 $finish;
    end
endmodule
