import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ReadOnly, ClockCycles
from cocotb_bus.bus import Bus
import random

# Reset DUT coro
async def reset_dut(clock, rst_n, cycles):
    rst_n.value = 0
    await ClockCycles(clock, cycles)
    rst_n.value = 1
    rst_n._log.debug("Reset complete")

# Balance credits 
async def balance_credits(use, clock):
    use.value = 1
    await ClockCycles(clock, 4)
    use.value = 0

# Driver basic coro
async def driver(drive_en, clk, count, limit: int):
    while True:
        drive_trigger = (random.randint(0,2)==2) and count!=limit
        if drive_trigger:
            drive_en.value = 1 
        else:
            drive_en.value = 0 
        await ReadOnly()
        await RisingEdge(clk)

# Main test
@cocotb.test()
async def basic_test(dut):

    # Start clock
    cocotb.start_soon(Clock(dut.clk, 1, 'ns').start())

    # Initialize some values
    dut.crd_grnt_val.value = 1
    dut.crd_grnt_en.value = 0 
    dut.crd_used_val.value = 1 
    dut.crd_used_en.value = 0 

    # Reset DUT
    await cocotb.start_soon(reset_dut(dut.clk, dut.rst_n, 5))

    # Balance credits
    await cocotb.start_soon(balance_credits(dut.crd_used_en, dut.clk))

    # Start driving push and pop
    granter = cocotb.start_soon(driver(dut.crd_grnt_en, dut.clk, dut.crd_cnt, 8))
    user = cocotb.start_soon(driver(dut.crd_used_en, dut.clk, dut.crd_cnt, 0))
    
    # Run for some cycles
    await ClockCycles(dut.clk, 64)
    granter.kill()
    user.kill()
