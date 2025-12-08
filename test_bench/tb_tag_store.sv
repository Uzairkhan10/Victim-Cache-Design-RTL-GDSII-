`timescale 1ns/1ps

module tb_tag_store;

    parameter TAG_WIDTH = 4;
    parameter NUM_WAYS  = 4;

    logic clk, rst_n;

    logic write_en, read_en, lookup_en;
    logic [TAG_WIDTH-1:0] tag_in;
    logic [$clog2(NUM_WAYS)-1:0] way_index_in;

    logic hit;
    logic [$clog2(NUM_WAYS)-1:0] hit_way_index;

    logic valid_clear, dirty_set, dirty_clear;

    logic valid_read, dirty_read;
    logic [TAG_WIDTH-1:0] tag_read;

    //  DUT INSTANTIATION 
    tag_store #(
        .TAG_WIDTH(TAG_WIDTH),
        .NUM_WAYS(NUM_WAYS)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .write_en(write_en),
        .read_en(read_en),
        .lookup_en(lookup_en),
        .tag_in(tag_in),
        .way_index_in(way_index_in),
        .hit(hit),
        .hit_way_index(hit_way_index),
        .valid_clear(valid_clear),
        .dirty_set(dirty_set),
        .dirty_clear(dirty_clear),
        .valid_read(valid_read),
        .dirty_read(dirty_read),
        .tag_read(tag_read)
    );

    //  CLOCK 
    always #5 clk = ~clk;

    //  TASKS 

    task reset_dut();
        rst_n = 0;
        write_en = 0;
        read_en = 0;
        lookup_en = 0;
        valid_clear = 0;
        dirty_set = 0;
        dirty_clear = 0;
        tag_in = 0;
        way_index_in = 0;
        #20;
        rst_n = 1;
        #10;
    endtask

    task write_tag(input int way, input int tag);
        @(posedge clk);
        write_en = 1;
        tag_in = tag;
        way_index_in = way;
        @(posedge clk);
        write_en = 0;
    endtask

    task read_tag(input int way);
        @(posedge clk);
        read_en = 1;
        way_index_in = way;
        @(posedge clk);
        read_en = 0;
    endtask

    task lookup_tag_task(input int tag);
        @(posedge clk);
        lookup_en = 1;
        tag_in = tag;
        @(posedge clk);
        lookup_en = 0;
    endtask

    task clear_valid(input int way);
        @(posedge clk);
        valid_clear = 1;
        way_index_in = way;
        @(posedge clk);
        valid_clear = 0;
    endtask

    task set_dirty_bit(input int way);
        @(posedge clk);
        dirty_set = 1;
        way_index_in = way;
        @(posedge clk);
        dirty_set = 0;
    endtask

    task clear_dirty_bit(input int way);
        @(posedge clk);
        dirty_clear = 1;
        way_index_in = way;
        @(posedge clk);
        dirty_clear = 0;
    endtask

    //  TEST SEQUENCE 
    initial begin
        clk = 0;
        reset_dut();

        $display(" WRITE TAGS");
        write_tag(0, 4'hA);
        write_tag(1, 4'hB);
        write_tag(2, 4'hC);

        $display("READ BACK ");
        read_tag(0);  #1 $display("WAY0 → TAG=%h VALID=%b DIRTY=%b", tag_read, valid_read, dirty_read);
        read_tag(1);  #1 $display("WAY1 → TAG=%h VALID=%b DIRTY=%b", tag_read, valid_read, dirty_read);
        read_tag(2);  #1 $display("WAY2 → TAG=%h VALID=%b DIRTY=%b", tag_read, valid_read, dirty_read);

        $display(" LOOKUP (HIT TEST) ");
        lookup_tag_task(4'hB);
        #1 $display("Lookup B → HIT=%b WAY=%d", hit, hit_way_index);

        lookup_tag_task(4'hC);
        #1 $display("Lookup C → HIT=%b WAY=%d", hit, hit_way_index);

        $display(" LOOKUP (MISS TEST) ");
        lookup_tag_task(4'hF);
        #1 $display("Lookup F → HIT=%b", hit);

        $display("DIRTY BIT TEST");
        set_dirty_bit(1);
        read_tag(1);  #1 $display("After DIRTY SET → WAY1 DIRTY=%b", dirty_read);

        clear_dirty_bit(1);
        read_tag(1);  #1 $display("After DIRTY CLEAR → WAY1 DIRTY=%b", dirty_read);

        $display(" VALID CLEAR TEST ");
        clear_valid(1);
        read_tag(1);  #1 $display("After VALID CLEAR → WAY1 VALID=%b", valid_read);

        $display("FINAL LOOKUP AFTER INVALIDATE");
        lookup_tag_task(4'hB);
        #1 $display("Lookup B After Invalidate → HIT=%b", hit);

        $display("DONE ALL TESTS COMPLETED");
        #20;
        $stop;
    end

endmodule

