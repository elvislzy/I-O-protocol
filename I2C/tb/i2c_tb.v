// -----------------------------------------------------------------
// Filename: i2c_tb.v                                             
// 
// Company: 
// Description:                                                     
// 
// 
//                                                                  
// Author: Elvis.Lu<lzyelvis@gmail.com>                            
// Create Date: 03/06/2022                                           
// Comments:                                                        
// 
// -----------------------------------------------------------------


module i2c_tb;

// i2c Parameters
parameter PERIOD = 2 ;
parameter DIV  = 100;
parameter DATA_WIDTH = 32;

// i2c Inputs
reg   clk                                  = 0 ;
reg   rst_n                                = 0 ;
reg   start                                = 0 ;
reg   mode                                 = 0 ;
reg   [6:0]  slave_addr_master             = 0 ;
reg   [7:0]  data_addr                     = 0 ;
reg   [DATA_WIDTH-1:0]  data_in            = 0 ;

reg   [6:0]  slave_addr_slave              = 0 ;
reg   [DATA_WIDTH-1:0]  r_data             = 0 ;

// i2c_slave Outputs
wire  [7:0]  data_addr_out                 ;
wire  [DATA_WIDTH-1:0]  w_data             ;
wire  w_en                                 ;

// i2c_master Outputs
wire  [DATA_WIDTH-1:0]  data_out           ;
wire  data_rdy                             ;
wire  scl                                  ;

// i2c_master Bidirs
wire  sda                                  ;


initial
begin
    forever #(PERIOD/2)  clk=~clk;
end

initial
begin
    #(PERIOD*2) rst_n  =  1;
end

i2c_master #(.DATA_WIDTH(DATA_WIDTH), .DIV ( DIV ))
 u_i2c_master (
    .clk                     ( clk                          ),
    .rst_n                   ( rst_n                        ),
    .start                   ( start                        ),
    .mode                    ( mode                         ),
    .slave_addr              ( slave_addr_master  [6:0]     ),
    .data_addr               ( data_addr   [7:0]            ),
    .data_in                 ( data_in     [DATA_WIDTH-1:0] ),

    .data_out                ( data_out    [DATA_WIDTH-1:0] ),
    .data_rdy                ( data_rdy                     ),
    .scl                     ( scl                          ),

    .sda                     ( sda                          )
);

i2c_slave  #(.DATA_WIDTH(DATA_WIDTH))
u_i2c_slave (
    .clk                     ( clk                          ),
    .rst_n                   ( rst_n                        ),
    .slave_addr              ( slave_addr_slave  [6:0]      ),
    .r_data                  ( r_data      [DATA_WIDTH-1:0] ),

    .data_addr               ( data_addr_out   [7:0]        ),
    .w_data                  ( w_data      [DATA_WIDTH-1:0] ),
    .w_en                    ( w_en                         ),
    .scl                     ( scl                          ),

    .sda                     ( sda                          )
);


initial
begin
    // write test 1
    #100;
    mode = 1'b1;
    slave_addr_master = 7'b100_1101;
    slave_addr_slave = 7'b100_1101;

    data_addr = 8'b0110_1001;
    data_in = 32'hab00_0001;

    r_data = 0;

    start = 1'b1;
    #10
    start = 1'b0;

    // write test 2
    @(posedge data_rdy);
    #10000
    slave_addr_master = 7'b001_0011;
    slave_addr_slave = 7'b001_0011;
    data_addr = 8'b1101_1110;
    data_in = 32'hcd00_0001;

    start = 1'b1;
    #10
    start = 1'b0;

    // read test 1
    @(posedge data_rdy);
    #10000
    mode = 1'b0;
    slave_addr_master = 7'b001_0011;
    slave_addr_slave = 7'b001_0011;
    data_addr = 8'b1101_1110;
    r_data = 32'hbcd0_a001;

    start = 1'b1;
    #10
    start = 1'b0;

    // read test 2
    @(posedge data_rdy);
    #10000
    mode = 1'b0;
    slave_addr_master = 7'b101_0011;
    slave_addr_slave = 7'b101_0011;
    data_addr = 8'b1111_1110;
    r_data = 32'hacd0_bbb1;

    start = 1'b1;
    #10
    start = 1'b0;


    #50000;
    $finish;
end


reg [DATA_WIDTH-1:0]    w_data_tmp;
initial begin
    forever begin
        @(posedge w_en);
        w_data_tmp = w_data;
        if(w_data!=data_in) begin
            $fatal("write test case failed!");
            $finish;
        end
        #(PERIOD);
    end
end

reg [DATA_WIDTH-1:0]    data_out_tmp;
initial begin
    forever begin
        @(posedge data_rdy);
        data_out_tmp = data_out;
        if(data_out!=r_data) begin
            $fatal("read test case failed!");
            $finish;
        end
        #(PERIOD);
    end
end


endmodule