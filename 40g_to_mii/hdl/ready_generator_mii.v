/*
 * Module `ready_generator`
 *
 * Bu modülün temel amacı AXI Stream "ready" sinyalini üretmektir.
 * 
 * Modülün portları ve parametreleri şu şekildedir:
 *   --> "axis_aclk": Yazma clock'udur ve AXI stream tarafını temsil
 *     eder (40G ETHERNET MODULE). Hızı 156.25 MHz'tir.
 *   --> "tx_axis_tready": 40G modülünden gelecek olan AXI stream 
 *     ready sinyalini temsil eder.
 *   --> "full_flag": Memory'nin dolu olup olmadığını bilmek için 
 *     vardır.
 *   --> "wr_rst_busy": Memory'nin data yazımı için meşgul olup 
 *     olmadığını haber veren bittir.
 */    
 module ready_generator_mii (
    axis_aclk,
    s_axis_tready,
    full_flag,
    wr_rst_busy
    );
    
    // ---------------------------------
    output reg s_axis_tready = 0;
    input  axis_aclk, full_flag;
    input wr_rst_busy;
    // ---------------------------------
    
   /*
    * Bu processte AXI Stream "ready" sinyaline
    * atamalar yapılmaktadır.
    *
    * "full_flag" ve "wr_rst_busy" sinyallerinin
    * 0 olması halinde memory yazılmaya hazır
    * demektir. Bu durumda ready sinyali 1 
    * yapılarak 40G tarafına haber verilir.
    */     
    always @(posedge axis_aclk)   
    begin
      s_axis_tready <= 1'b0;
      if (!full_flag && !wr_rst_busy) begin
        s_axis_tready <= 1'b1;
      end
    end
    
 endmodule