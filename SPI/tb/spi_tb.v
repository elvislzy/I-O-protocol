// -----------------------------------------------------------------
// Filename: spi_tb.v                                             
// 
// Company: 
// Description:                                                     
// 
// 
//                                                                  
// Author: Elvis.Lu<lzyelvis@gmail.com>                            
// Create Date: 02/12/2022                                           
// Comments:                                                        
// 
// -----------------------------------------------------------------


module spi_tb;

// spi_master Parameters
parameter PERIOD = 10;  
parameter WIDTH = 8;
parameter DIV_N  = 2;   

// spi_master Inputs    
reg   clk                                  = 0 ;
reg   rst_n                                = 0 ;
reg   [WIDTH-1:0]  master_din              = 0 ;
reg   spi_start                            = 0 ;
reg   [1:0]  mode                          = 0 ;
reg   slave_in_vld                         = 0 ;
reg   [WIDTH-1:0]  slave_din               = 0 ;

// spi_master Outputs
wire  sclk                                 ;
wire  cs_en                                ;
wire  miso                                 ;
wire  mosi                                 ;
wire  spi_rdy                              ;
wire  [WIDTH-1:0]  master_dout             ;
wire  slave_out_rdy                        ;
wire  [WIDTH-1:0]  slave_dout              ;

initial
begin
    forever #(PERIOD/2)  clk=~clk;
end

initial
begin
    #(PERIOD*2) rst_n  =  1;
end

spi_master #(
    .DIV_N ( DIV_N ))
 u_spi_master (
    .clk                     ( clk                      ),
    .rst_n                   ( rst_n                    ),
    .master_din              ( master_din   [WIDTH-1:0] ),
    .spi_start               ( spi_start                ),
    .miso                    ( miso                     ),
    .mode                    ( mode         [1:0]       ),

    .sclk                    ( sclk                     ),
    .cs_en                   ( cs_en                    ),
    .mosi                    ( mosi                     ),
    .spi_rdy                 ( spi_rdy                  ),
    .master_dout             ( master_dout  [WIDTH-1:0] )
);

spi_slave  u_spi_slave (
    .clk                     ( clk                        ),
    .rst_n                   ( rst_n                      ),
    .sclk                    ( sclk                       ),
    .cs_en                   ( cs_en                      ),
    .mode                    ( mode           [1:0]       ),
    .slave_din               ( slave_din      [WIDTH-1:0] ),
    .mosi                    ( mosi                       ),

    .miso                    ( miso                       ),
    .slave_out_rdy           ( slave_out_rdy              ),
    .slave_dout              ( slave_dout     [WIDTH-1:0] )
);

initial
begin
    mode = 2'b00;
    slave_din   = 8'b11111010;
    master_din  = 8'b10101111;
    #(PERIOD*3)
    slave_in_vld = 1'b1;
    spi_start = 1'b1;
    #(PERIOD)
    spi_start = 1'b0;
    slave_in_vld = 1'b0;
    #1000;
    $finish;
end


endmodule