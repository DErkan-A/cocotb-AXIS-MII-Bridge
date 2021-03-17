/*
 * Module `g40_2_mii`
 *
 * Bu modülün temel amacı "bits256_divider", "fifo_async" ve 
 * "ready_generator" modüllerini birleştirmektir.
 * 
 * Modülün portları ve parametreleri şu şekildedir:
 *   --> "parameter sig_stream_width: 40G modülünden gelen 
 *     datanın uzunluğunu temsil eder.
 *   --> "parameter sig_keep_width: 40G modülünden gelen keep
 *     sinyalinin uzunluğunu temsil eder.
 *   --> "parameter sig_mii_width": MII datasının uzunluğunu temsil
 *     eder. 
 *   --> "parameter sig_user_width": 40G modülünden gelen user
 *     sinyalinin uzunluğunu temsil eder. Sadece ilk 9 biti errorları
 *     gösterir. Geri kalan kısım llength/type ve reserved bitlerdir.
 *   --> "parameter READ_DATA_WIDTH": Okunacak verinin genişliğini 
 *     temsil eder.
 *   --> "parameter WRITE_DATA_WIDTH": Yazılacak verinin genişliğini 
 *     temsil eder.
 *   --> "MII_aclk": Okuma clock'udur ve MII tarafını temsil eder. 
 *     Hızı 25 MHz'tir (1 Gbps hız kullanılmadığı için hızı bu 
 *     şekildedir.).
 *   --> "axis_aclk": Yazma clock'udur ve AXI stream tarafını temsil
 *     eder (40G ETHERNET MODULE). Hızı 156.25 MHz'tir.
 *   --> "reset": Bütün sistemi sıfırlar ve synchronous bir
 *     şekilde çalışır.
 *   --> "mii_txd": MII tarafına gidecek datayı temsil eder. MII 
 *     tarafına gidecek data 8 bittir fakat bu bitlerin sadece 4 
 *     bitinde data bulunmaktadır.
 *   --> "mii_tx_dv": MII tarafına gidecek valid bitidir.
 *   --> "mii_tx_er": MII tarafına gidecek error bitidir.
 *   --> "tx_axis_tdata": 40G modülünden gelecek olan AXI stream datasını
 *     temsil eder.
 *   --> "s_axis_tready": 40G modülünden gelecek olan AXI stream ready
 *     sinyalini temsil eder.
 *   --> "s_axis_tvalid": 40G modülünden gelecek olan AXI stream valid
 *     sinyalini temsil eder.
 *   --> "s_axis_tlast": 40G modülünden gelecek olan AXI stream last
 *     sinyalini temsil eder.
 *   --> "s_axis_tkeep": 40G modülünden gelecek olan AXI stream keep
 *     datasını temsil eder.
 *   --> "s_axis_tuser": 40G modülünden gelecek olan AXI stream user
 *     datasını temsil eder.
 *   --> "s_axis_terr": 40G modülünden gelecek olan error datasını
 *     temsil eder.
 */  
 module g40_2_mii  #(
     parameter STREAM_DATA_WIDTH  = 256,
     parameter KEEP_WIDTH         = STREAM_DATA_WIDTH / 8,
     parameter MII_DATA_WIDTH     = 4,
     parameter ID_DEST_WIDTH      = 4) 
    (
     // Clocks and Resets
     input                            mii_clk,
     input                            axis_clk,
     input                            mii_reset_n,
     input                            axis_reset_n,
     
     // MII Signals
     output [MII_DATA_WIDTH-1 : 0]    mii_txd,
     output                           mii_tx_en,
     output                           mii_tx_er,
     
     // AXI Stream Signals
     output                           s_axis_tready,
     input                            s_axis_tvalid,
     input  [STREAM_DATA_WIDTH-1 : 0] s_axis_tdata,
     input  [KEEP_WIDTH-1 : 0]        s_axis_tkeep,
     input                            s_axis_tlast,
     input                            s_axis_terr,
     input [ID_DEST_WIDTH-1 : 0]      s_axis_tid,
     input [ID_DEST_WIDTH-1 : 0]      s_axis_tdest
    );

    localparam READ_DATA_WIDTH   = 290; //256 + 32 + 1 + 1 = 290
    localparam WRITE_DATA_WIDTH  = READ_DATA_WIDTH;
    
    // --------------------------------------------------
    // Aşağıdaki wireların tanımlamaları gönderildikleri 
    // modüller içerisinde yapılmıştır.
    wire [STREAM_DATA_WIDTH-1 : 0] data_wire; 
    wire [KEEP_WIDTH-1 : 0]        keep_wire; 
    wire                           error_wire; 
    wire                           last_wire;
    wire                           full_flag;
    wire                           empty_flag;
    wire                           raddr_activater;

    // -------------
    wire                           data_valid;
    wire                           wr_rst_busy;
    wire                           rd_rst_busy;
    
    
    // AXI Stream "user" sinyalinin ilk 9 biti errorları
    // gösterir. Herhangi bir biti 1 olduğu zaman bütün
    // paket discard edilir. Bu yüzden aşağıdaki gibi
    // 1 bite indirgeme kaynak kullanımı açısından 
    // daha verimli oalcaktır.
    //assign user_one_bit = (s_axis_tuser[8:0] != 0);
    // ---------------------------------------------------

    // ----------------------------------------------------------------------
    // -- PORT MAPLER -- //
    bits256_divider #(
        .sig_stream_width ( STREAM_DATA_WIDTH ),
        .sig_keep_width   ( KEEP_WIDTH        ),
        .sig_mii_width    ( MII_DATA_WIDTH    )
    )
    bits256_divider(
        .MII_aclk         ( mii_clk           ),
        .reset            ( mii_reset_n       ),
        .empty_flag       ( empty_flag        ),
        .mii_tx_dv        ( mii_tx_en         ),
        .mii_tx_er        ( mii_tx_er         ),
        .mii_txd          ( mii_txd           ),
        .raddr_activater  ( raddr_activater   ),
        .data             ( data_wire         ),
        .keep             ( keep_wire         ),
        .error_40G        ( error_wire        ),
        .last             ( last_wire         ),
        .data_valid       ( data_valid        ),
        .rd_rst_busy      ( rd_rst_busy       )
    );
    
    fifo_async_g40_2_mii #(
       .WRITE_DATA_WIDTH  ( WRITE_DATA_WIDTH                                  ),
       .READ_DATA_WIDTH   ( READ_DATA_WIDTH                                   )
    )    
    fifo_async_ii (
       .rd_clk      ( mii_clk                                                 ),
       .wr_clk      ( axis_clk                                                ),
       .rst         ( !axis_reset_n                                           ),
       .rd_en       ( raddr_activater                                         ),
       .din         ( {s_axis_tlast, s_axis_terr, s_axis_tkeep, s_axis_tdata} ),
       .wr_en       ( s_axis_tvalid && s_axis_tready                          ),
       .data_valid  ( data_valid                                              ),
       .full        ( full_flag                                               ),
       .empty       ( empty_flag                                              ),
       .dout        ( {last_wire, error_wire, keep_wire, data_wire}           ),
       .wr_rst_busy ( wr_rst_busy                                             ),
       .rd_rst_busy ( rd_rst_busy                                             )
    );

    ready_generator_mii ready_generator_i ( 
       .axis_aclk     ( axis_clk      ), 
       .s_axis_tready ( s_axis_tready ), 
       .full_flag     ( full_flag     ),
       .wr_rst_busy   ( wr_rst_busy   )
    );
    
    
//    reg  [11:0] gelen_last_num = 0;
//    wire [11:0] giden_last_num;
//    wire        empty_helper;
    
//    last_keeper last_keeper_i (
//    .gelen_last_num ( gelen_last_num),
//    .giden_last_num ( giden_last_num),
//    .empty_helper   ( empty_helper)
//    );
//    ila_axis256 ila_axis256_i (
//    .clk(axis_aclk),
//   .probe0(s_axis_tdata),
//    .probe1(s_axis_tkeep),
//    .probe2(s_axis_tready),
//    .probe3(s_axis_tlast),
//    .probe4(s_axis_tvalid),
//    .probe5(s_axis_tuser)
//    );
    
    // ------------------------------------------------------------------------

 endmodule