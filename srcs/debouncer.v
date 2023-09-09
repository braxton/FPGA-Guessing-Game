module debouncer(clean, button_push, clk);
    input button_push, clk;
    output reg clean;
    
    reg output_exist;
    reg [1:0] deb_count;
    // 3 for testbench
    // 20 for fpga
    parameter MAX = 2'b10;
    
    always @(posedge clk) begin
        if (button_push) begin
            if (!output_exist) begin
                if (deb_count == MAX) begin
                    clean <= 1;
                    deb_count <= 0;
                    output_exist <= 1;
                end else deb_count <= deb_count + 1;
            end else clean <= 0;
        end else begin
            clean <= 0;
            deb_count <= 0;
            output_exist <= 0;
        end
    end
endmodule
