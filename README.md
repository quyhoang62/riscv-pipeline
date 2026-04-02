# RISC-V 5-stage pipeline (Verilog)

Bộ xử lý RISC-V 32-bit theo kiến trúc **pipeline 5 giai đoạn** (IF → ID → EX → MEM → WB), có **forwarding** (bypass) và xử lý **load-use stall** cùng **flush** khi nhánh/nhảy được thực hiện.

## Cấu trúc thư mục

```
riscv_pipeline/
├── src/                 # Mã nguồn RTL
│   ├── pp_top.v         # Top-level pipeline
│   ├── forwarding_unit.v
│   ├── alu.v
│   ├── regfile.v
│   ├── imm_gen.v
│   ├── branch_comp.v
│   ├── controller.v
│   ├── imem.v
│   └── dmem.v
├── tb/                  # Testbench
│   └── tb_pp_top.v
├── mem/                 # Khởi tạo bộ nhớ (hex)
│   ├── instr_mem.hex
│   └── data_mem.hex
└── sim/                 # Kết quả mô phỏng (tạo khi chạy simulator)
```

## Tính năng chính

- **Pipeline**: IF/ID, ID/EX, EX/MEM, MEM/WB; PC và thanh ghi đồng bộ theo `clk`.
- **Forwarding**: `forwarding_unit.v` sinh `forward_a` / `forward_b` (ưu tiên EX/MEM trước MEM/WB), áp dụng cho toán hạng ALU và dữ liệu store.
- **Hazard**:
  - **Load-use**: dừng PC và IF/ID, chèn bubble vào ID/EX khi lệnh load ở EX cần được dùng ngay ở ID.
  - **Control**: khi branch/jump taken, làm sạch IF/ID (NOP) và bubble ID/EX.

Chạy mô phỏng từ **thư mục gốc dự án** (`riscv_pipeline/`) để đường dẫn `mem/instr_mem.hex` và `mem/data_mem.hex` trong `imem.v` / `dmem.v` khớp với file thật.

## File bộ nhớ

- **`mem/instr_mem.hex`**: mỗi dòng một từ 32-bit (hex), không prefix `0x`. `imem` đọc theo chỉ số từ `addr[31:2]`.
- **`mem/data_mem.hex`**: byte-hex theo thứ tự bộ nhớ byte (dùng cho `$readmemh` trong `dmem`).

## Mô phỏng

### Icarus Verilog (iverilog / vvp)

```bash
cd riscv_pipeline
iverilog -g2012 -o sim/a.out src/*.v tb/tb_pp_top.v
vvp sim/a.out
```

### ModelSim / Questa (ví dụ)

```bash
cd riscv_pipeline
vlog src/*.v tb/tb_pp_top.v
vsim -c tb_pp_top -do "run -all; quit"
```

Điều chỉnh lệnh compile theo công cụ bạn dùng; module đỉnh testbench là `tb_pp_top`.

## Yêu cầu

- Trình biên dịch/mô phỏng Verilog (SystemVerilog không bắt buộc; code dùng Verilog-2001 tương thích rộng).

## Giấy phép

Dự án học tập / tham khảo — thêm giấy phép nếu cần phân phối lại.
# riscv-pipeline
