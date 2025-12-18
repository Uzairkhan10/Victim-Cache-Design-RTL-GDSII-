`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/08/2025 09:11:22 PM
// Design Name: 
// Module Name: tb_tag_store
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
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

///DUT INSTANTIATION
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

initial clk = 0;
always #5 clk =~ clk;

 ///TASKS

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
        @(posedge clk);
        write_tag(1, 4'hB);
        write_tag(2, 4'hC);

        $display("READ BACK ");
        read_tag(0);  
        read_tag(1); 
        read_tag(2); 

        lookup_tag_task(4'hB);

        lookup_tag_task(4'hC);

        lookup_tag_task(4'hF);
        
        set_dirty_bit(1);
        read_tag(1);

        clear_dirty_bit(1);
        read_tag(1);

        clear_valid(1);
        read_tag(1); 

       
        lookup_tag_task(4'hB);

        #20;
        $stop;
    end

endmodule
