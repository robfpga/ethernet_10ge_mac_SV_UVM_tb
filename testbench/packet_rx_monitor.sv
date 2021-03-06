//////////////////////////////////////////////////////////////////////
//                                                                  //
//  File name : packet_rx_monitor.sv                                //
//  Author    : G. Andres Mancera                                   //
//  License   : GNU Lesser General Public License                   //
//  Course    : System and Functional Verification Using UVM        //
//              UCSC Silicon Valley Extension                       //
//                                                                  //
//////////////////////////////////////////////////////////////////////
`ifndef PACKET_RX_MONITOR__SV
`define PACKET_RX_MONITOR__SV


class packet_rx_monitor extends uvm_monitor;

  virtual xge_mac_interface     mon_vi;
  int unsigned                  m_num_captured;
  uvm_analysis_port #(packet)   ap_rx_mon;

  `uvm_component_utils( packet_rx_monitor )

  function new(input string name="packet_rx_monitor", input uvm_component parent);
    super.new(name, parent);
  endfunction : new


  virtual function void build_phase(input uvm_phase phase);
    super.build_phase(phase);
    m_num_captured = 0;
    ap_rx_mon = new ( "ap_rx_mon", this );
    uvm_config_db#(virtual xge_mac_interface)::get(this, "", "mon_vi", mon_vi);
    if ( mon_vi==null )
      `uvm_fatal(get_name(), "Virtual Interface for monitor not set!");
  endfunction : build_phase


  virtual task run_phase(input uvm_phase phase);
    packet      rcv_pkt;
    bit         pkt_in_progress = 0;
    bit         err_in_packet = 0;
    bit [7:0]   rx_data_q[$];
    int         idx;
    bit         packet_captured = 0;

    `uvm_info( get_name(), $sformatf("HIERARCHY: %m"), UVM_HIGH);
    // Initial assignment for pkt_rx interface signals.
    mon_vi.mon_cb.pkt_rx_ren    <= 1'b0;

    forever begin
      @(mon_vi.mon_cb)
      begin
        if ( mon_vi.mon_cb.pkt_rx_avail ) begin
          mon_vi.mon_cb.pkt_rx_ren <= 1'b1;
        end
        if ( mon_vi.mon_cb.pkt_rx_val ) begin
          if ( mon_vi.mon_cb.pkt_rx_sop && !mon_vi.mon_cb.pkt_rx_eop && pkt_in_progress==0 ) begin
            // -------------------------------- SOP cycle ----------------
            rcv_pkt = packet::type_id::create("rcv_pkt", this);
            pkt_in_progress = 1;
            mon_vi.mon_cb.pkt_rx_ren <= 1'b1;
            rcv_pkt.sop_mark            = mon_vi.mon_cb.pkt_rx_sop;
            rcv_pkt.mac_dst_addr        = mon_vi.mon_cb.pkt_rx_data[63:16];
            rcv_pkt.mac_src_addr[47:32] = mon_vi.mon_cb.pkt_rx_data[15:0];
            rcv_pkt.mac_src_addr[31:0]  = 32'h0;
            rcv_pkt.ether_type          = 16'h0;
            rcv_pkt.payload = new[0];
            while ( rx_data_q.size()>0 ) begin
              rx_data_q.pop_front();
            end
          end   // ---------------------------- SOP cycle ----------------
          if ( !mon_vi.mon_cb.pkt_rx_sop && !mon_vi.mon_cb.pkt_rx_eop && pkt_in_progress==1 ) begin
            // -------------------------------- MOP cycle ----------------
            pkt_in_progress = 1;
            mon_vi.mon_cb.pkt_rx_ren <= 1'b1;
            if ( rx_data_q.size()==0 ) begin
              rcv_pkt.mac_src_addr[31:0]  = mon_vi.mon_cb.pkt_rx_data[63:32];
              rcv_pkt.ether_type          = mon_vi.mon_cb.pkt_rx_data[31:16];
              rx_data_q.push_back(mon_vi.mon_cb.pkt_rx_data[15:8]);
              rx_data_q.push_back(mon_vi.mon_cb.pkt_rx_data[7:0]);
            end
            else begin
              for ( int i=0; i<8; i++ ) begin
                rx_data_q.push_back( (mon_vi.mon_cb.pkt_rx_data >> (64-8*(i+1))) & 8'hFF );
              end
            end
          end   // ---------------------------- MOP cycle ----------------
          if ( mon_vi.mon_cb.pkt_rx_eop && pkt_in_progress==1 ) begin
            // -------------------------------- EOP cycle ----------------
            rcv_pkt.eop_mark= mon_vi.mon_cb.pkt_rx_eop;
            pkt_in_progress = 0;
            err_in_packet   = mon_vi.mon_cb.pkt_rx_err;
            mon_vi.mon_cb.pkt_rx_ren <= 1'b0;
            if ( mon_vi.mon_cb.pkt_rx_mod==0 ) begin
              for ( int i=0; i<8; i++ ) begin
                rx_data_q.push_back( (mon_vi.mon_cb.pkt_rx_data >> (64-8*(i+1))) & 8'hFF );
              end
            end
            else begin
              for ( int i=0; i<mon_vi.mon_cb.pkt_rx_mod; i++ ) begin
                rx_data_q.push_back( (mon_vi.mon_cb.pkt_rx_data >> (64-8*(i+1))) & 8'hFF );
              end
            end
            rcv_pkt.payload = new[rx_data_q.size()];
            idx = 0;
            while ( rx_data_q.size()>0 ) begin
              rcv_pkt.payload[idx]  = rx_data_q.pop_front();
              idx++;
            end
            packet_captured  = 1;
            // -------------------------------- EOP cycle ----------------
          end
          if ( mon_vi.mon_cb.pkt_rx_sop && mon_vi.mon_cb.pkt_rx_eop && pkt_in_progress==0) begin
            // -------------------------------- SOP/EOP cycle ------------
            rcv_pkt = packet::type_id::create("rcv_pkt", this);
            err_in_packet   = mon_vi.mon_cb.pkt_rx_err;
            mon_vi.mon_cb.pkt_rx_ren <= 1'b1;
            rcv_pkt.sop_mark            = mon_vi.mon_cb.pkt_rx_sop;
            rcv_pkt.eop_mark            = mon_vi.mon_cb.pkt_rx_eop;
            rcv_pkt.mac_dst_addr        = mon_vi.mon_cb.pkt_rx_data[63:16];
            rcv_pkt.mac_src_addr[47:32] = mon_vi.mon_cb.pkt_rx_data[15:0];
            rcv_pkt.mac_src_addr[31:0]  = 32'h0;
            rcv_pkt.ether_type          = 16'h0;
            rcv_pkt.payload = new[0];
            while ( rx_data_q.size()>0 ) begin
              rx_data_q.pop_front();
            end
            packet_captured = 1;
            // -------------------------------- SOP/EOP cycle ------------
          end
          if ( packet_captured ) begin
            `uvm_info( get_name(), $psprintf("Packet: \n%0s", rcv_pkt.sprint()), UVM_HIGH)
            if ( !err_in_packet && rcv_pkt.sop_mark && rcv_pkt.eop_mark ) begin
              ap_rx_mon.write( rcv_pkt );
              m_num_captured++;
            end
            packet_captured = 0;
          end
        end
      end
    end
  endtask : run_phase


  function void report_phase( uvm_phase phase );
    `uvm_info( get_name( ), $sformatf( "REPORT: Captured %0d packets", m_num_captured ), UVM_LOW )
  endfunction : report_phase

endclass : packet_rx_monitor

`endif  //PACKET_RX_MONITOR__SV
