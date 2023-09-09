module clk_divider(
	input clk_in,
	input rst,
	output reg divided_clk
    );
	 
parameter toggle_value = 24'b100110001001011010000000; 
	 
reg[27:0] cnt;

always@(posedge clk_in or posedge rst)
begin
	if (rst==1) begin
		cnt <= 0;
		divided_clk <= 0;
	end
	else begin
		if (cnt==toggle_value) begin
			cnt <= 0;
			divided_clk <= ~divided_clk;
		end
		else begin
			cnt <= cnt +1;
			divided_clk <= divided_clk;		
		end
	end

end
endmodule
