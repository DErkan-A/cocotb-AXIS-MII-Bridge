# ==============================================================================
# Authors:              Martin Zabel
#
# Cocotb Testbench:     For D flip-flop
#
# Description:
# ------------------------------------
# Automated testbench for simple D flip-flop.
#
# License:
# ==============================================================================
# Copyright 2016 Technische Universitaet Dresden - Germany
# Chair for VLSI-Design, Diagnostics and Architecture
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ==============================================================================

import random
import warnings
import itertools
import logging
import os

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge,RisingEdge
from cocotb.monitors import Monitor
from cocotb.binary import BinaryValue
from cocotb.regression import TestFactory
from cocotb.scoreboard import Scoreboard
from cocotb.bus import Bus
from cocotbext.axi import AxiStreamFrame, AxiStreamSource, AxiStreamBus

STREAM_DATA_WIDTH=256
KEEP_WIDTH=32
MII_DATA_WIDTH=4
ID_DEST_WIDTH=4

async def reset(dut):
    dut.mii_reset_n<=0
    dut.axis_reset_n<=0
    await RisingEdge(dut.mii_clk)
    dut.mii_reset_n<=1
    dut.axis_reset_n<=1
    await RisingEdge(dut.mii_clk)


class MIIMonitor(Monitor): #This only monitor the send data when tx_en is 1
    """Observe a input or output of the DUT."""

    def __init__(self,name, MIIBus, clk, callback=None, event=None):
        self.name = name
        self.MIIBus = MIIBus
        self.clk = clk
        self.count=0
        self.log = logging.getLogger("MIIMonitor")
        self.log.setLevel(logging.DEBUG)
        Monitor.__init__(self, callback, event)

    async def _monitor_recv(self):
        while True:
            # Capture signal at rising edge of clock
            await RisingEdge(self.clk)
            #self.log.info("Received the enable: %s" % self.MIIBus.tx_en.value.binstr)
            if(self.MIIBus.tx_en.value.integer==1):
                self.count=self.count+1               
                self.log.info("Received the byte: %s" % self.MIIBus.txd.value.binstr)
                self._recv(self.MIIBus.txd.value)                

                
class AXIS_to_MII_Model:
    def __init__(self, MIIBus, AXISBus, mii_clk, axis_clk):      
        self.MIIBus=MIIBus
        self.AXISBus=AXISBus
        self.mii_clk=mii_clk
        self.axis_clk=axis_clk
        
        self.preamble_count=0
        self.packet_count=0
        self.output=[]
        self.last_mii_en=0
        self.log = logging.getLogger("Bridge_model")
        self.log.setLevel(logging.DEBUG)
        
    async def _run(self):
        cocotb.fork(self.AXIS_Monitor())
        cocotb.fork(self.MII_Monitor())
            
    async def MII_Monitor(self): # cocotb pops from the front of the list
        while True:
            # Capture signal at falling edge of clock
            await FallingEdge(self.mii_clk)
            if(self.MIIBus.tx_en.value.integer!=self.last_mii_en): # count the preambles
                if(self.MIIBus.tx_en.value.integer==1):
                    self.output.insert(0,BinaryValue(value=f'{0xD:0>4b}',n_bits=4,bigEndian=False))
                    for x in range(15):
                        self.output.insert(0,BinaryValue(value=f'{0x5:0>4b}',n_bits=4,bigEndian=False))
                    self.preamble_count= self.preamble_count +1
                self.last_mii_en=self.MIIBus.tx_en.value.integer    
            
            if(self.MIIBus.tx_en.value.integer==1): # count the packets
                self.packet_count=self.packet_count+1

    async def AXIS_Monitor(self):
        i=31
        while True:
            # Capture signal at falling edge of clock
            await FallingEdge(self.axis_clk)
            if(self.AXISBus.tready.value.integer==1 and self.AXISBus.tvalid.value.integer==1):
                self.log.info("Received the data: %s" % self.AXISBus.tdata.value.binstr)
                self.log.info("Received the tkeep: %s" % self.AXISBus.tkeep.value.binstr)
                while(self.AXISBus.tkeep.value.binstr[i]=='1' and i>=0): # add all the kept bytes
                    self.output.append(BinaryValue(value=self.AXISBus.tdata.value.binstr[8*i+4:8*i+8],
                    n_bits=4,bigEndian=False))
                    self.output.append(BinaryValue(value=self.AXISBus.tdata.value.binstr[8*i:8*i+4],
                    n_bits=4,bigEndian=False))
                    i=i-1
                i=31    
            

class TB: # revize the model according to the tkeep signal and make sure to write something to add preamble etc to mii expected output when enable toggles
    def __init__(self, dut):
        self.dut = dut
        
        #Create the Buses
        _signals = ["tdata"]
        _optional_signals = ["tvalid", "tready", "tlast", "tkeep", "tid", "tdest", "tuser"]
        self.MyAxisBus = Bus(self.dut, "s_axis", _signals, _optional_signals)
        self.MyMIIBus = Bus(self.dut, "mii", ["txd","tx_en","tx_er"])

        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)
        
        self.source = AxiStreamSource(AxiStreamBus.from_prefix(dut, "s_axis"), dut.axis_clk, dut.axis_reset_n)
        
        #Monitors and expected output list
        self.MII_Mon=MIIMonitor("MII",self.MyMIIBus,dut.mii_clk)
        
        
        #Create the expected output list
        self.model=AXIS_to_MII_Model(self.MyMIIBus,self.MyAxisBus,self.dut.mii_clk,self.dut.axis_clk)
        #Create the scoreboard
        with warnings.catch_warnings():
            warnings.simplefilter("ignore")
            self.scoreboard = Scoreboard(dut)
            
        self.scoreboard.add_interface(self.MII_Mon, self.model.output)    
            
            
    def set_idle_generator(self, generator=None):
        if generator:
            self.source.set_pause_generator(generator())

    async def reset(self):
        self.dut.mii_reset_n<=0
        self.dut.axis_reset_n<=0
        await RisingEdge(self.dut.mii_clk)
        self.dut.mii_reset_n<=1
        self.dut.axis_reset_n<=1
        await RisingEdge(self.dut.mii_clk)
        assert self.MyAxisBus.tready.value.integer==0
        assert self.MyMIIBus.txd.value.integer==0
        assert self.MyMIIBus.tx_en.value.integer==0
        assert self.MyMIIBus.tx_er.value.integer==0
        
async def run_test(dut, payload_lengths=None, payload_data=None, idle_inserter=None):
    """Setup testbench and run a test."""
    cocotb.fork(Clock(dut.mii_clk, 40, 'ns').start(start_high=False))
    cocotb.fork(Clock(dut.axis_clk, 6.4, 'ns').start(start_high=False))
    await reset(dut)
    tb = TB(dut)

    id_count = 2**len(tb.source.bus.tid)

    cur_id = 1
    #Start the clock
   
    await tb.reset()

    tb.set_idle_generator(idle_inserter)

    test_frames = []
    tkeep = bytearray(4)
    
    for x in range(0, 4):
        tkeep[x]=255
    
    for test_data in [payload_data(x) for x in payload_lengths()]:
        test_frame = AxiStreamFrame(test_data)
        test_frame.tid = cur_id
        test_frame.tdest = cur_id
        test_frame.tkeep = tkeep
        await tb.source.send(test_frame)

        test_frames.append(test_frame)
        print("test_data:",test_data)
        

        cur_id = (cur_id + 1) % id_count
        
    #cocotb.fork(tb.source._run())
    await tb.model._run()
    tb.source._handle_reset(0)
    await tb.source.wait()
    
    while(dut.empty_flag.value.integer==0 or dut.mii_tx_en==1 or dut.s_axis_tvalid==1):
        await RisingEdge(dut.axis_clk)
        #print(dut.mii_tx_en.value.binstr, dut.mii_txd.value.binstr) #for manual debug
    # Print result of scoreboard.
    raise tb.scoreboard.result
    
    
    
# Register the test.
def cycle_pause():
    return itertools.cycle([1, 1, 1, 0])


def size_list():
    data_width = STREAM_DATA_WIDTH
    number_bytes = data_width // 8
    return list(range(1, 32))


def incrementing_payload(length):
    return bytearray(itertools.islice(itertools.cycle(range(256)), length))
    
factory = TestFactory(run_test)
factory.add_option("payload_lengths", [size_list])
factory.add_option("payload_data", [incrementing_payload])
factory.add_option("idle_inserter", [None, cycle_pause])
factory.generate_tests()
