module tag_store #(parameter TAG_WIDTH = 4, NUM_WAYS = 4)(
	input clk, rst_n,
	
	input logic write_en, read_en, lookup_en,
	input logic [(TAG_WIDTH - 1) : 0] tag_in,
	input logic [($clog2(NUM_WAYS) - 1) : 0] way_index_in,
	
	output logic hit,
	//output logic [(NUM_WAYS - 1) : 0] hit_ways_vector, //each bit index representing the way number
	output logic [($clog2(NUM_WAYS) - 1) : 0] hit_way_index, //here index the way number
	 
	input logic valid_clear, dirty_set, dirty_clear,
	
	output logic valid_read, dirty_read,
	//output logic [(TAG_WIDTH - 1) : 0] tag_read	
	output logic [(NUM_WAYS - 1) : 0] valid_vector,
	output logic [(NUM_WAYS - 1) : 0] dirty_vector
);
		
	logic [(TAG_WIDTH - 1) : 0] tag_array [(NUM_WAYS - 1) : 0];
	logic valid_array [(NUM_WAYS - 1) : 0];
	logic dirty_array [(NUM_WAYS - 1) : 0];
	
	logic [(NUM_WAYS - 1) : 0] hit_vector; //for debugging in case more than 1 hit occurs 
	
	logic [(TAG_WIDTH - 1) : 0] lookup_tag;
	logic [(TAG_WIDTH - 1) : 0] write_tag;
	
	logic [($clog2(NUM_WAYS) - 1) : 0] write_way_index;
	logic [($clog2(NUM_WAYS) - 1) : 0] read_way_index;
	logic [($clog2(NUM_WAYS) - 1) : 0] invalidate_way_index;
	logic [($clog2(NUM_WAYS) - 1) : 0] set_dirty_way_index;
	logic [($clog2(NUM_WAYS) - 1) : 0] clear_dirty_way_index;
	
	assign write_way_index = way_index_in;
	assign read_way_index = way_index_in;
	assign invalidate_way_index = way_index_in;
	assign set_dirty_way_index = way_index_in;
	assign clear_dirty_way_index = way_index_in;
	
	assign lookup_tag = tag_in;
	assign write_tag = tag_in;
	
	
	//combinational associative lookup
	always_comb begin
		//valid_vector = '0;
		dirty_vector = '0;
		valid_vector = '0;
		hit_vector = '0;
		if(lookup_en)begin
			//valid_vector = '0;
			//dirty_vector = '0;
			//hit_vector = '0;
			for(int i = 0; i < NUM_WAYS; i++) begin
				valid_vector[i] = valid_array[i];
				dirty_vector[i] = dirty_array[i];	
				if(valid_array[i] && (tag_array[i] == lookup_tag)) begin
					hit_vector[i] = 1'b1;
				end
			end
		end
	end
	
	always_comb begin
		hit = |hit_vector;
		hit_way_index = '0;
		if(hit)begin
			for(int i = 0; i < NUM_WAYS; i++) begin
				if(hit_vector[i]) begin
					hit_way_index = i[($clog2(NUM_WAYS) - 1) : 0];		
				end
			end
		end
	end
	
	//combinational read			
	always_comb begin
		if(read_en) begin
			dirty_read = dirty_array[read_way_index];
			valid_read = valid_array[read_way_index];		
		end
		else begin
			dirty_read = 1'b0;
			valid_read = 1'b0;		
		end
	end
	
	
	//write sequentially
	always_ff @(posedge clk or negedge rst_n) begin
		if(!rst_n)begin
			for(int i = 0; i < NUM_WAYS; i++) begin
				tag_array[i] <= '0;
				valid_array[i] <= 1'b0;
				dirty_array[i] <= 1'b0;
			end
		end
		
		else begin
			if(write_en) begin
				tag_array[write_way_index] <= write_tag;
				valid_array[write_way_index] <= 1'b1;
				dirty_array[write_way_index] <= 1'b0;
			end
			
			// Invalidate specific way
            else if (valid_clear) begin
                valid_array[invalidate_way_index] <= 1'b0;
                // tagging the tag value retained but valid cleared
            end

            // Set dirty
            else if (dirty_set) begin
                dirty_array[set_dirty_way_index] <= 1'b1;
            end

            // Clear dirty
            else if (dirty_clear) begin
                dirty_array[clear_dirty_way_index] <= 1'b0;
            end
		end
	end
endmodule




