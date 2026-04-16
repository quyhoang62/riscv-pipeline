# RISC-V 5-Stage Pipeline (Verilog)

Thiết kế bộ xử lý RISC-V 32-bit theo kiến trúc pipeline 5 giai đoạn:

IF -> ID -> EX -> MEM -> WB

Mục tiêu của dự án là chứng minh đúng chức năng datapath, forwarding và xử lý hazard bằng bộ testbench theo nhóm chức năng, kèm waveform GTKWave để phân tích tín hiệu nội bộ theo chu kỳ.

## 1) Tính năng chính

- Pipeline register đầy đủ: IF/ID, ID/EX, EX/MEM, MEM/WB.
- Forwarding Unit cho ALU input A/B:
  - EX/MEM -> EX (ưu tiên cao hơn)
  - MEM/WB -> EX
  - Bỏ qua rd = x0
  - Chặn forward load ở EX/MEM (load-use cần stall)
- Hazard handling:
  - Load-use stall: giữ PC + IF/ID, chèn bubble vào ID/EX.
  - Control hazard: flush khi branch/jump được lấy.
- Write-back mux hỗ trợ nhiều nguồn:
  - ALU result
  - Memory result
  - PC+4
  - LUI
  - AUIPC
- Debug waveform signals (dbg\_\*) để quan sát nhanh toàn bộ stage.

## 2) Cấu trúc thư mục

```text
riscv_pipeline/
|- src/
|  |- pp_top.v
|  |- forwarding_unit.v
|  |- alu.v
|  |- branch_comp.v
|  |- controller.v
|  |- imm_gen.v
|  |- regfile.v
|  |- imem.v
|  `- dmem.v
|- tb/
|  |- tb_pp_top.v
|  |- tb_reset_basic.v
|  |- tb_rtype_itype_basic.v
|  |- tb_forward_exmem_a_b.v
|  |- tb_forward_memwb.v
|  |- tb_load_use_stall.v
|  |- tb_branch_flush.v
|  |- tb_store_load_wb.v
|  |- tb_branch_data_hazard.v
|  |- tb_x0_cornercase.v
|  `- tb_dependency_chain.v
|- mem/
|  |- instr_mem.hex
|  `- data_mem.hex
`- sim/
   |- *.out
   |- *.vcd
   |- pp_top_debug.gtkw
   `- pp_top_grouped.gtkw
```

## 3) Yêu cầu môi trường

- Windows + PowerShell (hoặc shell tương đương)
- Icarus Verilog:
  - `iverilog`
  - `vvp`
- GTKWave

Ví dụ đường dẫn đang dùng:

- `C:\iverilog\bin\iverilog.exe`
- `C:\iverilog\bin\vvp.exe`
- `C:\iverilog\gtkwave\bin\gtkwave.exe`

## 4) Cách chạy mô phỏng

Luôn chạy từ thư mục gốc dự án để `mem/instr_mem.hex` và `mem/data_mem.hex` được nạp đúng.

### 4.1 Chạy test tổng quát

```powershell
cd E:\riscv_pipeline
C:\iverilog\bin\iverilog.exe -g2012 -o sim\pp_tb.out tb\tb_pp_top.v src\alu.v src\branch_comp.v src\controller.v src\dmem.v src\forwarding_unit.v src\imem.v src\imm_gen.v src\pp_top.v src\regfile.v
C:\iverilog\bin\vvp.exe sim\pp_tb.out
```

### 4.2 Chạy một testbench bất kỳ

Ví dụ với `tb_branch_data_hazard`:

```powershell
cd E:\riscv_pipeline
C:\iverilog\bin\iverilog.exe -g2012 -o sim\tb_branch_data_hazard.out tb\tb_branch_data_hazard.v src\alu.v src\branch_comp.v src\controller.v src\dmem.v src\forwarding_unit.v src\imem.v src\imm_gen.v src\pp_top.v src\regfile.v
C:\iverilog\bin\vvp.exe sim\tb_branch_data_hazard.out
```

Kết quả waveform sẽ nằm ở `sim/tb_branch_data_hazard.vcd`.

## 5) Chạy toàn bộ test suite chức năng

Các testbench chức năng đã có:

- `tb_reset_basic`
- `tb_rtype_itype_basic`
- `tb_forward_exmem_a_b`
- `tb_forward_memwb`
- `tb_load_use_stall`
- `tb_branch_flush`
- `tb_store_load_wb`
- `tb_branch_data_hazard`
- `tb_x0_cornercase`
- `tb_dependency_chain`

Các test này được thiết kế để chứng minh riêng từng nhóm: reset/init, luồng cơ bản, forwarding, stall, flush branch, memory/WB và corner cases.

## 6) Xem waveform bằng GTKWave

### 6.1 Mở VCD trực tiếp

```powershell
cd E:\riscv_pipeline
C:\iverilog\gtkwave\bin\gtkwave.exe sim\tb_branch_data_hazard.vcd
```

### 6.2 Mở layout có sẵn

```powershell
cd E:\riscv_pipeline
C:\iverilog\gtkwave\bin\gtkwave.exe sim\pp_top_debug.gtkw
C:\iverilog\gtkwave\bin\gtkwave.exe sim\pp_top_grouped.gtkw
```

Nhóm tín hiệu quan trọng nên theo dõi:

- `dbg_pc`, `dbg_pc_next`
- `dbg_if_id_*`, `dbg_id_ex_*`
- `dbg_fwd_a`, `dbg_fwd_b`
- `dbg_stall`, `dbg_flush`, `dbg_br_take`
- `dbg_mem_*`
- `dbg_wb_data`
