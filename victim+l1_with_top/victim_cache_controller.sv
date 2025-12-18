 // -------------------------------------------------------------
// victim_cache_controller: connects tag_store_vc + data_store
// - line-granular vc
// - FIFO replacement (repl_way)
// - vc write-back on vc eviction (if dirty)
// - vc never fetches from memory on probe miss
// - supports L1 probe (lookup) and L1 eviction (install)
// -------------------------------------------------------------
module victim_cache_controller #(
    parameter TAG_WIDTH   = 20,   // combined L1 tag + index
    parameter LINE_BYTES  = 16,
    parameter NUM_WAYS    = 4
)(
    input  logic                         clk,
    input  logic                         rst_n,
    
    output logic vc_ready,

    // ---------------- L1 probe (lookup) ----------------
    // L1 uses this to probe vc on a miss
    input  logic                         probe_valid,    // assert to probe vc
    input  logic [TAG_WIDTH-1:0]         probe_tag,      // combined tag (L1 tag+index)
    output logic                         probe_hit,      // 1 if vc had it
    output logic [LINE_BYTES*8-1:0]      probe_line,     // full line returned if hit
    output logic                         probe_ready,    // vc responded (hit or miss)
	output logic 						 probe_dirty,
    // ---------------- L1 eviction (install) --------------
    // L1 hands an evicted line to vc for storage
    input  logic                         evict_valid,    // L1 wants to insert a line into vc
    input  logic [TAG_WIDTH-1:0]         evict_tag,
    input  logic [LINE_BYTES*8-1:0]      evict_line,
    input  logic                         evict_dirty,    // dirty flag from L1
    output logic                         evict_ack,      // vc accepted install
	
	
    // ---------------- Memory interface (write-back) -----
    output logic                         mem_req,
    output logic                         mem_req_write,
    output logic [TAG_WIDTH-1:0]         mem_req_tag,
    output logic [LINE_BYTES*8-1:0]      mem_req_wdata,
    input  logic                         mem_resp_valid
);
	
	logic vc_ready_reg;
	
    // ---------- instances signals ----------
    // tag store instance ports
    logic tag_write_en, tag_read_en, tag_invalidate_en;
    logic [$clog2(NUM_WAYS)-1:0] tag_way_index, tag_read_way;
    logic [TAG_WIDTH-1:0] tag_in;
    logic tag_dirty_in;
    logic tag_hit;
    logic [$clog2(NUM_WAYS)-1:0] tag_hit_way;
    logic tag_valid_read, tag_dirty_read;
    logic [TAG_WIDTH-1:0] tag_read_data;

    tag_store_vc #(.TAG_WIDTH(TAG_WIDTH), .NUM_WAYS(NUM_WAYS)) TAGS (
        .clk(clk), .rst_n(rst_n),
        .write_en(tag_write_en),
        .read_en(tag_read_en),
        .way_index_in(tag_way_index),
        .tag_in(tag_in),
        .dirty_in(tag_dirty_in),
        .invalidate_en(tag_invalidate_en),
        .invalidate_way(tag_way_index), // reuse tag_way_index for invalidate target
        .read_way_index(tag_read_way),
        .tag_read(tag_read_data),
        .dirty_read(tag_dirty_read),
        .valid_read(tag_valid_read),
        .tag_in_lookup(probe_tag),
        .hit(tag_hit),
        .hit_way_index(tag_hit_way)
    );

    // NOTE: above instantiation maps tag_in_lookup to probe_tag and
    // provides hit/hit_way combinationally. We also expose tag_read via tag_read_way.

    // data store instance ports
    logic data_write_en;
    logic [$clog2(NUM_WAYS)-1:0] data_write_way;
    logic [LINE_BYTES*8-1:0] data_write_data;
    logic data_read_en;
    logic [$clog2(NUM_WAYS)-1:0] data_read_way;
    logic [LINE_BYTES*8-1:0] data_read_data;

    data_store #(.LINE_BYTES(LINE_BYTES), .NUM_WAYS(NUM_WAYS)) DATA (
        .clk(clk), .rst_n(rst_n),
        .write_en(data_write_en),
        .write_way(data_write_way),
        .write_data(data_write_data),
        .read_en(data_read_en),
        .read_way(data_read_way),
        .read_data(data_read_data)
    );
    
    	//enum for fsm states
	typedef enum logic [3:0] {
        S_IDLE,
        S_PROBE_LOOKUP,
        S_MISS,
        S_HIT_RETURN_WAIT,   // read line and then return to L1
        S_EVICT_CHECK,
        S_VICTIM_READ,       // read victim tag+data to prepare WB
        S_WB_ISSUE,
        S_WB_WAIT,
        S_INSTALL_LINE
    } state_t;

    state_t state, next_state;
    

       // ---------------- FIFO age tracking ----------------
	logic [31:0] fifo_age [NUM_WAYS-1:0]; // wide enough for NUM_WAYS, could be $clog2(NUM_WAYS)
	logic [31:0] max_age;
	logic [$clog2(NUM_WAYS)-1:0] repl_way;
	
	logic free_found;

	// reset fifo_age
	always_ff @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
		    for (int i = 0; i < NUM_WAYS; i=i+1) 
		    	fifo_age[i] <= 0;
		end 
		else 
			
			if (state == S_INSTALL_LINE) begin
				for (int i = 0; i < NUM_WAYS; i=i+1) begin
				    if (fifo_age[i] > 0) 
				    	fifo_age[i] <= fifo_age[i] + 1;
				end

				// assign age 1 to newly installed line
				fifo_age[repl_way] <= 1;
			end
			else if(state == S_HIT_RETURN_WAIT || state == S_WB_WAIT) begin
				if(tag_invalidate_en == 1'b1)
					fifo_age[tag_hit_way] <= 0;
			end
	end

	// replace repl_way usage with max age selection for eviction
	always_comb begin
		max_age  = '0;
		repl_way = '0;
		
		free_found = 1'b0;

		for (int i = 0; i < NUM_WAYS; i = i + 1) begin
		    // if we haven't yet found a free way, check for it first
		    if (!free_found && fifo_age[i] == 0) begin
		        repl_way   = i[$clog2(NUM_WAYS)-1:0];
		        free_found = 1'b1;       // remember we found the first free way
		        // do NOT update max_age any more (we found free slot)
		    end
		    // only consider max-age selection while we haven't found a free slot
		    else if (!free_found) begin
		        if (fifo_age[i] > max_age) begin
		            max_age  = fifo_age[i];
		            repl_way = i[$clog2(NUM_WAYS)-1:0];
		        end
		    end
		    // if free_found==1 we simply skip updates for subsequent indices
		end
		
	end
    
    
	


    // ---------- captured registers ----------
    // For installs (eviction from L1)
    logic [TAG_WIDTH-1:0]    evict_tag_r;
    logic [LINE_BYTES*8-1:0] evict_line_r;
    logic                    evict_dirty_r;
    logic                    evict_pending;
    
    
   always_comb begin
		evict_pending = 1'b0;
   		if (evict_valid && !evict_pending) begin
	        evict_tag_r  	= evict_tag;
	        evict_line_r 	= evict_line;
	        evict_dirty_r	= evict_dirty;
	        evict_pending 	= 1'b1;
	    end else if (state == S_INSTALL_LINE) begin
	        evict_pending 	= 1'b0;
	    end
   end
    
/*
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            evict_tag_r  <= '0;
            evict_line_r <= '0;
            evict_dirty_r <= 1'b0;
            evict_pending <= 1'b0;
        end else begin
            if (evict_valid && !evict_pending) begin
                evict_tag_r  	<= evict_tag;
                evict_line_r 	<= evict_line;
                evict_dirty_r	<= evict_dirty;
                evict_pending 	<= 1'b1;
            end else if (state == S_INSTALL_LINE) begin
                evict_pending 	<= 1'b0;
            end
        end
    end
*/
    // For read-back / write-back: capture victim line's tag & data before mem write
    logic [TAG_WIDTH-1:0] victim_tag_r;
    logic [LINE_BYTES*8-1:0] victim_data_r;

    // ---------- FSM ----------
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)begin 
        	state <= S_IDLE;
        end
        else state <= next_state;
    end

    // response registers to L1 probe
    logic [LINE_BYTES*8-1:0] probe_line_reg;
    logic probe_hit_reg;
    logic probe_dirty_reg;
    logic probe_ready_reg;
    
    logic tag_valid_read_r;
    logic tag_dirty_read_r;

    assign probe_line = probe_line_reg;
    assign probe_dirty = probe_dirty_reg;
    assign probe_hit  = probe_hit_reg;
    assign probe_ready = probe_ready_reg;
    assign vc_ready = vc_ready_reg;
    

    // default assignments before case
    always_comb begin
        // default control signals
        tag_write_en = 1'b0;
        tag_read_en = 1'b0; 
        tag_in       = '0;
        tag_dirty_in = 1'b0;
        tag_invalidate_en = 1'b0;
        tag_way_index = repl_way;
        tag_read_way = '0;

        data_write_en = 1'b0;
        data_write_way = repl_way;
        data_write_data = '0;
        data_read_en = 1'b0;
        data_read_way = '0;

        mem_req = 1'b0;
        mem_req_write = 1'b0;
        mem_req_tag = '0;
        mem_req_wdata = '0;

        //repl_way_advance = 1'b0;

        //probe_line_reg = '0;
        //probe_hit_reg  = 1'b0;
        
        //vc_ready_reg = 1'b0;
        
        //tag_valid_read_r = 1'b0;
    	//tag_dirty_read_r = 1'b0;

        next_state = state;

        unique case (state)
            // -------------------------------------------------
            S_IDLE: begin
            	//vc_ready_reg = 1'b1;
                // prioritize probe if present; otherwise handle pending evict
                if (probe_valid == 1'b1) begin
                    next_state = S_PROBE_LOOKUP;
                    //vc_ready_reg = 1'b0;
                end else if (evict_pending == 1'b1) begin
                    next_state = S_EVICT_CHECK;
                    //vc_ready_reg = 1'b0;
                end
            end

            // lookup the probe_tag (combinational hit provided by tag_store_vc)
            S_PROBE_LOOKUP: begin
                // tag_store_vc's combinational hit is driven by probe_tag -> hit & tag_hit_way
                if (tag_hit) begin
                    // start reading the line from data array
                    data_read_en = 1'b1;
                    data_read_way = tag_hit_way;
                    //probe_line_reg = data_read_data;
                    // go wait one cycle to capture data_read_data
                    next_state = S_HIT_RETURN_WAIT;
                end else begin
                    // miss: vc does not fetch; inform L1
                    //probe_hit_reg = 1'b0;
                    next_state = S_MISS;
                end
            end
            
            S_MISS: begin
            	//probe_hit_reg = 1'b0;
            	next_state = S_IDLE;
            end

            // after requesting data_read_en in previous cycle, capture it and return
            S_HIT_RETURN_WAIT: begin
                // captured data_read_data is available combinationally; provide to L1
                //probe_hit_reg = 1'b1;
                //probe_line_reg = data_read_data;
                //probe_line_reg = data_read_data;
                // now invalidate that way (remove from vc)
                tag_invalidate_en = 1'b1;
                tag_way_index = tag_hit_way;    // invalidate the returned way
                // also clear the data entry by writing zeros
                data_write_en = 1'b1;
                data_write_way = tag_hit_way;
                data_write_data = '0;
                // advance FIFO (slot freed counts as progressed)
                //repl_way_advance = 1'b1;
                next_state = S_IDLE;
            end

            // check whether we must write-back the current repl_way victim before installing
            S_EVICT_CHECK: begin
                // We need tag & dirty info for repl_way; request a tag read and data read
                tag_read_way = repl_way;
                tag_read_en = 1'b1;
                data_read_en = 1'b1;
                data_read_way = repl_way;
                // move to victim read to capture them next cycle
                next_state = S_VICTIM_READ;
            end

            // capture victim tag/data and decide whether to WB
            
            S_VICTIM_READ: begin
                if (tag_valid_read_r && tag_dirty_read_r) begin
                	next_state = S_WB_ISSUE;
                end else begin
                    next_state = S_INSTALL_LINE;
                end
            end
            

            // issue write-back of victim (use captured victim_tag_r/victim_data_r)
            S_WB_ISSUE: begin
                mem_req = 1'b1;
                mem_req_write = 1'b1;
                mem_req_tag = victim_tag_r;
                mem_req_wdata = victim_data_r;
                next_state = S_WB_WAIT;
            end

            // wait for memory ack/response that WB completed
            S_WB_WAIT: begin
                mem_req = 1'b1;
                mem_req_write = 1'b1;
                mem_req_tag = victim_tag_r;
                mem_req_wdata = victim_data_r;
                if (mem_resp_valid) begin
                    // clear victim tag/dirty/valid and proceed to install new line
                    tag_invalidate_en = 1'b1;
                    tag_way_index = repl_way;
                    data_write_en = 1'b1;
                    data_write_way = repl_way;
                    data_write_data = '0; // will be overwritten in INSTALL_LINE
                    next_state = S_INSTALL_LINE;
                end
                else 
                	next_state = S_WB_WAIT;
            end

            // install the captured evicted line from L1 into repl_way
            S_INSTALL_LINE: begin
                // write tag + data into repl_way
                tag_write_en = 1'b1;
                tag_way_index = repl_way;
                tag_in = evict_tag_r;
                tag_dirty_in = evict_dirty_r;

                data_write_en = 1'b1;
                data_write_way = repl_way;
                data_write_data = evict_line_r;

                // mark done & advance replacement pointer
                //repl_way_advance = 1'b1;
                //evict_ack <= 1'b1;
                // ack to L1 that we accepted the evicted line
                // (evict_ack is deasserted elsewhere by default; set here)
                next_state = S_IDLE;
            end

            default: next_state = S_IDLE;
        endcase
    end

    // Sequential outputs / ack logic
    
    
    // evict_ack: assert for one cycle when we consumed evict_pending and installed
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            evict_ack <= 1'b0;
        end else begin
            if (state == S_INSTALL_LINE)
               evict_ack <= 1'b1;
            else
               evict_ack <= 1'b0;
        end
    end
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            probe_ready_reg <= 1'b0;
            probe_hit_reg <= 1'b0;
        end else begin
            if (state == S_MISS) begin
               probe_ready_reg <= 1'b1;
               probe_hit_reg <= 1'b0;
            end
            else if (state == S_HIT_RETURN_WAIT) begin
               probe_ready_reg <= 1'b1;
               probe_hit_reg <= 1'b1;
            end
            else begin
               probe_ready_reg <= 1'b0;
               probe_hit_reg <= 1'b0;
        	end
        end
    end
 
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            vc_ready_reg <= 1'b1;
        end else begin
            if (state == S_IDLE)  begin
               if (probe_valid == 1'b1)
                    vc_ready_reg <= 1'b0;
               else if(evict_pending)
               		vc_ready_reg <= 1'b0;
               else
               		vc_ready_reg <= 1'b1;
            end
            else
            	vc_ready_reg <= 1'b0;
        end
    end

    
    //UPDATING THE PROBE_LINE_REG ONLY IN THE S_PROBE_LOOKUP WHICH WOULD BE ACCEPTED BY L1 ONLY WHEN HIT OCCURS
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            probe_line_reg <= '0;
            probe_dirty_reg <= '0;
        end 
        else begin
            if (state == S_PROBE_LOOKUP) begin
            	probe_line_reg <= data_read_data;
            	probe_dirty_reg <= tag_dirty_read;
            end
        end
    end
	
	
    // capture victim_tag_r and victim_data_r registers properly in sequential domain
    // (we assigned them in combinational states above; ensure they are sequentially updated)
    // To avoid latches and ensure stable values, capture at clock boundary when we request reads.
    // We'll implement a simple capture when moving into S_VICTIM_READ:
  
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            victim_tag_r <= '0;
            victim_data_r <= '0;
            tag_valid_read_r <= '0;
            tag_dirty_read_r <= '0;
        end else begin
            if(state == S_EVICT_CHECK) begin
            	victim_tag_r <= tag_read_data;   // tag_read_data is comb from tag_store_vc read_en previous cycle
                victim_data_r <= data_read_data; // data_read_data is comb from data_store read_en previous cycle
            	tag_valid_read_r <= tag_valid_read;
            	tag_dirty_read_r <= tag_dirty_read;
            end
       end
    end
  
endmodule

