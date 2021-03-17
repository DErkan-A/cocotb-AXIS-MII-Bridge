 module bits256_divider #(
    parameter sig_stream_width = 256,
    parameter sig_keep_width   = sig_stream_width/8,
    parameter sig_mii_width    = 4) (
    MII_aclk,
    reset,
    mii_tx_dv,
    mii_tx_er,
    mii_txd,
    data,
    keep,
    last,
    error_40G,
    empty_flag,
    raddr_activater,
    data_valid,
    rd_rst_busy
    );
    
    // -----------------------------------------    
    output reg raddr_activater     = 0;
    output reg mii_tx_dv           = 0;
    output reg mii_tx_er           = 0;
    output reg [sig_mii_width-1:0] mii_txd = 0;      
    input  MII_aclk;
    input  reset;
    input  empty_flag;
    input  [sig_stream_width-1:0]  data;
    input  [sig_keep_width-1:0]    keep;
    input  error_40G;
    input  last;
    input  data_valid;
    input  rd_rst_busy;
    // -----------------------------------------    
    
    reg [2*sig_mii_width-1:0]      nibble_counter = 1;
    reg [6:0] intergap_cntr      = 0;
    //reg last_case_ctrl           = 1;
    //reg last_case                = 0;
    reg starting_case            = 1;
    reg [4:0] starting_case_cntr = 0;    
   // reg readable                 = 0;
   // reg new_data_req             = 1;
    // ---------------------------------------------------------------
    
    localparam DATA_OKUMA         = 1'b0;
    localparam IDLE               = 1'b1;
    
    localparam WRITING            = 2'b00;
    localparam INTERGAP           = 2'b01;
    localparam OTHER              = 2'b10;
    
        // STATELER
    reg [1 : 0] OKUMA     = 1'b0;
    reg [1 : 0] WRITE_MII = 2'b10;
    
    always @(posedge MII_aclk)
    begin    
      raddr_activater <= 0;
      mii_txd   <= 0;
      mii_tx_er <= 0;
      mii_tx_dv <= 0;
      if (!reset) begin
        nibble_counter <= 1;
        starting_case  <= 1'b1;
        intergap_cntr  <= 'b0;
        {mii_tx_dv, mii_tx_er, raddr_activater, mii_txd,starting_case_cntr} <= 0;
      end
      else begin
        case (OKUMA)
          DATA_OKUMA:
            begin
              if (data_valid) begin
                raddr_activater <= 0;
                nibble_counter  <= 1;
                WRITE_MII       <= WRITING;
                OKUMA           <= IDLE;
              end
              else begin
                if ( (!empty_flag && !rd_rst_busy && !raddr_activater) && (WRITE_MII != INTERGAP)) begin  //BURAYA DETAYLICA BİR BAK
                  raddr_activater <= 1;
                end
                else if ( empty_flag && !last && (WRITE_MII != INTERGAP) && (WRITE_MII != OTHER) && !raddr_activater) begin
                  raddr_activater <= 1;
                end
                else if (empty_flag && last) begin
                  raddr_activater <= 0;
                end
              end
            end
          IDLE:
            begin
              raddr_activater <= 0;
            end
          default: begin end
        endcase

        case (WRITE_MII)
          WRITING:
            begin
              if (starting_case) begin
                starting_case_cntr <= starting_case_cntr + 1;
                mii_tx_dv <= 1'b1;
                if (starting_case_cntr < 15) begin
                  mii_txd[3:0]  <= 4'b0101; 
                end
                else begin
                  mii_txd[3:0]   <= 4'b1101;
                  starting_case  <= 0;
                  nibble_counter <= 1;
                  starting_case_cntr <= 0;
                end             
              end
              else begin
                if (keep[(nibble_counter-1)/2] == 1'b1) begin                                                                                                        
                  mii_txd   <= data[(4*(nibble_counter))-1-:4];
                  {mii_tx_dv,mii_tx_er} <= {1'b1,error_40G};
                end 
                else begin
                  mii_txd               <= data[(4*(nibble_counter))-1-:4];
                  {mii_tx_dv,mii_tx_er} <= {1'b0,error_40G};
                end
                 
                if (nibble_counter < sig_stream_width/4-2) begin 
                  nibble_counter <= nibble_counter + 1;
                end 
                else if ( (nibble_counter >= sig_stream_width/4-2) && (nibble_counter <= sig_stream_width/4-1)) begin
                  if (nibble_counter <= sig_stream_width/4-2) begin
                    if (!last) begin
                      OKUMA <= DATA_OKUMA;
                    end
                  end
                  nibble_counter <= nibble_counter + 1;
                end
                else begin
                  if (last) begin
                    intergap_cntr <= 0;
                    WRITE_MII     <= INTERGAP;
                    starting_case <= 1;
                  end
                  else if (!last && empty_flag) begin
                    mii_tx_er     <= 1;
                    intergap_cntr <= 0;
                    WRITE_MII     <= INTERGAP;
                    starting_case <= 1;
                  end
                  nibble_counter  <= 1;
                end
              end
            end
          INTERGAP:
            begin
              if (intergap_cntr < 26) begin
                intergap_cntr          <= intergap_cntr + 1;
                {mii_tx_dv, mii_tx_er} <= 0;
                mii_txd                <= 0;
              end
              else begin
                WRITE_MII <= OTHER;
                intergap_cntr <= 0;
                OKUMA <= DATA_OKUMA;
              end
            end
          OTHER:
            begin
            
            end
          default: begin end
        endcase      
      end
    end
    /*
    always @(posedge MII_aclk)
    begin
      raddr_activater <= 0;
      mii_txd   <= 0;
      mii_tx_er <= error_40G;
      mii_tx_dv <= 0;
      if (!reset) begin
        nibble_counter <= 1;
        {starting_case, last_case_ctrl, intergap_cntr} <= 3'b110;
        {mii_tx_dv, mii_tx_er, raddr_activater, last_case, mii_txd,starting_case_cntr} <= 0;
      end
      else begin
        //== 1. KISIM ==//
        if (!empty_flag && !rd_rst_busy) begin  
          if (new_data_req) begin
            new_data_req    <= 0;  
            raddr_activater <= 1;
          end
          else begin
            if (data_valid) begin
              readable      <= 1;
              nibble_counter <= 1;
            end
          end
        end
        else begin
          if (nibble_counter >= 64) begin
            readable       <= 0;
            new_data_req   <= 1;
            nibble_counter <= 1;
          end  
        end
        
        //== 2. KISIM ==//
        if (readable) begin
          if (last && last_case_ctrl) begin
            last_case_ctrl    <= 0;
            if (error_40G) begin
            end 
            else begin
              last_case       <= 1;
            end
          end 
          if (intergap_cntr >= 26) begin
            if (starting_case) begin
              starting_case_cntr <= starting_case_cntr + 1;
              mii_tx_dv <= 1'b1;
              if (starting_case_cntr < 15) begin
                mii_txd[3:0]  <= 4'b0101; 
              end
              else begin
                mii_txd[3:0]  <= 4'b1101;
                starting_case <= 0;
              end
            end else begin
              starting_case_cntr <= 0;
              
              if (keep[(nibble_counter-1)/2] == 1'b1) begin                                                                                                        
                mii_txd   <= data[(4*(nibble_counter))-1-:4];
                mii_tx_dv <= 1'b1;
              end 
              else begin
                mii_txd               <= data[(4*(nibble_counter))-1-:4];
                {mii_tx_dv,mii_tx_er} <= {1'b0,1'b0};
              end
             
              if (nibble_counter < sig_stream_width/4-2) begin 
                nibble_counter <= nibble_counter + 1;
              end 
              else if ( (nibble_counter >= sig_stream_width/4-2) && (nibble_counter <= sig_stream_width/4-1)) begin
                if (nibble_counter <= sig_stream_width/4-2) begin
                  new_data_req <= 1;
                end
                nibble_counter <= nibble_counter + 1;
              end 
              else begin
                if (last_case || error_40G) begin
                  last_case <= 0;
                  intergap_cntr <= 0; 
                  starting_case <= 1;
                end
                
                if(!empty_flag) begin
                  nibble_counter <= 1;
                  last_case_ctrl <= 1;
                end
              end
            end
          end
          else begin
            intergap_cntr          <= intergap_cntr + 1;
            {mii_tx_dv, mii_tx_er} <= 0;
            mii_txd                <= 0;
            last_case              <= 0;
          end
        end  
        else begin 
          {mii_tx_dv, mii_tx_er} <= 0;
          last_case <= 0;
        end
      end
    end
    */
    
//    ila_bits256_divider ila_bits256_divider_i (
//        .clk(MII_aclk),
//        .probe0(data),
//        .probe1(keep),
//        .probe2(rd_rst_busy),
//        .probe3(last),
//        .probe4(empty_flag),
//        .probe5(raddr_activater),
//        .probe6(data_valid),
//        .probe7(reset),
//        .probe8(intergap_cntr),
//        .probe9(nibble_counter),
//        .probe10(OKUMA),
//        .probe11(0),
//        .probe12(starting_case),
//        .probe13(starting_case_cntr),
//        .probe14(WRITE_MII),
//        .probe15(0),
//        .probe16(mii_tx_dv),
//        .probe17(mii_tx_er),
//        .probe18(mii_txd)
//    );
    
 endmodule