import cocotb
from cocotb.triggers import FallingEdge, Timer, RisingEdge
from cocotb.clock import Clock
import numpy as np

# Reset inputs to 0, reset is active
async def reset_test(dut):
    dut.rst_n.value = 0 # Enable reset
    dut.vld_in.value = 0 # Enable reset
    dut.ter.value = 0 # Enable reset
    dut.data_in.value = 0 # Enable reset
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1 # Disable reset

# drive new valid input to data_in
async def drive_data(dut):
    dut.vld_in.value = 1 
    dut.data_in = np.random.randint(low=0, high=15)
    await RisingEdge(dut.clk)
    dut.vld_in.value = 0

@cocotb.test()
async def my_test(dut):
    cocotb.start_soon(Clock(dut.clk, 1, units="ns").start())
    await reset_test(dut)
    for _ in range(24):
        await drive_data(dut)
    await reset_test(dut)
